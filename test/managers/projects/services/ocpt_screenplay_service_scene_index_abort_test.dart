// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of what [OcptScreenplayService] does with a failure of the scene index, which
/// must undo whatever the same transaction had written before it.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const screenplayId = "screenplay-1";

  Future<String> testDeviceId() async => "test-device";

  final assetsService = OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId);

  final roleCandidatesService = OcptRoleCandidatesService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );

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
    roleCandidatesService: roleCandidatesService,
    deviceId: testDeviceId,
  );

  final breakdownService = OcptBreakdownService(
    logger: const SilentLogger(),
    elementsService: elementsService,
    locationsService: locationsService,
    deviceId: testDeviceId,
  );

  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);

  const sceneIndexService = OcptSceneIndexService(logger: SilentLogger());

  final shotListService = OcptShotListService(
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
  );

  final shotCoverageService = OcptShotCoverageService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );

  final service = OcptScreenplayService(
    logger: const SilentLogger(),
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    roleIndexService: roleIndexService,
    breakdownService: breakdownService,
    scheduleService: scheduleService,
    deviceId: testDeviceId,
  );

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
            sortKey: Value(ocptFractionalKeyBetween()),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  /// Every row of the tables a save or an episode deletion writes, the stamps included, as a
  /// comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [
      "screenplays",
      "screenplay_snapshots",
      "scenes",
      "shots",
      "row_field_versions",
    ]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Make every write on the scenes fail.
  Future<void> refuseSceneWrites() async {
    for (final verb in ["INSERT", "UPDATE"]) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_scenes BEFORE $verb ON scenes "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
    }
  }

  /// Lift what [refuseSceneWrites] put.
  Future<void> allowSceneWrites() async {
    for (final verb in ["insert", "update"]) {
      await database.customStatement("DROP TRIGGER refuse_${verb}_scenes");
    }
  }

  test(
    "a save whose scene index fails keeps the text, the snapshot and the stamps as they were",
    () async {
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "INT. HOUSE - DAY\n\nAction.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final untouched = await snapshot();
      await refuseSceneWrites();

      await expectLater(
        service.saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: "INT. CABIN - DAY\n\nAction.\n",
          snapshotReason: OcptSnapshotReason.manual,
        ),
        throwsA(anything),
      );

      expect(await snapshot(), untouched, reason: "the text and its snapshot were rolled back");

      await allowSceneWrites();
      await service.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: "INT. CABIN - DAY\n\nAction.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      expect(await snapshot(), isNot(untouched), reason: "the same save goes through");
    },
  );

  test(
    "an episode deletion whose scene tombstoning fails keeps the episode and its shots",
    () async {
      final otherId = (await service.createEpisode(database: database, title: "Episode 2"))!;
      await service.saveScreenplayText(
        database: database,
        screenplayId: otherId,
        fountainText: "INT. GARDEN - DAY\n\nAction.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final scene = await (database.select(
        database.ocptScenesTable,
      )..where((table) => table.screenplayId.equals(otherId))).getSingle();
      await shotListService
          .createShot(database: database, screenplayId: otherId, sceneId: scene.id)
          .maybeValueOrFail;
      final untouched = await snapshot();
      await refuseSceneWrites();

      await expectLater(
        service.deleteEpisode(database: database, screenplayId: otherId),
        throwsA(anything),
      );

      expect(await snapshot(), untouched, reason: "nothing the episode owns was tombstoned");

      await allowSceneWrites();
      expect(await service.deleteEpisode(database: database, screenplayId: otherId), isTrue);
      expect(await snapshot(), isNot(untouched), reason: "the same deletion goes through");
    },
  );
}
