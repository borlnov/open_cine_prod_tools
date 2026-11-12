// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_deterministic_role_id.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'ocpt_project_database_ddl_fixtures.dart';

// This file is the harness that pins each stable release's upgrade path
// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`). The 0.1.0 release froze the
// schema at v1; the 0.2.0 release froze v2 — `OcptSyncRelayCursorsTable` and
// `OcptSyncPairingsTable`, both local, never-synchronised tables the changeset engine and its relay
// transport add, plus `budget_lines.in_kind_resource_id`; the 0.2.1 release froze v3 —
// `shot_characters` reshaped from `{shotId, characterName}` to `{shotId, roleId}`; the 0.3.0
// release froze v4 — the five storyboard and floor plan tables; the 0.3.1 release froze v5 — no
// table reshaped, the `labelText` stamps of `storyboard_annotations` renamed to `text`.
//
// ADR 0029 ties a verbatim DDL fixture to each frozen release, one for the schema the *previous*
// stable shipped — the shape a real file from that release was left with, migrated forward and
// checked against `onCreate`. [v1Ddl] is the v1 fixture (a real 0.1.0 file), added when 0.2.0
// froze v2; [v2Ddl] is the v2 fixture (a real 0.2.0 file), added when 0.2.1 froze v3; [v3Ddl] is
// the v3 fixture (a real 0.2.1 file), added while v4 was still open, so that cycle's upgrade path
// was exercised before 0.3.0 froze it; [v4Ddl] is the v4 fixture (a real 0.3.0 file), added while
// v5 was still open, for the same reason, and v5 reshaped no table, so it is also the shape a real
// 0.3.1 file holds. Each is a hand-held copy of the real `CREATE TABLE`
// statements, never built through drift, so the test proves `onCreate` still reproduces migrating
// that real file forward rather than merely rewriting the same "undo the last upgrade" trick the
// schema's own `onUpgrade` doc comment already describes.

