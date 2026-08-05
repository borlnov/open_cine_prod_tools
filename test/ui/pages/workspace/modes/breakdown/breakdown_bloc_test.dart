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
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
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

  /// Writes a one-scene screenplay, an element tagged in it, and returns the scene and element
  /// ids the rest of a test writes against.
  Future<({String sceneId, String elementId})> writeTaggedElement() async {
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

    await projectsManager.breakdownService.createTag(
      database: project.database,
      sceneId: sceneId,
      startOffset: 2,
      endOffset: 6,
      taggedText: "lamp",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId!,
    );

    return (sceneId: sceneId, elementId: elementId);
  }

  /// Builds a bloc wired to the test project. [overrideProjectsManager] lets a test swap in a
  /// manager of its own (already holding an open project), for the one that needs to observe it.
  /// [fieldEditDebounce] defaults to a short duration so tests exercising the field-edit debounce
  /// don't have to wait out the real 2 s one.
  OcptBreakdownBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptProjectsManager? overrideProjectsManager,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptBreakdownBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    fieldEditDebounce: fieldEditDebounce,
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

  test("the centre starts on the script view with an empty search query", () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.centreView, OcptBreakdownCentreView.script);
    expect(state.searchQuery, "");

    await bloc.close();
  });

  test("switching the centre view clears a pending anchor and range", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    await waitForState(bloc, (state) => state.pendingTagAnchor != null);
    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42));
    await waitForState(bloc, (state) => state.pendingTagRange != null);

    bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.recap));
    final state = await waitForState(bloc, (state) => state.centreView == OcptBreakdownCentreView.recap);

    expect(state.pendingTagAnchor, isNull);
    expect(state.pendingTagRange, isNull);

    await bloc.close();
  });

  test("switching back to the script view leaves the search query untouched", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamp"));
    await waitForState(bloc, (state) => state.searchQuery == "lamp");

    bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.script));
    final state = await waitForState(
      bloc,
      (state) => state.centreView == OcptBreakdownCentreView.script,
    );

    expect(state.searchQuery, "lamp");

    await bloc.close();
  });

  test("typing a query from the script view switches to the recap, carrying the text", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.centreView, OcptBreakdownCentreView.script);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "Peugeot"));
    final state = await waitForState(
      bloc,
      (state) => state.centreView == OcptBreakdownCentreView.recap,
    );

    expect(state.searchQuery, "Peugeot");

    await bloc.close();
  });

  test("typing a query while already on the recap stays there", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.recap));
    await waitForState(bloc, (state) => state.centreView == OcptBreakdownCentreView.recap);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "Peugeot"));
    final state = await waitForState(bloc, (state) => state.searchQuery == "Peugeot");

    expect(state.centreView, OcptBreakdownCentreView.recap);

    await bloc.close();
  });

  test("clearing the query afterward does not switch back to the script view", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "Peugeot"));
    await waitForState(bloc, (state) => state.centreView == OcptBreakdownCentreView.recap);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: ""));
    final state = await waitForState(bloc, (state) => state.searchQuery == "");

    expect(state.centreView, OcptBreakdownCentreView.recap);

    await bloc.close();
  });

  test("typing a query from the script view also clears a pending anchor and range", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    final withAnchor = await waitForState(bloc, (state) => state.pendingTagAnchor != null);
    expect(withAnchor.pendingTagAnchor, isNotNull);

    bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamp"));
    final state = await waitForState(
      bloc,
      (state) => state.centreView == OcptBreakdownCentreView.recap,
    );

    expect(state.pendingTagAnchor, isNull);
    expect(state.pendingTagRange, isNull);

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

  test("a click with no pending anchor opens one and selects its scene", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    final state = await waitForState(bloc, (state) => state.pendingTagAnchor != null);

    expect(state.pendingTagAnchor, (sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    expect(state.selectedSceneId, sceneId);
    expect(state.pendingTagRange, isNull);

    await bloc.close();
  });

  test(
    "a click in another scene replaces the anchor rather than closing a range across two",
    () async {
      await writeScreenplay(
        "INT. HOUSE - DAY\n\nA lamp sits on the desk.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
      );
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
      final houseSceneId = loaded.scenes[0].id;
      final gardenSceneId = loaded.scenes[1].id;

      bloc.add(
        OcptBreakdownWordClickedEvent(sceneId: houseSceneId, wordStartOffset: 20, wordEndOffset: 24),
      );
      await waitForState(bloc, (state) => state.pendingTagAnchor != null);

      bloc.add(
        OcptBreakdownWordClickedEvent(sceneId: gardenSceneId, wordStartOffset: 0, wordEndOffset: 6),
      );
      final state = await waitForState(bloc, (state) => state.pendingTagAnchor?.sceneId == gardenSceneId);

      expect(state.pendingTagAnchor, (sceneId: gardenSceneId, wordStartOffset: 0, wordEndOffset: 6));
      expect(state.selectedSceneId, gardenSceneId);
      expect(state.pendingTagRange, isNull);

      await bloc.close();
    },
  );

  test(
    "two clicks in the same scene close the range on the right passage, opening the popover",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      // "lamp" (20, 24) then "desk." (37, 42): the range closes on "lamp sits on the desk.".
      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
      await waitForState(bloc, (state) => state.pendingTagAnchor != null);

      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42));
      final state = await waitForState(bloc, (state) => state.pendingTagRange != null);

      expect(state.pendingTagAnchor, isNull);
      expect(state.pendingTagRange, (
        sceneId: sceneId,
        startOffset: 20,
        endOffset: 42,
        taggedText: "lamp sits on the desk.",
        closingWordStartOffset: 37,
        closingWordEndOffset: 42,
      ));

      await bloc.close();
    },
  );

  test(
    "a second click closing the range backwards yields the same order-insensitive range",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      // "desk." (37, 42) first, then "lamp" (20, 24): same merged range as clicking forwards.
      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42));
      await waitForState(bloc, (state) => state.pendingTagAnchor != null);

      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
      final state = await waitForState(bloc, (state) => state.pendingTagRange != null);

      expect(state.pendingTagRange?.startOffset, 20);
      expect(state.pendingTagRange?.endOffset, 42);
      expect(state.pendingTagRange?.taggedText, "lamp sits on the desk.");
      // The popover still anchors under the word the second click actually landed on.
      expect(state.pendingTagRange?.closingWordStartOffset, 20);

      await bloc.close();
    },
  );

  test(
    "an overlapping second click is refused, keeping the anchor and opening no popover",
    () async {
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
      // A live tag over "lamp" (20, 24) already exists.
      await projectsManager.breakdownService.createTag(
        database: project.database,
        sceneId: sceneId,
        startOffset: 20,
        endOffset: 24,
        taggedText: "lamp",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId!,
      );

      final bloc = buildBloc();
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);

      // "A" (18, 19) as the anchor, then "sits" (25, 29): the merged range [18, 29) crosses the
      // existing tag over "lamp" (20, 24).
      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 18, wordEndOffset: 19));
      final withAnchor = await waitForState(bloc, (state) => state.pendingTagAnchor != null);
      expect(withAnchor.pendingTagAnchor?.wordStartOffset, 18);

      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 25, wordEndOffset: 29));
      // Nothing to wait for since the refusal changes nothing; give the event a moment to process.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.pendingTagAnchor, withAnchor.pendingTagAnchor);
      expect(bloc.state.pendingTagRange, isNull);
      expect(bloc.state.taggedTargetCount, 1);

      await bloc.close();
    },
  );

  test("cancelling the range clears the pending range and the anchor alike", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    await waitForState(bloc, (state) => state.pendingTagAnchor != null);
    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42));
    await waitForState(bloc, (state) => state.pendingTagRange != null);

    bloc.add(const OcptBreakdownTagRangeCancelledEvent());
    final state = await waitForState(bloc, (state) => state.pendingTagRange == null);

    expect(state.pendingTagAnchor, isNull);
    expect(state.pendingTagRange, isNull);

    await bloc.close();
  });

  test("linking the closed range to an existing element writes the tag and selects it", () async {
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

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    await waitForState(bloc, (state) => state.pendingTagAnchor != null);
    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    await waitForState(bloc, (state) => state.pendingTagRange != null);

    bloc.add(
      OcptBreakdownPopoverTargetLinkedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: elementId!,
      ),
    );
    final state = await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    expect(state.pendingTagAnchor, isNull);
    expect(state.pendingTagRange, isNull);
    expect(state.selectedTargetRef, (OcptBreakdownTargetKind.element, elementId));
    expect(state.selectedSceneId, sceneId);
    expect(state.rightDockTab, OcptBreakdownRightDockTab.inspector);

    await bloc.close();
  });

  test(
    "picking a category chip creates the element, tags the range with it and selects the new element",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
      await waitForState(bloc, (state) => state.pendingTagAnchor != null);
      bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42));
      await waitForState(bloc, (state) => state.pendingTagRange != null);

      bloc.add(
        const OcptBreakdownPopoverElementCreationRequestedEvent(
          category: OcptElementCategory.prop,
          name: "Desk lamp, 1960s",
        ),
      );
      final state = await waitForState(bloc, (state) => state.taggedTargetCount == 1);

      expect(state.pendingTagAnchor, isNull);
      expect(state.pendingTagRange, isNull);
      expect(state.targets.single.name, "Desk lamp, 1960s");
      expect(state.targets.single.category, OcptElementCategory.prop);
      expect(state.selectedTargetRef, (OcptBreakdownTargetKind.element, state.targets.single.id));
      expect(state.rightDockTab, OcptBreakdownRightDockTab.inspector);

      await bloc.close();
    },
  );

  test("an element created with a cleared field name falls back to the tagged passage", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    await waitForState(bloc, (state) => state.pendingTagAnchor != null);
    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    await waitForState(bloc, (state) => state.pendingTagRange != null);

    bloc.add(
      const OcptBreakdownPopoverElementCreationRequestedEvent(
        category: OcptElementCategory.prop,
        name: "   ",
      ),
    );
    final state = await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    expect(state.targets.single.name, "lamp");

    await bloc.close();
  });

  test("none of the range interaction happens while a version is previewed", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Base", note: ""));
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    await waitForState(bloc, (state) => state.previewedVersionId != null);

    bloc.add(OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24));
    // Nothing to wait for since nothing should change; give the event a moment to process.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.pendingTagAnchor, isNull);
    expect(bloc.state.pendingTagRange, isNull);
    expect(bloc.state.taggedTargetCount, 0);

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

  test("selecting a target opens the right dock on the Inspector tab", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, isNull);

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "scene-1",
      ),
    );
    final state = await waitForState(bloc, (state) => state.rightDockTab != null);

    expect(state.rightDockTab, OcptBreakdownRightDockTab.inspector);
    expect(state.lastRightDockTab, OcptBreakdownRightDockTab.inspector);

    await bloc.close();
  });

  test("the right dock toggle reopens the last tab explicitly selected, persisted across entries",
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptBreakdownRightDockTabSelectedEvent(tab: OcptBreakdownRightDockTab.versions),
    );
    await waitForState(bloc, (state) => state.rightDockTab == OcptBreakdownRightDockTab.versions);

    bloc.add(const OcptBreakdownRightDockClosedEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);

    bloc.add(const OcptBreakdownRightDockToggledEvent());
    final reopened = await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(reopened.rightDockTab, OcptBreakdownRightDockTab.versions);

    await bloc.close();

    expect(await propertiesManager.breakdownLastRightDockTab.load(), OcptBreakdownRightDockTab.versions);

    final nextEntry = buildBloc();
    final loaded = await waitForState(nextEntry, (state) => !state.isLoading);
    expect(loaded.lastRightDockTab, OcptBreakdownRightDockTab.versions);

    await nextEntry.close();
  });

  test("changing an element's status writes it immediately and reloads the snapshot", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownElementStatusChangedEvent(
        elementId: tagged.elementId,
        status: OcptElementStatus.confirmed,
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.targets.single.status == OcptElementStatus.confirmed,
    );

    expect(state.toFindCount, 0);

    await bloc.close();
  });

  test("changing an element's category writes it immediately and reloads the snapshot", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownElementCategoryChangedEvent(
        elementId: tagged.elementId,
        category: OcptElementCategory.vehicle,
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.targets.single.category == OcptElementCategory.vehicle,
    );

    expect(state.targets.single.color, isNot(0));

    await bloc.close();
  });

  test("typing into an element field debounces then writes it, clearing the pending edit",
      () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownElementFieldChangedEvent(
        elementId: tagged.elementId,
        field: OcptElementField.subCategory,
        rawValue: "1960s",
      ),
    );
    final pending = await waitForState(bloc, (state) => state.pendingElementFieldEdits.isNotEmpty);
    expect(
      pending.elementFieldValueOf(tagged.elementId, OcptElementField.subCategory, ""),
      "1960s",
    );

    final flushed = await waitForState(bloc, (state) => state.pendingElementFieldEdits.isEmpty);
    expect(flushed.selectedElement, isNull); // nothing selected here, just checking it flushed

    final elements = await projectsManager.elementsService.loadElements(
      database: projectsManager.currentProject!.database,
    );
    expect(elements.single.subCategory, "1960s");

    await bloc.close();
  });

  test("changing an element's owner writes it immediately", () async {
    final tagged = await writeTaggedElement();
    final project = projectsManager.currentProject!;
    final personId = await projectsManager.peopleService.createPerson(database: project.database);
    expect(personId, isNotNull);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownElementOwnerChangedEvent(elementId: tagged.elementId, personId: personId),
    );
    final state = await waitForState(
      bloc,
      (state) => state.elements.isNotEmpty && state.elements.single.ownerPersonId == personId,
    );

    expect(state.elements.single.ownerPersonId, personId);

    await bloc.close();
  });

  test("changing an element's who-brings-it writes it immediately", () async {
    final tagged = await writeTaggedElement();
    final project = projectsManager.currentProject!;
    final personId = await projectsManager.peopleService.createPerson(database: project.database);
    expect(personId, isNotNull);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownElementBringerChangedEvent(elementId: tagged.elementId, personId: personId),
    );
    final state = await waitForState(
      bloc,
      (state) => state.elements.isNotEmpty && state.elements.single.broughtByPersonId == personId,
    );

    expect(state.elements.single.broughtByPersonId, personId);

    await bloc.close();
  });

  test("the loaded snapshot carries the address book for the inspector's pickers", () async {
    final project = projectsManager.currentProject!;
    final personId = await projectsManager.peopleService.createPerson(database: project.database);
    expect(personId, isNotNull);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => state.people.isNotEmpty);

    expect(state.people.single.id, personId);

    await bloc.close();
  });

  test("an occurrence click selects its own scene", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
    final gardenSceneId = loaded.scenes[1].id;

    bloc.add(OcptBreakdownOccurrenceSelectedEvent(sceneId: gardenSceneId));
    final state = await waitForState(bloc, (state) => state.selectedSceneId == gardenSceneId);

    expect(state.selectedSceneId, gardenSceneId);

    await bloc.close();
  });

  test("tag removal asks first, and cancelling leaves the tag untouched", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: tagged.elementId,
        sceneId: tagged.sceneId,
      ),
    );
    await waitForState(bloc, (state) => state.selectedTarget != null);

    bloc.add(const OcptBreakdownTagRemovalRequestedEvent());
    await waitForState(bloc, (state) => state.isTagRemovalPending);

    bloc.add(const OcptBreakdownTagRemovalCancelledEvent());
    final state = await waitForState(bloc, (state) => !state.isTagRemovalPending);

    expect(state.taggedTargetCount, 1);

    await bloc.close();
  });

  test(
    "tag removal confirmed removes the tag but keeps the scene_elements link it once ensured",
    () async {
      final tagged = await writeTaggedElement();
      final project = projectsManager.currentProject!;
      final bloc = buildBloc();
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);

      bloc.add(
        OcptBreakdownTargetSelectedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: tagged.elementId,
          sceneId: tagged.sceneId,
        ),
      );
      await waitForState(bloc, (state) => state.selectedTarget != null);

      bloc.add(const OcptBreakdownTagRemovalRequestedEvent());
      await waitForState(bloc, (state) => state.isTagRemovalPending);

      bloc.add(const OcptBreakdownTagRemovalConfirmedEvent());
      final state = await waitForState(bloc, (state) => state.taggedTargetCount == 0);

      expect(state.isTagRemovalPending, isFalse);

      final elements = await projectsManager.elementsService.loadElements(
        database: project.database,
      );
      expect(elements.single.sceneLinks, isNotEmpty);

      await bloc.close();
    },
  );

  test("flushPendingFieldEdits writes a pending element field edit directly, bypassing the debounce",
      () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    bloc.add(
      OcptBreakdownElementFieldChangedEvent(
        elementId: tagged.elementId,
        field: OcptElementField.notes,
        rawValue: "handle with care",
      ),
    );
    await waitForState(bloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

    await bloc.flushPendingFieldEdits();

    final elements = await projectsManager.elementsService.loadElements(
      database: projectsManager.currentProject!.database,
    );
    expect(elements.single.notes, "handle with care");

    await bloc.close();
  });

  test("changing a scene's breakdown status writes it immediately and reloads the snapshot",
      () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(
      OcptBreakdownSceneStatusChangedEvent(sceneId: sceneId, status: OcptBreakdownSceneStatus.done),
    );
    final state = await waitForState(
      bloc,
      (state) => state.scenes.single.status == OcptBreakdownSceneStatus.done,
    );

    expect(state.scenes.single.status, OcptBreakdownSceneStatus.done);

    final scenes = await projectsManager.breakdownService.loadScenes(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
    );
    expect(scenes.single.status, OcptBreakdownSceneStatus.done);

    await bloc.close();
  });

  test("typing into a scene's breakdown notes debounces then writes it, clearing the pending edit",
      () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "Bring the lamp"));
    final pending = await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);
    expect(pending.sceneNotesValueOf(sceneId, ""), "Bring the lamp");

    final flushed = await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isEmpty);
    expect(flushed.scenes.single.notes, "Bring the lamp");

    final scenes = await projectsManager.breakdownService.loadScenes(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
    );
    expect(scenes.single.notes, "Bring the lamp");

    await bloc.close();
  });

  test("selecting a different scene flushes a pending scene notes edit", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
    final firstSceneId = loaded.scenes[0].id;
    final secondSceneId = loaded.scenes[1].id;

    bloc.add(OcptBreakdownSceneNotesChangedEvent(sceneId: firstSceneId, rawValue: "note one"));
    await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

    bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: secondSceneId));
    await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isEmpty);

    final scenes = await projectsManager.breakdownService.loadScenes(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
    );
    expect(scenes.firstWhere((scene) => scene.id == firstSceneId).notes, "note one");

    await bloc.close();
  });

  test("switching the right dock tab flushes a pending scene notes edit", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "note"));
    await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

    bloc.add(const OcptBreakdownRightDockTabSelectedEvent(tab: OcptBreakdownRightDockTab.versions));
    await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isEmpty);

    final scenes = await projectsManager.breakdownService.loadScenes(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
    );
    expect(scenes.single.notes, "note");

    await bloc.close();
  });

  test("flushPendingFieldEdits writes a pending scene notes edit directly, bypassing the debounce",
      () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "handle with care"));
    await waitForState(bloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

    await bloc.flushPendingFieldEdits();

    final scenes = await projectsManager.breakdownService.loadScenes(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
    );
    expect(scenes.single.notes, "handle with care");

    await bloc.close();
  });
}
