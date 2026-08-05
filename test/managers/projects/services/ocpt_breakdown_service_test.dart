// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const elementsService = OcptElementsService();
  const locationsService = OcptLocationsService();
  const roleIndexService = OcptRoleIndexService();
  const breakdownService = OcptBreakdownService(
    elementsService: elementsService,
    locationsService: locationsService,
  );
  const sceneIndexService = OcptSceneIndexService();
  const screenplayService = OcptScreenplayService(
    sceneIndexService: sceneIndexService,
    shotListService: OcptShotListService(),
    shotCoverageService: OcptShotCoverageService(),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
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

  /// Every live breakdown tag row.
  Future<List<OcptBreakdownTagRow>> readLiveTags() =>
      (database.select(database.ocptBreakdownTagsTable)..where((row) => row.isDeleted.equals(false))).get();

  Future<OcptBreakdownTagRow> readTag(String id) =>
      (database.select(database.ocptBreakdownTagsTable)..where((row) => row.id.equals(id))).getSingle();

  Future<List<OcptElementRow>> readLiveElements() =>
      (database.select(database.ocptElementsTable)..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptSceneElementRow>> readLiveSceneElements() => (database.select(
    database.ocptSceneElementsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptSceneSetRow>> readLiveSceneSets() =>
      (database.select(database.ocptSceneSetsTable)..where((row) => row.isDeleted.equals(false))).get();

  Future<OcptSceneBreakdownRow?> readSceneBreakdown(String sceneId) =>
      (database.select(database.ocptSceneBreakdownsTable)..where((row) => row.sceneId.equals(sceneId)))
          .getSingleOrNull();

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
  Future<String> createRole() =>
      roleIndexService
          .addRole(database: database, screenplayId: screenplayId, name: "LÉA", kind: OcptRoleKind.silent)
          .then((id) => id!);

  /// Creates a location and a set inside it, returning the set's id.
  Future<String> createSet() async {
    final locationId = (await locationsService.createLocation(database: database, name: "House"))!;
    return (await locationsService.createSet(database: database, locationId: locationId, name: "Kitchen"))!;
  }

  group("createTag", () {
    test("writes the element column for an element target, leaving role/set null", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final elementId = (await elementsService.createElement(
        database: database,
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      ))!;

      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      ))!;

      final tag = await readTag(tagId);
      expect(tag.targetKind, OcptBreakdownTargetKind.element);
      expect(tag.elementId, elementId);
      expect(tag.roleId, isNull);
      expect(tag.setId, isNull);
      expect(await readLiveTags(), [tag]);
    });

    test("writes the role column for a role target, leaving element/set null", () async {
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

      final tag = await readTag(tagId);
      expect(tag.targetKind, OcptBreakdownTargetKind.role);
      expect(tag.roleId, roleId);
      expect(tag.elementId, isNull);
      expect(tag.setId, isNull);
    });

    test("writes the set column for a set target, leaving element/role null", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final setId = await createSet();

      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.set,
        targetId: setId,
      ))!;

      final tag = await readTag(tagId);
      expect(tag.targetKind, OcptBreakdownTargetKind.set);
      expect(tag.setId, setId);
      expect(tag.elementId, isNull);
      expect(tag.roleId, isNull);
    });

    test("ensures the scene_elements link for an element target", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final elementId = (await elementsService.createElement(
        database: database,
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      ))!;

      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      );

      final links = await readLiveSceneElements();
      expect(links, hasLength(1));
      expect(links.single.sceneId, scene.id);
      expect(links.single.elementId, elementId);
      expect(await readLiveSceneSets(), isEmpty);
    });

    test("ensures the scene_sets link for a set target", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final setId = await createSet();

      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.set,
        targetId: setId,
      );

      final links = await readLiveSceneSets();
      expect(links, hasLength(1));
      expect(links.single.sceneId, scene.id);
      expect(links.single.setId, setId);
      expect(await readLiveSceneElements(), isEmpty);
    });

    test("a role target creates neither a scene_elements nor a scene_sets link", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final roleId = await createRole();

      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );

      expect(await readLiveSceneElements(), isEmpty);
      expect(await readLiveSceneSets(), isEmpty);
    });

    test("refuses a range overlapping a live tag of the same scene, writing nothing", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two three four five.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();

      final twoStart = sceneText.indexOf("two");
      final threeEnd = sceneText.indexOf("three") + "three".length;
      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: twoStart,
        endOffset: threeEnd,
        taggedText: sceneText.substring(twoStart, threeEnd),
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );
      expect(await readLiveTags(), hasLength(1));

      // "three four" overlaps the "two three" tag already there.
      final threeStart = sceneText.indexOf("three");
      final fourEnd = sceneText.indexOf("four") + "four".length;
      final refused = await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: threeStart,
        endOffset: fourEnd,
        taggedText: sceneText.substring(threeStart, fourEnd),
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );

      expect(refused, isNull);
      expect(await readLiveTags(), hasLength(1));
    });

    test("accepts a range that only touches an existing tag end to end", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two three.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();

      final oneStart = sceneText.indexOf("one");
      final oneEnd = oneStart + "one".length;
      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: oneStart,
        endOffset: oneEnd,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );

      // "two" starts exactly where "one" ends (through the space): touching, not overlapping.
      final twoStart = sceneText.indexOf("two");
      final twoEnd = twoStart + "two".length;
      final secondTagId = await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: oneEnd,
        endOffset: twoEnd,
        taggedText: sceneText.substring(oneEnd, twoEnd),
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );

      expect(secondTagId, isNotNull);
      expect(await readLiveTags(), hasLength(2));
    });

    test("throws ArgumentError for a malformed range", () async {
      expect(
        () => breakdownService.createTag(
          database: database,
          sceneId: "scene-1",
          startOffset: 5,
          endOffset: 5,
          taggedText: "never read",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: "role-1",
        ),
        throwsArgumentError,
      );
      expect(
        () => breakdownService.createTag(
          database: database,
          sceneId: "scene-1",
          startOffset: -1,
          endOffset: 3,
          taggedText: "never read",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: "role-1",
        ),
        throwsArgumentError,
      );
    });
  });

  group("deleteTag", () {
    test("tombstones the tag and leaves the scene_elements link alone", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final elementId = (await elementsService.createElement(
        database: database,
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      ))!;
      final tagId = (await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
      ))!;

      await breakdownService.deleteTag(database: database, tagId: tagId);

      final tag = await readTag(tagId);
      expect(tag.isDeleted, isTrue);

      final links = await readLiveSceneElements();
      expect(links, hasLength(1));
      expect(links.single.elementId, elementId);
    });
  });

  group("clearTagNeedsCheck", () {
    test("clears the flag alone, leaving the offsets exactly where they are", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
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
      );
      expect((await readTag(tagId)).needsCheck, isTrue);

      await breakdownService.clearTagNeedsCheck(database: database, tagId: tagId);

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isFalse);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
    });
  });

  group("createElementAndTag", () {
    test("mints the element with a generated code and toFind status, and tags it", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");

      final result = await breakdownService.createElementAndTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );

      expect(result, isNotNull);
      final element = (await readLiveElements()).singleWhere((row) => row.id == result!.elementId);
      expect(element.name, "Desk lamp");
      expect(element.code, isNotEmpty);
      expect(element.status, OcptElementStatus.toFind);

      final tag = await readTag(result!.tagId);
      expect(tag.targetKind, OcptBreakdownTargetKind.element);
      expect(tag.elementId, result.elementId);

      expect(await readLiveSceneElements(), hasLength(1));
    });

    test("rolls both writes back when the tag half is refused, leaving no orphan element", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two three.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();

      // Occupy the whole range with an existing tag first, so the popover's own attempt overlaps.
      final start = sceneText.indexOf("one");
      final end = sceneText.indexOf("three") + "three".length;
      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: end,
        taggedText: sceneText.substring(start, end),
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );
      final elementsBefore = await readLiveElements();

      final result = await breakdownService.createElementAndTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: end,
        taggedText: sceneText.substring(start, end),
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );

      expect(result, isNull);
      expect(await readLiveElements(), elementsBefore);
      expect(await readLiveTags(), hasLength(1));
    });
  });

  group("createSetAndTag", () {
    test("mints the set inside the location given, tags it and ensures the link", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");
      final locationId = (await locationsService.createLocation(
        database: database,
        name: "Maison des Martin",
      ))!;

      final result = await breakdownService.createSetAndTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        name: "Cuisine",
        locationId: locationId,
      );

      expect(result, isNotNull);
      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.sets.single.id, result!.setId);
      expect(locations.single.sets.single.name, "Cuisine");

      final tag = await readTag(result.tagId);
      expect(tag.targetKind, OcptBreakdownTargetKind.set);
      expect(tag.setId, result.setId);

      expect(await readLiveSceneSets(), hasLength(1));
    });

    test("mints a location of its own, named after the set, when given none", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");

      final result = await breakdownService.createSetAndTag(
        database: database,
        sceneId: scene.id,
        startOffset: 0,
        endOffset: 3,
        taggedText: "one",
        name: "Cuisine",
      );

      expect(result, isNotNull);
      final locations = await locationsService.loadLocations(database: database);
      expect(locations.single.name, "Cuisine");
      expect(locations.single.sets.single.id, result!.setId);
    });

    test("rolls every write back when the tag half is refused", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two three.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle())
          .fountainText
          .substring(scene.charStart, scene.charEnd);
      final roleId = await createRole();

      // Occupy the whole range first, so the creation's own tag overlaps and is refused.
      final start = sceneText.indexOf("one");
      final end = sceneText.indexOf("three") + "three".length;
      await breakdownService.createTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: end,
        taggedText: sceneText.substring(start, end),
        targetKind: OcptBreakdownTargetKind.role,
        targetId: roleId,
      );

      final result = await breakdownService.createSetAndTag(
        database: database,
        sceneId: scene.id,
        startOffset: start,
        endOffset: end,
        taggedText: sceneText.substring(start, end),
        name: "Cuisine",
      );

      expect(result, isNull);
      // Neither the set nor the location minted to hold it survives the tag that was their point.
      expect(await locationsService.loadLocations(database: database), isEmpty);
      expect(await readLiveTags(), hasLength(1));
    });
  });

  group("updateSceneBreakdown", () {
    test("creates the row on first write, updates it on the second without duplicating it", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        status: const Value(OcptBreakdownSceneStatus.inProgress),
      );

      final firstWrite = await readSceneBreakdown(scene.id);
      expect(firstWrite, isNotNull);
      expect(firstWrite!.status, OcptBreakdownSceneStatus.inProgress);
      expect(firstWrite.notes, isEmpty);

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        notes: const Value("Needs a period lamp"),
      );

      final allRows = await database.select(database.ocptSceneBreakdownsTable).get();
      expect(allRows, hasLength(1));
      expect(allRows.single.id, firstWrite.id);
      expect(allRows.single.status, OcptBreakdownSceneStatus.inProgress);
      expect(allRows.single.notes, "Needs a period lamp");
    });

    test("revives a tombstoned row instead of duplicating it", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        notes: const Value("Old notes"),
      );
      final original = (await readSceneBreakdown(scene.id))!;

      await (database.update(
        database.ocptSceneBreakdownsTable,
      )..where((table) => table.id.equals(original.id))).write(
        const OcptSceneBreakdownsTableCompanion(isDeleted: Value(true)),
      );

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        status: const Value(OcptBreakdownSceneStatus.done),
      );

      final allRows = await database.select(database.ocptSceneBreakdownsTable).get();
      expect(allRows, hasLength(1));
      expect(allRows.single.id, original.id);
      expect(allRows.single.isDeleted, isFalse);
      expect(allRows.single.status, OcptBreakdownSceneStatus.done);
      // Notes were not passed on the reviving call, so the value the row already held survives.
      expect(allRows.single.notes, "Old notes");
    });
  });

  group("loadTags / loadSceneBreakdowns", () {
    test(
      "filter tombstones and rows whose scene is tombstoned, ordering tags by scene then offset",
      () async {
        await screenplayService.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: '''
INT. HOUSE - DAY

Action one two.

EXT. STREET - NIGHT

Action three four.
''',
          snapshotReason: OcptSnapshotReason.manual,
        );
        final scenes = await readScenes();
        final houseScene = scenes.firstWhere((row) => row.heading == "INT. HOUSE - DAY");
        final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");
        final fountainText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText;
        final houseText = fountainText.substring(houseScene.charStart, houseScene.charEnd);
        final roleId = await createRole();

        final streetTagId = (await breakdownService.createTag(
          database: database,
          sceneId: streetScene.id,
          startOffset: 0,
          endOffset: 3,
          taggedText: "Act",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: roleId,
        ))!;
        final oneStart = houseText.indexOf("one");
        final houseTagLateId = (await breakdownService.createTag(
          database: database,
          sceneId: houseScene.id,
          startOffset: oneStart,
          endOffset: oneStart + "one".length,
          taggedText: "one",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: roleId,
        ))!;
        final houseTagEarlyId = (await breakdownService.createTag(
          database: database,
          sceneId: houseScene.id,
          startOffset: 0,
          endOffset: 3,
          taggedText: "INT",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: roleId,
        ))!;
        // A tombstoned tag must not appear in loadTags at all.
        final twoStart = houseText.indexOf("two");
        final removedTagId = (await breakdownService.createTag(
          database: database,
          sceneId: houseScene.id,
          startOffset: twoStart,
          endOffset: twoStart + "two".length,
          taggedText: "two",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: roleId,
        ))!;
        await breakdownService.deleteTag(database: database, tagId: removedTagId);

        await breakdownService.updateSceneBreakdown(
          database: database,
          sceneId: streetScene.id,
          status: const Value(OcptBreakdownSceneStatus.done),
        );
        await breakdownService.updateSceneBreakdown(
          database: database,
          sceneId: houseScene.id,
          status: const Value(OcptBreakdownSceneStatus.inProgress),
        );

        // Tombstone the street scene directly, as a fresh reconciliation would.
        await (database.update(
          database.ocptScenesTable,
        )..where((table) => table.id.equals(streetScene.id))).write(
          const OcptScenesTableCompanion(isDeleted: Value(true)),
        );

        final tags = await breakdownService.loadTags(database: database, screenplayId: screenplayId);
        expect(tags.map((row) => row.id), [houseTagEarlyId, houseTagLateId]);
        expect(tags.any((row) => row.id == streetTagId), isFalse);
        expect(tags.any((row) => row.id == removedTagId), isFalse);

        final sceneBreakdowns = await breakdownService.loadSceneBreakdowns(
          database: database,
          screenplayId: screenplayId,
        );
        expect(sceneBreakdowns.map((row) => row.sceneId), [houseScene.id]);
      },
    );
  });

  group("loadScenes", () {
    test(
      "loads every live scene in position order, joined with its scene_breakdowns row, tags left empty",
      () async {
        await screenplayService.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''',
          snapshotReason: OcptSnapshotReason.manual,
        );
        final scenes = await readScenes();
        final houseScene = scenes.firstWhere((row) => row.heading == "INT. HOUSE - DAY");
        final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

        await breakdownService.updateSceneBreakdown(
          database: database,
          sceneId: houseScene.id,
          status: const Value(OcptBreakdownSceneStatus.done),
          notes: const Value("Needs a period lamp"),
        );
        await breakdownService.createTag(
          database: database,
          sceneId: houseScene.id,
          startOffset: 0,
          endOffset: 3,
          taggedText: "one",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: await createRole(),
        );

        final loaded = await breakdownService.loadScenes(
          database: database,
          screenplayId: screenplayId,
        );

        expect(loaded.map((scene) => scene.id), [houseScene.id, streetScene.id]);

        final loadedHouse = loaded.firstWhere((scene) => scene.id == houseScene.id);
        expect(loadedHouse.status, OcptBreakdownSceneStatus.done);
        expect(loadedHouse.notes, "Needs a period lamp");
        // The tags are left for OcptBreakdownSnapshot.build to attach, not loaded here.
        expect(loadedHouse.tags, isEmpty);

        final loadedStreet = loaded.firstWhere((scene) => scene.id == streetScene.id);
        expect(loadedStreet.status, OcptBreakdownSceneStatus.toDo);
        expect(loadedStreet.notes, "");
      },
    );

    test("filters out a tombstoned scene", () async {
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''',
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scenes = await readScenes();
      final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

      await (database.update(
        database.ocptScenesTable,
      )..where((table) => table.id.equals(streetScene.id))).write(
        const OcptScenesTableCompanion(isDeleted: Value(true)),
      );

      final loaded = await breakdownService.loadScenes(
        database: database,
        screenplayId: screenplayId,
      );

      expect(loaded.any((scene) => scene.id == streetScene.id), isFalse);
    });

    test("filters out a tombstoned scene_breakdowns row, reading the scene as toDo again", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");

      await breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: scene.id,
        status: const Value(OcptBreakdownSceneStatus.done),
      );
      final breakdownRow = (await readSceneBreakdown(scene.id))!;
      await (database.update(
        database.ocptSceneBreakdownsTable,
      )..where((table) => table.id.equals(breakdownRow.id))).write(
        const OcptSceneBreakdownsTableCompanion(isDeleted: Value(true)),
      );

      final loaded = await breakdownService.loadScenes(
        database: database,
        screenplayId: screenplayId,
      );

      expect(loaded.single.status, OcptBreakdownSceneStatus.toDo);
      expect(loaded.single.notes, "");
    });
  });

  group("reconcileTags", () {
    test("leaves an unchanged tag untouched", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
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
        currentFountainText: (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText,
      );

      expect(await readTag(tagId), before);
    });

    test("re-anchors silently when the passage shifted earlier in the same scene", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
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
      final streetScene = (await readScenes()).firstWhere((row) => row.heading == "EXT. STREET - NIGHT");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
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
      );

      final tag = await readTag(tagId);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
      expect(tag.needsCheck, isFalse);
    });

    test("flags a tag whose text is gone", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one two.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
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
      );

      final tag = await readTag(tagId);
      expect(tag.needsCheck, isTrue);
      expect(tag.startOffset, start);
      expect(tag.endOffset, start + "two".length);
    });

    test("flags, and keeps the offsets of, a tag whose text now appears twice", () async {
      final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction alpha beta.\n");
      final sceneText = (await database.select(database.ocptScreenplaysTable).getSingle()).fountainText
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
      final streetScene = (await readScenes()).firstWhere((row) => row.heading == "EXT. STREET - NIGHT");
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
      );

      final tag = await readTag(tagId);
      expect(tag.isDeleted, isTrue);
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
          OcptRolesTableCompanion.insert(
            id: "role-1",
            screenplayId: screenplayId,
            name: "LÉA",
            kind: OcptRoleKind.silent,
          ),
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
