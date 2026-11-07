// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
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
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_floor_plan_canvas_bloc_test_doubles.dart';

/// A floor plan service whose symbol placements and updates always fail, to exercise the canvas's
/// write error path.
class _FailingFloorPlanService extends OcptFloorPlanService {
  /// Class constructor
  _FailingFloorPlanService(OcptFloorPlanService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Fail as a refused symbol placement does.
  @override
  Future<OcptDatabaseResult<String>> placeSymbol({
    required OcptProjectDatabase database,
    required String setId,
    required String? sceneId,
    required String? shotId,
    required OcptFloorPlanLayer layer,
    required double xM,
    required double yM,
    double rotationDeg = 0,
    double? widthM,
    double? heightM,
    double? fovDeg,
    double? fovReachM,
    String label = '',
    OcptFloorPlanSetElementShape? setElementShape,
    String? overridesSymbolId,
    bool isHidden = false,
  }) async => const OcptDatabaseResult(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "symbol placement intentionally failed for the test",
  );

  /// Fail as a refused symbol update does.
  @override
  Future<OcptDatabaseOutcome> updateSymbol({
    required OcptProjectDatabase database,
    required String symbolId,
    Value<double> xM = const Value.absent(),
    Value<double> yM = const Value.absent(),
    Value<double> rotationDeg = const Value.absent(),
    Value<double?> widthM = const Value.absent(),
    Value<double?> heightM = const Value.absent(),
    Value<double?> fovDeg = const Value.absent(),
    Value<double?> fovReachM = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<OcptFloorPlanSetElementShape?> setElementShape = const Value.absent(),
    Value<bool> isHidden = const Value.absent(),
  }) async => const OcptDatabaseOutcome(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "symbol update intentionally failed for the test",
  );
}

/// Run the tests of the shot list floor plan canvas bloc gestures and write errors.
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

    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
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

