// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String testAppLanguageCode() => "en";

/// The fixed device id every stamping service built in this file uses.
Future<String> testDeviceId() async => "test-device";

/// A screenplay service whose saves always fail, to exercise the bloc's save error path. Loads
/// still go through the real implementation.
class FailingScreenplayService extends OcptScreenplayService {
  /// Class constructor
  const FailingScreenplayService()
    : super(
        logger: const SilentLogger(),
        sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
        shotListService: const OcptShotListService(
          logger: SilentLogger(),
          roleIndexService: OcptRoleIndexService(
            logger: SilentLogger(),
            elementsService: OcptElementsService(
              logger: SilentLogger(),
              assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
              deviceId: testDeviceId,
            ),
            roleCandidatesService: OcptRoleCandidatesService(
              logger: SilentLogger(),
              deviceId: testDeviceId,
            ),
            deviceId: testDeviceId,
          ),
          storyboardService: OcptStoryboardService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
            deviceId: testDeviceId,
          ),
          floorPlanService: OcptFloorPlanService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
            deviceId: testDeviceId,
          ),
          deviceId: testDeviceId,
        ),
        shotCoverageService: const OcptShotCoverageService(
          logger: SilentLogger(),
          deviceId: testDeviceId,
        ),
        roleIndexService: const OcptRoleIndexService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
            deviceId: testDeviceId,
          ),
          roleCandidatesService: OcptRoleCandidatesService(
            logger: SilentLogger(),
            deviceId: testDeviceId,
          ),
          deviceId: testDeviceId,
        ),
        breakdownService: const OcptBreakdownService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
            deviceId: testDeviceId,
          ),
          locationsService: OcptLocationsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
            floorPlanService: OcptFloorPlanService(
              logger: SilentLogger(),
              assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId),
              deviceId: testDeviceId,
            ),
            deviceId: testDeviceId,
          ),
          deviceId: testDeviceId,
        ),
        scheduleService: const OcptScheduleService(logger: SilentLogger(), deviceId: testDeviceId),
        deviceId: testDeviceId,
      );

  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  @override
  Future<void> saveScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
  }) async => throw StateError("save intentionally failed for the test");
}

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
///
/// [onPop] lets a test await the exact moment [pop] is called, rather than racing on an unrelated
/// state emitted earlier in the same event handler (the emitted state and the handler's own
/// completion are not ordered with respect to a stream listener in the test).
class RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Whether [pop] was called.
  bool get popped => _popCompleter.isCompleted;

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// An export manager that is never asked for anything: these tests do not export.
class InertExportManager extends OcptExportManager {
  /// Class constructor
  InertExportManager() : super(fileSelectorManager: const FileSelectorManager());
}
