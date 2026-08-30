// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

// This file is the harness that will pin each future stable release's upgrade path
// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`). The 0.1.0 release froze the
// schema at v1, and schema version 2 — `OcptSyncRelayCursorsTable`, the changeset engine's own
// local delivery-cursor table — is this cycle's first `onUpgrade` step: `currentSchemaVersion == 2`
// while `lastStableSchemaVersion` stays `1`, per ADR 0029's "a cycle is open" state. A verbatim
// `CREATE TABLE` DDL fixture for the frozen v1 schema, proving `onCreate == every stable upgrade
// path`, is only owed once *this* step is itself frozen by a stable release — that is the moment
// ADR 0029 ties the fixture to, not the step's own authoring — so this file holds none yet. The
// tests below cover what always holds regardless, plus the v1-to-v2 upgrade itself.

void main() {
  test(
    'currentSchemaVersion is always lastStableSchemaVersion or one above it',
    () {
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
    },
  );

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
      ]),
    );

    final userVersion = await database.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
  });

  test(
    'a v1 database migrates to v2, keeping its rows and gaining the empty delivery-cursor table',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ocpt_migration_v1_to_v2_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'movie.ocpt');

      // The migration from 1 to 2 is additive-only and only ever creates `sync_relay_cursors`
      // (`OcptProjectDatabase.migration`'s own doc comment): a real v1 file is therefore exactly
      // what `onCreate` produces here minus that one table. Seed a real database at the current
      // schema, then undo that one addition by hand — the same trick
      // `home_bloc_test.dart`'s `createProjectAtPreviousFormat` uses — so reopening it exercises the
      // real `onUpgrade` step rather than a fixture standing in for it.
      final seeded = OcptProjectDatabase(File(filePath));
      await seeded
          .into(seeded.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(
              id: 's1',
              title: 'Draft',
              updatedAt: DateTime(2026),
            ),
          );
      await seeded.close();

      final raw = sqlite3.open(filePath);
      raw
        ..execute('DROP TABLE sync_relay_cursors')
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

      await migrated
          .into(migrated.ocptSyncRelayCursorsTable)
          .insert(OcptSyncRelayCursorsTableCompanion.insert(relayId: 'relay-1'));
      final cursorsAfterInsert = await migrated.select(migrated.ocptSyncRelayCursorsTable).get();
      expect(cursorsAfterInsert, hasLength(1));
      expect(cursorsAfterInsert.single.lastAppliedSequence, 0);
      expect(cursorsAfterInsert.single.outboxHighWaterMark, 0);

      final userVersion = await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(userVersion.data['user_version'], OcptProjectDatabase.currentSchemaVersion);
    },
  );
}
