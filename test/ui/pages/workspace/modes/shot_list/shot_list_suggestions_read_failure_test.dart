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
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A shot list service whose field suggestions read fails while [isFailing].
class _FlakyShotListService extends OcptShotListService {
  /// Whether the next suggestion reads fail.
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
  Future<OcptDatabaseResult<OcptShotFieldSuggestions>> loadFieldSuggestions({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    if (isFailing) {
      return const OcptDatabaseResult(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: "suggestions read intentionally failed for the test",
      );
    }

    return super.loadFieldSuggestions(database: database, screenplayId: screenplayId);
  }
}

/// What the shot list mode does when it cannot read the field suggestions: the mode that loads
/// stays loading, a read again answers false and shows the write error, and nothing is emitted.
void main() {
  const text = "INT. HOUSE - DAY\n\nAction one.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late _FlakyShotListService shotListService;
  late OcptShotListBloc mode;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Build the mode bloc over the flaky service.
  OcptShotListBloc buildMode() => OcptShotListBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _SilentRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    shotListService: shotListService,
  );

  /// Build the mode bloc and wait for it to load.
  Future<void> buildLoadedMode() async {
    shotListService.isFailing = false;
    mode = buildMode();
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    shotListService.isFailing = true;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_suggestions_read_test_");
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
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    shotListService = _FlakyShotListService(projectsManager.shotListService);
  });

  tearDown(() async {
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test("a mode that cannot read the suggestions stays loading", () async {
    mode = buildMode();

    await pumpEventQueue(times: 200);

    expect(mode.state.isLoading, isTrue);
  });

  test("reading the suggestions again answers false and shows the write error", () async {
    await buildLoadedMode();
    final suggestions = mode.state.suggestions;
    final epoch = mode.state.reloadEpoch;

    expect(await mode.reload({OcptShotListReloadScope.suggestions}), isFalse);

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.suggestions, same(suggestions));
    expect(mode.state.reloadEpoch, epoch);
  });

  test("reading the snapshot and the suggestions together emits neither when they fail", () async {
    await buildLoadedMode();
    final snapshot = mode.state.snapshot;
    final epoch = mode.state.reloadEpoch;

    final isReloaded = await mode.reload({
      OcptShotListReloadScope.snapshot,
      OcptShotListReloadScope.suggestions,
    });

    expect(isReloaded, isFalse);
    expect(mode.state.snapshot, same(snapshot));
    expect(mode.state.reloadEpoch, epoch);
  });

  test("deleting a shot shows the write error and reselects nothing when the read fails", () async {
    shotListService.isFailing = false;
    mode = buildMode();
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await mode.stream.firstWhere((state) => state.selectedShotId != null);
    final shotId = mode.state.selectedShotId!;
    final snapshot = mode.state.snapshot;
    shotListService.isFailing = true;

    mode.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
    await pumpEventQueue(times: 200);

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.selectedShotId, shotId);
    expect(mode.state.snapshot, same(snapshot));
  });
}