  /// The placements bloc of [modeBloc], built on first use: the Placements group's actions are its
  /// own, and the canvas reacts to the selection move they ask the mode for.
  OcptShotListFloorPlanPlacementsBloc placementsOf(OcptShotListBloc modeBloc) =>
      placementsBlocs.putIfAbsent(
        modeBloc,
        () => OcptShotListFloorPlanPlacementsBloc(
          modeBloc: modeBloc,
          projectsManager: projectsManager,
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

    group("a Placements gesture clears what it has always cleared", () {
      /// Places a symbol of [layer] on the shot of [mounted] and answers its id, once the canvas
      /// holds it as its selection.
      Future<String> placeOn(
        OcptShotListBloc mode,
        ({OcptShotListBloc mode, String setId, String shotId, String symbolId}) mounted,
        OcptFloorPlanLayer layer,
        double xM,
      ) async {
        final knownIds = {for (final symbol in mode.state.selectedSet!.symbols) symbol.id};
        canvasOf(mode).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: mounted.setId,
            layer: layer,
            shotId: mounted.shotId,
            sceneId: null,
            xM: xM,
            yM: 0,
          ),
        );
        await waitUntil(() => mode.state.selectedSet!.symbols.length == knownIds.length + 1);
        final placedId = mode.state.selectedSet!.symbols
            .firstWhere((symbol) => !knownIds.contains(symbol.id))
            .id;
        await waitUntil(() => canvasOf(mode).state.selectedFloorPlanSymbolId == placedId);
        return placedId;
      }

      /// Draws an arrow between two symbols and answers its id.
      Future<String> drawArrow(OcptShotListBloc mode, String fromId, String toId) async {
        final canvas = canvasOf(mode);
        final knownCount = mode.state.selectedSet!.arrows.length;
        canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: fromId));
        await waitUntil(() => canvas.state.pendingFloorPlanArrowAnchorSymbolId == fromId);
        canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: toId));
        await waitUntil(() => mode.state.selectedSet!.arrows.length == knownCount + 1);
        return mode.state.selectedSet!.arrows.last.id;
      }

      /// Selects the arrow [arrowId] on the canvas and waits for it.
      Future<void> selectArrow(OcptShotListBloc mode, String arrowId) async {
        canvasOf(mode).add(OcptShotListFloorPlanArrowSelectedEvent(arrowId: arrowId));
        await waitUntil(() => canvasOf(mode).state.selectedFloorPlanArrowId == arrowId);
      }

      /// A mode with an arrow between two character symbols, selected, and a camera that touches no
      /// arrow. Answers the mode and the ids.
      Future<({OcptShotListBloc mode, String arrowId, String cameraId, String firstId})>
      mountWithAnArrowSelected() async {
        final mounted = await mountWithASymbol();
        final mode = mounted.mode;
        final secondId = await placeOn(mode, mounted, OcptFloorPlanLayer.characters, 2);
        final cameraId = await placeOn(mode, mounted, OcptFloorPlanLayer.cameras, 4);
        final arrowId = await drawArrow(mode, mounted.symbolId, secondId);
        await selectArrow(mode, arrowId);
        return (mode: mode, arrowId: arrowId, cameraId: cameraId, firstId: mounted.symbolId);
      }

      final removals = <String, OcptShotListEvent Function(String symbolId)>{
        "deleting": (symbolId) =>
            OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: symbolId),
        "deleting everywhere": (symbolId) =>
            OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: symbolId),
        "restoring": (symbolId) =>
            OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: symbolId),
      };
      for (final MapEntry(key: name, value: eventOf) in removals.entries) {
        test(
          "$name a symbol drops the selected arrow, even one the symbol does not touch",
          () async {
            final mounted = await mountWithAnArrowSelected();
            final mode = mounted.mode;
            final canvas = canvasOf(mode);

            placementsOf(mode).add(eventOf(mounted.cameraId));
            await waitUntil(
              () => !mode.state.selectedSet!.symbols.any((symbol) => symbol.id == mounted.cameraId),
            );
            await waitUntil(() => canvas.state.selectedFloorPlanArrowId == null);

            expect(
              mode.state.selectedSet!.arrows.map((arrow) => arrow.id),
              [mounted.arrowId],
              reason: 'the arrow itself is still there',
            );

            await mode.close();
          },
        );
      }

      test("deleting the selected symbol drops it, and deleting another keeps it", () async {
        final mounted = await mountWithASymbol();
        final mode = mounted.mode;
        final canvas = canvasOf(mode);
        final otherId = await placeOn(mode, mounted, OcptFloorPlanLayer.characters, 2);
        canvas.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: mounted.symbolId));
        await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == mounted.symbolId);

        placementsOf(
          mode,
        ).add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: otherId));
        await waitUntil(() => mode.state.selectedSet!.symbols.length == 1);
        await pumpEventQueue();
        expect(canvas.state.selectedFloorPlanSymbolId, mounted.symbolId);

        placementsOf(
          mode,
        ).add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: mounted.symbolId));
        await waitUntil(() => mode.state.selectedSet!.symbols.isEmpty);
        await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);

        await mode.close();
      });

      test("deleting the selected arrow drops it, and deleting another keeps it", () async {
        final mounted = await mountWithAnArrowSelected();
        final mode = mounted.mode;
        final canvas = canvasOf(mode);
        final otherArrowId = await drawArrow(mode, mounted.firstId, mounted.cameraId);
        await selectArrow(mode, mounted.arrowId);

        placementsOf(
          mode,
        ).add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: otherArrowId));
        await waitUntil(() => mode.state.selectedSet!.arrows.length == 1);
        await pumpEventQueue();
        expect(canvas.state.selectedFloorPlanArrowId, mounted.arrowId);

        placementsOf(
          mode,
        ).add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: mounted.arrowId));
        await waitUntil(() => mode.state.selectedSet!.arrows.isEmpty);
        await waitUntil(() => canvas.state.selectedFloorPlanArrowId == null);

        await mode.close();
      });

      test("hiding a symbol the arrow does not touch keeps the selected arrow", () async {
        final mounted = await mountWithAnArrowSelected();
        final mode = mounted.mode;
        final canvas = canvasOf(mode);
        final project = projectsManager.currentProject!;
        final wallId = (await projectsManager.floorPlanService
            .placeSymbol(
              database: project.database,
              setId: mode.state.selectedSetId!,
              sceneId: null,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 6,
              yM: 6,
              setElementShape: OcptFloorPlanSetElementShape.wall,
            )
            .valueOrFail);
        await mode.reload({OcptShotListReloadScope.floorPlans});

        placementsOf(mode).add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: wallId,
            targetSceneId: mode.state.selectedSequenceId!,
          ),
        );
        await waitUntil(() => mode.state.selectionCause == OcptShotListSelectionCause.symbolHidden);
        await pumpEventQueue();

        expect(canvas.state.selectedFloorPlanArrowId, mounted.arrowId);

        await mode.close();
      });

      test("changing a field of view or its reach clears nothing", () async {
        final mounted = await mountWithAnArrowSelected();
        final mode = mounted.mode;
        final canvas = canvasOf(mode);

        placementsOf(
          mode,
        ).add(OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: mounted.cameraId, fovDeg: 35));
        await waitUntil(
          () => mode.state.selectedSet!.symbols.any(
            (symbol) => symbol.id == mounted.cameraId && symbol.fovDeg == 35,
          ),
        );
        placementsOf(mode).add(
          OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: mounted.cameraId, fovReachM: 6),
        );
        await waitUntil(
          () => mode.state.selectedSet!.symbols.any(
            (symbol) => symbol.id == mounted.cameraId && symbol.fovReachM == 6,
          ),
        );
        await pumpEventQueue();

        expect(canvas.state.selectedFloorPlanArrowId, mounted.arrowId);

        await mode.close();
      });

      /// A wall and a visible override of it for the first of two sequences, the override selected
      /// on the canvas. Answers the mode and the ids.
      Future<({OcptShotListBloc mode, String wallId, String overrideId, String sequenceId})>
      mountWithASelectedSequenceOverride() async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final canvas = canvasOf(mode);
        await waitForState(mode, (state) => !state.isLoading);
        final setId = await createCase(mode);
        final firstSequenceId = mode.state.selectedSequenceId!;

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
        final wallId = await selectedSymbolIdOf(mode);

        final secondSequenceId = mode.state.sequences[1].id;
        mode.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        await waitForState(mode, (state) => state.selectedSequenceId == secondSequenceId);
        final epoch = mode.state.selectionEpoch;
        setsOf(mode).add(OcptShotListSetLinkRequestedEvent(setId: setId));
        await waitForState(
          mode,
          (state) => state.setsOfSelectedSequence.isNotEmpty && state.selectionEpoch > epoch,
        );
        mode.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(mode, (state) => state.selectedSequenceId == firstSequenceId);

        canvas.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: wallId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 9,
            yM: 9,
          ),
        );
        await waitUntil(() => canvas.state.pendingFloorPlanScopeDecision != null);
        canvas.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        await waitUntil(() => mode.state.selectedSet!.symbols.length == 2);
        final overrideId = mode.state.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != wallId)
            .id;

        canvas.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: overrideId));
        await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == overrideId);
        return (mode: mode, wallId: wallId, overrideId: overrideId, sequenceId: firstSequenceId);
      }

      test(
        "hiding the selected override for its sequence drops the selection, not a ghost",
        () async {
          final mounted = await mountWithASelectedSequenceOverride();
          final mode = mounted.mode;
          final canvas = canvasOf(mode);

          placementsOf(mode).add(
            OcptShotListFloorPlanSymbolHideRequestedEvent(
              symbolId: mounted.overrideId,
              targetSceneId: mounted.sequenceId,
            ),
          );
          await waitUntil(
            () => mode.state.selectedSet!.symbols.any(
              (symbol) => symbol.id == mounted.overrideId && symbol.isHidden,
            ),
          );
          await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);

          await mode.close();
        },
      );

      test("hiding another symbol for a sequence keeps the selection", () async {
        final mounted = await mountWithASelectedSequenceOverride();
        final mode = mounted.mode;
        final canvas = canvasOf(mode);
        final project = projectsManager.currentProject!;
        final setId = mode.state.selectedSetId!;
        final otherId = (await projectsManager.floorPlanService
            .placeSymbol(
              database: project.database,
              setId: setId,
              sceneId: null,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 3,
              yM: 3,
              setElementShape: OcptFloorPlanSetElementShape.wall,
            )
            .valueOrFail);
        await mode.reload({OcptShotListReloadScope.floorPlans});

        placementsOf(mode).add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: otherId,
            targetSceneId: mounted.sequenceId,
          ),
        );
        await waitUntil(() => mode.state.selectedSet!.symbols.length == 4);
        await pumpEventQueue();

        expect(canvas.state.selectedFloorPlanSymbolId, mounted.overrideId);

        await mode.close();
      });

      test("hiding the selected override for its shot drops the selection, not a ghost", () async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final canvas = canvasOf(mode);
        await waitForState(mode, (state) => !state.isLoading);
        final setId = await createCase(mode);

        canvas.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: mode.state.selectedSequenceId,
            xM: 0,
            yM: 0,
          ),
        );
        final furnitureId = await selectedSymbolIdOf(mode);
        final firstShotId = await createShot(mode);
        await createShot(mode);
        mode.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
        await waitForState(mode, (state) => state.selectedShotId == firstShotId);

        canvas.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: furnitureId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.shot,
            xM: 5,
            yM: 5,
          ),
        );
        await waitUntil(() => canvas.state.pendingFloorPlanScopeDecision != null);
        canvas.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        await waitUntil(() => mode.state.selectedSet!.symbols.length == 2);
        final overrideId = mode.state.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != furnitureId)
            .id;
        canvas.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: overrideId));
        await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == overrideId);

        placementsOf(mode).add(
          OcptShotListFloorPlanSymbolHideForShotRequestedEvent(
            symbolId: overrideId,
            targetShotId: firstShotId,
          ),
        );
        await waitUntil(
          () => mode.state.selectedSet!.symbols.any(
            (symbol) => symbol.id == overrideId && symbol.isHidden,
          ),
        );
        await waitUntil(() => canvas.state.selectedFloorPlanSymbolId == null);

        await mode.close();
      });
    });

    test("closing the mode while a placement waits for it neither hangs nor throws", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final canvas = canvasOf(mode);
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode);

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
      await mode.close().timeout(const Duration(seconds: 5));
      await canvas.close().timeout(const Duration(seconds: 5));
    });

    test("a failing write raises the canvas's own write error, which can be dismissed", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final setId = await (() async {
        await waitForState(mode, (state) => !state.isLoading);
        return createCase(mode);
      })();
      final canvas = OcptShotListFloorPlanCanvasBloc(
        modeBloc: mode,
        projectsManager: projectsManager,
        floorPlanService: _FailingFloorPlanService(projectsManager.floorPlanService),
      );

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
      await waitUntil(() => canvas.state.hasWriteError);
      expect(mode.state.hasWriteError, isFalse, reason: 'the mode did not fail');
      expect(canvas.state.selectedFloorPlanSymbolId, isNull);

      canvas.add(const OcptShotListFloorPlanCanvasWriteErrorDismissedEvent());
      await waitUntil(() => !canvas.state.hasWriteError);

      canvas.add(const OcptShotListFloorPlanSymbolMovedEvent(symbolId: "gone", xM: 1, yM: 1));
      await waitUntil(() => canvas.state.hasWriteError);

      await canvas.close();
      await mode.close();
    });
  });
}
