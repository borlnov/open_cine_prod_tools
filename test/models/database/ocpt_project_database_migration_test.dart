// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// The exact `CREATE TABLE` statements drift generated for schema version 1 (captured from
// `ocpt_project_database.g.dart` before the shot list tables were added), used to build a v1
// fixture from scratch rather than through drift itself. Keeping this verbatim, rather than
// reconstructing it from the current table declarations, is what makes this test prove a real
// upgrade path instead of just a fresh `onCreate`.
const _v1Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, PRIMARY KEY ("id"));
''';

// The same, for schema version 2: the v1 tables plus the three shot list ones, all of them still
// without the sync-ready columns version 3 adds (`is_deleted` everywhere, `sort_key` on the two
// ordered tables) and without `row_field_versions`.
const _v2Ddl = '''
$_v1Ddl
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, PRIMARY KEY ("id"));
''';

// The same, for schema version 3: every table carrying its sync-ready columns (`is_deleted`
// everywhere, `sort_key` on the two ordered tables) and the `row_field_versions` sidecar, but the
// `shots` table still without the `abbreviation` column version 4 adds, and no `project_versions`
// table nor the `project_info.current_version_id` column pointing into it, both of which version 5
// adds.
const _v3Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
''';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_project_database_migration_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  final createdAt = DateTime.utc(2026, 1, 15, 9, 30);
  final updatedAt = DateTime.utc(2026, 1, 16, 18, 45, 30);
  final snapshotCreatedAt = DateTime.utc(2026, 1, 16, 18, 44);

  /// Writes the rows every version of the schema already had — the project header, one screenplay,
  /// one snapshot and one scene — into the legacy database [db] built from [_v1Ddl], [_v2Ddl] or
  /// [_v3Ddl].
  void seedCommonRows(sqlite3.Database db) {
    db.execute(
      "INSERT INTO project_info (id, name, created_at, app_version_at_creation, page_format) "
      "VALUES (1, 'My Movie', '${createdAt.toIso8601String()}', '0.1.0', 'a4');",
    );
    db.execute(
      "INSERT INTO screenplays (id, title, fountain_text, updated_at) "
      "VALUES ('s1', 'Draft', 'INT. HOUSE - DAY\n\nCLARA enters.', "
      "'${updatedAt.toIso8601String()}');",
    );
    db.execute(
      "INSERT INTO screenplay_snapshots (id, screenplay_id, created_at, reason, fountain_text) "
      "VALUES ('snap1', 's1', '${snapshotCreatedAt.toIso8601String()}', 'manual', "
      "'INT. HOUSE - DAY');",
    );
    db.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene1', 's1', 0, 'INT. HOUSE - DAY', NULL, 0, 18);",
    );
  }

  /// Asserts that the rows [seedCommonRows] wrote all came through [database] unchanged.
  Future<void> expectCommonRowsSurvived(OcptProjectDatabase database) async {
    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.name, "My Movie");
    expect(projectInfo.appVersionAtCreation, "0.1.0");
    expect(projectInfo.pageFormat, OcptPageFormat.a4);
    expect(projectInfo.createdAt, createdAt);

    final screenplay = await database.select(database.ocptScreenplaysTable).getSingle();
    expect(screenplay.id, "s1");
    expect(screenplay.title, "Draft");
    expect(screenplay.fountainText, "INT. HOUSE - DAY\n\nCLARA enters.");
    expect(screenplay.updatedAt, updatedAt);
    expect(screenplay.isDeleted, isFalse);

    final snapshot = await database.select(database.ocptScreenplaySnapshotsTable).getSingle();
    expect(snapshot.id, "snap1");
    expect(snapshot.screenplayId, "s1");
    expect(snapshot.reason, OcptSnapshotReason.manual);
    expect(snapshot.fountainText, "INT. HOUSE - DAY");
    expect(snapshot.createdAt, snapshotCreatedAt);
    expect(snapshot.isDeleted, isFalse);

    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((table) => table.id.equals("scene1"))).getSingle();
    expect(scene.id, "scene1");
    expect(scene.heading, "INT. HOUSE - DAY");
    expect(scene.sceneNumber, isNull);
    expect(scene.charStart, 0);
    expect(scene.charEnd, 18);
    expect(scene.isDeleted, isFalse);
  }

  /// Asserts that the version 5 shape is in place and usable in [database]: the `project_versions`
  /// table accepts a row, and `project_info.current_version_id` — added by the same step — accepts
  /// a pointer to it.
  Future<void> expectProjectVersionsAreUsable(OcptProjectDatabase database) async {
    await database
        .into(database.ocptProjectVersionsTable)
        .insert(
          OcptProjectVersionsTableCompanion.insert(
            id: "version1",
            name: "v1 — First read",
            createdAt: DateTime.utc(2026, 2, 1, 10),
            appVersion: "0.1.0",
            payloadFormat: 1,
            payload: '{"payloadFormat":1}',
            summaryJson: '{"pageCount":41}',
            createdByDeviceId: "device-1",
          ),
        );

    await database
        .update(database.ocptProjectInfoTable)
        .write(const OcptProjectInfoTableCompanion(currentVersionId: Value("version1")));

    final version = await database.select(database.ocptProjectVersionsTable).getSingle();
    expect(version.name, "v1 — First read");
    expect(version.note, "");

    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currentVersionId, "version1");
  }

  /// The `user_version` pragma [database]'s file now carries.
  Future<Object?> readSchemaVersion(OcptProjectDatabase database) async {
    final row = await database.customSelect('PRAGMA user_version').getSingle();
    return row.data['user_version'];
  }

  test('a v1 database migrates to the current schema, preserving every existing row', () async {
    final filePath = p.join(tempDir.path, 'legacy_v1.ocpt');

    // Build the v1 fixture directly with the `sqlite3` package: no drift involved yet, so this
    // is genuinely an "old file on disk" rather than something drift's own `onCreate` produced.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v1Ddl);
    legacyDb.execute('PRAGMA user_version = 1;');
    seedCommonRows(legacyDb);
    legacyDb.dispose();

    // Open the same file through the current OcptProjectDatabase: this is the migration, replayed
    // through both of its steps in order.
    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged.
    await expectCommonRowsSurvived(database);

    // (b) the shot list tables exist and accept a row, referencing the rows the file already held:
    // the migration has to leave the old and the new sides joinable. They were created from the
    // current declarations, so they carry the version 3 columns straight away.
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot1",
            screenplayId: "s1",
            sceneId: const Value("scene1"),
            position: 0,
            sortKey: const Value("V"),
          ),
        );
    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: "shot1",
            characterName: "CLARA",
            position: 0,
            sortKey: const Value("V"),
          ),
        );
    await database
        .into(database.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: "cov1",
            shotId: "shot1",
            sceneId: "scene1",
            startOffset: 0,
            endOffset: 12,
            coveredTextDigest: "digest",
          ),
        );

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot1");
    expect(shot.isDeleted, isFalse);
    expect(shot.abbreviation, "");
    final shotCharacter = await database.select(database.ocptShotCharactersTable).getSingle();
    expect(shotCharacter.characterName, "CLARA");
    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.sceneId, "scene1");

    // (c) the version 3 sidecar table exists too.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: "shots",
            rowId: "shot1",
            columnName: "framing",
            version: 1,
            deviceId: "device-1",
          ),
        );
    expect(await database.select(database.ocptRowFieldVersionsTable).getSingle(), isNotNull);

    // (d) so do the version 5 project versions, pointed at by the project header.
    await expectProjectVersionsAreUsable(database);

    // (e) the schema version stored in the file is now 5.
    expect(await readSchemaVersion(database), 5);

    await database.close();
  });

  test('a v2 database migrates to the current schema, backfilling a sortKey per group', () async {
    final filePath = p.join(tempDir.path, 'legacy_v2.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v2Ddl);
    legacyDb.execute('PRAGMA user_version = 2;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene2', 's1', 1, 'EXT. STREET - NIGHT', NULL, 18, 40);",
    );

    // Three shots in the first scene, one in the second, one already orphaned: three independent
    // groups, each numbered from 0 by the version the file comes from.
    for (final (id, sceneId, position) in const [
      ('shot-a', "'scene1'", 0),
      ('shot-b', "'scene1'", 1),
      ('shot-c', "'scene1'", 2),
      ('shot-d', "'scene2'", 0),
      ('shot-orphan', 'NULL', 0),
    ]) {
      legacyDb.execute(
        "INSERT INTO shots (id, screenplay_id, scene_id, position, framing) "
        "VALUES ('$id', 's1', $sceneId, $position, 'framing of $id');",
      );
    }

    for (final (name, position) in const [('CLARA', 0), ('MARC', 1), ('THÉO', 2)]) {
      legacyDb.execute(
        "INSERT INTO shot_characters (shot_id, character_name, position) "
        "VALUES ('shot-a', '$name', $position);",
      );
    }

    legacyDb.execute(
      "INSERT INTO shot_coverages (id, shot_id, scene_id, start_offset, end_offset, "
      "covered_text_digest) VALUES ('cov1', 'shot-a', 'scene1', 0, 12, 'digest');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged, and is live rather than tombstoned.
    await expectCommonRowsSurvived(database);

    final shots =
        await (database.select(database.ocptShotsTable)
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();
    expect(shots, hasLength(5));
    expect(shots.every((row) => !row.isDeleted), isTrue);
    for (final row in shots) {
      expect(row.framing, "framing of ${row.id}");
      expect(row.abbreviation, "");
    }

    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.shotId, "shot-a");
    expect(coverage.isDeleted, isFalse);

    // (b) every group got its own strictly ascending run of keys, in the order `position` held.
    final sortKeyById = {for (final row in shots) row.id: row.sortKey};
    expect(sortKeyById.values.every((key) => key.isNotEmpty), isTrue);
    expect(
      sortKeyById['shot-a']!.compareTo(sortKeyById['shot-b']!),
      lessThan(0),
    );
    expect(
      sortKeyById['shot-b']!.compareTo(sortKeyById['shot-c']!),
      lessThan(0),
    );

    // (c) reading each group back by sortKey yields the order the file had under `position`.
    Future<List<String>> shotIdsOfScene(String? sceneId) async {
      final rows =
          await (database.select(database.ocptShotsTable)
                ..where(
                  (table) => sceneId == null
                      ? table.sceneId.isNull()
                      : table.sceneId.equals(sceneId),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
      return [for (final row in rows) row.id];
    }

    expect(await shotIdsOfScene('scene1'), ['shot-a', 'shot-b', 'shot-c']);
    expect(await shotIdsOfScene('scene2'), ['shot-d']);
    expect(await shotIdsOfScene(null), ['shot-orphan']);

    // (d) a shot's characters are a group of their own, backfilled the same way.
    final characters =
        await (database.select(database.ocptShotCharactersTable)
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();
    expect([for (final row in characters) row.characterName], ['CLARA', 'MARC', 'THÉO']);
    expect(characters.every((row) => row.sortKey.isNotEmpty && !row.isDeleted), isTrue);

    // (e) the sidecar table was created, the project versions are usable, and the file now says
    // version 5.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: "shots",
            rowId: "shot-a",
            columnName: "framing",
            version: 1,
            deviceId: "device-1",
          ),
        );
    expect(await database.select(database.ocptRowFieldVersionsTable).getSingle(), isNotNull);
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 5);

    await database.close();
  });

  test('a v3 database migrates on, gaining an abbreviation and the project versions', () async {
    final filePath = p.join(tempDir.path, 'legacy_v3.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v3Ddl);
    legacyDb.execute('PRAGMA user_version = 3;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO shots (id, screenplay_id, scene_id, position, sort_key, shot_size, framing, "
      "is_deleted) VALUES ('shot-a', 's1', 'scene1', 0, 'V', 'Gros plan', 'framing of shot-a', 0);",
    );
    legacyDb.execute(
      "INSERT INTO row_field_versions (table_name, row_id, column_name, version, device_id) "
      "VALUES ('shots', 'shot-a', 'framing', 7, 'device-0');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived, the shot and the version 3 ones included:
    // these steps only add columns and a table, and touch nothing else.
    await expectCommonRowsSurvived(database);

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot-a");
    expect(shot.shotSize, "Gros plan");
    expect(shot.framing, "framing of shot-a");
    expect(shot.sortKey, "V");
    expect(shot.isDeleted, isFalse);

    final stamp = await database.select(database.ocptRowFieldVersionsTable).getSingle();
    expect(stamp.rowId, "shot-a");
    expect(stamp.version, 7);

    // (b) the version 4 column is there, holding its default rather than being deduced
    // retroactively: an abbreviation is only ever written when a shot size is committed from the
    // inspector.
    expect(shot.abbreviation, "");

    await database
        .update(database.ocptShotsTable)
        .write(const OcptShotsTableCompanion(abbreviation: Value("GP")));
    expect((await database.select(database.ocptShotsTable).getSingle()).abbreviation, "GP");

    // (c) the project header kept its own values, and its new pointer starts empty: a project that
    // predates this version has never had a version of its own.
    final projectInfoBefore = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfoBefore.currentVersionId, isNull);

    // (d) the version 5 shape is in place and usable, and the file now says version 5.
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 5);

    await database.close();
  });
}
