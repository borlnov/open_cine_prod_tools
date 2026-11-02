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
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
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
import 'shot_list_floor_plan_placements_bloc_test_doubles.dart';

/// A floor plan service whose symbol updates and deletions always fail, to exercise the placements
/// bloc's write error path.
class _FailingFloorPlanService extends OcptFloorPlanService {
  /// Class constructor
  _FailingFloorPlanService(OcptFloorPlanService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Fail as a refused symbol deletion does.
  @override
  Future<OcptDatabaseOutcome> deleteSymbol({
    required OcptProjectDatabase database,
    required String symbolId,
  }) async => const OcptDatabaseOutcome(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "symbol deletion intentionally failed for the test",
  );

  /// Fail as a refused arrow deletion does.
  @override
  Future<OcptDatabaseOutcome> deleteArrow({
    required OcptProjectDatabase database,
    required String arrowId,
  }) async => const OcptDatabaseOutcome(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "arrow deletion intentionally failed for the test",
  );
}

/// A floor plan service whose reads can be held back until the test releases them, to make a read
/// finish later than another one that started after it.
class _HoldingFloorPlanService extends OcptFloorPlanService {
  /// How many of the next reads are held back.
  int heldReads = 0;

  /// How many reads were held back so far.
  int holdCount = 0;

  /// Completes to let the held call go on.
  final Completer<void> _release = Completer<void>();

  /// Class constructor
  _HoldingFloorPlanService(OcptFloorPlanService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Lets every held read answer.
  void release() => _release.complete();

  /// Load the floor plans as the real service does, then hold the call while reads are to be held.
  @override
  Future<OcptDatabaseResult<OcptFloorPlanSnapshot>> loadFloorPlans({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final snapshot = await super.loadFloorPlans(database: database, screenplayId: screenplayId);
    if (heldReads > 0) {
      heldReads--;
      holdCount++;
      await _release.future;
    }
    return snapshot;
  }
}

/// Run the tests of the shot list floor plan placements bloc bloc as whole.
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

  /// Mounts the mode on [twoSceneText] with a set and a shot, and places one character symbol on
  /// the shot. Answers the mode and the ids.
  Future<({OcptShotListBloc mode, String setId, String shotId, String symbolId})> mountWithASymbol({
    OcptFloorPlanService? floorPlanService,
  }) async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc(floorPlanService: floorPlanService);
    await waitForState(mode, (state) => !state.isLoading);
    final setId = await createCase(mode);
    final shotId = await createShot(mode);

    canvasOf(mode).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.cameras,
        shotId: shotId,
        sceneId: null,
        xM: 0,
        yM: 0,
      ),
    );
    final symbolId = await selectedSymbolIdOf(mode);

