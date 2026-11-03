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
  String screenplayRole,
  String roleA,
  String roleB,
  String element,
  String link,
});

/// Answer with the fixed device id.
Future<String> _testDeviceId() async => _deviceId;

/// Run the tests of what [OcptRoleIndexService] answers when the database fails or refuses.
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
  const otherScreenplayId = "screenplay-2";

  late OcptProjectDatabase database;
  late _Fixture rows;

  const tables = [
    "roles",
    "role_episodes",
    "role_elements",
    "role_candidates",
    "shot_characters",
    "breakdown_tags",
    "shooting_slot_cast",
  ];

  /// Save a screenplay naming a character, add two hand-made roles and one element linked to the
  /// first, and a second episode.
  Future<_Fixture> seed() async {
    for (final id in [screenplayId, otherScreenplayId]) {
      await database
          .into(database.ocptScreenplaysTable)
          .insert(
            OcptScreenplaysTableCompanion.insert(id: id, title: id, updatedAt: DateTime.now()),
          );
    }
    await screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: "INT. HOUSE - DAY\n\nCLARA\nHello there.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final fromScreenplay = (await roleIndexService.loadRoles(database: database).valueOrFail)
        .singleWhere((role) => role.name == "CLARA");
    Future<String> role(String name) => roleIndexService
        .addRole(
          database: database,
          screenplayId: screenplayId,
          name: name,
          kind: OcptRoleKind.silent,
        )
        .valueOrFail;
    final a = await role("PASSERBY");
    final b = await role("DRIVER");
    final element = await elementsService
        .createElement(
          database: database,
          name: "Coat",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail;
    final link = await elementsService
        .addRoleElement(database: database, roleId: a, elementId: element)
        .valueOrFail;

    return (screenplayRole: fromScreenplay.id, roleA: a, roleB: b, element: element, link: link);
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
    "addRole": (r) async => (await roleIndexService.addRole(
      database: database,
      screenplayId: screenplayId,
      name: "NEIGHBOUR",
      kind: OcptRoleKind.extra,
    )).status,
    "updateRole": (r) async => (await roleIndexService.updateRole(
      database: database,
      roleId: r.roleA,
      castingNotes: const Value("Tall"),
    )).status,
    "setRoleEpisodes": (r) async => (await roleIndexService.setRoleEpisodes(
      database: database,
      roleId: r.roleA,
      screenplayIds: {otherScreenplayId},
    )).status,
    "mergeRole": (r) async => (await roleIndexService.mergeRole(
      database: database,
      sourceRoleId: r.roleA,
      targetRoleId: r.roleB,
    )).status,
    "deleteRole": (r) async =>
        (await roleIndexService.deleteRole(database: database, roleId: r.roleA)).status,
    "keepOrphanedRoleAsSilent": (r) async => (await roleIndexService.keepOrphanedRoleAsSilent(
      database: database,
      roleId: r.screenplayRole,
    )).status,
    "reorderRole": (r) async => (await roleIndexService.reorderRole(
      database: database,
      roleId: r.roleB,
      newPosition: 0,
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadRoles": (r) async => (await roleIndexService.loadRoles(database: database)).status,
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
      final added = await roleIndexService
          .addRole(
            database: preview,
            screenplayId: screenplayId,
            name: "NEIGHBOUR",
            kind: OcptRoleKind.extra,
          )
          .maybeValueOrFail;

      expect(added, isNull);
    });

    test("a read is not refused", () async {
      expect(await roleIndexService.loadRoles(database: preview).valueOrFail, isEmpty);
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

    test("a role keeps its links when one of them cannot be tombstoned", () async {
      await expectNothingKept("role_episodes", ["UPDATE"], () => writes["deleteRole"]!(rows));
    });

    test("a role keeps its element links when the role row cannot be tombstoned", () async {
      await expectNothingKept("roles", ["UPDATE"], () => writes["deleteRole"]!(rows));
    });

    test("a merge moves nothing when the source role cannot be tombstoned", () async {
      await expectNothingKept("roles", ["UPDATE"], () => writes["mergeRole"]!(rows));
    });

    test("a new role is not kept without the link to its episode", () async {
      await expectNothingKept("role_episodes", ["INSERT"], () => writes["addRole"]!(rows));
    });

    test("an episodes change drops nothing when a new link cannot be written", () async {
      await expectNothingKept("role_episodes", ["INSERT"], () => writes["setRoleEpisodes"]!(rows));
    });
  });
}
