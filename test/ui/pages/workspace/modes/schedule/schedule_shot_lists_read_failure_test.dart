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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_reload_scope.dart';
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

/// A shot list service whose reads fail while [isFailing], and are the source service's own after.
class _FlakyShotListService extends OcptShotListService {
  /// Whether the next reads fail.
  bool isFailing = true;

  /// Class constructor
  _FlakyShotListService(OcptShotListService source)
    : super(
        logger: const SilentLogger(),
        roleIndexService: source.roleIndexService,
        storyboardService: source.storyboardService,
        floorPlanService: source.floorPlanService,
        deviceId: source.deviceId,
      );

  /// Fail as a refused read does while [isFailing].
  @override
  Future<OcptDatabaseResult<OcptShotListSnapshot>> loadShotList({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int? episodeNumber,
  }) async {
    if (isFailing) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "shot list read intentionally failed for the test",
      );
    }

    return super.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: episodeNumber,
    );
  }
}

/// What the schedule mode does when it cannot read the shot lists it is loaded with: it stops
/// before it emits anything, and goes on once they can be read.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late _FlakyShotListService shotListService;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_shot_lists_read_test_");
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
    shotListService = _FlakyShotListService(projectsManager.shotListService);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Build a mode bloc on the test project, reading the shot lists through the flaky service.
  OcptScheduleBloc buildMode() => OcptScheduleBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _SilentRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    shotListService: shotListService,
  );

  test("the mode stays loading while the shot lists cannot be read", () async {
    final mode = buildMode();
    addTearDown(mode.close);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(mode.state.isLoading, isTrue);
  });

  test("reading the shot lists again answers false and emits nothing", () async {
    shotListService.isFailing = false;
    final mode = buildMode();
    addTearDown(mode.close);
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final held = mode.state;
    shotListService.isFailing = true;

    expect(await mode.reload({OcptScheduleReloadScope.shotLists}), isFalse);

    expect(mode.state, same(held));
    expect(mode.state.reloadEpoch, held.reloadEpoch);
  });

  test(
    "reading the schedule and the shot lists together emits nothing when the lists fail",
    () async {
      shotListService.isFailing = false;
      final mode = buildMode();
      addTearDown(mode.close);
      await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
      final held = mode.state;
      shotListService.isFailing = true;

      expect(
        await mode.reload({OcptScheduleReloadScope.schedule, OcptScheduleReloadScope.shotLists}),
        isFalse,
      );

      expect(mode.state, same(held));
    },
  );

  test("the mode reads the shot lists again once they can be read", () async {
    shotListService.isFailing = false;
    final mode = buildMode();
    addTearDown(mode.close);
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final epoch = mode.state.reloadEpoch;

    expect(await mode.reload({OcptScheduleReloadScope.shotLists}), isTrue);

    expect(mode.state.reloadEpoch, greaterThan(epoch));
  });
}
