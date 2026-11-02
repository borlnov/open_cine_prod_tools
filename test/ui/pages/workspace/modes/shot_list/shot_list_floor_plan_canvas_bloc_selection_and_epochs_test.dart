// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_floor_plan_canvas_bloc_test_doubles.dart';

/// Run the tests of the shot list floor plan canvas bloc selection and epochs.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  /// The floor plan sets bloc [setsOf] built for each mode bloc of a test, closed in [tearDown].
  final setsBlocs = Map<OcptShotListBloc, OcptShotListFloorPlanSetsBloc>.identity();

  /// The floor plan canvas bloc [canvasOf] built for each mode bloc of a test, closed in
  /// [tearDown].
  final canvasBlocs = Map<OcptShotListBloc, OcptShotListFloorPlanCanvasBloc>.identity();

  /// The placements bloc [placementsOf] built for each mode bloc of a test, closed in [tearDown].
  final placementsBlocs = Map<OcptShotListBloc, OcptShotListFloorPlanPlacementsBloc>.identity();

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    // The in-memory preference store outlives a single test, so every test that reads a
    // preference back seeds the ones it cares about rather than assuming a pristine store.
    await propertiesManager.shotListVisibleColumns.store(OcptShotListColumn.defaultVisibleColumns);
    await propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.shotListRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_floor_plan_canvas_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    for (final placements in placementsBlocs.values) {
      await placements.close();
    }
    placementsBlocs.clear();
    for (final canvas in canvasBlocs.values) {
      await canvas.close();
    }
    canvasBlocs.clear();
    for (final sets in setsBlocs.values) {
      await sets.close();
    }
    setsBlocs.clear();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the shot list its sequences.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Builds the mode bloc wired to the test project.
  OcptShotListBloc buildBloc({OcptFloorPlanService? floorPlanService}) => OcptShotListBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    floorPlanService: floorPlanService,
  );

  /// The floor plan sets bloc of [modeBloc], built on first use: the tests that need a set to work
  /// on ask it to create one, since the sets are its own to write.
  OcptShotListFloorPlanSetsBloc setsOf(OcptShotListBloc modeBloc) => setsBlocs.putIfAbsent(
    modeBloc,
    () => OcptShotListFloorPlanSetsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(milliseconds: 30),
    ),
  );

  /// The floor plan canvas bloc of [modeBloc], built on first use.
  OcptShotListFloorPlanCanvasBloc canvasOf(OcptShotListBloc modeBloc) => canvasBlocs.putIfAbsent(
    modeBloc,
    () => OcptShotListFloorPlanCanvasBloc(modeBloc: modeBloc, projectsManager: projectsManager),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListState> waitForState(
    OcptShotListBloc bloc,
    bool Function(OcptShotListState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Waits until [isDone] holds, looking again every few milliseconds: for a condition that spans
  /// the mode bloc and the canvas bloc, whose states change in an order a test must not depend on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Creates a set on the first scene of [twoSceneText] through the sets bloc and returns its id,
  /// waiting for the selection the creation always makes once the mode holds the set.
  Future<String> createCase(OcptShotListBloc bloc) async {
    final epoch = bloc.state.selectionEpoch;
    setsOf(bloc).add(const OcptShotListSetCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.selectionEpoch > epoch);
    return created.selectedSetId!;
  }

  /// Creates a shot on the sole selected sequence and returns its id, waiting for the selection to
  /// actually **change** from whatever it already was, not merely to be non-null: a current shot is
  /// always guaranteed whenever the sequence already holds one, so a second call in the same test
  /// would otherwise resolve against the still-current previous shot before the new one's own
  /// creation event is even processed.
  Future<String> createShot(OcptShotListBloc bloc) async {
    final previousShotId = bloc.state.selectedShotId;
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(
      bloc,
      (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
    );
    return created.selectedShotId!;
  }

  /// The id of the symbol the canvas bloc of [bloc] has selected, once it does: a placement
  /// selects the symbol it wrote, after the mode holds it.
  Future<String> selectedSymbolIdOf(OcptShotListBloc bloc) async {
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId != null);
    return canvasOf(bloc).state.selectedFloorPlanSymbolId!;
  }

  group("the bloc as a whole", () {
    /// Mounts the mode on [twoSceneText] with a set and a shot, and places one character symbol
    /// on the shot, which the canvas selects. Answers the mode and the ids.
    Future<({OcptShotListBloc mode, String setId, String shotId, String symbolId})>
    mountWithASymbol({OcptFloorPlanService? floorPlanService}) async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc(floorPlanService: floorPlanService);
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode);
      final shotId = await createShot(mode);

      canvasOf(mode).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.characters,
          shotId: shotId,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      final symbolId = await selectedSymbolIdOf(mode);

      return (mode: mode, setId: setId, shotId: shotId, symbolId: symbolId);
    }

    test("the mode moving its selection clears the canvas's, by what moved it", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final canvas = canvasOf(mode);
      final firstSequenceId = mode.state.selectedSequenceId!;
      final secondSequenceId = mode.state.sequences.last.id;

      /// Selects the symbol, arms the arrow anchor on it and raises a scope question about it.
      Future<void> arm() async {
        canvas.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: mounted.symbolId));
        canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: mounted.symbolId));
        canvas.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: mounted.symbolId,
            setId: mounted.setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 1,
            yM: 1,
          ),
        );
        await waitUntil(
          () =>
              canvas.state.selectedFloorPlanSymbolId == mounted.symbolId &&
              canvas.state.pendingFloorPlanArrowAnchorSymbolId == mounted.symbolId &&
              canvas.state.pendingFloorPlanScopeDecision != null,
        );
      }

      // The sequence already shown, selected again: only the half-drawn arrow is dropped.
      await arm();
      await mode.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitUntil(() => canvas.state.pendingFloorPlanArrowAnchorSymbolId == null);
      await pumpEventQueue();
      expect(canvas.state.selectedFloorPlanSymbolId, mounted.symbolId);
      expect(canvas.state.pendingFloorPlanScopeDecision, isNotNull);

      // A shot created, which selects it: nothing is cleared.
      await arm();
      mode.add(const OcptShotListShotCreationRequestedEvent());
      await waitUntil(() => mode.state.totalShotCount == 2);
      await pumpEventQueue();
      expect(canvas.state.selectedFloorPlanSymbolId, mounted.symbolId);
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, mounted.symbolId);
      expect(canvas.state.pendingFloorPlanScopeDecision, isNotNull);

      // The shot already selected, selected again: the symbol and the anchor go, not the question.
      await mode.addAndWait(OcptShotListShotSelectedEvent(shotId: mounted.shotId));
      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, isNull);
      expect(canvas.state.pendingFloorPlanScopeDecision, isNotNull);

      // A set selected: the same.
      await arm();
      await mode.addAndWait(OcptShotListSetSelectedEvent(setId: mounted.setId));
      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, isNull);
      expect(canvas.state.pendingFloorPlanScopeDecision, isNotNull);

      // A different sequence: everything goes, the question included.
      await arm();
      await mode.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, isNull);
      expect(canvas.state.pendingFloorPlanScopeDecision, isNull);

      await mode.close();
    });

    test("no frame can be drawn between the mode's selection change and the canvas's", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final canvas = canvasOf(mode);
      expect(canvas.state.selectedFloorPlanSymbolId, mounted.symbolId);

      // A frame is drawn in a task of the event loop of its own, so a task scheduled the moment the
      // mode's state is delivered stands for the next frame: what the canvas holds in it is what
      // that frame would draw. A reaction that waited for a timer, or for anything but microtasks,
      // would not have happened yet.
      final symbolInTheNextTask = Completer<String?>();
      final subscription = mode.stream.listen((state) {
        if (state.selectionCause == OcptShotListSelectionCause.shot &&
            !symbolInTheNextTask.isCompleted) {
          Timer.run(() => symbolInTheNextTask.complete(canvas.state.selectedFloorPlanSymbolId));
        }
      });

      mode.add(OcptShotListShotSelectedEvent(shotId: mounted.shotId));

      expect(await symbolInTheNextTask.future.timeout(const Duration(seconds: 5)), isNull);

      await subscription.cancel();
      await mode.close();
    });

    test("entering a version preview, which reads everything again, keeps the scope question and "
        "the character prompt", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final canvas = canvasOf(mode);
      await waitUntil(() => canvas.state.pendingCharacterNamePromptSymbolId == mounted.symbolId);
      canvas.add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: mounted.symbolId,
          setId: mounted.setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 1,
          yM: 1,
        ),
      );
      canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: mounted.symbolId));
      await waitUntil(
        () =>
            canvas.state.pendingFloorPlanScopeDecision != null &&
            canvas.state.pendingFloorPlanArrowAnchorSymbolId != null,
      );

      mode.add(const OcptProjectVersionCreationRequestedEvent(name: "With a symbol", note: ""));
      final withVersion = await waitForState(mode, (state) => state.projectVersions.isNotEmpty);
      mode.add(
        OcptProjectVersionPreviewRequestedEvent(versionId: withVersion.projectVersions.single.id),
      );
      await waitForState(mode, (state) => state.previewedVersionId != null);

      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.load);
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, isNull);
      expect(canvas.state.pendingFloorPlanScopeDecision, isNotNull);
      expect(canvas.state.pendingCharacterNamePromptSymbolId, mounted.symbolId);

      await mode.close();
    });

    test("the tool in hand drops a half-drawn arrow unless it is the arrow tool", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final canvas = canvasOf(mode);

      canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: mounted.symbolId));
      await waitUntil(() => canvas.state.pendingFloorPlanArrowAnchorSymbolId != null);

      canvas.add(const OcptShotListFloorPlanToolSelectedEvent(tool: OcptFloorPlanTool.arrow));
      await waitUntil(() => canvas.state.floorPlanActiveTool == OcptFloorPlanTool.arrow);
      await pumpEventQueue();
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, mounted.symbolId);

      canvas.add(const OcptShotListFloorPlanToolSelectedEvent(tool: OcptFloorPlanTool.select));
      await waitUntil(() => canvas.state.floorPlanActiveTool == OcptFloorPlanTool.select);
      expect(canvas.state.pendingFloorPlanArrowAnchorSymbolId, isNull);

      await mode.close();
    });

    test(
      "a placement waits for the mode to hold the symbol before the canvas selects it",
      () async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final canvas = canvasOf(mode);
        await waitForState(mode, (state) => !state.isLoading);
        final setId = await createCase(mode);

        // What the mode held at the very moment the canvas first named a selected symbol.
        final symbolCountWhenSelected = canvas.stream
            .firstWhere((state) => state.selectedFloorPlanSymbolId != null)
            .then((_) => mode.state.selectedSet!.symbols.length);

        canvas.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );

        expect(await symbolCountWhenSelected.timeout(const Duration(seconds: 5)), 1);

        await mode.close();
      },
    );

    test("the scope question stays until the mode holds what answering it wrote", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final canvas = canvasOf(mode);
      canvas.add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: mounted.symbolId,
          setId: mounted.setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 6,
          yM: 7,
        ),
      );
      await waitUntil(() => canvas.state.pendingFloorPlanScopeDecision != null);

      // What the mode held of the symbol at the very moment the question went away.
      final xWhenAnswered = canvas.stream
          .firstWhere((state) => state.pendingFloorPlanScopeDecision == null)
          .then(
            (_) => mode.state.selectedSet!.symbols.firstWhere((s) => s.id == mounted.symbolId).xM,
          );

      canvas.add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.every,
        ),
      );

      expect(await xWhenAnswered.timeout(const Duration(seconds: 5)), 6);

      await mode.close();
    });

    test("a reload the canvas did not ask for drops a selection that is gone or masked, not a "
        "ghost", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final canvas = canvasOf(mode);
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode);
      final sceneId = mode.state.selectedSequenceId!;
      final project = projectsManager.currentProject!;
      final floorPlanService = projectsManager.floorPlanService;

      Future<String> placeWall() async {
        canvas.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final previous = canvas.state.selectedFloorPlanSymbolId;
        await waitUntil(
          () =>
              canvas.state.selectedFloorPlanSymbolId != null &&
              canvas.state.selectedFloorPlanSymbolId != previous,
        );
        return canvas.state.selectedFloorPlanSymbolId!;
      }

      // Masked: a hidden override of the selected wall appears for the sequence shown.
      final wallId = await placeWall();
      final wall = mode.state.selectedSet!.symbols.firstWhere((symbol) => symbol.id == wallId);
      await floorPlanService
          .hideSymbolForScope(
            database: project.database,
            original: wall,
            existingOverride: null,
            sceneId: sceneId,
            shotId: null,
          )
          .okOrFail;
      await mode.reload({OcptShotListReloadScope.floorPlans});
      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);

      // A ghost, the hidden override itself, can be selected and survives a reload.
      final ghost = mode.state.selectedSet!.symbols.firstWhere((symbol) => symbol.isHidden);
      canvas.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: ghost.id));
      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == ghost.id);
      await mode.reload({OcptShotListReloadScope.floorPlans});
      await pumpEventQueue();
      expect(canvas.state.selectedFloorPlanSymbolId, ghost.id);

      // Gone: the selected symbol is deleted behind the canvas's back.
      final otherWallId = await placeWall();
      await floorPlanService
          .deleteSymbol(database: project.database, symbolId: otherWallId)
          .okOrFail;
      await mode.reload({OcptShotListReloadScope.floorPlans});
      await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);

      await mode.close();
    });

    test("a reload drops a selected arrow that is gone", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final canvas = canvasOf(mode);
      canvas.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: mounted.setId,
          layer: OcptFloorPlanLayer.characters,
          shotId: mounted.shotId,
          sceneId: null,
          xM: 2,
          yM: 2,
        ),
      );
      await waitUntil(() => mode.state.selectedSet!.symbols.length == 2);
      final secondId = mode.state.selectedSet!.symbols
          .firstWhere((symbol) => symbol.id != mounted.symbolId)
          .id;
      canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: mounted.symbolId));
      await waitUntil(() => canvas.state.pendingFloorPlanArrowAnchorSymbolId != null);
      canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: secondId));
      await waitUntil(() => mode.state.selectedSet!.arrows.isNotEmpty);
      final arrowId = mode.state.selectedSet!.arrows.single.id;
      canvas.add(OcptShotListFloorPlanArrowSelectedEvent(arrowId: arrowId));
      await waitUntil(() => canvas.state.selectedFloorPlanArrowId == arrowId);

      final project = projectsManager.currentProject!;
      await projectsManager.floorPlanService
          .deleteArrow(database: project.database, arrowId: arrowId)
          .okOrFail;
      await mode.reload({OcptShotListReloadScope.floorPlans});

      await waitUntil(() => canvas.state.selectedFloorPlanArrowId == null);

      await mode.close();
    });
  });
}
