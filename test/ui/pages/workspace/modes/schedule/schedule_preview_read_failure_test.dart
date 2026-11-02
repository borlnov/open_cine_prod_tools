// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A schedule service whose read fails while [isReadFailing] is set.
class _ReadFailsScheduleService extends OcptScheduleService {
  /// Whether [loadSchedule] answers a failure.
  bool isReadFailing = false;

  /// Class constructor
  _ReadFailsScheduleService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  /// Fail as a refused read does while told to, otherwise read the schedule as the real service
  /// does.
  @override
  Future<OcptDatabaseResult<OcptScheduleSnapshot>> loadSchedule({
    required OcptProjectDatabase database,
  }) async {
    if (isReadFailing) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "schedule read intentionally failed for the test",
      );
    }

    return super.loadSchedule(database: database);
  }
}

/// The fixed device id [_ReadFailsScheduleService] stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

/// What entering and leaving a version preview does when the mode cannot read its data again: it
/// stops there, before the card's delete confirmation is dismissed, as a raised failure used to
/// stop it.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptScheduleBloc mode;
  late _ReadFailsScheduleService service;
  late String versionId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the mode time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_preview_read_failure_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
    versionId = (await projectsManager.createProjectVersion(name: "v1", note: ""))!.id;

    service = _ReadFailsScheduleService();
    mode = OcptScheduleBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      scheduleService: service,
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    await settle();
  });

  tearDown(() async {
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Ask for the delete confirmation of the version's card.
  Future<void> askForDeletion() async {
    mode.add(OcptProjectVersionDeletionRequestedEvent(versionId: versionId));
    await settle();
    expect(mode.state.versionPendingDeletionId, versionId);
  }

  test("entering a preview stops before the delete confirmation is dismissed", () async {
    await askForDeletion();
    service.isReadFailing = true;

    mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();

    expect(projectsManager.currentProject!.previewedVersion, isNotNull, reason: "it did enter");
    expect(mode.state.versionPendingDeletionId, versionId);
    expect(mode.state.previewedVersionId, isNull, reason: "the mode never read the version");
  });

  test("entering a preview dismisses the delete confirmation when the read works", () async {
    await askForDeletion();

    mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();

    expect(mode.state.previewedVersionId, versionId);
    expect(mode.state.versionPendingDeletionId, isNull);
  });

  test("leaving a preview stops before the delete confirmation is dismissed", () async {
    mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();
    expect(mode.state.previewedVersionId, versionId);
    await askForDeletion();
    service.isReadFailing = true;

    mode.add(const OcptProjectVersionPreviewExitRequestedEvent());
    await settle();

    expect(projectsManager.currentProject!.previewedVersion, isNull, reason: "it did leave");
    expect(mode.state.versionPendingDeletionId, versionId);
    expect(
      mode.state.previewedVersionId,
      versionId,
      reason: "the mode never read the working copy",
    );
  });

  test("leaving a preview dismisses the delete confirmation when the read works", () async {
    mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await settle();
    await askForDeletion();

    mode.add(const OcptProjectVersionPreviewExitRequestedEvent());
    await settle();

    expect(mode.state.previewedVersionId, isNull);
    expect(mode.state.versionPendingDeletionId, isNull);
  });
}
