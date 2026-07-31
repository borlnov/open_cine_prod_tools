// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

void main() {
  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  test('project_info: a row can be inserted and read back, with its default id', () async {
    final now = DateTime.now();

    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "My Movie",
            createdAt: now,
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
          ),
        );

    final row = await database.select(database.ocptProjectInfoTable).getSingle();

    expect(row.id, 1);
    expect(row.name, "My Movie");
    expect(row.appVersionAtCreation, "0.1.0");
    expect(row.pageFormat, OcptPageFormat.a4);
    expect(row.settingsJson, isNull);
  });

  test('screenplays: a row can be inserted and read back, with its default text', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    final row = await database.select(database.ocptScreenplaysTable).getSingle();

    expect(row.id, "s1");
    expect(row.title, "Draft");
    expect(row.fountainText, "");
  });

  test('screenplay_snapshots: a row can be inserted and read back', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    await database
        .into(database.ocptScreenplaySnapshotsTable)
        .insert(
          OcptScreenplaySnapshotsTableCompanion.insert(
            id: "snap1",
            screenplayId: "s1",
            createdAt: DateTime.now(),
            reason: OcptSnapshotReason.manual,
            fountainText: "INT. HOUSE - DAY",
          ),
        );

    final row = await database.select(database.ocptScreenplaySnapshotsTable).getSingle();

    expect(row.screenplayId, "s1");
    expect(row.reason, OcptSnapshotReason.manual);
    expect(row.fountainText, "INT. HOUSE - DAY");
  });

  test('scenes: a row can be inserted and read back, with a null scene number', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene1",
            screenplayId: "s1",
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 0,
            charEnd: 20,
          ),
        );

    final row = await database.select(database.ocptScenesTable).getSingle();

    expect(row.heading, "INT. HOUSE - DAY");
    expect(row.sceneNumber, isNull);
    expect(row.charStart, 0);
    expect(row.charEnd, 20);
  });

  test('shots: a row inserted with only its ids gets every documented default', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );
    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene1",
            screenplayId: "s1",
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 0,
            charEnd: 20,
          ),
        );

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

    final row = await database.select(database.ocptShotsTable).getSingle();

    expect(row.sceneId, "scene1");
    expect(row.orphanedHeading, isNull);
    expect(row.shotSize, "");
    expect(row.framing, "");
    expect(row.cameraMove, "");
    expect(row.lens, "");
    expect(row.recordingFormat, "");
    expect(row.estimatedDurationMs, isNull);
    expect(row.shootingDay, isNull);
    expect(row.plannedTakes, isNull);
    expect(row.sound, "");
    expect(row.status, OcptShotStatus.toShoot);
    expect(row.difficultySet, 1);
    expect(row.difficultyCamera, 1);
    expect(row.difficultyActing, 1);
    expect(row.difficultySound, 1);
    expect(row.notes, "");
    expect(row.locationNotes, "");
    expect(row.needsCheck, isFalse);
    expect(row.checkReason, isNull);
  });

  test('shots: a null sceneId with a non-null orphanedHeading round-trips (an orphaned shot)', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );

    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot1",
            screenplayId: "s1",
            orphanedHeading: const Value("INT. DELETED SCENE - DAY"),
            position: 0,
            needsCheck: const Value(true),
            checkReason: const Value(OcptShotCheckReason.sceneDeleted),
          ),
        );

    final row = await database.select(database.ocptShotsTable).getSingle();

    expect(row.sceneId, isNull);
    expect(row.orphanedHeading, "INT. DELETED SCENE - DAY");
    expect(row.needsCheck, isTrue);
    expect(row.checkReason, OcptShotCheckReason.sceneDeleted);
  });

  test('shot_characters: a row can be inserted and read back, normalised name and position', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );
    await database
        .into(database.ocptShotsTable)
        .insert(OcptShotsTableCompanion.insert(id: "shot1", screenplayId: "s1", position: 0));

    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: "shot1",
            characterName: "CLARA",
            position: 0,
          ),
        );

    final row = await database.select(database.ocptShotCharactersTable).getSingle();

    expect(row.shotId, "shot1");
    expect(row.characterName, "CLARA");
    expect(row.position, 0);
  });

  test('shot_coverages: a row can be inserted and read back, offsets relative to the scene', () async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: DateTime.now()),
        );
    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene1",
            screenplayId: "s1",
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 100,
            charEnd: 200,
          ),
        );
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
        .into(database.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: "cov1",
            shotId: "shot1",
            sceneId: "scene1",
            startOffset: 5,
            endOffset: 25,
            coveredTextDigest: "abc123",
          ),
        );

    final row = await database.select(database.ocptShotCoveragesTable).getSingle();

    expect(row.shotId, "shot1");
    expect(row.sceneId, "scene1");
    expect(row.startOffset, 5);
    expect(row.endOffset, 25);
    expect(row.coveredTextDigest, "abc123");
  });

  test('foreign keys are enforced: a shot referencing an unknown screenplay is rejected', () async {
    // `NativeDatabase` leaves SQLite's `foreign_keys` pragma at its own default, which is off, so
    // the `references()` declared on the tables would never actually be enforced: this asserts the
    // `beforeOpen` pragma really does turn it on, rather than trusting the declaration alone.
    await expectLater(
      database
          .into(database.ocptShotsTable)
          .insert(OcptShotsTableCompanion.insert(id: "shot1", screenplayId: "nope", position: 0)),
      throwsA(isA<SqliteException>()),
    );
  });
}