/// Run the tests of the project database migration.
void main() {
  test('currentSchemaVersion is always lastStableSchemaVersion or one above it', () {
    final current = OcptProjectDatabase.currentSchemaVersion;
    final lastStable = OcptProjectDatabase.lastStableSchemaVersion;

    expect(
      current == lastStable || current == lastStable + 1,
      isTrue,
      reason:
          'currentSchemaVersion ($current) must equal lastStableSchemaVersion ($lastStable) '
          'when the top migration file is frozen, or lastStableSchemaVersion + 1 when a '
          'development cycle is open: a cycle never bumps the schema version twice.',
    );
  });

  test('a fresh in-memory database opens and holds every table onCreate declares', () async {
    final database = OcptProjectDatabase.memory();
    addTearDown(database.close);

    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = {for (final row in tables) row.data['name'] as String};

    // A representative sample spanning every area the database holds (see
    // `OcptProjectDatabase`'s own class doc comment): opening succeeds only if `onCreate` ran
    // `m.createAll()` against the full `@DriftDatabase` table list without error.
    expect(
      tableNames,
      containsAll(<String>[
        'project_info',
        'screenplays',
        'scenes',
        'shots',
        'row_field_versions',
        'project_versions',
        'people',
        'roles',
        'locations',
        'elements',
        'breakdown_tags',
        'scene_breakdowns',
        'shooting_days',
        'shooting_slots',
        'budget_postes',
        'budget_entries',
        'budget_resources',
        'budget_revenues',
        'budget_allowances',
        'sync_relay_cursors',
        'sync_pairings',
      ]),
    );

    final userVersion = await database.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
  });

  test('a v1 database migrates to v2, keeping its rows, gaining the two empty local tables and the '
      'budget_lines.in_kind_resource_id column', () async {
    final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v1_to_v2_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final filePath = p.join(tempDir.path, 'movie.ocpt');

    // The migration from 1 to 2 is additive-only and only ever creates `sync_relay_cursors` and
    // `sync_pairings`, and adds `budget_lines.in_kind_resource_id`
    // (`OcptProjectDatabase.migration`'s own doc comment): a real v1 file is therefore exactly what
    // `onCreate` produces here minus those two tables, that column, and — from schema version 3 on
    // — minus `shot_characters`' reshape to `{shotId, roleId}`
    // (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), undone below by recreating
    // the table in its frozen v1/v2 shape. Seed a real database at the current schema, then undo
    // those additions by hand — the same trick `home_bloc_recent_projects_and_import_test.dart`'s
    // `createProjectAtPreviousFormat` uses — so reopening it exercises the real `onUpgrade` step
    // rather than a fixture standing in for it. [v1Ddl] below covers the structural side of the
    // same claim, verbatim rather than by undoing the current schema.
    final seeded = OcptProjectDatabase(File(filePath));
    await seeded
        .into(seeded.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: 's1', title: 'Draft', updatedAt: DateTime(2026)),
        );
    await seeded.close();

    final raw = sqlite3.open(filePath);
    raw
      ..execute('DROP TABLE sync_relay_cursors')
      ..execute('DROP TABLE sync_pairings')
      ..execute('ALTER TABLE budget_lines DROP COLUMN in_kind_resource_id')
      // Undoes schema version 3's reshape of `shot_characters` (empty here, so a plain
      // drop-and-recreate loses nothing): a v1/v2 file never had `role_id` at all.
      ..execute('DROP TABLE shot_characters')
      ..execute(
        'CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), '
        '"character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, '
        '"sort_key" TEXT NOT NULL DEFAULT \'\', '
        '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
        'PRIMARY KEY ("shot_id", "character_name"))',
      )
      ..execute('PRAGMA user_version = 1')
      ..dispose();

    final migrated = OcptProjectDatabase(File(filePath));
    addTearDown(migrated.close);

    final screenplays = await migrated.select(migrated.ocptScreenplaysTable).get();
    expect(screenplays, hasLength(1));
    expect(screenplays.single.id, 's1');
    expect(screenplays.single.title, 'Draft');

    final cursorsBeforeInsert = await migrated.select(migrated.ocptSyncRelayCursorsTable).get();
    expect(cursorsBeforeInsert, isEmpty);
    final pairingsBeforeInsert = await migrated.select(migrated.ocptSyncPairingsTable).get();
    expect(pairingsBeforeInsert, isEmpty);

    await migrated
        .into(migrated.ocptSyncRelayCursorsTable)
        .insert(OcptSyncRelayCursorsTableCompanion.insert(relayId: 'relay-1'));
    final cursorsAfterInsert = await migrated.select(migrated.ocptSyncRelayCursorsTable).get();
    expect(cursorsAfterInsert, hasLength(1));
    expect(cursorsAfterInsert.single.lastAppliedSequence, 0);
    expect(cursorsAfterInsert.single.outboxHighWaterMark, 0);

    await migrated
        .into(migrated.ocptSyncPairingsTable)
        .insert(
          OcptSyncPairingsTableCompanion.insert(
            projectId: 'p1',
            relayBaseUrl: 'https://relay.example.org/',
          ),
        );
    final pairingsAfterInsert = await migrated.select(migrated.ocptSyncPairingsTable).get();
    expect(pairingsAfterInsert, hasLength(1));
    expect(pairingsAfterInsert.single.relayBaseUrl, 'https://relay.example.org/');

    final budgetLinesColumns = await migrated.customSelect('PRAGMA table_info(budget_lines)').get();
    expect(budgetLinesColumns.map((row) => row.data['name']), contains('in_kind_resource_id'));

    final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
  });

  test(
    'onCreate reproduces exactly what migrating the verbatim v1 fixture forward produces',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v1_fixture_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // [v1Ddl] is created with the raw sqlite3 binding, deliberately never through drift or
      // `OcptProjectDatabase`: that is what makes it a fixture of the frozen v1 shape rather than
      // just another way of asking drift to build the current one.
      final raw = sqlite3.open(filePath);
      for (final statement in v1Ddl) {
        raw.execute(statement);
      }
      raw
        ..execute('PRAGMA user_version = 1')
        ..dispose();

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);
      final migratedShape = _schemaShape(await _tableSqlByName(migrated));

      final fresh = OcptProjectDatabase.memory();
      addTearDown(fresh.close);
      final freshShape = _schemaShape(await _tableSqlByName(fresh));

      // Compared clause by clause, table by table, rather than as whole `CREATE TABLE` strings:
      // `ALTER TABLE ... ADD COLUMN` (`OcptProjectDatabase.migration`'s `m.addColumn` call) always
      // appends the new column at the end of SQLite's own stored schema text, wherever the
      // `OcptBudgetLinesTable` class itself declares it — a real difference in the two engines'
      // output that carries no shape change at all, and a literal string compare of `budget_lines`
      // would wrongly report as one.
      expect(migratedShape, freshShape);

      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );

  test(
    'onCreate reproduces exactly what migrating the verbatim v2 fixture forward produces',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v2_fixture_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // [v2Ddl] is created with the raw sqlite3 binding, deliberately never through drift or
      // `OcptProjectDatabase`: that is what makes it a fixture of the frozen v2 shape a real 0.2.0
      // file was left with, rather than just another way of asking drift to build the current one.
      final raw = sqlite3.open(filePath);
      for (final statement in v2Ddl) {
        raw.execute(statement);
      }
      raw
        ..execute('PRAGMA user_version = 2')
        ..dispose();

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);
      final migratedShape = _schemaShape(await _tableSqlByName(migrated));

      final fresh = OcptProjectDatabase.memory();
      addTearDown(fresh.close);
      final freshShape = _schemaShape(await _tableSqlByName(fresh));

      // Compared clause by clause, table by table, as with the v1 fixture above: the v2 to v3 step
      // drops and recreates `shot_characters` (empty here, so nothing is lost), and its recreated
      // shape must match what `onCreate` builds.
      expect(migratedShape, freshShape);

      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );

  test(
    'onCreate reproduces exactly what migrating the verbatim v3 fixture forward to v4 produces',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v3_fixture_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // [v3Ddl] is created with the raw sqlite3 binding, deliberately never through drift or
      // `OcptProjectDatabase`: that is what makes it a fixture of the frozen v3 shape a real 0.2.1
      // file was left with, rather than just another way of asking drift to build the current one.
      final raw = sqlite3.open(filePath);
      for (final statement in v3Ddl) {
        raw.execute(statement);
      }
      raw
        ..execute('PRAGMA user_version = 3')
        ..dispose();

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);
      final migratedShape = _schemaShape(await _tableSqlByName(migrated));

      final fresh = OcptProjectDatabase.memory();
      addTearDown(fresh.close);
      final freshShape = _schemaShape(await _tableSqlByName(fresh));

      // Compared clause by clause, table by table, as with the v1 and v2 fixtures above: the v3 to
      // v4 step is purely additive — five `createTable` calls, nothing else — and their shape must
      // match what `onCreate` builds for the same five tables.
      expect(migratedShape, freshShape);

      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );

  test(
    'onCreate reproduces exactly what migrating the verbatim v4 fixture forward to v5 produces',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v4_fixture_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // [v4Ddl] is created with the raw sqlite3 binding, deliberately never through drift or
      // `OcptProjectDatabase`: that is what makes it a fixture of the frozen v4 shape a real 0.3.0
      // file was left with, rather than just another way of asking drift to build the current one.
      final raw = sqlite3.open(filePath);
      for (final statement in v4Ddl) {
        raw.execute(statement);
      }
      raw
        ..execute(
          'INSERT INTO row_field_versions (table_name, row_id, column_name, version, device_id) '
          "VALUES ('storyboard_annotations', 'a1', 'labelText', 3, 'dev-1')",
        )
        ..execute('PRAGMA user_version = 4')
        ..dispose();

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);
      final migratedShape = _schemaShape(await _tableSqlByName(migrated));

      final fresh = OcptProjectDatabase.memory();
      addTearDown(fresh.close);
      final freshShape = _schemaShape(await _tableSqlByName(fresh));

      // Compared clause by clause, table by table, as with the earlier fixtures: the v4 to v5 step
      // reshapes no table, so the file must already hold what `onCreate` builds.
      expect(migratedShape, freshShape);

      final stamp = await migrated
          .customSelect(
            'SELECT column_name FROM row_field_versions '
            "WHERE table_name = 'storyboard_annotations'",
          )
          .getSingle();
      expect(stamp.data['column_name'], 'text', reason: 'the v5 step renamed the stamp');
      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );

  // Schema version 3's own step: `shot_characters` reshaped from `{shotId, characterName}` to
  // `{shotId, roleId}` (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), carried
  // out by `ocptMigrateToSchemaV3`. [_seedV2FixtureAt] below is a v2-schema fixture whose shot
  // names variously match a live role, a live-but-orphaned role, and no role at all (live and
  // tombstoned alike) — the three cases the migration has to tell apart.
  group('schema v3 migration: shot_characters becomes roleId-keyed', () {
    test('every attachment survives on the right role: a matched live role, a matched orphaned '
        'role, and a freshly minted one for an unmatched name, live or tombstoned', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v2_to_v3_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      await _seedV2FixtureAt(filePath);

      final migrated = OcptProjectDatabase(File(filePath));
      addTearDown(migrated.close);

      final ghostRoleId = ocptDeterministicRoleId('GHOST');
      final phantomRoleId = ocptDeterministicRoleId('PHANTOM');

      final characterRows = await migrated.select(migrated.ocptShotCharactersTable).get();
      final byShotId = <String, List<OcptShotCharacterRow>>{};
      for (final row in characterRows) {
        byShotId.putIfAbsent(row.shotId, () => []).add(row);
      }

      expect(byShotId['shot-a']!.single.roleId, 'role-clara');
      expect(byShotId['shot-a']!.single.isDeleted, isFalse);
      expect(byShotId['shot-b']!.single.roleId, 'role-marc');
      expect(byShotId['shot-b']!.single.isDeleted, isFalse);

      final shotCRows = {for (final row in byShotId['shot-c']!) row.roleId: row};
      expect(shotCRows.keys, {ghostRoleId, phantomRoleId});
      expect(shotCRows[ghostRoleId]!.isDeleted, isFalse);
      expect(shotCRows[phantomRoleId]!.isDeleted, isTrue);

      // Exactly one role minted per unmatched name, hand-added and silent (ADR 0030, decision
      // 6), and the two pre-existing roles (one of them orphaned) untouched.
      final roleRows = await migrated.select(migrated.ocptRolesTable).get();
      final roleById = {for (final role in roleRows) role.id: role};
      expect(roleRows, hasLength(4));
      expect(roleById['role-clara']!.orphanedName, isNull);
      expect(roleById['role-marc']!.orphanedName, 'MARC');
      for (final mintedId in [ghostRoleId, phantomRoleId]) {
        final minted = roleById[mintedId]!;
        expect(minted.isFromScreenplay, isFalse);
        expect(minted.isDeleted, isFalse);
        expect(minted.castingNotes, '');
      }
      expect(roleById[ghostRoleId]!.kind, OcptRoleKind.silent);
      expect(roleById[ghostRoleId]!.name, 'GHOST');
      expect(roleById[phantomRoleId]!.kind, OcptRoleKind.silent);
      expect(roleById[phantomRoleId]!.name, 'PHANTOM');

      // Each minted role gained exactly one `role_episodes` link, to shot-c's own screenplay,
      // at the deterministic id `ocptDeterministicRoleEpisodeId` computes — no stamp of its own
      // (asserted below), so its identity alone is what a second replica would converge on.
      final linkRows = await migrated.select(migrated.ocptRoleEpisodesTable).get();
      final linksByRoleId = <String, List<OcptRoleEpisodeRow>>{};
      for (final link in linkRows) {
        linksByRoleId.putIfAbsent(link.roleId, () => []).add(link);
      }
      for (final mintedId in [ghostRoleId, phantomRoleId]) {
        final link = linksByRoleId[mintedId]!.single;
        expect(link.screenplayId, 's1');
        expect(link.id, ocptDeterministicRoleEpisodeId(roleId: mintedId, screenplayId: 's1'));
        expect(link.isDeleted, isFalse);
      }

      // The stamp rekey: every one of the fixture's 20 `shot_characters` stamps (4 rows × 5
      // columns) survives, moved to its row's new key, `characterName` renamed to `roleId` —
      // and nothing new is fabricated for the roles or links minted above.
      final stampRows = await (migrated.select(
        migrated.ocptRowFieldVersionsTable,
      )..where((table) => table.targetTableName.equals('shot_characters'))).get();
      expect(stampRows, hasLength(20));
      for (final (expectedShotId, roleId) in [
        ('shot-a', 'role-clara'),
        ('shot-b', 'role-marc'),
        ('shot-c', ghostRoleId),
        ('shot-c', phantomRoleId),
      ]) {
        final rowId = ocptCompositeRowStampKey([expectedShotId, roleId]);
        final ownStamps = {
          for (final stamp in stampRows)
            if (stamp.rowId == rowId) stamp.columnName: stamp,
        };
        expect(ownStamps.keys, {'shotId', 'roleId', 'position', 'sortKey', 'isDeleted'});
        for (final stamp in ownStamps.values) {
          expect(stamp.version, 5);
          expect(stamp.deviceId, 'device-fixture');
        }
      }

      final roleStamps = await (migrated.select(
        migrated.ocptRowFieldVersionsTable,
      )..where((table) => table.targetTableName.isIn(['roles', 'role_episodes']))).get();
      expect(roleStamps, isEmpty);
    });

    test('two replicas migrating the same v2 file independently converge: same minted role and '
        'link ids, same rekeyed stamps', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v2_convergence_');
      addTearDown(() => tempDir.delete(recursive: true));
      final pathA = p.join(tempDir.path, 'replica-a.ocpt');
      final pathB = p.join(tempDir.path, 'replica-b.ocpt');

      await _seedV2FixtureAt(pathA);
      await _seedV2FixtureAt(pathB);

      final replicaA = OcptProjectDatabase(File(pathA));
      final replicaB = OcptProjectDatabase(File(pathB));
      addTearDown(replicaA.close);
      addTearDown(replicaB.close);

      Future<List<Map<String, Object?>>> canonicalRowsOf(
        OcptProjectDatabase database,
        String tableName,
        List<String> orderColumns,
      ) async {
        final rows = await database
            .customSelect(
              'SELECT * FROM "$tableName" ORDER BY '
              '${orderColumns.map((column) => '"$column"').join(', ')}',
            )
            .get();
        return [for (final row in rows) row.data];
      }

      expect(
        await canonicalRowsOf(replicaA, 'shot_characters', ['shot_id', 'role_id']),
        await canonicalRowsOf(replicaB, 'shot_characters', ['shot_id', 'role_id']),
      );
      expect(
        await canonicalRowsOf(replicaA, 'roles', ['id']),
        await canonicalRowsOf(replicaB, 'roles', ['id']),
      );
      expect(
        await canonicalRowsOf(replicaA, 'role_episodes', ['id']),
        await canonicalRowsOf(replicaB, 'role_episodes', ['id']),
      );
      expect(
        await canonicalRowsOf(replicaA, 'row_field_versions', [
          'table_name',
          'row_id',
          'column_name',
        ]),
        await canonicalRowsOf(replicaB, 'row_field_versions', [
          'table_name',
          'row_id',
          'column_name',
        ]),
      );
    });
  });
}

