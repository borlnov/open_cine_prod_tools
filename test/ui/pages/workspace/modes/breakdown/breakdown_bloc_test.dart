// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
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
  /// The export manager is a real one no test asks to export, so no test ever reaches a native save
  /// dialog.
  OcptBreakdownBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptProjectsManager? overrideProjectsManager,
    String? selectedEpisodeId,
  }) => OcptBreakdownBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("the epochs the views react to", () {
    test("entering the mode moves both epochs and says why", () async {
      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, greaterThan(0));
      expect(state.selectionEpoch, greaterThan(0));
      expect(state.selectionCause, OcptBreakdownSelectionCause.load);

      await bloc.close();
    });

    test("reading the snapshot again answers true and moves the reload epoch alone", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);

      // Written behind the mode's back, as a view's own write would be.
      await projectsManager.elementsService.createElement(
        database: projectsManager.currentProject!.database,
        name: "Desk lamp",
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      );

      final hasRead = await bloc.reload({OcptBreakdownReloadScope.snapshot});

      expect(hasRead, isTrue);
      expect(bloc.state.elements, hasLength(1));
      expect(bloc.state.reloadEpoch, greaterThan(loaded.reloadEpoch));
      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);

      await bloc.close();
    });

    test("reading again with no project open answers false and moves nothing", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      await projectsManager.closeCurrentProject();

      final hasRead = await bloc.reload({OcptBreakdownReloadScope.snapshot});

      expect(hasRead, isFalse);
      expect(bloc.state.reloadEpoch, loaded.reloadEpoch);

      await bloc.close();
    });

    test("a read that fails answers false and moves nothing", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final database = projectsManager.currentProject!.database;

      await database.customStatement("ALTER TABLE elements RENAME TO elements_gone");
      try {
        final hasRead = await bloc.reload({OcptBreakdownReloadScope.snapshot});

        expect(hasRead, isFalse);
        expect(bloc.state.reloadEpoch, loaded.reloadEpoch);
      } finally {
        await database.customStatement("ALTER TABLE elements_gone RENAME TO elements");
      }

      await bloc.close();
    });

    test(
      "a scene selection moves the selection epoch with its cause, a stale one does not",
      () async {
        await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
        final sceneId = loaded.scenes.single.id;

        bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId));
        final selected = await waitForState(
          bloc,
          (state) => state.selectionEpoch > loaded.selectionEpoch,
        );
        expect(selected.selectionCause, OcptBreakdownSelectionCause.scene);

        // Selecting the scene again is still a move: the views are told even though nothing changed.
        bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId));
        await waitForState(bloc, (state) => state.selectionEpoch > selected.selectionEpoch);

        final reselected = bloc.state;
        bloc.add(const OcptBreakdownSceneSelectedEvent(sceneId: "not-a-scene"));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state.selectionEpoch, reselected.selectionEpoch);

        await bloc.close();
      },
    );

    test("each way of moving the selection names itself", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      Future<OcptBreakdownSelectionCause> causeOf(OcptBreakdownEvent event) async {
        final before = bloc.state.selectionEpoch;
        bloc.add(event);
        final moved = await waitForState(bloc, (state) => state.selectionEpoch > before);
        return moved.selectionCause;
      }

      expect(
        await causeOf(OcptBreakdownSceneHeadingSelectedEvent(sceneId: sceneId)),
        OcptBreakdownSelectionCause.sceneHeading,
      );
      expect(
        await causeOf(
          OcptBreakdownTargetSelectedEvent(
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "el-1",
            sceneId: sceneId,
          ),
        ),
        OcptBreakdownSelectionCause.target,
      );
      expect(
        await causeOf(const OcptBreakdownTargetSelectionClearedEvent()),
        OcptBreakdownSelectionCause.targetCleared,
      );
      expect(
        await causeOf(OcptBreakdownAnchorSceneSelectedEvent(sceneId: sceneId)),
        OcptBreakdownSelectionCause.anchorScene,
      );

      await bloc.close();
    });

    test(
      "an anchor opened in a scene that is gone drops the scene selection, unlike a click",
      () async {
        await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
        bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: loaded.scenes.single.id));
        final selected = await waitForState(bloc, (state) => state.selectedSceneId != null);

        bloc.add(const OcptBreakdownAnchorSceneSelectedEvent(sceneId: "not-a-scene"));
        final dropped = await waitForState(
          bloc,
          (state) => state.selectionEpoch > selected.selectionEpoch,
        );

        expect(dropped.selectedSceneId, isNull);
        expect(dropped.selectionCause, OcptBreakdownSelectionCause.anchorScene);

        await bloc.close();
      },
    );

    test("leaving the script moves the selection epoch, a search on the recap does not", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamp"));
      final switched = await waitForState(
        bloc,
        (state) => state.selectionEpoch > loaded.selectionEpoch,
      );
      expect(switched.centreView, OcptBreakdownCentreView.recap);
      expect(switched.selectionCause, OcptBreakdownSelectionCause.centreView);

      bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamps"));
      await waitForState(bloc, (state) => state.searchQuery == "lamps");
      expect(bloc.state.selectionEpoch, switched.selectionEpoch);

      bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.recap));
      await waitForState(bloc, (state) => state.selectionEpoch > switched.selectionEpoch);

      await bloc.close();
    });

    test("a change that replaces no data leaves the reload epoch alone", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBreakdownLeftPanelToggledEvent());
      await waitForState(bloc, (state) => !state.isListPanelVisible);

      expect(bloc.state.reloadEpoch, loaded.reloadEpoch);
      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);

      await bloc.close();
    });

    test("the project settings page moves the reload epoch, never the selection", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptBreakdownProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.reloadEpoch > loaded.reloadEpoch);

      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);

      await bloc.close();
    });
  });

  test(
    "loads the project's title and an empty snapshot when the screenplay has no scene",
    () async {
      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.title, "My Movie");
      expect(state.scenes, isEmpty);
      expect(state.taggedTargetCount, 0);
      expect(state.usedCategoryCount, 0);
      expect(state.toFindCount, 0);
      expect(state.selectedSceneId, isNull);

      await bloc.close();
    },
  );

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

  test("constructed with a second episode selected, reads and writes that episode rather than the "
      "primary screenplay", () async {
    await writeScreenplay("INT. PRIMARY - DAY\n\nAction one.\n");
    final project = projectsManager.currentProject!;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
    );
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: secondEpisodeId!,
      fountainText: "INT. SECOND EPISODE - NIGHT\n\nAction two.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );

    final bloc = buildBloc(selectedEpisodeId: secondEpisodeId);
    final inspectorBloc = OcptBreakdownInspectorBloc(
      modeBloc: bloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    final state = await waitForState(bloc, (state) => state.scenes.isNotEmpty);

    expect(state.scenes.single.heading, "INT. SECOND EPISODE - NIGHT");
    expect(state.screenplayText, contains("SECOND EPISODE"));

    final sceneId = state.scenes.single.id;
    inspectorBloc.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "note"));
    await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);
    await bloc.flushPendingFieldEdits();

    final primaryScenes = await projectsManager.breakdownService.loadScenes(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      episodeNumber: null,
    );
    final secondEpisodeScenes = await projectsManager.breakdownService.loadScenes(
      database: project.database,
      screenplayId: secondEpisodeId,
      episodeNumber: null,
    );
    expect(primaryScenes.single.notes, isEmpty);
    expect(secondEpisodeScenes.single.notes, "note");

    await inspectorBloc.close();
    await bloc.close();
  });

  test("a tagged element is resolved into the snapshot's targets and counters", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");

    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

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

  test("selecting a scene from the left dock leaves the right dock alone", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "not-a-scene",
      ),
    );
    await waitForState(bloc, (state) => state.selectedTargetRef != null);

    bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId));
    final state = await waitForState(bloc, (state) => state.selectedSceneId != null);

    expect(
      state.selectedTargetRef,
      isNotNull,
      reason:
          "browsing the left dock's list is reading, so it must not drop the sheet the "
          "inspector is showing",
    );

    await bloc.close();
  });

  test("clicking a scene heading shows the scene's own sheet in the inspector", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    bloc.add(
      const OcptBreakdownTargetSelectedEvent(
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
        sceneId: "not-a-scene",
      ),
    );
    await waitForState(bloc, (state) => state.selectedTargetRef != null);

    bloc.add(OcptBreakdownSceneHeadingSelectedEvent(sceneId: sceneId));
    final state = await waitForState(bloc, (state) => state.selectedTargetRef == null);

    expect(state.selectedSceneId, sceneId);
    expect(state.rightDockTab, OcptBreakdownRightDockTab.inspector);
    expect(state.lastRightDockTab, OcptBreakdownRightDockTab.inspector);

    await bloc.close();
  });

  test("clicking a scene heading opens a closed right dock on the inspector", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;
    expect(loaded.rightDockTab, isNull);

    bloc.add(OcptBreakdownSceneHeadingSelectedEvent(sceneId: sceneId));
    final state = await waitForState(bloc, (state) => state.rightDockTab != null);

    expect(state.rightDockTab, OcptBreakdownRightDockTab.inspector);
    expect(state.selectedSceneId, sceneId);

    await bloc.close();
  });

  test("clicking a heading naming a scene that no longer exists is ignored", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);

    bloc.add(const OcptBreakdownSceneHeadingSelectedEvent(sceneId: "not-a-scene"));
    // Nothing to wait for since nothing should change; give the event a moment to be processed.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.selectedSceneId, isNull);
    expect(bloc.state.rightDockTab, isNull);

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
    expect(
      await propertiesManager.breakdownLeftDockFraction.load(),
      OcptWorkspaceDock.leftDefaultFraction,
    );
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

      bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "One scene", note: ""));
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

  group("the compact role alert banner", () {
    test("orphanedRoleAlerts reports a role the screenplay no longer names", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nCLARA\nHello.\n");

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.roles.isNotEmpty);
      expect(loaded.orphanedRoleAlerts, isEmpty);

      await writeScreenplay("INT. HOUSE - DAY\n\nAction, no dialogue anymore.\n");
      // Forces a full reload: unlike the resources mode's own handler, this event's breakdown
      // sibling only re-reads the page setup, not the whole snapshot.
      bloc.add(const OcptBreakdownLoadRequestedEvent());
      final orphaned = await waitForState(bloc, (state) => state.orphanedRoleAlerts.isNotEmpty);

      expect(orphaned.orphanedRoleAlerts, hasLength(1));
      expect(orphaned.orphanedRoleAlerts.single.characterName, "CLARA");
      expect(orphaned.orphanedRoleAlerts.single.roleId, orphaned.roles.single.id);

      await bloc.close();
    });

    test(
      "roleCollisionAlerts reports a hand-added role sharing a screenplay role's name",
      () async {
        await writeScreenplay("INT. HOUSE - DAY\n\nCLARA\nHello.\n");
        final project = projectsManager.currentProject!;

        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => state.roles.isNotEmpty);
        expect(loaded.roleCollisionAlerts, isEmpty);
        final screenplayRoleId = loaded.roles.single.id;

        final handAddedRoleId = await projectsManager.roleIndexService.addRole(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          name: "Clara",
          kind: OcptRoleKind.extra,
        );

        bloc.add(const OcptBreakdownLoadRequestedEvent());
        final state = await waitForState(bloc, (state) => state.roleCollisionAlerts.isNotEmpty);

        expect(state.roleCollisionAlerts, hasLength(1));
        expect(state.roleCollisionAlerts.single.screenplayRoleId, screenplayRoleId);
        expect(state.roleCollisionAlerts.single.handAddedRoleId, handAddedRoleId);

        await bloc.close();
      },
    );
  });

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

  test(
    "selecting a target naming a scene id that no longer exists drops the scene selection",
    () async {
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
    },
  );

  test("a selected target resolves against the loaded snapshot's own targets", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");

    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

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

  test(
    "leaving a preview reloads the working copy's own read, clearing the previewed id",
    () async {
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
    },
  );

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

  test(
    "the right dock toggle reopens the last tab explicitly selected, persisted across entries",
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

      expect(
        await propertiesManager.breakdownLastRightDockTab.load(),
        OcptBreakdownRightDockTab.versions,
      );

      final nextEntry = buildBloc();
      final loaded = await waitForState(nextEntry, (state) => !state.isLoading);
      expect(loaded.lastRightDockTab, OcptBreakdownRightDockTab.versions);

      await nextEntry.close();
    },
  );

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
}
