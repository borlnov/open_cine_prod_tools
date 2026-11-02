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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'shot_list_floor_plan_sets_bloc_test_doubles.dart';

/// A floor plan service whose reads fail once [failsReads] is set, so the mode cannot read again
/// what a view has just written.
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

/// Run the tests of the shot list floor plan sets bloc naming and underlay.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

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

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_floor_plan_sets_bloc_test_");
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

  /// Builds the floor plan sets bloc of [modeBloc], picking underlays through
  /// [fileSelectorManager] — a cancelled dialog unless the test says otherwise, so no test ever
  /// reaches a native one.
  OcptShotListFloorPlanSetsBloc buildSets(
    OcptShotListBloc modeBloc, {
    FileSelectorManager fileSelectorManager = const StubFileSelectorManager(pickedPath: null),
    OcptLocationsService? locationsService,
    OcptElementsService? elementsService,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptShotListFloorPlanSetsBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    locationsService: locationsService,
    elementsService: elementsService,
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
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
  /// the mode bloc and the sets bloc, whose states change in an order a test must not depend on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Closes the sets bloc and the mode, in the order the widget tree does.
  Future<void> closeAll(OcptShotListFloorPlanSetsBloc sets, OcptShotListBloc mode) async {
    await sets.close();
    await mode.close();
  }

  /// Creates a shot on the sole selected sequence and returns its id, waiting for the selection to
  /// actually change.
  Future<String> createShot(OcptShotListBloc bloc) async {
    final previousShotId = bloc.state.selectedShotId;
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(
      bloc,
      (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
    );
    return created.selectedShotId!;
  }

  /// Creates a set on the selected sequence through [sets] and returns its id, waiting for the
  /// mode to select it, which it does once it holds the set.
  Future<String> createCase(OcptShotListBloc bloc, OcptShotListFloorPlanSetsBloc sets) async {
    final epoch = bloc.state.selectionEpoch;
    sets.add(const OcptShotListSetCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.selectionEpoch > epoch);
    return created.selectedSetId!;
  }

  test("a fresh set is named from the scene heading's place and selected", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    await waitForState(bloc, (state) => !state.isLoading);

    final setId = await createCase(bloc, sets);
    final state = bloc.state;

    expect(state.setsOfSelectedSequence, hasLength(1));
    expect(state.selectedSetId, setId);
    expect(state.selectedSet!.name, "HOUSE");

    await closeAll(sets, bloc);
  });

  test("renaming a set debounces then writes", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc, sets);

    sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Living room"));
    await waitUntil(
      () => sets.state.pendingFieldEdits.containsKey(OcptShotListSetNameEditKey(setId: setId)),
    );
    expect(bloc.state.selectedSet!.name, "HOUSE");

    final flushed = await waitForState(bloc, (state) => state.selectedSet!.name == "Living room");
    await waitUntil(() => sets.state.pendingFieldEdits.isEmpty);
    expect(flushed.selectedSet!.name, "Living room");
    expect(sets.state.pendingFieldEdits, isEmpty);

    await closeAll(sets, bloc);
  });

  test(
    "unlinking the selected set removes its tab and selects the sequence's next first set",
    () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      final sets = buildSets(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final firstSetId = await createCase(bloc, sets);
      var epoch = bloc.state.selectionEpoch;
      sets.add(const OcptShotListSetCreationRequestedEvent());
      final afterSecond = await waitForState(
        bloc,
        (state) => state.setsOfSelectedSequence.length == 2 && state.selectionEpoch > epoch,
      );
      final secondSetId = afterSecond.selectedSetId!;
      expect(secondSetId, isNot(firstSetId));

      epoch = afterSecond.selectionEpoch;
      sets.add(OcptShotListSetDeletionRequestedEvent(setId: secondSetId));
      final afterDelete = await waitForState(
        bloc,
        (state) => state.setsOfSelectedSequence.length == 1 && state.selectionEpoch > epoch,
      );
      expect(afterDelete.selectedSetId, firstSetId);

      epoch = afterDelete.selectionEpoch;
      sets.add(OcptShotListSetDeletionRequestedEvent(setId: firstSetId));
      final afterLastDelete = await waitForState(
        bloc,
        (state) => state.setsOfSelectedSequence.isEmpty && state.selectionEpoch > epoch,
      );
      expect(afterLastDelete.selectedSetId, isNull);

      await closeAll(sets, bloc);
    },
  );

  test("linking an existing set to another sequence adds it to that sequence's own tabs and "
      "selects it", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc, sets);
    final secondSequenceId = bloc.state.sequences[1].id;

    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
    await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
    expect(bloc.state.setsOfSelectedSequence, isEmpty);

    final epoch = bloc.state.selectionEpoch;
    sets.add(OcptShotListSetLinkRequestedEvent(setId: setId));
    final linked = await waitForState(
      bloc,
      (state) => state.setsOfSelectedSequence.isNotEmpty && state.selectionEpoch > epoch,
    );

    expect(linked.setsOfSelectedSequence.single.id, setId);
    expect(linked.selectedSetId, setId);

    await closeAll(sets, bloc);
  });

  test(
    "a floor plans read that fails leaves the selection where it was, whatever was written",
    () async {
      await writeScreenplay(twoSceneText);
      final service = _ReadFailingFloorPlanService(projectsManager.floorPlanService);
      final bloc = buildBloc(floorPlanService: service);
      final sets = buildSets(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final firstSetId = await createCase(bloc, sets);
      final epoch = bloc.state.selectionEpoch;
      service.failsReads = true;

      /// Sends [event], waits for the mode's error and for the view to have had its say.
      Future<void> failWith(OcptShotListFloorPlanSetsEvent event) async {
        sets.add(event);
        await waitUntil(() => bloc.state.hasWriteError);
        await pumpEventQueue();
        expect(bloc.state.selectionEpoch, epoch);
        expect(bloc.state.selectedSetId, firstSetId);
        bloc.add(const OcptShotListWriteErrorDismissedEvent());
        await waitUntil(() => !bloc.state.hasWriteError);
      }

      await failWith(const OcptShotListSetCreationRequestedEvent());
      await failWith(
        OcptShotListSetDuplicationRequestedEvent(setId: firstSetId, newSetName: "Copy"),
      );
      await failWith(OcptShotListSetDeletionRequestedEvent(setId: firstSetId));

      // Linking: the second sequence holds no set, and still does not select the one just linked.
      service.failsReads = false;
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: bloc.state.sequences[1].id));
      await waitForState(bloc, (state) => state.selectedSequenceId == bloc.state.sequences[1].id);
      final linkEpoch = bloc.state.selectionEpoch;
      service.failsReads = true;
      sets.add(OcptShotListSetLinkRequestedEvent(setId: firstSetId));
      await waitUntil(() => bloc.state.hasWriteError);
      await pumpEventQueue();
      expect(bloc.state.selectionEpoch, linkEpoch);
      expect(bloc.state.selectedSetId, isNull);

      await closeAll(sets, bloc);
    },
  );

  test("importing an underlay frames it at the default rectangle", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(
      bloc,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc, sets);

    sets.add(
      OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: setId, fileTypeLabel: "Images"),
    );
    final state = await waitForState(bloc, (state) => state.selectedSet!.underlayAssetId != null);

    expect(state.selectedSet!.underlayPath, "/plans/kitchen.png");
    expect(state.selectedSet!.underlayWidthM, isNotNull);
    expect(state.selectedSet!.underlayHeightM, isNotNull);

    await closeAll(sets, bloc);
  });

  test("moving/resizing the underlay re-frames it through updateUnderlayFrame, minting or "
      "tombstoning no asset", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(
      bloc,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc, sets);

    sets.add(
      OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: setId, fileTypeLabel: "Images"),
    );
    final imported = await waitForState(
      bloc,
      (state) => state.selectedSet!.underlayAssetId != null,
    );
    final assetId = imported.selectedSet!.underlayAssetId;
    final database = projectsManager.currentProject!.database;
    final assetsBeforeMove = await database.select(database.ocptAssetsTable).get();

    sets.add(
      OcptShotListFloorPlanUnderlayTransformChangedEvent(
        setId: setId,
        xM: 2,
        yM: 1,
        widthM: 5,
        heightM: 3,
      ),
    );
    final transformed = await waitForState(bloc, (state) => state.selectedSet!.underlayWidthM == 5);
    expect(transformed.selectedSet!.underlayXM, 2);
    expect(transformed.selectedSet!.underlayYM, 1);
    expect(transformed.selectedSet!.underlayHeightM, 3);
    expect(transformed.selectedSet!.underlayPath, "/plans/kitchen.png");
    // The very defect this fixes: dragging the underlay must never mint a fresh `assets` row
    // and tombstone the old one — it keeps writing the very same one.
    expect(transformed.selectedSet!.underlayAssetId, assetId);
    final assetsAfterMove = await database.select(database.ocptAssetsTable).get();
    expect(assetsAfterMove, hasLength(assetsBeforeMove.length));
    expect(assetsAfterMove.single.id, assetsBeforeMove.single.id);
    expect(assetsAfterMove.single.isDeleted, isFalse);

    await closeAll(sets, bloc);
  });

  test("clearing the underlay removes it", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(
      bloc,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc, sets);

    sets.add(
      OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: setId, fileTypeLabel: "Images"),
    );
    await waitForState(bloc, (state) => state.selectedSet!.underlayAssetId != null);

    sets.add(OcptShotListFloorPlanUnderlayClearRequestedEvent(setId: setId));
    final cleared = await waitForState(bloc, (state) => state.selectedSet!.underlayAssetId == null);
    expect(cleared.selectedSet!.underlayPath, isNull);

    await closeAll(sets, bloc);
  });

  test("zoom, active layer and layer visibility are session view state", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    await waitForState(bloc, (state) => !state.isLoading);
    expect(sets.state.floorPlanZoom, 1);

    sets.add(const OcptShotListFloorPlanZoomChangedEvent(zoom: 2));
    await waitUntil(() => sets.state.floorPlanZoom == 2);

    sets.add(
      const OcptShotListFloorPlanActiveSetElementShapeChangedEvent(
        shape: OcptFloorPlanSetElementShape.freeform,
      ),
    );
    await waitUntil(
      () => sets.state.floorPlanActiveSetElementShape == OcptFloorPlanSetElementShape.freeform,
    );

    sets.add(const OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: OcptFloorPlanLayer.set));
    await waitUntil(() => sets.state.floorPlanHiddenLayers.contains(OcptFloorPlanLayer.set));
    final hidden = sets.state;

    sets.add(const OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: OcptFloorPlanLayer.set));
    await waitUntil(() => !sets.state.floorPlanHiddenLayers.contains(OcptFloorPlanLayer.set));
    final shown = sets.state;
    expect(hidden.floorPlanHiddenLayers, contains(OcptFloorPlanLayer.set));
    expect(shown.floorPlanHiddenLayers, isNot(contains(OcptFloorPlanLayer.set)));

    await closeAll(sets, bloc);
  });

  test("per-camera visibility, onion skin and the metrics toggle are session view state", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    await waitForState(bloc, (state) => !state.isLoading);
    expect(sets.state.isFloorPlanOnionSkinPreviousShown, isTrue);
    expect(sets.state.isFloorPlanOnionSkinNextShown, isTrue);
    expect(sets.state.isFloorPlanMetricsShown, isFalse);

    sets.add(const OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: "cam-1"));
    await waitUntil(() => sets.state.floorPlanHiddenCameraSymbolIds.contains("cam-1"));
    final hidden = sets.state;
    sets.add(const OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: "cam-1"));
    await waitUntil(() => !sets.state.floorPlanHiddenCameraSymbolIds.contains("cam-1"));
    final shown = sets.state;
    expect(hidden.floorPlanHiddenCameraSymbolIds, contains("cam-1"));
    expect(shown.floorPlanHiddenCameraSymbolIds, isNot(contains("cam-1")));

    sets.add(const OcptShotListFloorPlanOnionSkinToggledEvent(isPrevious: true));
    await waitUntil(() => !sets.state.isFloorPlanOnionSkinPreviousShown);
    final prevOff = sets.state;
    expect(prevOff.isFloorPlanOnionSkinNextShown, isTrue);

    sets.add(const OcptShotListFloorPlanOnionSkinOpacityChangedEvent(opacity: 0.7));
    await waitUntil(() => sets.state.floorPlanOnionSkinOpacity == 0.7);
    final opacityChanged = sets.state;
    expect(opacityChanged.floorPlanOnionSkinOpacity, 0.7);

    sets.add(const OcptShotListFloorPlanMetricsToggledEvent());
    await waitUntil(() => sets.state.isFloorPlanMetricsShown);
    final metricsOn = sets.state;
    expect(metricsOn.isFloorPlanMetricsShown, isTrue);

    await closeAll(sets, bloc);
  });

  test("← / → walk the sequence's own shots, stopping at either end", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    await waitForState(bloc, (state) => !state.isLoading);

    final firstShotId = await createShot(bloc);
    final secondShotId = await createShot(bloc);
    expect(secondShotId, isNot(firstShotId));
    expect(bloc.state.selectedShotId, secondShotId);

    // Already the last shot: walking further does nothing.
    sets.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.selectedShotId, secondShotId);

    sets.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: -1));
    await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

    // Already the first shot: walking backward does nothing.
    sets.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: -1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.selectedShotId, firstShotId);

    sets.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: 1));
    await waitForState(bloc, (state) => state.selectedShotId == secondShotId);

    await closeAll(sets, bloc);
  });

  test("duplicating the selected set copies its own set-scope placements as independent rows, "
      "into a new Resources set linked to the same sequence, and selects the copy", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    final sets = buildSets(bloc);
    final canvas = OcptShotListFloorPlanCanvasBloc(
      modeBloc: bloc,
      projectsManager: projectsManager,
    );
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc, sets);

    canvas.add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.set,
        shotId: null,
        sceneId: null,
        xM: 1,
        yM: 2,
      ),
    );
    final withSet = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    final sourceSymbolId = withSet.selectedSet!.symbols.single.id;

    final epoch = bloc.state.selectionEpoch;
    sets.add(OcptShotListSetDuplicationRequestedEvent(setId: setId, newSetName: "House copy"));
    final afterDuplicate = await waitForState(
      bloc,
      (state) => state.setsOfSelectedSequence.length == 2 && state.selectionEpoch > epoch,
    );
    final newSetId = afterDuplicate.selectedSetId!;
    expect(newSetId, isNot(setId));
    expect(afterDuplicate.selectedSet!.name, "House copy");
    expect(afterDuplicate.selectedSet!.symbols, hasLength(1));
    final copiedSymbolId = afterDuplicate.selectedSet!.symbols.single.id;
    expect(copiedSymbolId, isNot(sourceSymbolId));

    // Independent: moving the copy leaves the source set's own symbol untouched.
    canvas.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: copiedSymbolId, xM: 9, yM: 9));
    await waitForState(bloc, (state) => state.selectedSet!.symbols.single.xM == 9);
    final sourceSet = bloc.state.setsOfSelectedSequence.firstWhere((s) => s.id == setId);
    expect(sourceSet.symbols.single.xM, 1);

    await canvas.close();
    await closeAll(sets, bloc);
  });

  test(
    "copying another shot's own blocking writes independent copies onto the focused shot",
    () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      final sets = buildSets(bloc);
      final canvas = OcptShotListFloorPlanCanvasBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc, sets);
      final sourceShotId = await createShot(bloc);

      canvas.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.cameras,
          shotId: sourceShotId,
          sceneId: null,
          xM: 1,
          yM: 1,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);

      final destinationShotId = await createShot(bloc);
      // The set's own symbols carry every shot's placements — only the destination shot's
      // own slice is still empty at this point.
      expect(
        bloc.state.selectedSet!.symbols.where((symbol) => symbol.shotId == destinationShotId),
        isEmpty,
      );

      sets.add(
        OcptShotListFloorPlanBlockingCopyRequestedEvent(setId: setId, sourceShotId: sourceShotId),
      );
      final copied = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.any((symbol) => symbol.shotId == destinationShotId),
      );

      final destinationSymbols = copied.selectedSet!.symbols
          .where((symbol) => symbol.shotId == destinationShotId)
          .toList();
      expect(destinationSymbols, hasLength(1));
      final copiedSymbol = destinationSymbols.single;
      expect(copiedSymbol.layer, OcptFloorPlanLayer.cameras);

      // Independent: moving the copy leaves the source shot's own symbol untouched.
      canvas.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: copiedSymbol.id, xM: 5, yM: 5));
      await waitForState(
        bloc,
        (state) =>
            state.selectedSet!.symbols.firstWhere((symbol) => symbol.id == copiedSymbol.id).xM == 5,
      );
      final sourceSymbol = bloc.state.selectedSet!.symbols.firstWhere(
        (symbol) => symbol.shotId == sourceShotId,
      );
      expect(sourceSymbol.xM, 1);

      await canvas.close();
      await closeAll(sets, bloc);
    },
  );
}