/// Builds a v2-schema `.ocpt` fixture at [filePath]: one screenplay ('s1') and three shots
/// ('shot-a', 'shot-b', 'shot-c'), with `shot_characters` rows in the frozen v2 shape
/// (`{shotId, characterName}`) covering the three cases the schema v3 migration has to tell apart —
/// 'shot-a' names "CLARA", matching the live, from-screenplay role `role-clara`; 'shot-b' names
/// "MARC", matching `role-marc`, a live role that happens to be orphaned (`orphanedName` set, but
/// not tombstoned — still a live-role match, exactly as an ordinary one); 'shot-c' carries two
/// names matching no role at all, one live ("GHOST") and one tombstoned ("PHANTOM"), so the
/// migration mints a role for each regardless of liveness. Every `shot_characters` row is stamped
/// across all five of its columns in `row_field_versions`, at a fixed version and device id, so the
/// migration test can assert the stamp rekey as well as the row mapping.
///
/// Every table but `shot_characters` is seeded through the typed API, since only that one's shape
/// differs between v2 and v3 — a real v2 file already carries `sync_relay_cursors`, `sync_pairings`
/// and `budget_lines.in_kind_resource_id`, schema version 2's own frozen addition, which a fresh
/// [OcptProjectDatabase] already creates. `shot_characters` itself, and its own stamps, go in
/// through raw SQL against the v2 shape instead: the same trick `createProjectAtPreviousFormat` in
/// `test/ui/pages/home/home_bloc_recent_projects_and_import_test.dart` uses.
///
/// Every id here is a fixed literal rather than a freshly generated UUID, which is what makes this
/// fixture reproducible byte-for-byte between two calls at two different paths — the convergence
/// test's whole premise.
Future<void> _seedV2FixtureAt(String filePath) async {
  final seeded = OcptProjectDatabase(File(filePath));

  await seeded
      .into(seeded.ocptScreenplaysTable)
      .insert(
        OcptScreenplaysTableCompanion.insert(
          id: 's1',
          title: 'Draft',
          updatedAt: DateTime.utc(2026),
        ),
      );
  await seeded.batch((batch) {
    batch.insertAll(seeded.ocptShotsTable, [
      OcptShotsTableCompanion.insert(id: 'shot-a', screenplayId: 's1', position: 0),
      OcptShotsTableCompanion.insert(id: 'shot-b', screenplayId: 's1', position: 1),
      OcptShotsTableCompanion.insert(id: 'shot-c', screenplayId: 's1', position: 2),
    ]);
    batch.insertAll(seeded.ocptRolesTable, [
      OcptRolesTableCompanion.insert(
        id: 'role-clara',
        name: 'CLARA',
        sortKey: const Value('A'),
        kind: OcptRoleKind.speaking,
        isFromScreenplay: const Value(true),
      ),
      OcptRolesTableCompanion.insert(
        id: 'role-marc',
        name: 'MARC',
        sortKey: const Value('B'),
        kind: OcptRoleKind.speaking,
        isFromScreenplay: const Value(true),
        orphanedName: const Value('MARC'),
      ),
    ]);
    batch.insertAll(seeded.ocptRoleEpisodesTable, [
      OcptRoleEpisodesTableCompanion.insert(
        id: 'link-clara',
        roleId: 'role-clara',
        screenplayId: 's1',
      ),
      OcptRoleEpisodesTableCompanion.insert(
        id: 'link-marc',
        roleId: 'role-marc',
        screenplayId: 's1',
      ),
    ]);
  });

  await seeded.close();

  final raw = sqlite3.open(filePath);
  raw
    ..execute('DROP TABLE shot_characters')
    ..execute(
      'CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), '
      '"character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, '
      '"sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
      'PRIMARY KEY ("shot_id", "character_name"))',
    );

  void insertCharacter({
    required String shotId,
    required String name,
    required int position,
    required String sortKey,
    required bool isDeleted,
  }) {
    final isDeletedFlag = isDeleted ? 1 : 0;
    raw.execute(
      'INSERT INTO shot_characters (shot_id, character_name, position, sort_key, is_deleted) '
      'VALUES (?, ?, ?, ?, ?)',
      [shotId, name, position, sortKey, isDeletedFlag],
    );

    for (final column in const ['shotId', 'characterName', 'position', 'sortKey', 'isDeleted']) {
      raw.execute(
        'INSERT INTO row_field_versions (table_name, row_id, column_name, version, device_id) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          'shot_characters',
          ocptCompositeRowStampKey([shotId, name]),
          column,
          5,
          'device-fixture',
        ],
      );
    }
  }

  insertCharacter(shotId: 'shot-a', name: 'CLARA', position: 0, sortKey: 'V', isDeleted: false);
  insertCharacter(shotId: 'shot-b', name: 'MARC', position: 0, sortKey: 'V', isDeleted: false);
  insertCharacter(shotId: 'shot-c', name: 'GHOST', position: 0, sortKey: 'V', isDeleted: false);
  insertCharacter(shotId: 'shot-c', name: 'PHANTOM', position: 1, sortKey: 'k', isDeleted: true);

  raw
    ..execute('PRAGMA user_version = 2')
    ..dispose();
}

