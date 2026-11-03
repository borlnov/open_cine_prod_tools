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
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the breakdown service reconcile and stamps.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);

  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  final locationsService = OcptLocationsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    floorPlanService: OcptFloorPlanService(
      logger: const SilentLogger(),
      assetsService: assetsService,
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  final roleIndexService = OcptRoleIndexService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  final breakdownService = OcptBreakdownService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: testDeviceId,
  );

  const sceneIndexService = OcptSceneIndexService(logger: SilentLogger());

  final screenplayService = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: sceneIndexService,
    shotListService: OcptShotListService(
      logger: const SilentLogger(),
      roleIndexService: roleIndexService,
      storyboardService: OcptStoryboardService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      floorPlanService: OcptFloorPlanService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      deviceId: testDeviceId,
    ),
    shotCoverageService: OcptShotCoverageService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId),
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

  Future<List<OcptSceneRow>> readScenes() =>
      (database.select(database.ocptScenesTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.position)]))
          .get();

  Future<OcptBreakdownTagRow> readTag(String id) => (database.select(
    database.ocptBreakdownTagsTable,
  )..where((row) => row.id.equals(id))).getSingle();

  Future<List<OcptSceneElementRow>> readLiveSceneElements() => (database.select(
    database.ocptSceneElementsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptSceneSetRow>> readLiveSceneSets() => (database.select(
    database.ocptSceneSetsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<OcptSceneBreakdownRow?> readSceneBreakdown(String sceneId) => (database.select(
    database.ocptSceneBreakdownsTable,
  )..where((row) => row.sceneId.equals(sceneId))).getSingleOrNull();

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptShotListService`'s own stamping tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  /// Saves [fountainText] as the screenplay's only content and returns its single resulting scene.
  Future<OcptSceneRow> saveSingleScene(String fountainText) async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: fountainText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    return (await readScenes()).single;
  }

  /// Creates a role of screenplay [screenplayId], returning its id — a stand-in target for the
  /// tests that tag a role, since [OcptRoleIndexService.reconcile] is out of scope here.
  Future<String> createRole() => roleIndexService
      .addRole(
        database: database,
        screenplayId: screenplayId,
        name: "LÉA",
        kind: OcptRoleKind.silent,
      )
      .then((id) => id!);

  /// Creates a location and a set inside it, returning the set's id.
  Future<String> createSet() async {
    final locationId = (await locationsService.createLocation(database: database, name: "House"))!;
    return (await locationsService.createSet(
      database: database,
      locationId: locationId,
      name: "Kitchen",
    ))!;
  }

  group("reconcileTags", () {
    test("leaves an unchanged tag untouched", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;
      final before = await readTag(tagId);

      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText:
            (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText,
        stamps: null,
      );

      expect(await readTag(tagId), before);
    });

    test("re-anchors silently when the passage shifted earlier in the same scene", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      const newText = "INT. HOUSE - DAY\n\nAction one, with a lot more happening, two.\n";
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: newText,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: newText,
        stamps: null,
      );

      final newScene = (await readScenes()).single;
      final newSceneText = newText.substring(newScene.charStart, newScene.charEnd);
      final tag = await readTag(tagId);
      expect(tag.startOffset, isNot(start));
      expect(newSceneText.substring(tag.startOffset, tag.endOffset), "two");
      expect(tag.needsCheck, isFalse);
    });

    test("needs no re-anchoring when the edit is in a preceding scene", () async {
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
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(streetScene.charStart, streetScene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: streetScene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

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
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: newText,
        stamps: null,
      );

      final tag = await readTag(tagId);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
      expect(tag.needsCheck, isFalse);
    });

    test("flags a tag whose text is gone", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      const newText = "INT. HOUSE - DAY\n\nAction one FOUR.\n";
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: newText,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: newText,
        stamps: null,
      );

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isTrue);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
    });

    test("flags, and keeps the offsets of, a tag whose text now appears twice", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction alpha beta.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("beta");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "beta".length,
        taggedText: "beta",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      // Inserting a word before "alpha" shifts the stored offset off "beta", and a second "beta"
      // appears right after the first: now ambiguous.
      const newText = "INT. HOUSE - DAY\n\nAction extra alpha beta beta.\n";
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: newText,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: newText,
        stamps: null,
      );

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isTrue);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "beta".length);
    });

    test("clears needsCheck once the text is back exactly where it was", () async {
      const originalText = "INT. HOUSE - DAY\n\nAction one two.\n";
      final scene = await saveSingleScene(originalText);
      final sceneText = originalText.substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();
      final start = sceneText.indexOf("two");
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: start + "two".length,
        taggedText: "two",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      const goneText = "INT. HOUSE - DAY\n\nAction one FOUR.\n";
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: goneText,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: goneText,
        stamps: null,
      );
      expect((await readTag(tagId)).needsCheck, isTrue);

      // Back to the exact original text: the stored offsets are valid again.
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: originalText,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: originalText,
        stamps: null,
      );

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isFalse);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
    });

    test("tombstones a tag whose scene disappeared", () async {
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
      final roleId = await createRole();
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: streetScene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "Act",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      const newText = "INT. HOUSE - DAY\n\nAction one.\n";
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: newText,
        snapshotReason: OcptSnapshotReason.manual,
      );
      await breakdownService.reconcileTags(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: newText,
        stamps: null,
      );

      final tag = await readTag(tagId);
      expect(tag.isDeleted, isTrue);
    });
  });

  group("row-field-version stamps", () {
    test("createTag stamps every column of the new row", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final roleId = await createRole();
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;

      final stamps = await readStamps();
      final tag = await readTag(tagId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("breakdown_tags/$tagId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(tag.toJson().length));
      for (final column in tag.toJson().keys) {
        expect(
          ownStamps["breakdown_tags/$tagId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("deleteTag stamps isDeleted on the tag", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final roleId = await createRole();
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await breakdownService.deleteTag(database: database, tagId: tagId);

      final stamps = await readStamps();
      expect(stamps["breakdown_tags/$tagId/isDeleted"]!.version, 1);
    });

    test("updateSceneBreakdown stamps every column of the new row", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        status: const Value(OcptBreakdownSceneStatus.inProgress),
      );

      final row = (await readSceneBreakdown(scene.id))!;
      final stamps = await readStamps();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("scene_breakdowns/${row.id}/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        expect(
          ownStamps["scene_breakdowns/${row.id}/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("updateSceneBreakdown stamps only the columns that actually changed", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        status: const Value(OcptBreakdownSceneStatus.inProgress),
      );
      final row = (await readSceneBreakdown(scene.id))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        notes: const Value("Needs a period lamp"),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys
          .where((key) => key.startsWith("scene_breakdowns/${row.id}/"))
          .toSet();
      expect(ownKeys, {"scene_breakdowns/${row.id}/notes"});
    });

    test("deleteEpisode stamps isDeleted on breakdown_tags, scene_breakdowns, scene_elements and "
        "scene_sets", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final elementId = (await elementsService
          .createElement(
            database: database,
            name: "Desk lamp",
            category: OcptElementCategory.prop,
            sourceKind: OcptElementSourceKind.owned,
          )
          .valueOrFail);
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      ))!;
      final sceneElementId = (await readLiveSceneElements()).single.id;
      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        status: const Value(OcptBreakdownSceneStatus.inProgress),
      );
      final sceneBreakdownId = (await readSceneBreakdown(scene.id))!.id;
      final setId = await createSet();
      final setTagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 3,
        endOffset: 5,
        taggedText: " ",
        targetKind: OcptBreakdownTargetKind.set,
        targetId: setId,
      ))!;
      final sceneSetId = (await readLiveSceneSets()).single.id;

      // A second, unrelated episode so this one is not the project's last live one.
      await screenplayService.createEpisode(database: database, title: "Episode 2");

      await database.delete(database.ocptRowFieldVersionsTable).go();

      final deleted = await screenplayService.deleteEpisode(
        database: database,
        screenplayId: screenplayId,
      );
      expect(deleted, isTrue);

      final stamps = await readStamps();
      expect(stamps["breakdown_tags/$tagId/isDeleted"]!.version, 1);
      expect(stamps["breakdown_tags/$setTagId/isDeleted"]!.version, 1);
      expect(stamps["scene_breakdowns/$sceneBreakdownId/isDeleted"]!.version, 1);
      expect(stamps["scene_elements/$sceneElementId/isDeleted"]!.version, 1);
      expect(stamps["scene_sets/$sceneSetId/isDeleted"]!.version, 1);
    });
  });

  test("every write handed the read-only database of a previewed version is refused", () async {
    final preview = OcptProjectDatabase.memory(isPreview: true);
    addTearDown(preview.close);

    await preview
        .into(preview.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            fountainText: const Value("INT. HOUSE - DAY\n\nAction one.\n"),
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
            charEnd: 30,
          ),
        );
    await preview
        .into(preview.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(id: "role-1", name: "LÉA", kind: OcptRoleKind.silent),
        );
    await preview
        .into(preview.ocptBreakdownTagsTable)
        .insert(
          OcptBreakdownTagsTableCompanion.insert(
            id: "tag-1",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.role,
            roleId: const Value("role-1"),
            startOffset: 0,
            endOffset: 3,
            taggedText: "one",
            needsCheck: const Value(true),
          ),
        );

    final createdTagId = await breakdownService.createTag(
      database: preview,
      sceneId: "scene-1",
      startOffset: 10,
      endOffset: 13,
      taggedText: "one",
      targetKind: OcptBreakdownTargetKind.role,
      targetId: "role-1",
    );
    await breakdownService.clearTagNeedsCheck(database: preview, tagId: "tag-1");
    await breakdownService.deleteTag(database: preview, tagId: "tag-1");
    final createdPair = await breakdownService.createElementAndTag(
      database: preview,
      sceneId: "scene-1",
      startOffset: 10,
      endOffset: 13,
      taggedText: "one",
      name: "Desk lamp",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    );
    final createdSetPair = await breakdownService.createSetAndTag(
      database: preview,
      sceneId: "scene-1",
      startOffset: 10,
      endOffset: 13,
      taggedText: "one",
      name: "Cuisine",
    );
    await breakdownService.updateSceneBreakdown(
      database: preview,
      sceneId: "scene-1",
      status: const Value(OcptBreakdownSceneStatus.done),
    );
    await breakdownService.reconcileTags(
      database: preview,
      screenplayId: screenplayId,
      currentFountainText: "EXT. STREET - NIGHT\n\nSomething else.\n",
      stamps: null,
    );

    expect(createdTagId, isNull);
    expect(createdPair, isNull);
    expect(createdSetPair, isNull);

    final tags = await preview.select(preview.ocptBreakdownTagsTable).get();
    expect(tags, hasLength(1));
    expect(tags.single.id, "tag-1");
    expect(tags.single.isDeleted, isFalse);
    expect(tags.single.startOffset, 0);
    expect(tags.single.needsCheck, isTrue);

    expect(await preview.select(preview.ocptElementsTable).get(), isEmpty);
    expect(await preview.select(preview.ocptLocationsTable).get(), isEmpty);
    expect(await preview.select(preview.ocptSetsTable).get(), isEmpty);
    expect(await preview.select(preview.ocptSceneBreakdownsTable).get(), isEmpty);
  });
}
