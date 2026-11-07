// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of what [OcptProjectVersionsService] answers when the database fails.
void main() {
  // Refusing a write logs through appLogger(), which requires a global manager instance to be set;
  // merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const deviceId = "device-1";
  Future<String> testDeviceId() async => deviceId;

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);
  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );
  final floorPlanService = OcptFloorPlanService(
    logger: const SilentLogger(),
    assetsService: assetsService,
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
  final screenplayService = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
    shotListService: OcptShotListService(
      logger: const SilentLogger(),
      roleIndexService: roleIndexService,
      storyboardService: OcptStoryboardService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        deviceId: testDeviceId,
      ),
      floorPlanService: floorPlanService,
      deviceId: testDeviceId,
    ),
    shotCoverageService: OcptShotCoverageService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: const SilentLogger(),
      elementsService: elementsService,
      locationsService: OcptLocationsService(
        logger: const SilentLogger(),
        assetsService: assetsService,
        floorPlanService: floorPlanService,
        deviceId: testDeviceId,
      ),
      deviceId: testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );
  final service = OcptProjectVersionsService(
    logger: const SilentLogger(),
    codec: const OcptProjectVersionCodec(logger: SilentLogger()),
    screenplayService: screenplayService,
  );

  const margins = FountainPageMargins(
    leftInches: 1.5,
    rightInches: 1,
    topInches: 0.75,
    bottomInches: 1.25,
  );

  late OcptProjectDatabase database;
  late String firstVersion;
  late String secondVersion;

  /// Every table the service writes, or reads to write.
  const tables = [
    "project_versions",
    "project_info",
    "screenplays",
    "scenes",
    "row_field_versions",
  ];

  /// Create a version named [name].
  Future<String> create(String name) async =>
      (await service
              .createVersion(
                database: database,
                name: name,
                note: "",
                appVersion: "0.1.0",
                deviceId: deviceId,
                pageMargins: margins,
              )
              .valueOrFail)
          .id;

  /// Open a fresh database holding a project and two versions.
  Future<void> seed() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "My Movie",
            createdAt: DateTime.utc(2026, 1, 4),
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
          ),
        );
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: "screenplay-1",
            title: "Draft",
            fountainText: const Value("INT. HOUSE - DAY\n\nCLARA enters."),
            updatedAt: DateTime.utc(2026, 1, 5),
          ),
        );
    firstVersion = await create("v1");
    secondVersion = await create("v2");
  }

  setUp(seed);

  /// Replace the database by a fresh seeded one.
  Future<void> tearDownAndSeed() async {
    await database.close();
    await seed();
  }

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function()>{
    "createVersion": () async => (await service.createVersion(
      database: database,
      name: "v3",
      note: "",
      appVersion: "0.1.0",
      deviceId: deviceId,
      pageMargins: margins,
    )).status,
    "renameVersion": () async => (await service.renameVersion(
      database: database,
      id: firstVersion,
      name: "v1 bis",
      note: "a note",
    )).status,
    "deleteVersion": () async =>
        (await service.deleteVersion(database: database, id: secondVersion)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function()>{
    "listVersions": () async => (await service.listVersions(database: database)).status,
    "loadVersion": () async =>
        (await service.loadVersion(database: database, id: firstVersion)).status,
    "loadPayload": () async =>
        (await service.loadPayload(database: database, id: firstVersion)).status,
    "captureWorkingCopyState": () async =>
        (await service.captureWorkingCopyState(database: database, pageMargins: margins)).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in tables) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2").get();
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
        expect(await entry.value(), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await tearDownAndSeed();

        final untouched = await snapshot();
        for (final table in ["project_versions", "project_info"]) {
          await refuse(table, ["INSERT", "UPDATE", "DELETE"]);
        }

        final status = await entry.value();

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in ["project_versions", "project_info"]) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(), OcptDatabaseStatus.databaseError);
      });
    }

    test("hydratePreview answers a database error and keeps nothing", () async {
      final payload =
          (await service.loadPayload(database: database, id: firstVersion).valueOrFail).value!;
      final info = await database.select(database.ocptProjectInfoTable).getSingle();
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);
      await preview.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");

      final hydrated = await service.hydratePreview(
        database: preview,
        projectInfo: info,
        payload: payload,
      );

      expect(hydrated.status, OcptDatabaseStatus.databaseError);
      expect(await preview.select(preview.ocptProjectInfoTable).get(), isEmpty);
    });
  });

  group("a write that touches several rows is one transaction", () {
    test("a created version is not kept when the header pointer cannot move", () async {
      await refuse("project_info", ["UPDATE"]);
      final untouched = await snapshot();

      final status = await writes["createVersion"]!();

      expect(status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });

    test("a deleted version keeps its row when the pointer to it cannot be cleared", () async {
      await refuse("project_info", ["UPDATE"]);
      final untouched = await snapshot();

      final deleted = await service.deleteVersion(database: database, id: secondVersion);

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });

    test("a deleted version keeps its pointer when its row cannot be deleted", () async {
      await refuse("project_versions", ["DELETE"]);
      final untouched = await snapshot();

      final deleted = await service.deleteVersion(database: database, id: secondVersion);

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
      expect(
        (await database.select(database.ocptProjectInfoTable).getSingle()).currentVersionId,
        secondVersion,
      );
    });
  });

  test("a version that does not exist is an answer, not a failure", () async {
    final missing = await service.loadVersion(database: database, id: "no-such").maybeValueOrFail;
    final payload = await service.loadPayload(database: database, id: "no-such").valueOrFail;

    expect(missing, isNull);
    expect(payload.status, OcptProjectVersionPayloadStatus.malformedPayload);
  });

  test("a restore still raises when it cannot read the version it restores", () async {
    await database.customStatement("ALTER TABLE project_versions RENAME TO project_versions_gone");

    expect(
      service.restoreVersion(
        database: database,
        id: firstVersion,
        safetyVersionName: "safety",
        appVersion: "0.1.0",
        deviceId: deviceId,
        pageMargins: margins,
      ),
      throwsA(anything),
    );
  });
}
