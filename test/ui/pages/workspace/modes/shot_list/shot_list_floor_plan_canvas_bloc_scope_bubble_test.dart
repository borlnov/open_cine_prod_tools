// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
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
import 'shot_list_floor_plan_canvas_bloc_test_doubles.dart';

/// A floor plan service whose reads fail once [failsReads] is set, so the mode cannot read again
/// what the canvas has just written.
class _ReadFailingFloorPlanService extends OcptFloorPlanService {
  /// Whether the reads fail.
  bool failsReads = false;

  /// Class constructor
  _ReadFailingFloorPlanService(OcptFloorPlanService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Fail while told to, otherwise load the floor plans as the real service does.
  @override
  Future<OcptFloorPlanSnapshot> loadFloorPlans({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    if (failsReads) {
      throw StateError("floor plans read intentionally failed for the test");
    }
    return super.loadFloorPlans(database: database, screenplayId: screenplayId);
  }
}

/// Run the tests of the shot list floor plan canvas bloc scope bubble.
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

  group("the scope bubble", () {
    /// Links [setId] to the sequence's own second scene too, selects that second sequence, and
    /// returns its own id — building the "set linked to two sequences" fixture every test here
    /// needs, then the caller re-selects whichever sequence it actually wants focused.
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

    /// Places a wall on [setId], returns its id, and re-selects [sequenceId] once done — every
    /// test here starts from the wall already placed and the intended sequence focused.
    Future<String> placeWallAndFocus(
      OcptShotListBloc bloc, {
      required String setId,
      required String sequenceId,
    }) async {
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

      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: sequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == sequenceId);
      return symbolId;
    }

    test("a set-scope symbol on a set linked to a single sequence is never a scope-decision "
        "candidate — the mode dispatches the plain move event straight away, and this bloc has "
        "no notion of a pending decision to store one for", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final symbolId = await placeWallAndFocus(
        bloc,
        setId: setId,
        sequenceId: bloc.state.selectedSequenceId!,
      );

      canvasOf(bloc).add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: 5, yM: 5));
      await waitForState(bloc, (state) => state.selectedSet!.symbols.single.xM == 5);
      expect(canvasOf(bloc).state.pendingFloorPlanScopeDecision, isNull);

      await bloc.close();
    });

    test("OcptShotListFloorPlanScopeDecisionRequestedEvent only stores the pending decision — "
        "nothing is written until it is resolved", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
      await linkSecondSequence(bloc, setId);
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 9,
          yM: 9,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      final pending = canvasOf(bloc).state;

      expect(pending.pendingFloorPlanScopeDecision!.symbolId, symbolId);
      expect(pending.pendingFloorPlanScopeDecision!.sequenceCount, 2);
      // Nothing written yet: the original still sits at its own placed position.
      expect(bloc.state.selectedSet!.symbols.single.xM, 0);

      await bloc.close();
    });

    test("cancel drops the pending decision, writing nothing at all", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
      await linkSecondSequence(bloc, setId);
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 9,
          yM: 9,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);

      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.cancel,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision == null);

      expect(bloc.state.selectedSet!.symbols, hasLength(1));
      expect(bloc.state.selectedSet!.symbols.single.xM, 0); // untouched

      await bloc.close();
    });

    test("every sequence writes the change onto the original itself", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
      await linkSecondSequence(bloc, setId);
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 9,
          yM: 9,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);

      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.every,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision == null);

      expect(bloc.state.selectedSet!.symbols, hasLength(1));
      final original = bloc.state.selectedSet!.symbols.single;
      expect(original.id, symbolId);
      expect(original.xM, 9);
      expect(original.yM, 9);
      expect(original.sceneId, isNull); // still set-scope, no override created

      await bloc.close();
    });

    test("only sequence n creates a scene-scope override of the focused sequence alone, leaving "
        "the original untouched", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
      await linkSecondSequence(bloc, setId);
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 9,
          yM: 9,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);

      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.only,
        ),
      );
      final resolved = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

      final original = resolved.selectedSet!.symbols.firstWhere((symbol) => symbol.id == symbolId);
      expect(original.xM, 0); // untouched
      expect(original.sceneId, isNull);

      final override = resolved.selectedSet!.symbols.firstWhere((symbol) => symbol.id != symbolId);
      expect(override.overridesSymbolId, symbolId);
      expect(override.sceneId, firstSequenceId);
      expect(override.xM, 9);
      expect(override.yM, 9);
      expect(override.isHidden, isFalse);

      await bloc.close();
    });

    test("only sequence n updates an override that already exists instead of creating a second "
        "one", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final firstSequenceId = bloc.state.selectedSequenceId!;
      final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
      await linkSecondSequence(bloc, setId);
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

      // A first "only" resolution creates the override.
      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 9,
          yM: 9,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.only,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
      final overrideId = bloc.state.selectedSet!.symbols
          .firstWhere((symbol) => symbol.id != symbolId)
          .id;

      // A second "only" resolution, rotating it this time, updates that very same override.
      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          rotationDeg: 45,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.only,
        ),
      );
      final resolved = await waitForState(
        bloc,
        (state) =>
            state.selectedSet!.symbols
                .firstWhere((symbol) => symbol.id == overrideId)
                .rotationDeg ==
            45,
      );

      // Still only two symbols: no second override was created.
      expect(resolved.selectedSet!.symbols, hasLength(2));
      final override = resolved.selectedSet!.symbols.firstWhere(
        (symbol) => symbol.id == overrideId,
      );
      expect(override.xM, 9); // the move from before survives the later rotate
      expect(override.rotationDeg, 45);

      await bloc.close();
    });
  });

  group("the scope bubble, shot level", () {
    /// Creates a shot on the sole selected sequence and returns its id, waiting for the
    /// selection to actually change — mirrors "the shot half" group's own helper.
    Future<String> createShot(OcptShotListBloc bloc) async {
      final previousShotId = bloc.state.selectedShotId;
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(
        bloc,
        (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
      );
      return created.selectedShotId!;
    }

    /// Places a plain scene-scope furniture item (no `overridesSymbolId` — never a sequence
    /// override) on [setId], for the sequence currently selected, and returns its id.
    Future<String> placeSceneFurniture(OcptShotListBloc bloc, String setId) async {
      final sceneId = bloc.state.selectedSequenceId!;
      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: sceneId,
          xM: 0,
          yM: 0,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      return selectedSymbolIdOf(bloc);
    }

    test("a scene-scope symbol of a sequence with two or more shots is a scope-decision "
        "candidate at shot level", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final symbolId = await placeSceneFurniture(bloc, setId);
      final firstShotId = await createShot(bloc);
      await createShot(bloc);
      bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
      await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.shot,
          xM: 9,
          yM: 9,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      final pending = canvasOf(bloc).state;

      expect(pending.pendingFloorPlanScopeDecision!.symbolId, symbolId);
      expect(pending.pendingFloorPlanScopeDecision!.level, OcptFloorPlanOverrideLevel.shot);
      // Nothing written yet: the scene symbol still sits at its own placed position.
      expect(bloc.state.selectedSet!.symbols.single.xM, 0);

      await bloc.close();
    });

    test("the whole sequence writes the change onto the scene-scope original itself", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final symbolId = await placeSceneFurniture(bloc, setId);
      await createShot(bloc);
      await createShot(bloc);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.shot,
          xM: 7,
          yM: 7,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.every,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision == null);

      expect(bloc.state.selectedSet!.symbols, hasLength(1));
      expect(bloc.state.selectedSet!.symbols.single.id, symbolId);
      expect(bloc.state.selectedSet!.symbols.single.xM, 7);

      await bloc.close();
    });

    test("only shot n creates a shot-scope override of the focused shot alone, leaving the "
        "scene symbol untouched", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final symbolId = await placeSceneFurniture(bloc, setId);
      final firstShotId = await createShot(bloc);
      await createShot(bloc);
      bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
      await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

      canvasOf(bloc).add(
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: symbolId,
          setId: setId,
          level: OcptFloorPlanOverrideLevel.shot,
          xM: 5,
          yM: 5,
        ),
      );
      await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
      canvasOf(bloc).add(
        const OcptShotListFloorPlanScopeDecisionResolvedEvent(
          choice: OcptFloorPlanScopeChoice.only,
        ),
      );
      final resolved = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

      final original = resolved.selectedSet!.symbols.firstWhere((symbol) => symbol.id == symbolId);
      final override = resolved.selectedSet!.symbols.firstWhere((symbol) => symbol.id != symbolId);
      expect(original.xM, 0);
      expect(override.overridesSymbolId, symbolId);
      expect(override.shotId, firstShotId);
      expect(override.sceneId, isNull);
      expect(override.xM, 5);

      await bloc.close();
    });

    test(
      "only shot n updates an override that already exists instead of creating a second one",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final symbolId = await placeSceneFurniture(bloc, setId);
        final firstShotId = await createShot(bloc);
        await createShot(bloc);
        bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
        await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

        for (final xM in [5.0, 6.0]) {
          canvasOf(bloc).add(
            OcptShotListFloorPlanScopeDecisionRequestedEvent(
              symbolId: symbolId,
              setId: setId,
              level: OcptFloorPlanOverrideLevel.shot,
              xM: xM,
              yM: 0,
            ),
          );
          await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
          canvasOf(bloc).add(
            const OcptShotListFloorPlanScopeDecisionResolvedEvent(
              choice: OcptFloorPlanScopeChoice.only,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
          await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision == null);
        }

        final override = bloc.state.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id != symbolId,
        );
        expect(override.xM, 6);
        expect(bloc.state.selectedSet!.symbols, hasLength(2));

        await bloc.close();
      },
    );
  });

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it
    /// makes this fail to compile until the list below names it too.
    String nameOf(OcptShotListFloorPlanCanvasEvent event) => switch (event) {
      OcptShotListFloorPlanToolSelectedEvent() => "tool",
      OcptShotListFloorPlanSymbolPlacedEvent() => "placed",
      OcptShotListFloorPlanSymbolSelectedEvent() => "symbol selected",
      OcptShotListFloorPlanSymbolMovedEvent() => "moved",
      OcptShotListFloorPlanSymbolResizedEvent() => "resized",
      OcptShotListFloorPlanSymbolRotatedEvent() => "rotated",
      OcptShotListFloorPlanScopeDecisionRequestedEvent() => "decision requested",
      OcptShotListFloorPlanScopeDecisionResolvedEvent() => "decision resolved",
      OcptShotListFloorPlanArrowSymbolTappedEvent() => "arrow tap",
      OcptShotListFloorPlanArrowAnchorCancelledEvent() => "anchor cancelled",
      OcptShotListFloorPlanArrowSelectedEvent() => "arrow selected",
      OcptShotListFloorPlanArrowCurveChangedEvent() => "arrow curve",
      OcptShotListFloorPlanSymbolDuplicatedEvent() => "duplicated",
      OcptShotListFloorPlanCharacterNamePromptDismissedEvent() => "prompt dismissed",
      OcptShotListFloorPlanCanvasWriteErrorDismissedEvent() => "dismiss",
    };

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

    test("every event of its hierarchy has a handler", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final canvas = canvasOf(mode);
      await waitForState(mode, (state) => !state.isLoading);

      const events = <OcptShotListFloorPlanCanvasEvent>[
        OcptShotListFloorPlanToolSelectedEvent(tool: OcptFloorPlanTool.arrow),
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: "s",
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
        OcptShotListFloorPlanSymbolSelectedEvent(symbolId: "a"),
        OcptShotListFloorPlanSymbolMovedEvent(symbolId: "a", xM: 0, yM: 0),
        OcptShotListFloorPlanSymbolResizedEvent(symbolId: "a", widthM: 1, heightM: 1),
        OcptShotListFloorPlanSymbolRotatedEvent(symbolId: "a", rotationDeg: 10),
        OcptShotListFloorPlanScopeDecisionRequestedEvent(
          symbolId: "a",
          setId: "s",
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
        ),
        OcptShotListFloorPlanScopeDecisionResolvedEvent(choice: OcptFloorPlanScopeChoice.cancel),
        OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: "a"),
        OcptShotListFloorPlanArrowAnchorCancelledEvent(),
        OcptShotListFloorPlanArrowSelectedEvent(arrowId: "w"),
        OcptShotListFloorPlanArrowCurveChangedEvent(arrowId: "w", ctrlXM: null, ctrlYM: null),
        OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: "a"),
        OcptShotListFloorPlanCharacterNamePromptDismissedEvent(),
        OcptShotListFloorPlanCanvasWriteErrorDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(15));

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => canvas.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await canvas.close();
      await mode.close();
    });

    test("a floor plans read that fails leaves the canvas's selection alone", () async {
      final service = _ReadFailingFloorPlanService(projectsManager.floorPlanService);
      final mounted = await mountWithASymbol(floorPlanService: service);
      final mode = mounted.mode;
      final canvas = canvasOf(mode);

      service.failsReads = true;

      /// Sends [event], waits for the mode's error and for the canvas to have had its say.
      Future<void> failWith(OcptShotListFloorPlanCanvasEvent event) async {
        canvas.add(event);
        await waitUntil(() => mode.state.hasWriteError);
        await pumpEventQueue();
        mode.add(const OcptShotListWriteErrorDismissedEvent());
        await waitUntil(() => !mode.state.hasWriteError);
      }

      await failWith(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: mounted.setId,
          layer: OcptFloorPlanLayer.characters,
          shotId: mounted.shotId,
          sceneId: null,
          xM: 6,
          yM: 6,
        ),
      );
      expect(canvas.state.selectedFloorPlanSymbolId, mounted.symbolId);

      await failWith(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: mounted.symbolId));
      expect(canvas.state.selectedFloorPlanSymbolId, mounted.symbolId);

      await canvas.close();
      await mode.close();
    });
  });
}