/// Every table's own `CREATE TABLE` text, keyed by table name, read off [database]'s
/// `sqlite_master`. SQLite's own automatic indexes (`sqlite_autoindex_...`, one per `PRIMARY KEY`)
/// are excluded: they are not part of the schema anybody wrote, and neither this schema nor its v1
/// fixture declares any explicit index of its own.
Future<Map<String, String>> _tableSqlByName(OcptProjectDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
      )
      .get();

  return {for (final row in rows) row.data['name'] as String: row.data['sql'] as String};
}

/// Turns [tableSql] — a table name mapped to its verbatim `CREATE TABLE` text — into a shape that
/// compares two schemas for the same columns and table constraints regardless of the order SQLite
/// happened to list them in, via [_topLevelClauses].
Map<String, Set<String>> _schemaShape(Map<String, String> tableSql) => {
  for (final entry in tableSql.entries) entry.key: _topLevelClauses(entry.value),
};

/// The column and table-constraint definitions inside a `CREATE TABLE "name" (...)` statement, one
/// entry per comma-separated clause at the statement's own top level — a `CHECK (... IN (0, 1))`
/// column's inner comma is never split on, since it sits one parenthesis deeper.
Set<String> _topLevelClauses(String createTableSql) {
  final inner = createTableSql.substring(
    createTableSql.indexOf('(') + 1,
    createTableSql.lastIndexOf(')'),
  );

  final clauses = <String>{};
  var depth = 0;
  var clauseStart = 0;
  for (var i = 0; i < inner.length; i++) {
    switch (inner[i]) {
      case '(':
        depth++;
      case ')':
        depth--;
      case ',' when depth == 0:
        clauses.add(inner.substring(clauseStart, i).trim());
        clauseStart = i + 1;
    }
  }
  clauses.add(inner.substring(clauseStart).trim());

  return clauses;
}
