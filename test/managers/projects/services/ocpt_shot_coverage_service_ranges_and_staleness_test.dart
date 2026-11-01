// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm;
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
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'ocpt_shot_coverage_service_test_doubles.dart';

/// Run the tests of the shot coverage service ranges and staleness.
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

  Future<List<OcptSceneRow>> readScenes() =>
      (database.select(database.ocptScenesTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.position)]))
          .get();

  group("addRange", () {
    test("computes and stores the digest of the covered text", () async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one.
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
      final wordOffset = sceneText.indexOf("one");

      final rangeId = (await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: wordOffset,
        endOffset: wordOffset + "one".length,
        sceneText: sceneText,
      ))!;

      final range = await readSingleRange();
      expect(range.id, rangeId);
      expect(range.coveredTextDigest, testDigestOf("one"));
    });

    test("accepts a range spanning more than one block", () async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one.
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

      // From inside the heading through the blank line and into the action below it: the click
      // interaction closes a range wherever the second click lands, so nothing rejects this.
      final startOffset = sceneText.indexOf("HOUSE");
      final endOffset = sceneText.indexOf("one.") + "one.".length;
      final rangeId = (await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: startOffset,
        endOffset: endOffset,
        sceneText: sceneText,
      ))!;

      final range = await (database.select(
        database.ocptShotCoveragesTable,
      )..where((table) => table.id.equals(rangeId))).getSingle();

      expect(range.startOffset, startOffset);
      expect(range.endOffset, endOffset);
      expect(range.coveredTextDigest, testDigestOf(sceneText.substring(startOffset, endOffset)));
    });

    test("merges a range into the one it overlaps, keeping a single row", () async {
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
      final oneOffset = sceneText.indexOf("one");
      final twoOffset = sceneText.indexOf("two");
      final threeEnd = sceneText.indexOf("three.") + "three.".length;

      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: oneOffset,
        endOffset: twoOffset + "two".length,
        sceneText: sceneText,
      );
      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: twoOffset,
        endOffset: threeEnd,
        sceneText: sceneText,
      );

      final range = await readSingleRange();
      expect(range.startOffset, oneOffset);
      expect(range.endOffset, threeEnd);
      expect(range.coveredTextDigest, testDigestOf(sceneText.substring(oneOffset, threeEnd)));
    });

    test("merges two ranges a single space apart: they already read as one highlight", () async {
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
      final oneOffset = sceneText.indexOf("one");
      final twoOffset = sceneText.indexOf("two");

      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: oneOffset,
        endOffset: oneOffset + "one".length,
        sceneText: sceneText,
      );
      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: twoOffset,
        endOffset: twoOffset + "two".length,
        sceneText: sceneText,
      );

      final range = await readSingleRange();
      expect(sceneText.substring(range.startOffset, range.endOffset), "one two");
    });

    test("a range bridging two existing ones absorbs both", () async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one two three four.
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
      final oneOffset = sceneText.indexOf("one");
      final twoOffset = sceneText.indexOf("two");
      final fourEnd = sceneText.indexOf("four.") + "four.".length;

      // "one", then "four.", far enough apart to stay two rows: real words sit between them.
      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: oneOffset,
        endOffset: oneOffset + "one".length,
        sceneText: sceneText,
      );
      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: sceneText.indexOf("four."),
        endOffset: fourEnd,
        sceneText: sceneText,
      );
      expect(await readRanges(), hasLength(2));

      // The bridge covers "two three", joining both of them at once.
      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: twoOffset,
        endOffset: sceneText.indexOf("three") + "three".length,
        sceneText: sceneText,
      );

      final range = await readSingleRange();
      expect(sceneText.substring(range.startOffset, range.endOffset), "one two three four.");
    });

    test("leaves apart two ranges with real text between them", () async {
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
      final oneOffset = sceneText.indexOf("one");
      final threeOffset = sceneText.indexOf("three.");

      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: oneOffset,
        endOffset: oneOffset + "one".length,
        sceneText: sceneText,
      );
      await coverageService.addRange(
        database: database,
        shotId: shotId,
        sceneId: scene.id,
        startOffset: threeOffset,
        endOffset: threeOffset + "three.".length,
        sceneText: sceneText,
      );

      expect(await readRanges(), hasLength(2));
    });

    test("never merges across two shots, nor across two scenes", () async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one two.
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

      await coverageService.addRange(
        database: database,
        shotId: shotA,
        sceneId: scene.id,
        startOffset: oneOffset,
        endOffset: oneOffset + "one".length,
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

      final ranges = await readRanges();
      expect(ranges, hasLength(2));
      expect(ranges.map((range) => range.shotId), containsAll([shotA, shotB]));
    });

    test("still rejects an empty or negative range", () async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one.
''',
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scene = (await readScenes()).single;
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scene.id,
      ))!;

      expect(
        () => coverageService.addRange(
          database: database,
          shotId: shotId,
          sceneId: scene.id,
          startOffset: 5,
          endOffset: 5,
          sceneText: "never read: the guard rejects the range first",
        ),
        throwsArgumentError,
      );
    });
  });

  test("a coverage range survives a scene that moves because a scene above it grew: "
      "no digest change, no needsCheck", () async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action one.

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

    final sceneTextBefore = (await database.select(database.ocptScreenplaysTable).getSingle())
        .fountainText
        .substring(streetScene.charStart, streetScene.charEnd);
    final wordOffset = sceneTextBefore.indexOf("two");

    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: streetScene.id,
      startOffset: wordOffset,
      endOffset: wordOffset + "two".length,
      sceneText: sceneTextBefore,
    );
    final rangeBefore = await readSingleRange();

    // Scene 1 grows; scene 2's own text is untouched.
    const newText = '''
INT. HOUSE - DAY

Action one, with a lot more happening in this scene now.

EXT. STREET - NIGHT

Action two three.
''';
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: newText,
      snapshotReason: OcptSnapshotReason.manual,
    );

    await coverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: newText,
      stamps: null,
    );

    final rangeAfter = await readSingleRange();
    expect(rangeAfter.startOffset, rangeBefore.startOffset);
    expect(rangeAfter.endOffset, rangeBefore.endOffset);
    expect(rangeAfter.coveredTextDigest, rangeBefore.coveredTextDigest);

    final shot = await readShot(shotId);
    expect(shot.needsCheck, isFalse);
    expect(shot.checkReason, isNull);
  });

  test("an edit inside the covered range flags the owning shot", () async {
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

    // "two" becomes "TWO": the covered word itself changed.
    const newText = '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action TWO three.
''';
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: newText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    await coverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: newText,
      stamps: null,
    );

    final shot = await readShot(shotId);
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);
  });

  test("saving is enough to flag a stale shot: the save pass runs the check itself", () async {
    // The other staleness tests call refreshStaleness explicitly, which would still pass if the
    // save pass had never been wired to it. This one never calls it: saving is the only trigger,
    // exactly as it is in the running app.
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action one two.
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
    final wordOffset = sceneText.indexOf("one");

    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: scene.id,
      startOffset: wordOffset,
      endOffset: wordOffset + "one".length,
      sceneText: sceneText,
    );

    expect((await readShot(shotId)).needsCheck, isFalse);

    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action ONE two.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final shot = await readShot(shotId);
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);
  });

  test("an edit after the covered range, still inside the same scene, stays quiet", () async {
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
    // Cover the *first* word of the action line, so an edit further along the same line/scene
    // doesn't shift this range's offsets at all.
    final wordOffset = sceneText.indexOf("Action", sceneText.indexOf("STREET"));

    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: streetScene.id,
      startOffset: wordOffset,
      endOffset: wordOffset + "Action".length,
      sceneText: sceneText,
    );

    // Only "three" (after the covered word) changes.
    const newText = '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action two four.
''';
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: newText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    await coverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: newText,
      stamps: null,
    );

    final shot = await readShot(shotId);
    expect(shot.needsCheck, isFalse);
    expect(shot.checkReason, isNull);
  });

  test("a range that no longer fits its scene is clamped and flagged as out of bounds", () async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action two three four.
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

    final sceneTextBefore = (await database.select(database.ocptScreenplaysTable).getSingle())
        .fountainText
        .substring(streetScene.charStart, streetScene.charEnd);
    final wordOffset = sceneTextBefore.indexOf("four");
    final rangeEnd = wordOffset + "four".length;

    await coverageService.addRange(
      database: database,
      shotId: shotId,
      sceneId: streetScene.id,
      startOffset: wordOffset,
      endOffset: rangeEnd,
      sceneText: sceneTextBefore,
    );

    // The scene shrinks: "four" (and its trailing content) is gone, so the stored range no longer
    // fits inside the scene's new, shorter bounds.
    const newText = '''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action two.
''';
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: newText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    await coverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: newText,
      stamps: null,
    );

    final newStreetScene = (await readScenes()).firstWhere(
      (row) => row.heading == "EXT. STREET - NIGHT",
    );
    final rangeAfter = await readSingleRange();
    expect(rangeAfter.endOffset, newStreetScene.charEnd - newStreetScene.charStart);
    expect(rangeAfter.endOffset, lessThan(rangeEnd));

    final shot = await readShot(shotId);
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coverageOutOfBounds);
  });
}
