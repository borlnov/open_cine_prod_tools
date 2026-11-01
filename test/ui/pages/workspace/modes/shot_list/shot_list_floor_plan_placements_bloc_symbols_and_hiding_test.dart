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
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
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
import 'shot_list_floor_plan_placements_bloc_test_doubles.dart';

/// Run the tests of the shot list floor plan placements bloc symbols and hiding.
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

    tempDir = await Directory.systemTemp.createTemp(
      "ocpt_shot_list_floor_plan_placements_bloc_test_",
    );
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

  /// Builds the mode bloc wired to the test project, reading the floor plans through
  /// [floorPlanService] when a test holds them back.
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

  /// The floor plan canvas bloc of [modeBloc], built on first use: the tests that need a symbol to
  /// work on ask it to place one, since the gestures on the plan are its own.
  OcptShotListFloorPlanCanvasBloc canvasOf(OcptShotListBloc modeBloc) => canvasBlocs.putIfAbsent(
    modeBloc,
    () => OcptShotListFloorPlanCanvasBloc(modeBloc: modeBloc, projectsManager: projectsManager),
  );

  /// The placements bloc of [modeBloc], built on first use, with [fieldEditDebounce] if it is the
  /// call that builds it.
  OcptShotListFloorPlanPlacementsBloc placementsOf(
    OcptShotListBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => placementsBlocs.putIfAbsent(
    modeBloc,
    () => OcptShotListFloorPlanPlacementsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: fieldEditDebounce,
    ),
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
  /// several blocs, whose states change in an order a test must not depend on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// The id of the symbol the canvas bloc of [bloc] has selected, once it does: a placement
  /// selects the symbol it wrote, after the mode holds it.
  Future<String> selectedSymbolIdOf(OcptShotListBloc bloc) async {
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId != null);
    return canvasOf(bloc).state.selectedFloorPlanSymbolId!;
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
  /// always guaranteed whenever the sequence already holds one.
  Future<String> createShot(OcptShotListBloc bloc) async {
    final previousShotId = bloc.state.selectedShotId;
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(
      bloc,
      (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
    );
    return created.selectedShotId!;
  }

  test("deleting a symbol removes it and clears its own selection", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc);

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.set,
        shotId: null,
        sceneId: null,
        xM: 0,
        yM: 0,
      ),
    );
    await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    final symbolId = await selectedSymbolIdOf(bloc);

    placementsOf(bloc).add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: symbolId));
    await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId == null);
    expect(canvasOf(bloc).state.selectedFloorPlanSymbolId, isNull);

    await bloc.close();
  });

  test("editing a symbol's label debounces then writes", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc);
    final shotId = await createShot(bloc);

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.characters,
        shotId: shotId,
        sceneId: null,
        xM: 0,
        yM: 0,
      ),
    );
    final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    final symbolId = placed.selectedSet!.symbols.single.id;

    final placements = placementsOf(bloc);
    placements.add(
      OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: "SAM"),
    );
    await waitUntil(
      () => placements.state.pendingFieldEdits.containsKey(
        OcptShotListSymbolLabelEditKey(symbolId: symbolId),
      ),
    );
    expect(bloc.state.selectedSet!.symbols.single.label, isEmpty);

    await waitForState(bloc, (state) => state.selectedSet!.symbols.single.label == "SAM");
    await waitUntil(() => placements.state.pendingFieldEdits.isEmpty);

    await bloc.close();
  });

  test(
    "changing a camera's field of view writes it (OcptShotListFloorPlanSymbolFovChangedEvent)",
    () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final shotId = await createShot(bloc);

      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.cameras,
          shotId: shotId,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = placed.selectedSet!.symbols.single.id;
      expect(placed.selectedSet!.symbols.single.fovDeg, isNull);

      placementsOf(
        bloc,
      ).add(OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: symbolId, fovDeg: 35));
      final changed = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.single.fovDeg == 35,
      );
      expect(changed.selectedSet!.symbols.single.fovDeg, 35);

      await bloc.close();
    },
  );

  group("restore / hide / delete everywhere", () {
    Future<String> linkSecondSequence(OcptShotListBloc bloc, String setId) async {
      final secondSequenceId = bloc.state.sequences[1].id;
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
      final epoch = bloc.state.selectionEpoch;
      setsOf(bloc).add(OcptShotListSetLinkRequestedEvent(setId: setId));
      await waitForState(
        bloc,
        (state) => state.setsOfSelectedSequence.isNotEmpty && state.selectionEpoch > epoch,
      );
      return secondSequenceId;
    }

    test(
      "restoring an override tombstones it, so the original reappears for that sequence",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;

        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = await selectedSymbolIdOf(bloc);

        // Hiding it (with no override yet) is what creates the override end to end.
        placementsOf(bloc).add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: originalId,
            targetSceneId: firstSequenceId,
          ),
        );
        final hidden = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
        final overrideId = hidden.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != originalId)
            .id;
        expect(
          hidden.selectedSet!.symbols.firstWhere((symbol) => symbol.id == overrideId).isHidden,
          isTrue,
        );

        placementsOf(
          bloc,
        ).add(OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: overrideId));
        final restored = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 1,
        );

        expect(restored.selectedSet!.symbols.single.id, originalId);

        await bloc.close();
      },
    );

    test("hiding a set-scope original with no override yet creates a hidden one, masking it for "
        "the target sequence", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final originalId = await selectedSymbolIdOf(bloc);

      placementsOf(bloc).add(
        OcptShotListFloorPlanSymbolHideRequestedEvent(
          symbolId: originalId,
          targetSceneId: firstSequenceId,
        ),
      );
      final hidden = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

      final override = hidden.selectedSet!.symbols.firstWhere((symbol) => symbol.id != originalId);
      expect(override.overridesSymbolId, originalId);
      expect(override.sceneId, firstSequenceId);
      expect(override.isHidden, isTrue);

      await bloc.close();
    });

    test("hiding a symbol that already has a visible override sets isHidden on it, without "
        "creating a second one", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final originalId = await selectedSymbolIdOf(bloc);
      final secondSequenceId = await linkSecondSequence(bloc, setId);
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

      // "Only sequence n" first, creating a **visible** override.
      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: originalId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 3,
          yM: 3,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.only,
        ),
      );
      final withVisibleOverride = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.length == 2,
      );
      final overrideId = withVisibleOverride.selectedSet!.symbols
          .firstWhere((symbol) => symbol.id != originalId)
          .id;
      expect(
        withVisibleOverride.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id == overrideId)
            .isHidden,
        isFalse,
      );

      // Hiding it now must flip that very same row, not add a third one.
      placementsOf(bloc).add(
        OcptShotListFloorPlanSymbolHideRequestedEvent(
          symbolId: originalId,
          targetSceneId: firstSequenceId,
        ),
      );
      final hidden = await waitForState(
        bloc,
        (state) =>
            state.selectedSet!.symbols.firstWhere((symbol) => symbol.id == overrideId).isHidden,
      );

      expect(hidden.selectedSet!.symbols, hasLength(2));
      expect(secondSequenceId, isNot(firstSequenceId));

      await bloc.close();
    });

    test(
      "delete everywhere tombstones the original and every override of it, in every sequence",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = await selectedSymbolIdOf(bloc);

        final secondSequenceId = await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        placementsOf(bloc).add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: originalId,
            targetSceneId: firstSequenceId,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
        placementsOf(bloc).add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: originalId,
            targetSceneId: secondSequenceId,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 3);

        placementsOf(
          bloc,
        ).add(OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: originalId));
        final deleted = await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);

        expect(deleted.selectedSet!.symbols, isEmpty);

        await bloc.close();
      },
    );

    test(
      "delete everywhere resolves an override id to its own original before cascading",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = await selectedSymbolIdOf(bloc);

        placementsOf(bloc).add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: originalId,
            targetSceneId: firstSequenceId,
          ),
        );
        final hidden = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
        final overrideId = hidden.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != originalId)
            .id;

        placementsOf(
          bloc,
        ).add(OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: overrideId));
        final deleted = await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);

        expect(deleted.selectedSet!.symbols, isEmpty);

        await bloc.close();
      },
    );

    test("hiding a scene-scope symbol with no shot override yet creates a hidden one, masking "
        "it for the target shot", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      // A plain scene-scope furniture item (no `overridesSymbolId` — never a sequence override).
      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: bloc.state.selectedSequenceId,
          xM: 0,
          yM: 0,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = await selectedSymbolIdOf(bloc);

      Future<String> createShot() async {
        final previousShotId = bloc.state.selectedShotId;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(
          bloc,
          (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
        );
        return created.selectedShotId!;
      }

      final firstShotId = await createShot();
      await createShot();

      placementsOf(bloc).add(
        OcptShotListFloorPlanSymbolHideForShotRequestedEvent(
          symbolId: symbolId,
          targetShotId: firstShotId,
        ),
      );
      final hidden = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

      final override = hidden.selectedSet!.symbols.firstWhere((symbol) => symbol.id != symbolId);
      expect(override.overridesSymbolId, symbolId);
      expect(override.shotId, firstShotId);
      expect(override.isHidden, isTrue);

      await bloc.close();
    });
  });
}
