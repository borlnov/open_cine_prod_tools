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
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_reader.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state_derived.dart';
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

/// What the shot list does when the floor plans cannot be read, with a real SQLite failure (the
/// table of the plans is gone): the reader answers the failure, and every read that composes it,
/// the first load, a reload of the plans or of the set thumbnails and the read after a deleted
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

  /// Make the floor plans unreadable.
  Future<void> loseThePlans() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE floor_plan_sets RENAME TO floor_plan_sets_gone",
  );

  /// Make the symbols of the plans unreadable.
  Future<void> loseTheSymbols() => projectsManager.currentProject!.database.customStatement(
    "ALTER TABLE floor_plan_symbols RENAME TO floor_plan_symbols_gone",
  );

  /// Build a reader over the test project.
  OcptShotListReader buildReader() => OcptShotListReader(
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

  /// Give the mode time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_floor_plan_read_test_");
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

    // A set linked to the first scene, so that the plans have something to read, and two shots:
    // the first one can be selected, and deleted, whatever the plans hold.
    await buildMode();
    final sets = OcptShotListFloorPlanSetsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    addTearDown(sets.close);
    final epoch = mode.state.selectionEpoch;
    sets.add(const OcptShotListSetCreationRequestedEvent());
    await mode.stream.firstWhere((state) => state.selectionEpoch > epoch);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await mode.stream.firstWhere((state) => state.selectedShotId != null);
    emptyShotId = mode.state.selectedShotId!;
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await mode.stream.firstWhere(
      (state) => state.selectedShotId != null && state.selectedShotId != emptyShotId,
    );
    expect(await mode.reload({OcptShotListReloadScope.floorPlans}), isTrue);
  });

  tearDown(() async {
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test("the reader answers the failure of the plans instead of a snapshot", () async {
    await loseThePlans();
    final project = projectsManager.currentProject!;

    final read = await buildReader().loadFloorPlans(project);

    expect(read.status, OcptDatabaseStatus.databaseError);
    expect(read.value, isNull);
  });

  test("the reader answers the failure of the set thumbnails instead of a map", () async {
    await loseTheSymbols();
    final project = projectsManager.currentProject!;

    final read = await buildReader().loadSetScopeSymbolsBySetId(project);

    expect(read.status, OcptDatabaseStatus.databaseError);
    expect(read.value, isNull);
  });

  test("a mode that cannot read the plans stays loading", () async {
    await mode.close();
    await loseThePlans();

    await buildMode(expectsLoaded: false);

    expect(mode.state.isLoading, isTrue);
    expect(mode.state.hasWriteError, isFalse);
  });

  for (final (scope, lose) in [
    (OcptShotListReloadScope.floorPlans, loseThePlans),
    (OcptShotListReloadScope.setScopeSymbols, loseTheSymbols),
  ]) {
    test("reading $scope again answers false and shows the write error", () async {
      final plans = mode.state.floorPlanSnapshot;
      final epoch = mode.state.reloadEpoch;
      await lose();

      expect(await mode.reload({scope}), isFalse);

      expect(mode.state.hasWriteError, isTrue);
      expect(mode.state.floorPlanSnapshot, same(plans));
      expect(mode.state.reloadEpoch, epoch);
    });
  }

  test("the props of a sequence that cannot be read leave the palette with none", () async {
    final project = projectsManager.currentProject!;
    final sequence = mode.state.selectedSequence! as OcptSceneShotSequence;
    final elementId = await projectsManager.elementsService
        .createElement(
          database: project.database,
          name: "Lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .valueOrFail;
    await projectsManager.elementsService
        .addSceneElement(
          database: project.database,
          sceneId: sequence.sceneId,
          elementId: elementId,
        )
        .valueOrFail;
    final sets = OcptShotListFloorPlanSetsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    addTearDown(sets.close);
    sets.add(OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: sequence.id));
    await settle();
    expect(sets.state.propsOfSelectedSequence, hasLength(1));

    await project.database.customStatement(
      "ALTER TABLE scene_elements RENAME TO scene_elements_gone",
    );
    sets.add(OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: sequence.id));
    await settle();

    expect(sets.state.propsOfSelectedSequence, isEmpty);
    expect(sets.state.hasWriteError, isFalse);
  });

  test("deleting a shot shows the write error and reselects nothing when the read fails", () async {
    mode.add(OcptShotListShotSelectedEvent(shotId: emptyShotId));
    await settle();
    final snapshot = mode.state.snapshot;
    final epoch = mode.state.reloadEpoch;
    await loseThePlans();

    mode.add(OcptShotListShotDeletionRequestedEvent(shotId: emptyShotId));
    await settle();

    expect(mode.state.hasWriteError, isTrue);
    expect(mode.state.selectedShotId, emptyShotId);
    expect(mode.state.snapshot, same(snapshot));
    expect(mode.state.reloadEpoch, epoch);
  });
}
