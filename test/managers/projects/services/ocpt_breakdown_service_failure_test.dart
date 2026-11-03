// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

/// The rows the calls of this file work on.
typedef _Fixture = ({String sceneId, String element, String freeElement, String tagId});

/// Answer with the fixed device id.
Future<String> _testDeviceId() async => _deviceId;

/// Run the tests of what [OcptBreakdownService] answers when the database fails or refuses.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId);
  const storyboardService = OcptStoryboardService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const elementsService = OcptElementsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const locationsService = OcptLocationsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    floorPlanService: OcptFloorPlanService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: _testDeviceId,
    ),
    deviceId: _testDeviceId,
  );
  const roleIndexService = OcptRoleIndexService(
    logger: SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: SilentLogger(),
      deviceId: _testDeviceId,
    ),
    deviceId: _testDeviceId,
  );
  const shotListService = OcptShotListService(
    logger: SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: storyboardService,
    floorPlanService: OcptFloorPlanService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: _testDeviceId,
    ),
    deviceId: _testDeviceId,
  );
  const breakdownService = OcptBreakdownService(
    logger: SilentLogger(),
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: _testDeviceId,
  );
  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: OcptSceneIndexService(logger: SilentLogger()),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(logger: SilentLogger(), deviceId: _testDeviceId),
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: OcptScheduleService(logger: SilentLogger(), deviceId: _testDeviceId),
    deviceId: _testDeviceId,
  );
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;
  late _Fixture rows;

  const tables = [
    "breakdown_tags",
    "scene_breakdowns",
    "elements",
    "scene_elements",
    "locations",
    "sets",
    "scene_sets",
  ];

  /// Save a one-scene screenplay, two elements, a tag on the first and one breakdown row.
  Future<_Fixture> seed() async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: "INT. HOUSE - DAY\n\nA lamp sits on the desk beside a chair.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((row) => row.isDeleted.equals(false))).getSingle();
    Future<String> element(String name) => elementsService
        .createElement(
          database: database,
          name: name,
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail;
    final first = await element("Lamp");
    final free = await element("Chair");
    final tagId = await breakdownService
        .createTag(
          database: database,
          sceneId: scene.id,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: first,
        )
        .valueOrFail;
    await database.customStatement("UPDATE breakdown_tags SET needs_check = 1");
    await breakdownService
        .updateSceneBreakdown(database: database, sceneId: scene.id, notes: const Value("Notes"))
        .okOrFail;

    return (sceneId: scene.id, element: first, freeElement: free, tagId: tagId);
  }

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// Tag the free element's own passage, at offsets that overlap nothing.
  Future<OcptDatabaseResult<String>> tagFreeElement(_Fixture r) => breakdownService.createTag(
    database: database,
    sceneId: r.sceneId,
    startOffset: 30,
    endOffset: 35,
    taggedText: "chair",
    targetKind: OcptBreakdownTargetKind.element,
    targetId: r.freeElement,
  );

  /// Create an element and tag it, at offsets that overlap nothing.
  Future<OcptDatabaseResult<({String elementId, String tagId})>> createElementAndTag(_Fixture r) =>
      breakdownService.createElementAndTag(
        database: database,
        sceneId: r.sceneId,
        startOffset: 20,
        endOffset: 24,
        taggedText: "desk",
        name: "Desk",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );

  /// Create a set, with a location of its own, and tag it, at offsets that overlap nothing.
  Future<OcptDatabaseResult<({String setId, String tagId})>> createSetAndTag(_Fixture r) =>
      breakdownService.createSetAndTag(
        database: database,
        sceneId: r.sceneId,
        startOffset: 20,
        endOffset: 24,
        taggedText: "desk",
        name: "House",
      );

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createTag": (r) async => (await tagFreeElement(r)).status,
    "createElementAndTag": (r) async => (await createElementAndTag(r)).status,
    "createSetAndTag": (r) async => (await createSetAndTag(r)).status,
    "deleteTag": (r) async =>
        (await breakdownService.deleteTag(database: database, tagId: r.tagId)).status,
    "clearTagNeedsCheck": (r) async =>
        (await breakdownService.clearTagNeedsCheck(database: database, tagId: r.tagId)).status,
    "updateSceneBreakdown": (r) async => (await breakdownService.updateSceneBreakdown(
      database: database,
      sceneId: r.sceneId,
      status: const Value(OcptBreakdownSceneStatus.done),
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadTags": (r) async => (await breakdownService.loadTags(database: database)).status,
    "loadSceneBreakdowns": (r) async =>
        (await breakdownService.loadSceneBreakdowns(database: database)).status,
    "loadScenes": (r) async => (await breakdownService.loadScenes(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: null,
    )).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Refuse the [verbs] on [table].
  Future<void> refuse(String table, List<String> verbs) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
    }
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
        for (final table in tables) {
          await refuse(table, ["INSERT", "UPDATE"]);
        }

        final status = await entry.value(rows);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in [...tables, "scenes"]) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("on the database of a version being previewed", () {
    late OcptProjectDatabase preview;

    setUp(() => preview = OcptProjectDatabase.memory(isPreview: true));

    tearDown(() => preview.close());

    test("every write is refused as a call that went well, and writes nothing", () async {
      final previous = database;
      database = preview;
      final untouched = await snapshot();

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a write that answers an id answers none", () async {
      final tagged = await breakdownService
          .createTag(
            database: preview,
            sceneId: rows.sceneId,
            startOffset: 30,
            endOffset: 35,
            taggedText: "chair",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: rows.freeElement,
          )
          .maybeValueOrFail;
      final element = await breakdownService
          .createElementAndTag(
            database: preview,
            sceneId: rows.sceneId,
            startOffset: 20,
            endOffset: 24,
            taggedText: "desk",
            name: "Desk",
            category: OcptElementCategory.prop,
            sourceKind: OcptElementSourceKind.owned,
          )
          .maybeValueOrFail;
      final set = await breakdownService
          .createSetAndTag(
            database: preview,
            sceneId: rows.sceneId,
            startOffset: 20,
            endOffset: 24,
            taggedText: "desk",
            name: "House",
          )
          .maybeValueOrFail;

      expect([tagged, element, set], everyElement(isNull));
    });

    test("a read is not refused", () async {
      expect(await breakdownService.loadTags(database: preview).valueOrFail, isEmpty);
      expect(await breakdownService.loadSceneBreakdowns(database: preview).valueOrFail, isEmpty);
    });
  });

  group("a write that touches several rows is one transaction", () {
    /// Refuse the [verbs] on [table], then expect [call] to answer a database error with every
    /// table as it was.
    Future<void> expectNothingKept(
      String table,
      List<String> verbs,
      Future<MixinResultStatus> Function() call,
    ) async {
      final untouched = await snapshot();
      await refuse(table, verbs);

      final status = await call();

      expect(status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    }

    test("an element is not minted when the tag that was its point is refused", () async {
      await expectNothingKept("breakdown_tags", [
        "INSERT",
      ], () async => (await createElementAndTag(rows)).status);
    });

    test("a tag is not kept when the element it points at is refused", () async {
      await expectNothingKept("elements", [
        "INSERT",
      ], () async => (await createElementAndTag(rows)).status);
    });

    test("an element and its tag are not kept when the scene link is refused", () async {
      await expectNothingKept("scene_elements", [
        "INSERT",
      ], () async => (await createElementAndTag(rows)).status);
    });

    test("a tag is not kept when its scene link is refused", () async {
      await expectNothingKept("scene_elements", [
        "INSERT",
      ], () async => (await tagFreeElement(rows)).status);
    });

    test("a set tag is not kept when its scene link is refused", () async {
      await expectNothingKept("scene_sets", [
        "INSERT",
      ], () async => (await createSetAndTag(rows)).status);
    });

    test(
      "a location and a set are not minted when the tag that was their point is refused",
      () async {
        await expectNothingKept("breakdown_tags", [
          "INSERT",
        ], () async => (await createSetAndTag(rows)).status);
      },
    );

    test(
      "a set and its tag are not minted when the location that was to hold it is refused",
      () async {
        await expectNothingKept("locations", [
          "INSERT",
        ], () async => (await createSetAndTag(rows)).status);
      },
    );

    test("a location is not kept when its set is refused", () async {
      await expectNothingKept("sets", ["INSERT"], () async => (await createSetAndTag(rows)).status);
    });

    test("a refused overlap keeps nothing and is not a failure", () async {
      final untouched = await snapshot();

      final created = await breakdownService.createElementAndTag(
        database: database,
        sceneId: rows.sceneId,
        startOffset: 2,
        endOffset: 6,
        taggedText: "lamp",
        name: "Lamp 2",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );

      expect(created.status, OcptDatabaseStatus.ok);
      expect(created.value, isNull);
      expect(await snapshot(), untouched);
    });
  });
}
