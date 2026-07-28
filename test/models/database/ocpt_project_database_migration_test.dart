// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show Value;
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_project_database_migration_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('a v1 database migrates to v2, preserving every existing row', () async {
    final filePath = p.join(tempDir.path, 'legacy.ocpt');
    final createdAt = DateTime.utc(2026, 1, 15, 9, 30);
    final updatedAt = DateTime.utc(2026, 1, 16, 18, 45, 30);
    final snapshotCreatedAt = DateTime.utc(2026, 1, 16, 18, 44);

    // Build the v1 fixture directly with the `sqlite3` package: no drift involved yet, so this
    // is genuinely an "old file on disk" rather than something drift's own `onCreate` produced.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v1Ddl);
    legacyDb.execute('PRAGMA user_version = 1;');
    legacyDb.execute(
      "INSERT INTO project_info (id, name, created_at, app_version_at_creation, page_format) "
      "VALUES (1, 'My Movie', '${createdAt.toIso8601String()}', '0.1.0', 'a4');",
    );
    legacyDb.execute(
      "INSERT INTO screenplays (id, title, fountain_text, updated_at) "
      "VALUES ('s1', 'Draft', 'INT. HOUSE - DAY\n\nCLARA enters.', "
      "'${updatedAt.toIso8601String()}');",
    );
    legacyDb.execute(
      "INSERT INTO screenplay_snapshots (id, screenplay_id, created_at, reason, fountain_text) "
      "VALUES ('snap1', 's1', '${snapshotCreatedAt.toIso8601String()}', 'manual', "
      "'INT. HOUSE - DAY');",
    );
    legacyDb.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene1', 's1', 0, 'INT. HOUSE - DAY', NULL, 0, 18);",
    );
    legacyDb.dispose();

    // Open the same file through the current (v2) OcptProjectDatabase: this is the migration.
    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged.
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

    final snapshot = await database.select(database.ocptScreenplaySnapshotsTable).getSingle();
    expect(snapshot.id, "snap1");
    expect(snapshot.screenplayId, "s1");
    expect(snapshot.reason, OcptSnapshotReason.manual);
    expect(snapshot.fountainText, "INT. HOUSE - DAY");
    expect(snapshot.createdAt, snapshotCreatedAt);

    final scene = await database.select(database.ocptScenesTable).getSingle();
    expect(scene.id, "scene1");
    expect(scene.heading, "INT. HOUSE - DAY");
    expect(scene.sceneNumber, isNull);
    expect(scene.charStart, 0);
    expect(scene.charEnd, 18);

    // (b) the three new shot list tables exist and accept a row, referencing the rows the file
    // already held: the migration has to leave the old and the new sides joinable.
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot1",
            screenplayId: "s1",
            sceneId: const Value("scene1"),
            position: 0,
          ),
        );
    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: "shot1",
            characterName: "CLARA",
            position: 0,
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
    final shotCharacter = await database.select(database.ocptShotCharactersTable).getSingle();
    expect(shotCharacter.characterName, "CLARA");
    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.sceneId, "scene1");

    // (c) the schema version stored in the file is now 2.
    final userVersion = await database.customSelect('PRAGMA user_version').getSingle();
    expect(userVersion.data['user_version'], 2);

    await database.close();
  });
}
