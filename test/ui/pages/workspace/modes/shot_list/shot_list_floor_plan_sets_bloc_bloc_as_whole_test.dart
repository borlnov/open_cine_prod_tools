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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_prop_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'shot_list_floor_plan_sets_bloc_test_doubles.dart';

/// A locations service whose set creation and renaming always fail, to exercise the sets bloc's
/// write error path.
class _FailingLocationsService extends OcptLocationsService {
  /// Class constructor
  _FailingLocationsService(OcptLocationsService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        floorPlanService: source.floorPlanService,
        deviceId: source.deviceId,
      );

  @override
  Future<String?> createSetLinkedToScene({
    required OcptProjectDatabase database,
    required String sceneId,
    required String name,
    String? locationId,
  }) async => throw StateError("set creation intentionally failed for the test");

  @override
  Future<void> updateSet({
    required OcptProjectDatabase database,
    required String setId,
    Value<String> name = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async => throw StateError("set rename intentionally failed for the test");
}

/// An elements service whose prop reads of one scene can be held back: while [heldScenes] holds
/// the scene, its read takes its data at once, then waits for [release] before answering, so what
/// it answers arrives after whatever was selected meanwhile.
class _HoldingElementsService extends OcptElementsService {
  /// The scenes whose next prop read is held back.
  final Set<String> heldScenes = {};

  /// How many reads were held back so far.
  int holdCount = 0;

  final Completer<void> _release = Completer<void>();

  /// Class constructor
  _HoldingElementsService(OcptElementsService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Lets every held read answer.
  void release() => _release.complete();

  @override
  Future<List<OcptScenePropSummary>> propsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) async {
    final props = await super.propsOfScene(database: database, sceneId: sceneId);
    if (heldScenes.remove(sceneId)) {
      holdCount++;
      await _release.future;
    }
    return props;
  }
}

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

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
    String nameOf(OcptShotListFloorPlanSetsEvent event) => switch (event) {
      OcptShotListSetCreationRequestedEvent() => "creation",
      OcptShotListSetLinkRequestedEvent() => "link",
      OcptShotListSetNameChangedEvent() => "name",
      OcptShotListSetDeletionRequestedEvent() => "deletion",
      OcptShotListSetDuplicationRequestedEvent() => "duplication",
      OcptShotListFloorPlanBlockingCopyRequestedEvent() => "blocking copy",
      OcptShotListFloorPlanZoomChangedEvent() => "zoom",
      OcptShotListFloorPlanActiveLayerChangedEvent() => "active layer",
      OcptShotListFloorPlanActiveSetElementShapeChangedEvent() => "shape",
      OcptShotListFloorPlanActiveSetElementScopeChangedEvent() => "scope",
      OcptShotListFloorPlanActiveLabelChangedEvent() => "label",
      OcptShotListFloorPlanLayerVisibilityToggledEvent() => "layer visibility",
      OcptShotListFloorPlanUnderlayVisibilityToggledEvent() => "underlay visibility",
      OcptShotListFloorPlanCameraVisibilityToggledEvent() => "camera visibility",
      OcptShotListFloorPlanOnionSkinToggledEvent() => "onion skin",
      OcptShotListFloorPlanOnionSkinOpacityChangedEvent() => "onion opacity",
      OcptShotListFloorPlanMetricsToggledEvent() => "metrics",
      OcptShotListFloorPlanUnderlayImportRequestedEvent() => "underlay import",
      OcptShotListFloorPlanUnderlayTransformChangedEvent() => "underlay transform",
      OcptShotListFloorPlanUnderlayClearRequestedEvent() => "underlay clear",
      OcptShotListFloorPlanShotWalkRequestedEvent() => "walk",
      OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent() => "flush",
      OcptShotListFloorPlanPropsLoadRequestedEvent() => "props",
      OcptShotListFloorPlanSetsWriteErrorDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode);
      await waitForState(mode, (state) => !state.isLoading);

      const events = <OcptShotListFloorPlanSetsEvent>[
        OcptShotListSetCreationRequestedEvent(),
        OcptShotListSetLinkRequestedEvent(setId: "s"),
        OcptShotListSetNameChangedEvent(setId: "s", rawValue: ""),
        OcptShotListSetDeletionRequestedEvent(setId: "s"),
        OcptShotListSetDuplicationRequestedEvent(setId: "s", newSetName: "Copy"),
        OcptShotListFloorPlanBlockingCopyRequestedEvent(setId: "s", sourceShotId: "x"),
        OcptShotListFloorPlanZoomChangedEvent(zoom: 2),
        OcptShotListFloorPlanActiveLayerChangedEvent(layer: OcptFloorPlanLayer.set),
        OcptShotListFloorPlanActiveSetElementShapeChangedEvent(
          shape: OcptFloorPlanSetElementShape.door,
        ),
        OcptShotListFloorPlanActiveSetElementScopeChangedEvent(scope: OcptFloorPlanScope.scene),
        OcptShotListFloorPlanActiveLabelChangedEvent(label: "Lamp"),
        OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: OcptFloorPlanLayer.set),
        OcptShotListFloorPlanUnderlayVisibilityToggledEvent(),
        OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: "c"),
        OcptShotListFloorPlanOnionSkinToggledEvent(isPrevious: true),
        OcptShotListFloorPlanOnionSkinOpacityChangedEvent(opacity: 0.5),
        OcptShotListFloorPlanMetricsToggledEvent(),
        OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: "s", fileTypeLabel: "Images"),
        OcptShotListFloorPlanUnderlayTransformChangedEvent(
          setId: "s",
          xM: 0,
          yM: 0,
          widthM: 1,
          heightM: 1,
        ),
        OcptShotListFloorPlanUnderlayClearRequestedEvent(setId: "s"),
        OcptShotListFloorPlanShotWalkRequestedEvent(delta: 1),
        OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent(),
        OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: null),
        OcptShotListFloorPlanSetsWriteErrorDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(24));

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => sets.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await closeAll(sets, mode);
    });

    /// Adds a prop named [name] to the breakdown of scene [sceneId], answering its element id.
    Future<String> addProp(String sceneId, String name) async {
      final project = projectsManager.currentProject!;
      final elementId = (await projectsManager.elementsService.createElement(
        database: project.database,
        name: name,
        category: OcptElementCategory.prop,
        sourceKind: OcptElementSourceKind.owned,
      ))!;
      await projectsManager.elementsService.addSceneElement(
        database: project.database,
        sceneId: sceneId,
        elementId: elementId,
      );
      return elementId;
    }

    test(
      "the mode's selection moves read the new sequence's props, the palette never going empty",
      () async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        await waitForState(mode, (state) => !state.isLoading);
        final firstSequence = mode.state.sequences.first as OcptSceneShotSequence;
        final secondSequence = mode.state.sequences.last as OcptSceneShotSequence;
        final candlesId = await addProp(firstSequence.sceneId, "Candles");
        final lanternId = await addProp(secondSequence.sceneId, "Lantern");
        final service = _HoldingElementsService(projectsManager.elementsService);

        // Built once the mode loaded: it reads the props of the sequence the mode is on at once.
        final sets = buildSets(mode, elementsService: service);
        await waitUntil(() => sets.state.propsOfSelectedSequence.length == 1);
        expect(sets.state.propsOfSelectedSequence.single.elementId, candlesId);

        // Another sequence: the props shown stay while the read is on its way, then are replaced.
        final shown = <int>[];
        final shownSubscription = sets.stream.listen(
          (state) => shown.add(state.propsOfSelectedSequence.length),
        );
        service.heldScenes.add(secondSequence.sceneId);
        await mode.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: secondSequence.id));
        await waitUntil(() => service.holdCount == 1);
        expect(sets.state.propsOfSelectedSequence.single.elementId, candlesId);
        service.release();
        await waitUntil(() => sets.state.propsOfSelectedSequence.single.elementId == lanternId);

        // Back: the first sequence's.
        await mode.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: firstSequence.id));
        await waitUntil(() => sets.state.propsOfSelectedSequence.single.elementId == candlesId);
        expect(shown, isNot(contains(0)));
        await shownSubscription.cancel();

        // The sequence already shown, a shot and a set selected leave them as they are.
        final emissions = <int>[];
        final subscription = sets.stream.listen(
          (state) => emissions.add(state.propsOfSelectedSequence.length),
        );
        await mode.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: firstSequence.id));
        final shotId = await createShot(mode);
        await mode.addAndWait(OcptShotListShotSelectedEvent(shotId: shotId));
        await pumpEventQueue();
        expect(sets.state.propsOfSelectedSequence, hasLength(1));
        expect(emissions, isEmpty);

        await subscription.cancel();
        await closeAll(sets, mode);
      },
    );

    test("entering and leaving a version preview keeps the palette's props on screen", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      await waitForState(mode, (state) => !state.isLoading);
      final firstSequence = mode.state.sequences.first as OcptSceneShotSequence;
      final candlesId = await addProp(firstSequence.sceneId, "Candles");
      final sets = buildSets(mode);
      await waitUntil(() => sets.state.propsOfSelectedSequence.length == 1);

      final shown = <int>[];
      final subscription = sets.stream.listen(
        (state) => shown.add(state.propsOfSelectedSequence.length),
      );

      mode.add(const OcptProjectVersionCreationRequestedEvent(name: "With a prop", note: ""));
      final withVersion = await waitForState(mode, (state) => state.projectVersions.isNotEmpty);
      mode.add(
        OcptProjectVersionPreviewRequestedEvent(versionId: withVersion.projectVersions.single.id),
      );
      await waitForState(mode, (state) => state.previewedVersionId != null);
      await pumpEventQueue();
      await waitUntil(() => sets.state.propsOfSelectedSequence.length == 1);

      mode.add(const OcptProjectVersionPreviewExitRequestedEvent());
      await waitForState(mode, (state) => state.previewedVersionId == null);
      await pumpEventQueue();

      expect(sets.state.propsOfSelectedSequence.single.elementId, candlesId);
      expect(shown, isNot(contains(0)));

      await subscription.cancel();
      await closeAll(sets, mode);
    });

    test("props read for a sequence the mode has left do not reach the palette", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      await waitForState(mode, (state) => !state.isLoading);
      final firstSequence = mode.state.sequences.first as OcptSceneShotSequence;
      final secondSequence = mode.state.sequences.last as OcptSceneShotSequence;
      await addProp(firstSequence.sceneId, "Candles");
      final lanternId = await addProp(secondSequence.sceneId, "Lantern");
      final service = _HoldingElementsService(projectsManager.elementsService);
      final sets = buildSets(mode, elementsService: service);
      await pumpEventQueue();

      // The first sequence's props are read and held, while the mode moves to the second.
      service.heldScenes.add(firstSequence.sceneId);
      mode.add(const OcptShotListLoadRequestedEvent());
      await waitUntil(() => service.holdCount == 1);
      await mode.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: secondSequence.id));
      await waitUntil(
        () =>
            sets.state.propsOfSelectedSequence.isNotEmpty &&
            sets.state.propsOfSelectedSequence.single.elementId == lanternId,
      );

      service.release();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sets.state.propsOfSelectedSequence.single.elementId, lanternId);

      await closeAll(sets, mode);
    });

    test("a set is selected only once the mode holds it", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode);
      await waitForState(mode, (state) => !state.isLoading);

      // How many sets the mode held at the very moment it first named a selected one.
      final setCountWhenSelected = mode.stream
          .firstWhere((state) => state.selectedSetId != null)
          .then((state) => state.setsOfSelectedSequence.length);

      sets.add(const OcptShotListSetCreationRequestedEvent());

      expect(await setCountWhenSelected.timeout(const Duration(seconds: 5)), 1);

      await closeAll(sets, mode);
    });

    test("every way a set becomes the selected one moves the mode's selection epoch", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode);
      var state = await waitForState(mode, (state) => !state.isLoading);

      // Created.
      var epoch = state.selectionEpoch;
      var reloadEpoch = state.reloadEpoch;
      sets.add(const OcptShotListSetCreationRequestedEvent());
      state = await waitForState(
        mode,
        (state) => state.setsOfSelectedSequence.length == 1 && state.selectionEpoch > epoch,
      );
      final firstSetId = state.selectedSetId!;
      expect(state.selectionEpoch, epoch + 1, reason: 'created');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'created');
      expect(state.selectionCause, OcptShotListSelectionCause.setAdded, reason: 'created');

      // Linked, from the second sequence.
      mode.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences[1].id));
      state = await waitForState(
        mode,
        (state) => state.selectedSequenceId == state.sequences[1].id,
      );
      epoch = state.selectionEpoch;
      reloadEpoch = state.reloadEpoch;
      sets.add(OcptShotListSetLinkRequestedEvent(setId: firstSetId));
      state = await waitForState(
        mode,
        (state) => state.setsOfSelectedSequence.isNotEmpty && state.selectionEpoch > epoch,
      );
      expect(state.selectionEpoch, epoch + 1, reason: 'linked');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'linked');
      expect(state.selectionCause, OcptShotListSelectionCause.setAdded, reason: 'linked');

      // Duplicated.
      epoch = state.selectionEpoch;
      reloadEpoch = state.reloadEpoch;
      sets.add(OcptShotListSetDuplicationRequestedEvent(setId: firstSetId, newSetName: "Copy"));
      state = await waitForState(
        mode,
        (state) => state.setsOfSelectedSequence.length == 2 && state.selectionEpoch > epoch,
      );
      final copyId = state.selectedSetId!;
      expect(state.selectionEpoch, epoch + 1, reason: 'duplicated');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'duplicated');
      expect(state.selectionCause, OcptShotListSelectionCause.setAdded, reason: 'duplicated');

      // Unlinked while selected: the sequence's next set is selected.
      epoch = state.selectionEpoch;
      reloadEpoch = state.reloadEpoch;
      sets.add(OcptShotListSetDeletionRequestedEvent(setId: copyId));
      state = await waitForState(
        mode,
        (state) => state.setsOfSelectedSequence.length == 1 && state.selectionEpoch > epoch,
      );
      expect(state.selectionEpoch, epoch + 1, reason: 'unlinked');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'unlinked');
      expect(state.selectionCause, OcptShotListSelectionCause.setRemoved, reason: 'unlinked');

      // Unlinked while not selected: only the data is read again.
      sets.add(OcptShotListSetDeletionRequestedEvent(setId: firstSetId));
      await waitForState(mode, (state) => state.setsOfSelectedSequence.isEmpty);
      await pumpEventQueue();

      await closeAll(sets, mode);
    });

    test("unlinking a set drops the name typed into it", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode, sets);

      sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Lost"));
      await waitUntil(() => sets.state.pendingFieldEdits.isNotEmpty);

      sets.add(OcptShotListSetDeletionRequestedEvent(setId: setId));
      await waitUntil(() => sets.state.pendingFieldEdits.isEmpty);
      expect(mode.state.setsOfSelectedSequence, isEmpty);

      await closeAll(sets, mode);
    });

    test("the mode's flush writes a set name still being typed", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode, sets);

      sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Typed"));
      await waitUntil(() => sets.state.pendingFieldEdits.isNotEmpty);
      expect(mode.state.selectedSet!.name, "HOUSE");

      await mode.flushAllPendingWrites();

      expect(sets.state.pendingFieldEdits, isEmpty);
      expect(mode.state.selectedSet!.name, "Typed");
      expect(mode.state.locations.expand((location) => location.sets).single.name, "Typed");

      await closeAll(sets, mode);
    });

    test(
      "a version preview writes the set name still being typed before it swaps the database",
      () async {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final sets = buildSets(mode, fieldEditDebounce: const Duration(days: 1));
        await waitForState(mode, (state) => !state.isLoading);
        final setId = await createCase(mode, sets);

        sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Typed"));
        await waitUntil(() => sets.state.pendingFieldEdits.isNotEmpty);

        mode.add(const OcptProjectVersionCreationRequestedEvent(name: "Typing", note: ""));
        await waitForState(mode, (state) => state.projectVersions.isNotEmpty);

        // The working copy holds the name: the flush went through the mode, to the sets bloc.
        expect(sets.state.pendingFieldEdits, isEmpty);
        expect(mode.state.selectedSet!.name, "Typed");

        await closeAll(sets, mode);
      },
    );

    test("a name typed while the sets' flush is in flight is kept and written", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode, fieldEditDebounce: const Duration(days: 1));
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode, sets);
      OcptShotListSetNameChangedEvent typed(String text) =>
          OcptShotListSetNameChangedEvent(setId: setId, rawValue: text);

      sets.add(typed("5"));
      await waitUntil(() => sets.state.pendingFieldEdits.isNotEmpty);

      final flush = sets.flushPendingWrites();
      sets.add(typed("50"));
      await flush;
      await waitUntil(() => sets.state.pendingFieldEdits.values.contains("50"));

      expect(sets.state.pendingFieldEdits.values, ["50"], reason: 'the keystroke is not lost');
      await sets.flushPendingWrites();
      expect(sets.state.pendingFieldEdits, isEmpty);
      expect(mode.state.selectedSet!.name, "50");

      await closeAll(sets, mode);
    });

    test("a set name still being typed is written whichever of the sets bloc and the mode closes "
        "first", () async {
      for (final setsFirst in [true, false]) {
        await writeScreenplay(twoSceneText);
        final mode = buildBloc();
        final sets = buildSets(mode, fieldEditDebounce: const Duration(days: 1));
        await waitForState(mode, (state) => !state.isLoading);
        final setId = await createCase(mode, sets);

        sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Kept"));
        await waitUntil(() => sets.state.pendingFieldEdits.isNotEmpty);

        if (setsFirst) {
          await sets.close();
          await mode.close();
        } else {
          await mode.close();
          await sets.close();
        }

        final project = projectsManager.currentProject!;
        final locations = await projectsManager.locationsService.loadLocations(
          database: project.database,
        );
        expect(
          locations.expand((location) => location.sets).firstWhere((set) => set.id == setId).name,
          "Kept",
          reason: setsFirst ? "sets bloc closed first" : "mode closed first",
        );

        // The next round starts from a project without that set.
        await projectsManager.locationsService.removeSceneFromSet(
          database: project.database,
          sceneId: (mode.state.sequences.first as OcptSceneShotSequence).sceneId,
          setId: setId,
        );
        await projectsManager.locationsService.updateSet(
          database: project.database,
          setId: setId,
          name: const Value("Gone"),
        );
      }
    });

    test("closing the mode while a set creation waits for it neither hangs nor throws", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode);
      await waitForState(mode, (state) => !state.isLoading);

      sets.add(const OcptShotListSetCreationRequestedEvent());
      await mode.close().timeout(const Duration(seconds: 5));
      await sets.close().timeout(const Duration(seconds: 5));
    });

    test("a failing write raises the sets' own write error, which can be dismissed", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(
        mode,
        locationsService: _FailingLocationsService(projectsManager.locationsService),
      );
      await waitForState(mode, (state) => !state.isLoading);

      sets.add(const OcptShotListSetCreationRequestedEvent());
      await waitUntil(() => sets.state.hasWriteError);
      expect(mode.state.hasWriteError, isFalse, reason: 'the mode did not fail');

      sets.add(const OcptShotListFloorPlanSetsWriteErrorDismissedEvent());
      await waitUntil(() => !sets.state.hasWriteError);

      await closeAll(sets, mode);
    });

    test("a failing name write raises the write error and forgets the name", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final setsToCreate = buildSets(mode);
      await waitForState(mode, (state) => !state.isLoading);
      final setId = await createCase(mode, setsToCreate);
      await setsToCreate.close();
      final sets = buildSets(
        mode,
        locationsService: _FailingLocationsService(projectsManager.locationsService),
        fieldEditDebounce: const Duration(days: 1),
      );

      sets.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Nope"));
      await waitUntil(() => sets.state.pendingFieldEdits.isNotEmpty);
      await mode.flushAllPendingWrites();

      expect(sets.state.hasWriteError, isTrue);
      expect(sets.state.pendingFieldEdits, isEmpty);

      await closeAll(sets, mode);
    });

    test("the zoom, the hidden layers and the armed placement survive the mode reading everything "
        "again", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final sets = buildSets(mode);
      await waitForState(mode, (state) => !state.isLoading);

      sets.add(const OcptShotListFloorPlanZoomChangedEvent(zoom: 2));
      sets.add(
        const OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: OcptFloorPlanLayer.set),
      );
      sets.add(const OcptShotListFloorPlanActiveLabelChangedEvent(label: "Lamp"));
      await waitUntil(() => sets.state.floorPlanActiveLabel == "Lamp");

      mode.add(const OcptProjectVersionCreationRequestedEvent(name: "Keep", note: ""));
      final withVersion = await waitForState(mode, (state) => state.projectVersions.isNotEmpty);
      mode.add(
        OcptProjectVersionPreviewRequestedEvent(versionId: withVersion.projectVersions.single.id),
      );
      await waitForState(mode, (state) => state.previewedVersionId != null);
      await pumpEventQueue();

      expect(sets.state.floorPlanZoom, 2);
      expect(sets.state.floorPlanHiddenLayers, {OcptFloorPlanLayer.set});
      expect(sets.state.floorPlanActiveLabel, "Lamp");

      await closeAll(sets, mode);
    });
  });
}
