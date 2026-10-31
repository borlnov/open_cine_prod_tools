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
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String _testAppLanguageCode() => "en";

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

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

  @override
  Future<String?> placeSymbol({
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
  }) async => throw StateError("symbol placement intentionally failed for the test");

  @override
  Future<void> updateSymbol({
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
  }) async => throw StateError("symbol update intentionally failed for the test");
}

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
      appLanguageCode: _testAppLanguageCode,
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
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

  /// Builds the mode bloc wired to the test project. [fieldEditDebounce] defaults to a short
  /// duration so tests exercising the field-edit debounce don't have to wait out the real 2 s one.
  OcptShotListBloc buildBloc({Duration fieldEditDebounce = const Duration(milliseconds: 30)}) =>
      OcptShotListBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _RecordingRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        fieldEditDebounce: fieldEditDebounce,
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

    bloc.add(
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

    bloc.add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: arrowId));
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

    bloc.add(OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: sourceId, fovReachM: 4.5));
    await waitForState(bloc, (state) => state.selectedSet!.symbols.single.fovReachM == 4.5);

    canvasOf(bloc).add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId));
    final duplicated = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
    final copy = duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id != sourceId);
    expect(copy.fovReachM, 4.5);

    await bloc.close();
  });

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
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
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

    /// Mounts the mode on [twoSceneText] with a set and a shot, and places one character symbol
    /// on the shot, which the canvas selects. Answers the mode and the ids.
    Future<({OcptShotListBloc mode, String setId, String shotId, String symbolId})>
    mountWithASymbol() async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
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
      await floorPlanService.hideSymbolForScope(
        database: project.database,
        original: wall,
        existingOverride: null,
        sceneId: sceneId,
        shotId: null,
      );
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
      await floorPlanService.deleteSymbol(database: project.database, symbolId: otherWallId);
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
      await projectsManager.floorPlanService.deleteArrow(
        database: project.database,
        arrowId: arrowId,
      );
      await mode.reload({OcptShotListReloadScope.floorPlans});

      await waitUntil(() => canvas.state.selectedFloorPlanArrowId == null);

      await mode.close();
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
