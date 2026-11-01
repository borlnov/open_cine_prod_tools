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
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
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

  test("the active tool is session view state", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(canvasOf(bloc).state.floorPlanActiveTool, OcptFloorPlanTool.select);

    canvasOf(
      bloc,
    ).add(const OcptShotListFloorPlanToolSelectedEvent(tool: OcptFloorPlanTool.setElement));
    await waitUntil(() => canvasOf(bloc).state.floorPlanActiveTool == OcptFloorPlanTool.setElement);

    await bloc.close();
  });

  test("placing a set element writes a sequence-scoped symbol on the active layer", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc);

    setsOf(
      bloc,
    ).add(const OcptShotListFloorPlanActiveLayerChangedEvent(layer: OcptFloorPlanLayer.set));
    await waitUntil(() => setsOf(bloc).state.floorPlanActiveLayer == OcptFloorPlanLayer.set);

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.set,
        shotId: null,
        sceneId: null,
        xM: 1.5,
        yM: -2,
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);

    final symbol = state.selectedSet!.symbols.single;
    expect(symbol.shotId, isNull);
    expect(symbol.layer, OcptFloorPlanLayer.set);
    expect(symbol.xM, 1.5);
    expect(symbol.yM, -2);
    expect(await selectedSymbolIdOf(bloc), symbol.id);

    await bloc.close();
  });

  test("the palette's own typed set-element entries each write their own setElementShape, and "
      "arming one becomes the click-to-arm default", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc);

    // A drop from the palette carries its own shape on the event itself.
    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.set,
        shotId: null,
        sceneId: null,
        xM: 0,
        yM: 0,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      ),
    );
    final withWall = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    expect(withWall.selectedSet!.symbols.single.setElementShape, OcptFloorPlanSetElementShape.wall);

    // Arming the door entry (click-to-arm) becomes the state's own default shape.
    setsOf(bloc).add(
      const OcptShotListFloorPlanActiveSetElementShapeChangedEvent(
        shape: OcptFloorPlanSetElementShape.door,
      ),
    );
    await waitUntil(
      () => setsOf(bloc).state.floorPlanActiveSetElementShape == OcptFloorPlanSetElementShape.door,
    );

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.set,
        shotId: null,
        sceneId: null,
        xM: 1,
        yM: 1,
        setElementShape: OcptFloorPlanSetElementShape.door,
      ),
    );
    final withDoor = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
    final door = withDoor.selectedSet!.symbols.firstWhere((symbol) => symbol.xM == 1);
    expect(door.setElementShape, OcptFloorPlanSetElementShape.door);

    await bloc.close();
  });

  test("moving a symbol writes one row on drag end", () async {
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
    final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    final symbolId = placed.selectedSet!.symbols.single.id;

    canvasOf(bloc).add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: 3, yM: 4));
    final moved = await waitForState(bloc, (state) => state.selectedSet!.symbols.single.xM == 3);
    expect(moved.selectedSet!.symbols.single.yM, 4);

    await bloc.close();
  });

  test("resizing and rotating a symbol writes one row each", () async {
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
    final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    final symbolId = placed.selectedSet!.symbols.single.id;

    canvasOf(
      bloc,
    ).add(OcptShotListFloorPlanSymbolResizedEvent(symbolId: symbolId, widthM: 1.2, heightM: 0.8));
    final resized = await waitForState(
      bloc,
      (state) => state.selectedSet!.symbols.single.widthM == 1.2,
    );
    expect(resized.selectedSet!.symbols.single.heightM, 0.8);

    canvasOf(
      bloc,
    ).add(OcptShotListFloorPlanSymbolRotatedEvent(symbolId: symbolId, rotationDeg: 45));
    final rotated = await waitForState(
      bloc,
      (state) => state.selectedSet!.symbols.single.rotationDeg == 45,
    );
    expect(rotated.selectedSet!.symbols.single.id, symbolId);

    await bloc.close();
  });

  test("placing a camera/character/light symbol is shot-scoped to the focused shot", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc);
    final shotId = await createShot(bloc);

    for (final layer in [
      OcptFloorPlanLayer.cameras,
      OcptFloorPlanLayer.characters,
      OcptFloorPlanLayer.lights,
    ]) {
      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: layer,
          shotId: shotId,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      final placed = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.any((symbol) => symbol.layer == layer),
      );
      final symbol = placed.selectedSet!.symbols.firstWhere((symbol) => symbol.layer == layer);
      expect(symbol.shotId, shotId);
    }

    await bloc.close();
  });

  test("two cameras placed on the same shot derive rank/letter labels (1A, 1B style)", () async {
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
    await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 1);
    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.cameras,
        shotId: shotId,
        sceneId: null,
        xM: 1,
        yM: 1,
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

    // The derivation itself (`ocptFloorPlanCameraLabelOf`/`OcptFloorPlanSheet.of`) is a pure
    // rule already unit-tested on its own; this proves the production path — the bloc's own
    // writes through `OcptFloorPlanService.placeSymbol` — feeds it the right rows.
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: state.selectedSet!,
      focusSceneId: state.selectedSequenceId!,
      focusShotId: shotId,
      shotRankByShotId: {shotId: 1},
    );
    final labels = sheet.symbols.map((symbol) => symbol.cameraLabel).toList()..sort();
    expect(labels, ["1A", "1B"]);

    await bloc.close();
  });

  test("the arrow tool's own pending anchor completes a movement on the second tap, and "
      "Escape/the cancel event abandons it", () async {
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
    final withFirst = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 1);
    final firstSymbolId = withFirst.selectedSet!.symbols.single.id;

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.characters,
        shotId: shotId,
        sceneId: null,
        xM: 2,
        yM: 2,
      ),
    );
    final withSecond = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
    final secondSymbolId = withSecond.selectedSet!.symbols
        .firstWhere((symbol) => symbol.id != firstSymbolId)
        .id;

    // First tap: picks the pending anchor, writes nothing.
    canvasOf(bloc).add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: firstSymbolId));
    await waitUntil(
      () => canvasOf(bloc).state.pendingFloorPlanArrowAnchorSymbolId == firstSymbolId,
    );
    expect(bloc.state.selectedSet!.arrows, isEmpty);

    // Cancelled (mirrors `Escape`): the anchor is abandoned, still nothing written.
    canvasOf(bloc).add(const OcptShotListFloorPlanArrowAnchorCancelledEvent());
    await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanArrowAnchorSymbolId == null);
    expect(bloc.state.selectedSet!.arrows, isEmpty);

    // Re-anchor and complete on the second tap.
    canvasOf(bloc).add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: firstSymbolId));
    await waitUntil(
      () => canvasOf(bloc).state.pendingFloorPlanArrowAnchorSymbolId == firstSymbolId,
    );
    canvasOf(bloc).add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: secondSymbolId));
    final completed = await waitForState(bloc, (state) => state.selectedSet!.arrows.isNotEmpty);
    await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanArrowAnchorSymbolId == null);
    expect(canvasOf(bloc).state.pendingFloorPlanArrowAnchorSymbolId, isNull);
    expect(completed.selectedSet!.arrows.single.fromSymbolId, firstSymbolId);
    expect(completed.selectedSet!.arrows.single.toSymbolId, secondSymbolId);
    expect(completed.selectedSet!.arrows.single.shotId, shotId);

    placementsOf(bloc).add(
      OcptShotListFloorPlanArrowDeletionRequestedEvent(
        arrowId: completed.selectedSet!.arrows.single.id,
      ),
    );
    final deleted = await waitForState(bloc, (state) => state.selectedSet!.arrows.isEmpty);
    expect(deleted.selectedSet!.arrows, isEmpty);

    await bloc.close();
  });

  test("placing a character symbol arms the name prompt, dismissed clears it", () async {
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
    await waitUntil(() => canvasOf(bloc).state.pendingCharacterNamePromptSymbolId == symbolId);
    expect(canvasOf(bloc).state.pendingCharacterNamePromptSymbolId, symbolId);

    canvasOf(bloc).add(const OcptShotListFloorPlanCharacterNamePromptDismissedEvent());
    await waitUntil(() => canvasOf(bloc).state.pendingCharacterNamePromptSymbolId == null);
    expect(bloc.state.selectedSet!.symbols.single.id, symbolId);

    // A camera, a light or a set element never arms the prompt at all.
    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.cameras,
        shotId: shotId,
        sceneId: null,
        xM: 1,
        yM: 1,
      ),
    );
    await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId != symbolId);
    expect(canvasOf(bloc).state.pendingCharacterNamePromptSymbolId, isNull);

    await bloc.close();
  });

  test("selecting an arrow, bending it and straightening it back out writes the control "
      "point", () async {
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
    final withFirst = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 1);
    final firstSymbolId = withFirst.selectedSet!.symbols.single.id;

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.characters,
        shotId: shotId,
        sceneId: null,
        xM: 2,
        yM: 2,
      ),
    );
    await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

    canvasOf(bloc).add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: firstSymbolId));
    await waitUntil(
      () => canvasOf(bloc).state.pendingFloorPlanArrowAnchorSymbolId == firstSymbolId,
    );
    final secondSymbolId = bloc.state.selectedSet!.symbols
        .firstWhere((symbol) => symbol.id != firstSymbolId)
        .id;
    canvasOf(bloc).add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: secondSymbolId));
    final withArrow = await waitForState(bloc, (state) => state.selectedSet!.arrows.isNotEmpty);
    final arrowId = withArrow.selectedSet!.arrows.single.id;

    // Selecting the arrow is mutually exclusive with a symbol's own selection.
    canvasOf(bloc).add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: firstSymbolId));
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId == firstSymbolId);
    canvasOf(bloc).add(OcptShotListFloorPlanArrowSelectedEvent(arrowId: arrowId));
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanArrowId == arrowId);
    final selected = canvasOf(bloc).state;
    expect(selected.selectedFloorPlanSymbolId, isNull);

    canvasOf(
      bloc,
    ).add(OcptShotListFloorPlanArrowCurveChangedEvent(arrowId: arrowId, ctrlXM: 1.5, ctrlYM: 0.2));
    final bent = await waitForState(
      bloc,
      (state) => state.selectedSet!.arrows.single.ctrlXM == 1.5,
    );
    expect(bent.selectedSet!.arrows.single.ctrlYM, 0.2);

    canvasOf(bloc).add(
      OcptShotListFloorPlanArrowCurveChangedEvent(arrowId: arrowId, ctrlXM: null, ctrlYM: null),
    );
    final straightened = await waitForState(
      bloc,
      (state) => state.selectedSet!.arrows.single.ctrlXM == null,
    );
    expect(straightened.selectedSet!.arrows.single.ctrlYM, isNull);

    placementsOf(bloc).add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: arrowId));
    await waitForState(bloc, (state) => state.selectedSet!.arrows.isEmpty);
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanArrowId == null);
    expect(canvasOf(bloc).state.selectedFloorPlanArrowId, isNull);

    await bloc.close();
  });

  test("Ctrl+D duplicates a symbol offset from its source, an Alt-drag duplicates at the "
      "drag's own position, neither touching the source", () async {
    await writeScreenplay(twoSceneText);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setId = await createCase(bloc);
    final shotId = await createShot(bloc);

    canvasOf(bloc).add(
      OcptShotListFloorPlanSymbolPlacedEvent(
        setId: setId,
        layer: OcptFloorPlanLayer.lights,
        shotId: shotId,
        sceneId: null,
        xM: 1,
        yM: 1,
      ),
    );
    final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
    final sourceId = placed.selectedSet!.symbols.single.id;

    // No explicit position (the `Ctrl+D` shortcut): offsets from the source.
    canvasOf(bloc).add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId));
    final duplicated = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
    expect(duplicated.selectedSet!.symbols.map((symbol) => symbol.id), contains(sourceId));
    final firstCopy = duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id != sourceId);
    expect(firstCopy.xM, isNot(1));
    expect(firstCopy.layer, OcptFloorPlanLayer.lights);
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId == firstCopy.id);
    expect(canvasOf(bloc).state.selectedFloorPlanSymbolId, firstCopy.id);
    // The source itself is untouched.
    expect(duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id == sourceId).xM, 1);

    // An explicit position (an `Alt`-drag's own settled point) places the copy exactly
    // there instead of at the default offset.
    canvasOf(
      bloc,
    ).add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId, xM: 9, yM: -4));
    final secondDuplicate = await waitForState(
      bloc,
      (state) => state.selectedSet!.symbols.length == 3,
    );
    final secondCopy = secondDuplicate.selectedSet!.symbols.firstWhere(
      (symbol) => symbol.id != sourceId && symbol.id != firstCopy.id,
    );
    expect(secondCopy.xM, 9);
    expect(secondCopy.yM, -4);
    expect(
      secondDuplicate.selectedSet!.symbols.firstWhere((symbol) => symbol.id == sourceId).xM,
      1,
    );

    await bloc.close();
  });

  test("duplicating a camera carries its own field-of-view reach to the copy", () async {
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
    final sourceId = placed.selectedSet!.symbols.single.id;

    placementsOf(
      bloc,
    ).add(OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: sourceId, fovReachM: 4.5));
    await waitForState(bloc, (state) => state.selectedSet!.symbols.single.fovReachM == 4.5);

    canvasOf(bloc).add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId));
    final duplicated = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
    final copy = duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id != sourceId);
    expect(copy.fovReachM, 4.5);

    await bloc.close();
  });
}