    return (mode: mode, setId: setId, shotId: shotId, symbolId: symbolId);
  }

  /// The label [mode] holds for [symbolId] in its floor plans.
  String storedLabelOf(OcptShotListBloc mode, String symbolId) =>
      mode.state.selectedSet!.symbols.firstWhere((symbol) => symbol.id == symbolId).label;

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it
    /// makes this fail to compile until the list below names it too.
    String nameOf(OcptShotListFloorPlanPlacementsEvent event) => switch (event) {
      OcptShotListFloorPlanSymbolDeletionRequestedEvent() => "delete",
      OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent() => "delete everywhere",
      OcptShotListFloorPlanSymbolHideRequestedEvent() => "hide",
      OcptShotListFloorPlanSymbolHideForShotRequestedEvent() => "hide for shot",
      OcptShotListFloorPlanSymbolRestoreRequestedEvent() => "restore",
      OcptShotListFloorPlanArrowDeletionRequestedEvent() => "arrow delete",
      OcptShotListFloorPlanSymbolLabelChangedEvent() => "label",
      OcptShotListFloorPlanSymbolFovChangedEvent() => "fov",
      OcptShotListFloorPlanSymbolFovReachChangedEvent() => "reach",
      OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent() => "flush",
      OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);

      const events = <OcptShotListFloorPlanPlacementsEvent>[
        OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: "a"),
        OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: "a"),
        OcptShotListFloorPlanSymbolHideRequestedEvent(symbolId: "a", targetSceneId: "s"),
        OcptShotListFloorPlanSymbolHideForShotRequestedEvent(symbolId: "a", targetShotId: "s"),
        OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: "a"),
        OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: "w"),
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: "a", rawValue: "x"),
        OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: "a", fovDeg: 30),
        OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: "a", fovReachM: 3),
        OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent(),
        OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(11));

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => placements.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await placements.close();
      await mode.close();
    });

    test("a failing write raises the bloc's own write error, which can be dismissed", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final placements = OcptShotListFloorPlanPlacementsBloc(
        modeBloc: mode,
        projectsManager: projectsManager,
        floorPlanService: _FailingFloorPlanService(projectsManager.floorPlanService),
      );
      final epoch = mode.state.selectionEpoch;

      placements.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: mounted.symbolId));
      await waitUntil(() => placements.state.hasWriteError);
      expect(mode.state.hasWriteError, isFalse, reason: 'the mode did not fail');
      expect(mode.state.selectionEpoch, epoch, reason: 'a failed write moves no selection');
      expect(canvasOf(mode).state.selectedFloorPlanSymbolId, mounted.symbolId);

      placements.add(const OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent());
      await waitUntil(() => !placements.state.hasWriteError);

      placements.add(const OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: "gone"));
      await waitUntil(() => placements.state.hasWriteError);

      await placements.close();
      await mode.close();
    });

    test("closing the mode while a removal waits for it neither hangs nor throws", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final placements = placementsOf(mode);

      placements.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: mounted.symbolId));
      await mode.close().timeout(const Duration(seconds: 5));
      await placements.close().timeout(const Duration(seconds: 5));
    });
  });

  group("the symbol label typed in place", () {
    test("the mode's flush writes it at once, and the bloc forgets it", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

      placements.add(
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
      );
      await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);
      expect(storedLabelOf(mode, mounted.symbolId), isNot("SAM"));

      await mode.flushAllPendingWrites();

      expect(storedLabelOf(mode, mounted.symbolId), "SAM");
      expect(placements.state.pendingFieldEdits, isEmpty);

      await mode.close();
    });

    test("flushing for a closing widget writes it without touching the state", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

      placements.add(
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
      );
      await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

      await mode.flushPendingFieldEdits();

      expect(placements.state.pendingFieldEdits, isNotEmpty);
      final project = projectsManager.currentProject!;
      final snapshot = await projectsManager.floorPlanService
          .loadFloorPlans(database: project.database, screenplayId: project.primaryScreenplayId)
          .valueOrFail;
      final stored = snapshot.setsById[mounted.setId]!.symbols
          .firstWhere((symbol) => symbol.id == mounted.symbolId)
          .label;
      expect(stored, "SAM");

      await mode.close();
    });

    test(
      "a label typed for a symbol that is deleted is dropped with it, and stops the debounce",
      () async {
        final mounted = await mountWithASymbol();
        final mode = mounted.mode;
        final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

        placements.add(
          OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
        );
        await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

        placements.add(
          OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: mounted.symbolId),
        );
        await waitUntil(() => placements.state.pendingFieldEdits.isEmpty);
        expect(mode.state.selectedSet!.symbols, isEmpty);

        await mode.close();
      },
    );

    test("a label typed for a symbol of a shot that is deleted is dropped with it", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

      placements.add(
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
      );
      await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

      mode.add(OcptShotListShotDeletionRequestedEvent(shotId: mounted.shotId));
      await waitUntil(() => placements.state.pendingFieldEdits.isEmpty);
      expect(mode.state.totalShotCount, 0);

      await mode.close();
    });

    test(
      "a label typed for a symbol that is still there survives a reload it did not ask for",
      () async {
        final mounted = await mountWithASymbol();
        final mode = mounted.mode;
        final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

        placements.add(
          OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
        );
        await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

        await mode.reload({OcptShotListReloadScope.floorPlans});
        await pumpEventQueue();

        expect(placements.state.pendingFieldEdits.values, ["SAM"]);

        await mode.close();
      },
    );

    test("a label typed for a symbol whose set is unlinked meanwhile is still written", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final sets = setsOf(mode);
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

      placements.add(
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
      );
      await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

      // The set leaves the episode's floor plans, but its symbols are not deleted.
      sets.add(OcptShotListSetDeletionRequestedEvent(setId: mounted.setId));
      await waitUntil(() => mode.state.setsOfSelectedSequence.isEmpty);
      await pumpEventQueue();

      sets.add(OcptShotListSetLinkRequestedEvent(setId: mounted.setId));
      await waitUntil(() => mode.state.selectedSet != null);
      expect(storedLabelOf(mode, mounted.symbolId), "SAM");

      await mode.close();
    });

    test("an older floor plans read does not put an older plan over a newer one", () async {
      final service = _HoldingFloorPlanService(projectsManager.floorPlanService);
      final mounted = await mountWithASymbol(floorPlanService: service);
      final mode = mounted.mode;
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));

      placements.add(
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: "SAM"),
      );
      await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

      // The flush writes the label and reads the floor plans while the camera has no field of view
      // yet, and is held there.
      service.heldReads = 1;
      final flush = placements.flushPendingWrites();
      await waitUntil(() => service.holdCount == 1);

      // Meanwhile a field of view is written and read.
      placements.add(
        OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: mounted.symbolId, fovDeg: 35),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      service.release();
      await flush.timeout(const Duration(seconds: 5));
      await waitUntil(() => mode.state.selectedSet!.symbols.single.fovDeg == 35);
      await pumpEventQueue();

      final symbol = mode.state.selectedSet!.symbols.single;
      expect(symbol.fovDeg, 35);
      expect(symbol.label, "SAM");

      await mode.close();
    });

    test("a label typed while the flush is in flight is kept and written", () async {
      final service = _HoldingFloorPlanService(projectsManager.floorPlanService);
      final mounted = await mountWithASymbol(floorPlanService: service);
      final mode = mounted.mode;
      final placements = placementsOf(mode, fieldEditDebounce: const Duration(days: 1));
      OcptShotListFloorPlanSymbolLabelChangedEvent typed(String text) =>
          OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: mounted.symbolId, rawValue: text);

      placements.add(typed("5"));
      await waitUntil(() => placements.state.pendingFieldEdits.isNotEmpty);

      service.heldReads = 1;
      final flush = placements.flushPendingWrites();
      await waitUntil(() => service.holdCount == 1);

      placements.add(typed("50"));
      await waitUntil(() => placements.state.pendingFieldEdits.values.contains("50"));
      service.release();
      await flush;

      expect(placements.state.pendingFieldEdits.values, [
        "50",
      ], reason: 'the keystroke is not lost');
      await placements.flushPendingWrites();
      expect(placements.state.pendingFieldEdits, isEmpty);
      expect(storedLabelOf(mode, mounted.symbolId), "50");

      await mode.close();
    });
  });

  group("the field of view of a camera", () {
    test("its reach is written like its angle, one row, clearing no selection", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final epoch = mode.state.selectionEpoch;

      placementsOf(mode).add(
        OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: mounted.symbolId, fovReachM: 7.5),
      );
      final changed = await waitForState(
        mode,
        (state) => state.selectedSet!.symbols.single.fovReachM == 7.5,
      );

      expect(changed.selectionEpoch, epoch, reason: 'the selection did not move');
      expect(canvasOf(mode).state.selectedFloorPlanSymbolId, mounted.symbolId);

      await mode.close();
    });
  });

  group("a removal moves the mode's selection with its cause", () {
    test("deleting, restoring, hiding and deleting an arrow each say what and which", () async {
      final mounted = await mountWithASymbol();
      final mode = mounted.mode;
      final placements = placementsOf(mode);

      var epoch = mode.state.selectionEpoch;
      placements.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: mounted.symbolId));
      await waitUntil(() => mode.state.selectionEpoch > epoch);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.symbolRemoved);
      expect(mode.state.selectionTargetId, mounted.symbolId);

      epoch = mode.state.selectionEpoch;
      placements.add(const OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: "gone"));
      await waitUntil(() => mode.state.selectionEpoch > epoch);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.arrowRemoved);
      expect(mode.state.selectionTargetId, "gone");

      await mode.close();
    });
  });
}
