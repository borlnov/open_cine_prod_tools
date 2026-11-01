// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'ocpt_shot_coverage_service_test_doubles.dart';

/// Run the tests of the shot coverage service checked and covering.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const coverageService = OcptShotCoverageService(logger: SilentLogger(), deviceId: testDeviceId);

  const sceneIndexService = OcptSceneIndexService(logger: SilentLogger());

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId);

  const elementsService = OcptElementsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  const locationsService = OcptLocationsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    floorPlanService: OcptFloorPlanService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  const roleIndexService = OcptRoleIndexService(
    logger: SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: SilentLogger(),
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  const shotListService = OcptShotListService(
    logger: SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: OcptStoryboardService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: testDeviceId,
    ),
    floorPlanService: OcptFloorPlanService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: coverageService,
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: SilentLogger(),
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );

  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<OcptShotRow> readShot(String shotId) =>
      (database.select(database.ocptShotsTable)..where((row) => row.id.equals(shotId))).getSingle();

  /// Every live coverage range: a range this service "removes" is tombstoned rather than deleted,
  /// and every reader filters tombstones out.
  Future<List<OcptShotCoverageRow>> readRanges() => (database.select(
    database.ocptShotCoveragesTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  /// The one live coverage range, failing if there is anything but exactly one.
  Future<OcptShotCoverageRow> readSingleRange() async => (await readRanges()).single;

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptProjectVersionsService`'s own tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  Future<List<OcptSceneRow>> readScenes() =>
      (database.select(database.ocptScenesTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.position)]))
          .get();

  test("markAsChecked re-stamps digests so a second refreshStaleness stays quiet", () async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action two three.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final streetScene = (await readScenes()).firstWhere(
      (row) => row.heading == "EXT. STREET - NIGHT",
    );
    final shotId = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: streetScene.id,
    ))!;

    final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
        .fountainText
        .substring(streetScene.charStart, streetScene.charEnd);
    final wordOffset = sceneText.indexOf("two");

    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: streetScene.id,
      startOffset: wordOffset,
      endOffset: wordOffset + "two".length,
      sceneText: sceneText,
    );

    const editedText = '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action TWO three.
''';
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: editedText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    await coverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: editedText,
      stamps: null,
    );
    expect((await readShot(shotId)).needsCheck, isTrue);

    await coverageService.markAsChecked(
      database: database,
      shotId: shotId,
      currentFountainText: editedText,
    );

    final checkedShot = await readShot(shotId);
    expect(checkedShot.needsCheck, isFalse);
    expect(checkedShot.checkReason, isNull);

    final restampedRange = await readSingleRange();
    expect(restampedRange.coveredTextDigest, testDigestOf("TWO"));

    // A second refreshStaleness against the same text must stay quiet.
    await coverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: editedText,
      stamps: null,
    );
    final shotAfterSecondRefresh = await readShot(shotId);
    expect(shotAfterSecondRefresh.needsCheck, isFalse);
  });

  test("shotIdsCoveringRange returns the other shots overlapping a scene range", () async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action one two three.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final scene = (await readScenes()).single;
    final shotA = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: scene.id,
    ))!;
    final shotB = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: scene.id,
    ))!;

    final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
        .fountainText
        .substring(scene.charStart, scene.charEnd);
    final oneOffset = sceneText.indexOf("one");
    final twoOffset = sceneText.indexOf("two");

    // Shot A covers "one two", shot B covers just "two": they overlap on "two".
    await coverageService.addRange(
      database: database,
      shotId: shotA,
      sceneId: scene.id,
      startOffset: oneOffset,
      endOffset: twoOffset + "two".length,
      sceneText: sceneText,
    );
    await coverageService.addRange(
      database: database,
      shotId: shotB,
      sceneId: scene.id,
      startOffset: twoOffset,
      endOffset: twoOffset + "two".length,
      sceneText: sceneText,
    );

    final overlappingWithB = await coverageService.shotIdsCoveringRange(
      database: database,
      sceneId: scene.id,
      startOffset: twoOffset,
      endOffset: twoOffset + "two".length,
      excludingShotId: shotB,
    );

    expect(overlappingWithB, [shotA]);

    // Removing shot A's range tombstones it, and every reader — this one included — has to stop
    // seeing it rather than rely on the row being gone.
    final rangeOfA = (await readRanges()).firstWhere((row) => row.shotId == shotA);
    await coverageService.removeRange(database: database, rangeId: rangeOfA.id);

    expect(
      await coverageService.shotIdsCoveringRange(
        database: database,
        sceneId: scene.id,
        startOffset: twoOffset,
        endOffset: twoOffset + "two".length,
        excludingShotId: shotB,
      ),
      isEmpty,
    );
    expect((await readRanges()).map((row) => row.shotId), [shotB]);
    // The row itself is still there, flagged.
    expect(await database.select(database.ocptShotCoveragesTable).get(), hasLength(2));
  });

  test("a shot whose ranges were all cleared stops being flagged stale by a later save", () async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action one two three.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final scene = (await readScenes()).single;
    final shotId = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: scene.id,
    ))!;
    final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
        .fountainText
        .substring(scene.charStart, scene.charEnd);

    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: scene.id,
      startOffset: sceneText.indexOf("one"),
      endOffset: sceneText.indexOf("three") + "three".length,
      sceneText: sceneText,
    );
    await coverageService.clearRangesOfShot(database: database, shotId: shotId);

    expect(await readRanges(), isEmpty);

    // Rewriting the text the cleared range covered must not raise a flag through a tombstone.
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action four five six.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    expect((await readShot(shotId)).needsCheck, isFalse);
  });

  group("digestOf", () {
    test("returns the SHA-256 hex digest of the text's UTF-8 bytes", () {
      expect(OcptShotCoverageService.digestOf("hello"), testDigestOf("hello"));
    });

    test("differs for different text", () {
      expect(
        OcptShotCoverageService.digestOf("hello"),
        isNot(OcptShotCoverageService.digestOf("Hello")),
      );
    });
  });

  group("isRangeStale", () {
    const sceneText = "Action one two three.";

    /// Builds an [OcptShotCoverageRange] covering `sceneText[start:end]`, with its digest already
    /// stamped from that substring, as it would be right after [OcptShotCoverageService.addRange].
    OcptShotCoverageRange buildRange(int start, int end) => OcptShotCoverageRange(
      id: "range",
      sceneId: "scene-1",
      startOffset: start,
      endOffset: end,
      coveredTextDigest: OcptShotCoverageService.digestOf(sceneText.substring(start, end)),
      isStale: false,
    );

    test("is false when the covered substring hasn't changed", () {
      final start = sceneText.indexOf("two");
      final range = buildRange(start, start + "two".length);

      expect(OcptShotCoverageService.isRangeStale(range: range, sceneText: sceneText), isFalse);
    });

    test("is true when a character inside the range changed", () {
      final start = sceneText.indexOf("two");
      final range = buildRange(start, start + "two".length);
      const editedText = "Action one TWO three.";

      expect(OcptShotCoverageService.isRangeStale(range: range, sceneText: editedText), isTrue);
    });

    test("is false when the change is outside the range", () {
      final start = sceneText.indexOf("two");
      final range = buildRange(start, start + "two".length);
      // "three" (after the covered range) changes; the prefix up to and including "two" is
      // untouched, so the range's own offsets still point at the same unchanged substring.
      const editedText = "Action one two FOUR.";

      expect(OcptShotCoverageService.isRangeStale(range: range, sceneText: editedText), isFalse);
    });

    test("is true when the range no longer fits inside the text", () {
      final range = buildRange(sceneText.length - 3, sceneText.length);
      const shorterText = "Action one";

      expect(OcptShotCoverageService.isRangeStale(range: range, sceneText: shorterText), isTrue);
    });
  });

  test('every write handed the read-only database of a previewed version is refused', () async {
    final preview = OcptProjectDatabase.memory(isPreview: true);
    addTearDown(preview.close);

    await preview
        .into(preview.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    await preview
        .into(preview.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene-1",
            screenplayId: screenplayId,
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 0,
            charEnd: 16,
          ),
        );
    await preview
        .into(preview.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot-1",
            screenplayId: screenplayId,
            sceneId: const Value("scene-1"),
            position: 0,
            sortKey: const Value("V"),
            needsCheck: const Value(true),
            checkReason: const Value(OcptShotCheckReason.coveredTextChanged),
          ),
        );
    await preview
        .into(preview.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: "coverage-1",
            shotId: "shot-1",
            sceneId: "scene-1",
            startOffset: 0,
            endOffset: 5,
            coveredTextDigest: "digest",
          ),
        );

    final addedId = await coverageService.addRange(
      database: preview,
      shotId: "shot-1",
      sceneId: "scene-1",
      startOffset: 6,
      endOffset: 9,
      sceneText: "INT. HOUSE - DAY",
    );
    await coverageService.removeRange(database: preview, rangeId: "coverage-1");
    await coverageService.clearRangesOfShot(database: preview, shotId: "shot-1");
    await coverageService.markAsChecked(
      database: preview,
      shotId: "shot-1",
      currentFountainText: "INT. HOUSE - DAY",
    );
    await coverageService.refreshStaleness(
      database: preview,
      screenplayId: screenplayId,
      currentFountainText: "EXT. STREET - NIGHT",
      stamps: null,
    );

    // A version the user is only reading isn't editable, and it is the service that says so: a UI
    // bug must not be able to write a preview's coverage.
    expect(addedId, isNull);

    final ranges = await preview.select(preview.ocptShotCoveragesTable).get();
    expect(ranges, hasLength(1));
    expect(ranges.single.id, "coverage-1");
    expect(ranges.single.isDeleted, isFalse);
    expect(ranges.single.coveredTextDigest, "digest");

    final shot = await preview.select(preview.ocptShotsTable).getSingle();
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);
  });

  group("row-field-version stamps", () {
    /// A shot on a fresh, single-scene screenplay, and that scene's own current text — ready for a
    /// test to add a coverage range against.
    Future<(String shotId, OcptSceneRow scene, String sceneText)> insertShotWithScene() async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one two three.
''',
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scene = (await readScenes()).single;
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scene.id,
      ))!;
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(scene.charStart, scene.charEnd);

      // Every stamp the save and the shot creation themselves left is irrelevant to what follows.
      await database.delete(database.ocptRowFieldVersionsTable).go();

      return (shotId, scene, sceneText);
    }

    test("addRange stamps every column of the new coverage row", () async {
      final (shotId, scene, sceneText) = await insertShotWithScene();
      final offset = sceneText.indexOf("one");

      final rangeId = (await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: offset,
        endOffset: offset + "one".length,
        sceneText: sceneText,
      ))!;

      final stamps = await readStamps();
      final range = await readSingleRange();
      for (final column in range.toJson().keys) {
        final stamp = stamps["shot_coverages/$rangeId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
        expect(stamp.deviceId, deviceId);
      }
      expect(stamps.keys, hasLength(range.toJson().length));
    });

    test(
      "a merge stamps the absorbed range's tombstone and the surviving range's columns",
      () async {
        final (shotId, scene, sceneText) = await insertShotWithScene();
        final oneOffset = sceneText.indexOf("one");
        final twoOffset = sceneText.indexOf("two");
        final threeEnd = sceneText.indexOf("three.") + "three.".length;

        final firstId = (await coverageService.addRange(
          database: database,
          shotId: shotId,
          sceneId: scene.id,
          startOffset: oneOffset,
          endOffset: twoOffset + "two".length,
          sceneText: sceneText,
        ))!;
        await database.delete(database.ocptRowFieldVersionsTable).go();

        final mergedId = (await coverageService.addRange(
          database: database,
          shotId: shotId,
          sceneId: scene.id,
          startOffset: twoOffset,
          endOffset: threeEnd,
          sceneText: sceneText,
        ))!;

        final stamps = await readStamps();
        expect(stamps["shot_coverages/$firstId/isDeleted"]!.version, 1);
        final mergedRange = await readSingleRange();
        for (final column in mergedRange.toJson().keys) {
          expect(stamps["shot_coverages/$mergedId/$column"], isNotNull, reason: column);
        }
      },
    );

    test("removeRange stamps isDeleted, like any other column", () async {
      final (shotId, scene, sceneText) = await insertShotWithScene();
      final offset = sceneText.indexOf("one");
      final rangeId = (await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: offset,
        endOffset: offset + "one".length,
        sceneText: sceneText,
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await coverageService.removeRange(database: database, rangeId: rangeId);

      final stamps = await readStamps();
      expect(stamps.keys.toSet(), {"shot_coverages/$rangeId/isDeleted"});
      expect(stamps["shot_coverages/$rangeId/isDeleted"]!.version, 1);
    });

    test("markAsChecked stamps only the digest it actually re-stamps", () async {
      final (shotId, scene, sceneText) = await insertShotWithScene();
      final offset = sceneText.indexOf("one");
      final rangeId = (await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: offset,
        endOffset: offset + "one".length,
        sceneText: sceneText,
      ))!;
      await coverageService.refreshStaleness(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: (await database.select(database.ocptScreenplaysTable).getSingle())
            .fountainText
            .replaceFirst("one", "won"),
        stamps: null,
      );
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await coverageService.markAsChecked(
        database: database,
        shotId: shotId,
        currentFountainText: (await database.select(database.ocptScreenplaysTable).getSingle())
            .fountainText
            .replaceFirst("one", "won"),
      );

      final stamps = await readStamps();
      expect(stamps.keys.toSet(), {
        "shot_coverages/$rangeId/coveredTextDigest",
        "shots/$shotId/needsCheck",
        "shots/$shotId/checkReason",
      });
    });
  });
}
