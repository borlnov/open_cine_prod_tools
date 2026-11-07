// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({String rangeId});

/// Run the tests of what [OcptShotCoverageService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  const sceneText = "INT. HOUSE - DAY\n\nJOHN\nHello there.\n";
  const rangeStart = 18;
  const rangeEnd = 22;

  Future<String> testDeviceId() async => "test-device";
  final service = OcptShotCoverageService(logger: const SilentLogger(), deviceId: testDeviceId);

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Insert the screenplay, scene and shot every case works on, and one range through the service.
  Future<_Fixture> seed() async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: "screenplay-1",
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene-1",
            screenplayId: "screenplay-1",
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 0,
            charEnd: sceneText.length,
          ),
        );
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(id: "shot-1", screenplayId: "screenplay-1", position: 0),
        );
    final rangeId = await service
        .addRange(
          database: database,
          shotId: "shot-1",
          sceneId: "scene-1",
          startOffset: rangeStart,
          endOffset: rangeEnd,
          sceneText: sceneText,
        )
        .valueOrFail;
    // The shot is flagged, so that checking it changes a row.
    await database.customStatement("UPDATE shots SET needs_check = 1 WHERE id = 'shot-1'");

    return (rangeId: rangeId);
  }

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "addRange": (r) async => (await service.addRange(
      database: database,
      shotId: "shot-1",
      sceneId: "scene-1",
      startOffset: 28,
      endOffset: 33,
      sceneText: sceneText,
    )).status,
    "removeRange": (r) async =>
        (await service.removeRange(database: database, rangeId: r.rangeId)).status,
    "clearRangesOfShot": (r) async =>
        (await service.clearRangesOfShot(database: database, shotId: "shot-1")).status,
    "markAsChecked": (r) async => (await service.markAsChecked(
      database: database,
      shotId: "shot-1",
      currentFountainText: sceneText.replaceFirst("Hello", "Howdy"),
    )).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in ["shot_coverages", "shots", "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  group("every write answers a database error when the database refuses it", () {
    for (final entry in writes.entries) {
      test("${entry.key} writes nothing", () async {
        // The call must change something when nothing is wrong, or the refusal proves nothing.
        final before = await snapshot();
        expect(await entry.value(rows), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await database.close();
        database = OcptProjectDatabase.memory();
        rows = await seed();

        final untouched = await snapshot();
        for (final table in ["shot_coverages", "shots"]) {
          for (final verb in ["INSERT", "UPDATE"]) {
            await database.customStatement(
              "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
              "BEGIN SELECT RAISE(ABORT, 'refused'); END",
            );
          }
        }

        final status = await entry.value(rows);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every write answers a database error when its tables are gone", () {
    for (final entry in writes.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in ["shot_coverages", "shots"]) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("an empty, inverted or negative range", () {
    for (final (start, end) in [(5, 5), (7, 3), (-1, 4)]) {
      test("$start..$end is a failure and writes nothing", () async {
        final untouched = await snapshot();

        final result = await service.addRange(
          database: database,
          shotId: "shot-1",
          sceneId: "scene-1",
          startOffset: start,
          endOffset: end,
          sceneText: sceneText,
        );

        expect(result.status, OcptDatabaseStatus.databaseError);
        expect(result.value, isNull);
        expect(await snapshot(), untouched);
      });
    }
  });

  group("on the database of a version being previewed", () {
    test("every write is refused as a call that went well, and writes nothing", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);
      await preview.customStatement("PRAGMA foreign_keys = OFF");
      await preview
          .into(preview.ocptShotCoveragesTable)
          .insert(
            OcptShotCoveragesTableCompanion.insert(
              id: "range-1",
              shotId: "shot-1",
              sceneId: "scene-1",
              startOffset: rangeStart,
              endOffset: rangeEnd,
              coveredTextDigest: "digest",
            ),
          );
      final untouched = await preview.customSelect("SELECT * FROM shot_coverages").get();

      final added = await service.addRange(
        database: preview,
        shotId: "shot-1",
        sceneId: "scene-1",
        startOffset: 28,
        endOffset: 33,
        sceneText: sceneText,
      );
      expect(added.status, OcptDatabaseStatus.ok);
      expect(added.value, isNull, reason: "no range was added");
      await service.removeRange(database: preview, rangeId: "range-1").okOrFail;
      await service.clearRangesOfShot(database: preview, shotId: "shot-1").okOrFail;
      await service
          .markAsChecked(database: preview, shotId: "shot-1", currentFountainText: sceneText)
          .okOrFail;

      final after = await preview.customSelect("SELECT * FROM shot_coverages").get();
      expect([for (final row in after) row.data], [for (final row in untouched) row.data]);
    });

    test("the refusal comes before the check of the range", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      final added = await service.addRange(
        database: preview,
        shotId: "shot-1",
        sceneId: "scene-1",
        startOffset: 5,
        endOffset: 5,
        sceneText: sceneText,
      );

      expect(added.status, OcptDatabaseStatus.ok);
    });
  });
}
