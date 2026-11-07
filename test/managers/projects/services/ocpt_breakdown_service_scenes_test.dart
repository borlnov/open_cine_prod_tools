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
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the breakdown service scenes read.
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

  Future<OcptSceneBreakdownRow?> readSceneBreakdown(String sceneId) => (database.select(
    database.ocptSceneBreakdownsTable,
  )..where((row) => row.sceneId.equals(sceneId))).getSingleOrNull();

  /// Creates a role of screenplay [screenplayId], returning its id.
  Future<String> createRole() => roleIndexService
      .addRole(
        database: database,
        screenplayId: screenplayId,
        name: "LÉA",
        kind: OcptRoleKind.silent,
      )
      .valueOrFail;

  /// Saves [fountainText] as the screenplay's only content and returns its single resulting scene.
  Future<OcptSceneRow> saveSingleScene(String fountainText) async {
    await screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: fountainText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    return (await readScenes()).single;
  }

  group("loadScenes", () {
    test(
      "loads every live scene in position order, joined with its scene_breakdowns row, tags left "
      "empty",
      () async {
        await screenplayService
            .saveScreenplayText(
              database: database,
              screenplayId: screenplayId,
              fountainText: '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''',
              snapshotReason: OcptSnapshotReason.manual,
            )
            .okOrFail;
        final scenes = await readScenes();
        final houseScene = scenes.firstWhere((row) => row.heading == "INT. HOUSE - DAY");
        final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

        await breakdownService
            .updateSceneBreakdown(
              database: database,
              sceneId: houseScene.id,
              status: const Value(OcptBreakdownSceneStatus.done),
              notes: const Value("Needs a period lamp"),
            )
            .okOrFail;
        await breakdownService
            .createTag(
              database: database,
              sceneId: houseScene.id,
              startOffset: 0,
              endOffset: 3,
              taggedText: "one",
              targetKind: OcptBreakdownTargetKind.role,
              targetId: await createRole(),
            )
            .maybeValueOrFail;

        final loaded = await breakdownService
            .loadScenes(database: database, screenplayId: screenplayId, episodeNumber: null)
            .valueOrFail;

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
      await screenplayService
          .saveScreenplayText(
            database: database,
            screenplayId: screenplayId,
            fountainText: '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''',
            snapshotReason: OcptSnapshotReason.manual,
          )
          .okOrFail;
      final scenes = await readScenes();
      final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

      await (database.update(database.ocptScenesTable)
            ..where((table) => table.id.equals(streetScene.id)))
          .write(const OcptScenesTableCompanion(isDeleted: Value(true)));

      final loaded = await breakdownService
          .loadScenes(database: database, screenplayId: screenplayId, episodeNumber: null)
          .valueOrFail;

      expect(loaded.any((scene) => scene.id == streetScene.id), isFalse);
    });

    test(
      "filters out a tombstoned scene_breakdowns row, reading the scene as toDo again",
      () async {
        final scene = await saveSingleScene("INT. HOUSE - DAY\n\nAction one.\n");

        await breakdownService
            .updateSceneBreakdown(
              database: database,
              sceneId: scene.id,
              status: const Value(OcptBreakdownSceneStatus.done),
            )
            .okOrFail;
        final breakdownRow = (await readSceneBreakdown(scene.id))!;
        await (database.update(database.ocptSceneBreakdownsTable)
              ..where((table) => table.id.equals(breakdownRow.id)))
            .write(const OcptSceneBreakdownsTableCompanion(isDeleted: Value(true)));

        final loaded = await breakdownService
            .loadScenes(database: database, screenplayId: screenplayId, episodeNumber: null)
            .valueOrFail;

        expect(loaded.single.status, OcptBreakdownSceneStatus.toDo);
        expect(loaded.single.notes, "");
      },
    );

    test("carries the given episode number onto every scene's displayNumber", () async {
      await screenplayService
          .saveScreenplayText(
            database: database,
            screenplayId: screenplayId,
            fountainText: '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''',
            snapshotReason: OcptSnapshotReason.manual,
          )
          .okOrFail;

      final loadedWithoutEpisode = await breakdownService
          .loadScenes(database: database, screenplayId: screenplayId, episodeNumber: null)
          .valueOrFail;
      expect(loadedWithoutEpisode.map((scene) => scene.displayNumber), ["1", "2"]);

      final loadedWithEpisode = await breakdownService
          .loadScenes(database: database, screenplayId: screenplayId, episodeNumber: 2)
          .valueOrFail;
      expect(loadedWithEpisode.map((scene) => scene.displayNumber), ["2.1", "2.2"]);
    });
  });
}
