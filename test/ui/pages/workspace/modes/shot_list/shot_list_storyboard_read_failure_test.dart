// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_reader.dart';
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

/// What the shot list does when the storyboard cannot be read, with a real SQLite failure (the
/// table of the marks is gone while a panel holds some): the reader answers the failure, and every
/// read that composes it, the first load, a reload of the board and the read after a deleted
/// shot, stops where the exception stopped it.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late String emptyShotId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Build the mode bloc and wait for it to load, or just give it time when [expectsLoaded] is
  /// false.
  Future<void> buildMode({bool expectsLoaded = true}) async {
    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    if (expectsLoaded) {
      await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    } else {
      await pumpEventQueue(times: 200);
    }
  }

  /// Make the marks of the storyboard unreadable.
  Future<void> loseTheMarks() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE storyboard_annotations RENAME TO storyboard_annotations_gone",
  );

  /// Give the mode time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_storyboard_read_test_");
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
          fountainText: twoSceneText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;

    // Two shots, the second one holding a panel: the first one can be deleted without reading the
    // marks, which the read after it cannot do.
    await buildMode();
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await mode.stream.firstWhere((state) => state.selectedShotId != null);
    emptyShotId = mode.state.selectedShotId!;
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await mode.stream.firstWhere(
      (state) => state.selectedShotId != null && state.selectedShotId != emptyShotId,
    );
    final panelShotId = mode.state.selectedShotId!;
    final service = projectsManager.storyboardService;
    final panelId = await service
        .addPanel(database: project.database, shotId: panelShotId)
        .valueOrFail;
    await service
        .addAnnotation(
          database: project.database,
          panelId: panelId,
          kind: OcptStoryboardAnnotationKind.label,
          x1: 0.5,
          y1: 0.5,
        )
        .valueOrFail;
    expect(await mode.reload({OcptShotListReloadScope.storyboard}), isTrue);
  });

  tearDown(() async {
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test("the reader answers the failure of the storyboard instead of a snapshot", () async {
    await loseTheMarks();
    final reader = OcptShotListReader(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      shotListService: projectsManager.shotListService,
      roleIndexService: projectsManager.roleIndexService,
      scheduleService: projectsManager.scheduleService,
      storyboardService: projectsManager.storyboardService,
      floorPlanService: projectsManager.floorPlanService,
      locationsService: projectsManager.locationsService,
      screenplayIdOf: (project) => project.primaryScreenplayId,
    );

    final read = await reader.loadStoryboard(projectsManager.currentProject!);

    expect(read.status, OcptDatabaseStatus.databaseError);
    expect(read.value, isNull);
  });

  test("a mode that cannot read the storyboard stays loading", () async {
    await mode.close();
    await loseTheMarks();

    await buildMode(expectsLoaded: false);

    expect(mode.state.isLoading, isTrue);
    expect(mode.state.hasWriteError, isFalse);
  });

  test("reading the storyboard again answers false and shows the write error", () async {
    final storyboard = mode.state.storyboardSnapshot;
    final epoch = mode.state.reloadEpoch;
    await loseTheMarks();

    expect(await mode.reload({OcptShotListReloadScope.storyboard}), isFalse);

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.storyboardSnapshot, same(storyboard));
    expect(mode.state.reloadEpoch, epoch);
  });

  test("deleting a shot shows the write error and reselects nothing when the read fails", () async {
    mode.add(OcptShotListShotSelectedEvent(shotId: emptyShotId));
    await settle();
    final snapshot = mode.state.snapshot;
    final epoch = mode.state.reloadEpoch;
    await loseTheMarks();

    mode.add(OcptShotListShotDeletionRequestedEvent(shotId: emptyShotId));
    await settle();

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.selectedShotId, emptyShotId);
    expect(mode.state.snapshot, same(snapshot));
    expect(mode.state.reloadEpoch, epoch);
  });
}
