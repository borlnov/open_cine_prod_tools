// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state_derived.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_floor_plan_sets_bloc_test_doubles.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The ids of what the handlers work on.
typedef _Seeded = ({
  String sceneId,
  String setId,
  String firstShot,
  String setSymbol,
  String camera,
  String character,
  String sceneOverride,
  String arrow,
});

/// What a handler does for one event: where it dispatches, and which state says it failed.
typedef _Case = ({
  String table,
  String verb,
  void Function(_Seeded seeded) dispatch,
  bool Function() hasFailed,
});

/// What the floor plans do when the database refuses a write, or cannot read them, with a real
/// SQLite failure: the handler stops where the exception stopped it, raises the write error of its
/// own bloc, reads nothing again, and the same event goes through once the refusal is lifted.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late OcptShotListFloorPlanSetsBloc sets;
  late OcptShotListFloorPlanCanvasBloc canvas;
  late OcptShotListFloorPlanPlacementsBloc placements;
  late _Seeded seeded;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  /// Build the mode bloc and its three floor plan views and wait for the mode to load.
  Future<void> build() async {
    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    sets = OcptShotListFloorPlanSetsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fileSelectorManager: const StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
      fieldEditDebounce: const Duration(days: 1),
    );
    canvas = OcptShotListFloorPlanCanvasBloc(modeBloc: mode, projectsManager: projectsManager);
    placements = OcptShotListFloorPlanPlacementsBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_floor_plan_failure_test_");
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

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: twoSceneText,
      snapshotReason: OcptSnapshotReason.manual,
    );
    await build();

    final epoch = mode.state.selectionEpoch;
    sets.add(const OcptShotListSetCreationRequestedEvent());
    await settle();
    expect(mode.state.selectionEpoch, greaterThan(epoch));
    final setId = mode.state.selectedSetId!;
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await settle();
    final firstShot = mode.state.selectedShotId!;
    final sequence = mode.state.selectedSequence;
    expect(sequence, isA<OcptSceneShotSequence>());
    final sceneId = (sequence! as OcptSceneShotSequence).sceneId;

    final service = projectsManager.floorPlanService;
    Future<String> place(OcptFloorPlanLayer layer, String? shotId, {String? scene, String? over}) =>
        service
            .placeSymbol(
              database: project.database,
              setId: setId,
              sceneId: scene,
              shotId: shotId,
              layer: layer,
              xM: 1,
              yM: 1,
              overridesSymbolId: over,
            )
            .valueOrFail;
    final setSymbol = await place(OcptFloorPlanLayer.set, null);
    final sceneOverride = await place(
      OcptFloorPlanLayer.set,
      null,
      scene: sceneId,
      over: setSymbol,
    );
    final camera = await place(OcptFloorPlanLayer.cameras, firstShot);
    final character = await place(OcptFloorPlanLayer.characters, firstShot);
    final arrow = await service
        .addArrow(
          database: project.database,
          setId: setId,
          shotId: firstShot,
          kind: OcptFloorPlanArrowKind.movement,
          fromSymbolId: camera,
          toSymbolId: character,
        )
        .valueOrFail;
    await service
        .setSetUnderlay(
          database: project.database,
          setId: setId,
          path: "/plans/old.png",
          xM: 0,
          yM: 0,
          widthM: 4,
          heightM: 3,
        )
        .okOrFail;

    // A second shot, the one the mode focuses, to copy the first one's blocking onto.
    mode.add(const OcptShotListShotCreationRequestedEvent());
    await settle();
    await mode.reload({
      OcptShotListReloadScope.floorPlans,
      OcptShotListReloadScope.locations,
      OcptShotListReloadScope.setScopeSymbols,
    });
    seeded = (
      sceneId: sceneId,
      setId: setId,
      firstShot: firstShot,
      setSymbol: setSymbol,
      camera: camera,
      character: character,
      sceneOverride: sceneOverride,
      arrow: arrow,
    );
  });

  tearDown(() async {
    await placements.close();
    await canvas.close();
    await sets.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make the database refuse the [verb] of [table].
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift the refusal [refuse] put on the [verb] of [table].
  Future<void> lift(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Resolve a pending scope decision on the set symbol with [choice].
  void decide(_Seeded s, OcptFloorPlanScopeChoice choice) {
    canvas.add(
      OcptShotListFloorPlanScopeDecisionRequestedEvent(
        symbolId: s.setSymbol,
        setId: s.setId,
        level: OcptFloorPlanOverrideLevel.sequence,
        sequenceCount: 2,
        xM: 5,
      ),
    );
    canvas.add(OcptShotListFloorPlanScopeDecisionResolvedEvent(choice: choice));
  }

  /// The handlers, each with the table and the verb that fail it.
  final cases = <String, _Case>{
    "placing a symbol": (
      table: "floor_plan_symbols",
      verb: "INSERT",
      dispatch: (s) => canvas.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: s.setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 2,
          yM: 2,
        ),
      ),
      hasFailed: () => canvas.state.hasWriteError,
    ),
    "moving a symbol": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) =>
          canvas.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: s.camera, xM: 3, yM: 3)),
      hasFailed: () => canvas.state.hasWriteError,
    ),
    "resizing a symbol": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) => canvas.add(
        OcptShotListFloorPlanSymbolResizedEvent(symbolId: s.setSymbol, widthM: 2, heightM: 2),
      ),
      hasFailed: () => canvas.state.hasWriteError,
    ),
    "rotating a symbol": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) =>
          canvas.add(OcptShotListFloorPlanSymbolRotatedEvent(symbolId: s.camera, rotationDeg: 45)),
      hasFailed: () => canvas.state.hasWriteError,
    ),
    "resolving a scope decision on every scope": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) => decide(s, OcptFloorPlanScopeChoice.every),
      hasFailed: () =>
          canvas.state.hasWriteError && canvas.state.pendingFloorPlanScopeDecision == null,
    ),
    "resolving a scope decision on this sequence alone": (
      table: "floor_plan_symbols",
      verb: "INSERT",
      dispatch: (s) => decide(s, OcptFloorPlanScopeChoice.only),
      hasFailed: () =>
          canvas.state.hasWriteError && canvas.state.pendingFloorPlanScopeDecision == null,
    ),
    "drawing an arrow": (
      table: "floor_plan_arrows",
      verb: "INSERT",
      dispatch: (s) {
        canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: s.character));
        canvas.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: s.camera));
      },
      hasFailed: () =>
          canvas.state.hasWriteError && canvas.state.pendingFloorPlanArrowAnchorSymbolId == null,
    ),
    "bending an arrow": (
      table: "floor_plan_arrows",
      verb: "UPDATE",
      dispatch: (s) => canvas.add(
        OcptShotListFloorPlanArrowCurveChangedEvent(arrowId: s.arrow, ctrlXM: 1, ctrlYM: 1),
      ),
      hasFailed: () => canvas.state.hasWriteError,
    ),
    "duplicating a symbol": (
      table: "floor_plan_symbols",
      verb: "INSERT",
      dispatch: (s) =>
          canvas.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: s.setSymbol)),
      hasFailed: () => canvas.state.hasWriteError,
    ),
    "deleting a symbol": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) =>
          placements.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: s.character)),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "deleting a symbol everywhere": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) => placements.add(
        OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: s.setSymbol),
      ),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "hiding a symbol for a sequence": (
      table: "floor_plan_symbols",
      verb: "INSERT",
      dispatch: (s) => placements.add(
        OcptShotListFloorPlanSymbolHideRequestedEvent(
          symbolId: s.setSymbol,
          targetSceneId: s.sceneId,
        ),
      ),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "hiding a symbol for a shot": (
      table: "floor_plan_symbols",
      verb: "INSERT",
      dispatch: (s) => placements.add(
        OcptShotListFloorPlanSymbolHideForShotRequestedEvent(
          symbolId: s.sceneOverride,
          targetShotId: s.firstShot,
        ),
      ),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "restoring an override": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) => placements.add(
        OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: s.sceneOverride),
      ),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "deleting an arrow": (
      table: "floor_plan_arrows",
      verb: "UPDATE",
      dispatch: (s) =>
          placements.add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: s.arrow)),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "changing a field of view": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) => placements.add(
        OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: s.camera, fovDeg: 40),
      ),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "changing a field of view reach": (
      table: "floor_plan_symbols",
      verb: "UPDATE",
      dispatch: (s) => placements.add(
        OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: s.camera, fovReachM: 6),
      ),
      hasFailed: () => placements.state.hasWriteError,
    ),
    "copying the blocking of a shot": (
      table: "floor_plan_symbols",
      verb: "INSERT",
      dispatch: (s) => sets.add(
        OcptShotListFloorPlanBlockingCopyRequestedEvent(setId: s.setId, sourceShotId: s.firstShot),
      ),
      hasFailed: () => sets.state.hasWriteError,
    ),
    "importing an underlay": (
      table: "assets",
      verb: "INSERT",
      dispatch: (s) => sets.add(
        OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: s.setId, fileTypeLabel: "Image"),
      ),
      hasFailed: () => sets.state.hasWriteError,
    ),
    "moving an underlay": (
      table: "floor_plan_sets",
      verb: "UPDATE",
      dispatch: (s) => sets.add(
        OcptShotListFloorPlanUnderlayTransformChangedEvent(
          setId: s.setId,
          xM: 1,
          yM: 1,
          widthM: 6,
          heightM: 5,
        ),
      ),
      hasFailed: () => sets.state.hasWriteError,
    ),
    "clearing an underlay": (
      table: "floor_plan_sets",
      verb: "UPDATE",
      dispatch: (s) => sets.add(OcptShotListFloorPlanUnderlayClearRequestedEvent(setId: s.setId)),
      hasFailed: () => sets.state.hasWriteError,
    ),
  };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test(
      "${entry.key} raises the write error, reads nothing again, and goes through once lifted",
      () async {
        final held = mode.state;
        await refuse(case_.verb, case_.table);

        case_.dispatch(seeded);
        await settle();

        expect(case_.hasFailed(), isTrue);
        expect(mode.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");

        await lift(case_.verb, case_.table);
        canvas.add(const OcptShotListFloorPlanCanvasWriteErrorDismissedEvent());
        placements.add(const OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent());
        sets.add(const OcptShotListFloorPlanSetsWriteErrorDismissedEvent());
        case_.dispatch(seeded);
        await settle();

        expect(canvas.state.hasWriteError, isFalse);
        expect(placements.state.hasWriteError, isFalse);
        expect(sets.state.hasWriteError, isFalse);
        expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
      },
    );
  }

  test("duplicating a shot-scope override of a prop, which the service refuses, raises the "
      "write error and writes nothing", () async {
    final database = projectsManager.currentProject!.database;
    final service = projectsManager.floorPlanService;
    final prop = await service
        .placeSymbol(
          database: database,
          setId: seeded.setId,
          sceneId: seeded.sceneId,
          shotId: null,
          layer: OcptFloorPlanLayer.props,
          xM: 1,
          yM: 1,
        )
        .valueOrFail;
    final override = await service
        .placeSymbol(
          database: database,
          setId: seeded.setId,
          sceneId: null,
          shotId: seeded.firstShot,
          layer: OcptFloorPlanLayer.props,
          xM: 2,
          yM: 2,
          overridesSymbolId: prop,
        )
        .valueOrFail;
    await mode.reload({OcptShotListReloadScope.floorPlans});
    final held = mode.state;
    final count = (await database.select(database.ocptFloorPlanSymbolsTable).get()).length;

    canvas.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: override));
    await settle();

    expect(canvas.state.hasWriteError, isTrue);
    expect(mode.state.reloadEpoch, held.reloadEpoch);
    expect(canvas.state.selectedFloorPlanSymbolId, isNot(override));
    expect((await database.select(database.ocptFloorPlanSymbolsTable).get()).length, count);
  });

  group("flushing a typed symbol label", () {
    /// Type a label into the camera symbol.
    Future<void> type() async {
      placements.add(
        OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: seeded.camera, rawValue: "Cam A"),
      );
      await settle();
    }

    test("a refused write loses the label, raises the write error and goes on", () async {
      await type();
      final held = mode.state;
      await refuse("UPDATE", "floor_plan_symbols");

      final status = await placements.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(placements.state.hasWriteError, isTrue);
      expect(placements.state.pendingFieldEdits, isEmpty);
      expect(mode.state.reloadEpoch, held.reloadEpoch);

      await lift("UPDATE", "floor_plan_symbols");
      await type();

      expect(await placements.flushPendingWrites(), OcptPendingWritesStatus.ok);
      expect(mode.state.reloadEpoch, isNot(held.reloadEpoch));
    });

    test("a refused write leaves the label to the next flush that has no state", () async {
      await type();
      final held = mode.state;
      await refuse("UPDATE", "floor_plan_symbols");

      await placements.flushPendingWritesWithoutState();

      expect(mode.state.reloadEpoch, held.reloadEpoch);
      expect(placements.state.pendingFieldEdits, isNotEmpty);

      await lift("UPDATE", "floor_plan_symbols");
      await placements.flushPendingWritesWithoutState();
      await mode.reload({OcptShotListReloadScope.floorPlans});

      final symbols = mode.state.floorPlanSnapshot!.setsById[seeded.setId]!.symbols;
      expect(symbols.firstWhere((symbol) => symbol.id == seeded.camera).label, "Cam A");
    });
  });
}
