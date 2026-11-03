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
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String sceneId,
  String roleId,
  String element,
  String freeElement,
  String sceneLink,
  String roleLink,
});

/// Answer with the fixed device id.
Future<String> _testDeviceId() async => _deviceId;

/// Run the tests of what [OcptElementsService] answers when the database fails or refuses.
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
  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: OcptSceneIndexService(logger: SilentLogger()),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(logger: SilentLogger(), deviceId: _testDeviceId),
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: SilentLogger(),
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: _testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: SilentLogger(), deviceId: _testDeviceId),
    deviceId: _testDeviceId,
  );
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;
  late _Fixture rows;

  const tables = ["elements", "scene_elements", "role_elements", "assets"];

  /// Save a one-scene screenplay, a role, two elements and the links and photo of the first.
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
      fountainText: "INT. HOUSE - DAY\n\nAction.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((row) => row.isDeleted.equals(false))).getSingle();
    final roleId = (await roleIndexService
        .addRole(
          database: database,
          screenplayId: screenplayId,
          name: "CLARA",
          kind: OcptRoleKind.silent,
        )
        .valueOrFail);
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
    final sceneLink = await elementsService
        .addSceneElement(database: database, sceneId: scene.id, elementId: first)
        .valueOrFail;
    final roleLink = await elementsService
        .addRoleElement(database: database, roleId: roleId, elementId: first)
        .valueOrFail;
    await elementsService
        .setElementPhoto(database: database, elementId: first, path: "/photos/old.jpg")
        .valueOrFail;

    return (
      sceneId: scene.id,
      roleId: roleId,
      element: first,
      freeElement: free,
      sceneLink: sceneLink,
      roleLink: roleLink,
    );
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
    "createElement": (r) async => (await elementsService.createElement(
      database: database,
      name: "Sofa",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    )).status,
    "updateElement": (r) async => (await elementsService.updateElement(
      database: database,
      elementId: r.element,
      name: const Value("Changed"),
    )).status,
    "deleteElement": (r) async =>
        (await elementsService.deleteElement(database: database, elementId: r.element)).status,
    "setElementPhoto": (r) async => (await elementsService.setElementPhoto(
      database: database,
      elementId: r.element,
      path: "/photos/new.jpg",
    )).status,
    "clearElementPhoto": (r) async =>
        (await elementsService.clearElementPhoto(database: database, elementId: r.element)).status,
    "reorderElement": (r) async => (await elementsService.reorderElement(
      database: database,
      elementId: r.freeElement,
      newPosition: 0,
    )).status,
    "addSceneElement": (r) async => (await elementsService.addSceneElement(
      database: database,
      sceneId: r.sceneId,
      elementId: r.freeElement,
    )).status,
    "updateSceneElement": (r) async => (await elementsService.updateSceneElement(
      database: database,
      id: r.sceneLink,
      quantity: const Value("3"),
    )).status,
    "removeSceneElement": (r) async =>
        (await elementsService.removeSceneElement(database: database, id: r.sceneLink)).status,
    "addRoleElement": (r) async => (await elementsService.addRoleElement(
      database: database,
      roleId: r.roleId,
      elementId: r.freeElement,
    )).status,
    "updateRoleElement": (r) async => (await elementsService.updateRoleElement(
      database: database,
      id: r.roleLink,
      notes: "Worn",
    )).status,
    "removeRoleElement": (r) async =>
        (await elementsService.removeRoleElement(database: database, id: r.roleLink)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadElements": (r) async => (await elementsService.loadElements(database: database)).status,
    "sceneElementsOfScene": (r) async =>
        (await elementsService.sceneElementsOfScene(database: database, sceneId: r.sceneId)).status,
    "propsOfScene": (r) async =>
        (await elementsService.propsOfScene(database: database, sceneId: r.sceneId)).status,
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
        for (final table in tables) {
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
      final element = await elementsService
          .createElement(
            database: preview,
            name: "Sofa",
            category: OcptElementCategory.prop,
            sourceKind: OcptElementSourceKind.owned,
          )
          .maybeValueOrFail;
      final sceneLink = await elementsService
          .addSceneElement(database: preview, sceneId: rows.sceneId, elementId: rows.freeElement)
          .maybeValueOrFail;
      final roleLink = await elementsService
          .addRoleElement(database: preview, roleId: rows.roleId, elementId: rows.freeElement)
          .maybeValueOrFail;
      final photo = await elementsService
          .setElementPhoto(database: preview, elementId: rows.element, path: "/photos/new.jpg")
          .maybeValueOrFail;

      expect([element, sceneLink, roleLink, photo], everyElement(isNull));
    });

    test("a read is not refused", () async {
      expect(await elementsService.loadElements(database: preview).valueOrFail, isEmpty);
    });
  });

  group("a write that touches several rows is one transaction", () {
    test("an element whose links cannot be tombstoned stays live", () async {
      final untouched = await snapshot();
      await refuse("scene_elements", ["UPDATE"]);

      final deleted = await elementsService.deleteElement(
        database: database,
        elementId: rows.element,
      );

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });

    test("an element keeps its former photo when the new one cannot be minted", () async {
      final untouched = await snapshot();
      await refuse("assets", ["INSERT"]);

      final replaced = await elementsService.setElementPhoto(
        database: database,
        elementId: rows.element,
        path: "/photos/new.jpg",
      );

      expect(replaced.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the former photo stayed tombstoned");
    });
  });
}
