// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

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

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() resolvable; the bloc's dependencies
    // themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the breakdown mode its scenes.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Builds a bloc wired to the test project. [overrideProjectsManager] lets a test swap in a
  /// manager of its own (already holding an open project), for the one that needs to observe it.
  OcptBreakdownBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptProjectsManager? overrideProjectsManager,
  }) => OcptBreakdownBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptBreakdownState> waitForState(
    OcptBreakdownBloc bloc,
    bool Function(OcptBreakdownState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test("the breakdown mode's preference round-trips through the persisted workspace mode", () async {
    await propertiesManager.workspaceMode.store(OcptWorkspaceMode.breakdown);

    expect(await propertiesManager.workspaceMode.load(), OcptWorkspaceMode.breakdown);
  });

  test("loads the project's title and an empty snapshot when the screenplay has no scene", () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.title, "My Movie");
    expect(state.scenes, isEmpty);
    expect(state.taggedTargetCount, 0);
    expect(state.usedCategoryCount, 0);
    expect(state.toFindCount, 0);
    expect(state.selectedSceneId, isNull);

    await bloc.close();
  });

  test("loads every scene of the screenplay, in source order", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => state.scenes.length == 2);

    expect(state.scenes[0].heading, "INT. HOUSE - DAY");
    expect(state.scenes[1].heading, "EXT. GARDEN - NIGHT");
    expect(state.screenplayText, contains("INT. HOUSE - DAY"));

    await bloc.close();
  });

  test("a tagged element is resolved into the snapshot's targets and counters", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");

    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(project.database.ocptScenesTable)).get())
        .single
        .id;

    final elementId = await projectsManager.elementsService.createElement(
      database: project.database,
      name: "Desk lamp",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    );
    expect(elementId, isNotNull);

    final tagId = await projectsManager.breakdownService.createTag(
      database: project.database,
      sceneId: sceneId,
      startOffset: 2,
      endOffset: 6,
      taggedText: "lamp",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId!,
    );
    expect(tagId, isNotNull);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    expect(state.usedCategoryCount, 1);
    expect(state.targets.single.name, "Desk lamp");
    expect(state.scenes.single.tags, hasLength(1));

    await bloc.close();
  });

  test("selecting a scene that exists updates the selection", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId));
    final state = await waitForState(bloc, (state) => state.selectedSceneId != null);

    expect(state.selectedSceneId, sceneId);

    await bloc.close();
  });

  test("selecting a scene id that no longer exists is ignored", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);

    bloc.add(const OcptBreakdownSceneSelectedEvent(sceneId: "not-a-scene"));
    // Nothing to wait for since nothing should change; give the event a moment to be processed.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.selectedSceneId, isNull);

    await bloc.close();
  });

  test("toggling the left dock flips its visibility", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.isListPanelVisible, isTrue);

    bloc.add(const OcptBreakdownLeftPanelToggledEvent());
    final state = await waitForState(bloc, (state) => !state.isListPanelVisible);

    expect(state.isListPanelVisible, isFalse);

    await bloc.close();
  });

  test("dock fractions are persisted per drag and restored on the next entry", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownDockFractionsChangedEvent(left: 0.3, right: null));
    await waitForState(bloc, (state) => state.leftDockFraction == 0.3);
    bloc.add(const OcptBreakdownDockFractionsChangedEvent(left: null, right: 0.25));
    await waitForState(bloc, (state) => state.rightDockFraction == 0.25);
    await bloc.close();

    expect(await propertiesManager.breakdownLeftDockFraction.load(), 0.3);
    expect(await propertiesManager.breakdownRightDockFraction.load(), 0.25);

    final reopened = buildBloc();
    final reopenedState = await waitForState(reopened, (state) => !state.isLoading);

    expect(reopenedState.leftDockFraction, 0.3);
    expect(reopenedState.rightDockFraction, 0.25);

    await reopened.close();
  });

  test("resetting the panel layout restores both fractions to their defaults", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownDockFractionsChangedEvent(left: 0.1, right: 0.6));
    await waitForState(bloc, (state) => state.leftDockFraction == 0.1);

    bloc.add(const OcptBreakdownDockLayoutResetEvent());
    final state = await waitForState(
      bloc,
      (state) => state.leftDockFraction == OcptWorkspaceDock.leftDefaultFraction,
    );

    expect(state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);
    expect(await propertiesManager.breakdownLeftDockFraction.load(), OcptWorkspaceDock.leftDefaultFraction);
    expect(
      await propertiesManager.breakdownRightDockFraction.load(),
      OcptWorkspaceDock.rightDefaultFraction,
    );

    await bloc.close();
  });

  test("going back closes the current project and pops", () async {
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test(
    "previewing a version emits its own scenes together with its id, in the same state",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => state.scenes.isNotEmpty);

      bloc.add(
        const OcptProjectVersionCreationRequestedEvent(name: "One scene", note: ""),
      );
      final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
      final versionId = withVersion.projectVersions.single.id;

      // A second scene, written after the version, must not be part of what it holds.
      await writeScreenplay(
        "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
      );

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
      final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

      // The version's own id and the scenes it was captured with land in the very same state:
      // a preview reads back exactly one scene, never the two the working copy now holds.
      expect(previewing.previewedVersionId, versionId);
      expect(previewing.isPreviewingVersion, isTrue);
      expect(previewing.scenes, hasLength(1));

      await bloc.close();
    },
  );

  test("toggling a legend entry hides it, toggling it again reveals it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    const key = (OcptBreakdownTargetKind.element, OcptElementCategory.prop);

    bloc.add(const OcptBreakdownLegendEntryToggledEvent(key: key));
    final hidden = await waitForState(bloc, (state) => state.hiddenLegendKeys.isNotEmpty);
    expect(hidden.hiddenLegendKeys, {key});

    bloc.add(const OcptBreakdownLegendEntryToggledEvent(key: key));
    final revealed = await waitForState(bloc, (state) => state.hiddenLegendKeys.isEmpty);
    expect(revealed.hiddenLegendKeys, isEmpty);

    await bloc.close();
  });

  test("show all reveals every hidden legend key", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptBreakdownLegendEntryToggledEvent(
        key: (OcptBreakdownTargetKind.element, OcptElementCategory.prop),
      ),
    );
    bloc.add(const OcptBreakdownLegendEntryToggledEvent(key: (OcptBreakdownTargetKind.role, null)));
    await waitForState(bloc, (state) => state.hiddenLegendKeys.length == 2);

    bloc.add(const OcptBreakdownLegendShowAllRequestedEvent());
    final state = await waitForState(bloc, (state) => state.hiddenLegendKeys.isEmpty);

    expect(state.hiddenLegendKeys, isEmpty);

    await bloc.close();
  });

  test("selecting a target also selects the scene the click happened in", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
    final gardenSceneId = loaded.scenes[1].id;

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: gardenSceneId,
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedTargetRef != null);

    expect(state.selectedTargetRef, (OcptBreakdownTargetKind.element, "el-1"));
    expect(state.selectedSceneId, gardenSceneId);

    await bloc.close();
  });

  test("selecting a target naming a scene id that no longer exists drops the scene selection", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "not-a-scene",
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedTargetRef != null);

    expect(state.selectedTargetRef, (OcptBreakdownTargetKind.element, "el-1"));
    expect(state.selectedSceneId, isNull);

    await bloc.close();
  });

  test("a selected target resolves against the loaded snapshot's own targets", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");

    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(project.database.ocptScenesTable)).get())
        .single
        .id;

    final elementId = await projectsManager.elementsService.createElement(
      database: project.database,
      name: "Desk lamp",
      category: OcptElementCategory.prop,
      sourceKind: OcptElementSourceKind.owned,
    );
    expect(elementId, isNotNull);

    await projectsManager.breakdownService.createTag(
      database: project.database,
      sceneId: sceneId,
      startOffset: 2,
      endOffset: 6,
      taggedText: "lamp",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId!,
    );

    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId,
        sceneId: sceneId,
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedTarget != null);

    expect(state.selectedTarget?.name, "Desk lamp");

    await bloc.close();
  });

  test("clearing the target selection drops it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "scene-1",
      ),
    );
    await waitForState(bloc, (state) => state.selectedTargetRef != null);

    bloc.add(const OcptBreakdownTargetSelectionClearedEvent());
    final state = await waitForState(bloc, (state) => state.selectedTargetRef == null);

    expect(state.selectedTargetRef, isNull);

    await bloc.close();
  });

  test("a word click does nothing today, and never crashes", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 0, wordEndOffset: 6));
    // Nothing to wait for since nothing should change; give the event a moment to be processed.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.scenes.single.id, sceneId);

    await bloc.close();
  });

  test("a fresh load always drops the selected target, exactly as the selected scene", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: sceneId,
      ),
    );
    await waitForState(bloc, (state) => state.selectedTargetRef != null);

    bloc.add(const OcptBreakdownProjectSettingsChangedEvent());
    // `_onProjectSettingsChanged` doesn't reload the snapshot itself; reload through a version
    // preview round trip instead, which does go through `_onLoadRequested`.
    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Checkpoint", note: ""));
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    expect(previewing.selectedTargetRef, isNull);

    await bloc.close();
  });

  test("leaving a preview reloads the working copy's own read, clearing the previewed id", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Base", note: ""));
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);

    bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
    final state = await waitForState(bloc, (state) => state.previewedVersionId == null);

    expect(state.isPreviewingVersion, isFalse);
    expect(state.scenes, isNotEmpty);

    await bloc.close();
  });
}
