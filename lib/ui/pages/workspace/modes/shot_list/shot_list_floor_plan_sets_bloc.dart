// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_prop_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_set_suggestion.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';

/// This is the bloc class for the shot list mode's floor plan sets: the set tabs and the empty
/// state gallery, the tray and the palette around the canvas, and the underlay.
///
/// The sets, their symbols and their underlays are the mode's data, in
/// `OcptShotListState.floorPlanSnapshot` and `.locations`. This bloc owns what the floor plans view
/// does with them around the canvas: it creates, links, renames, unlinks and duplicates the
/// selected sequence's sets, copies a shot's blocking, imports, frames and clears an underlay,
/// walks the focus from one shot to the next, and holds the session's view preferences (zoom, the
/// layers, cameras and underlay hidden, the onion skin, the metrics overlay), the palette's armed
/// placement, the props the palette offers for the selected sequence, and the set names typed and
/// not yet written ([OcptShotListFloorPlanSetsState.pendingFieldEdits]).
///
/// **Writing.** A write calls its service, then waits for the mode to read what it changed
/// (`OcptShotListBloc.reload`). A write that makes a set the selected one (a set created, linked or
/// duplicated into the sequence, or the selected set unlinked from it) then asks the mode to move
/// its selection (`OcptShotListSetAddedEvent`, `OcptShotListSetRemovedEvent`) and waits for it,
/// since which set is selected is the mode's: the mode's state already holds the set when the
/// selection lands on it. A typed set name is held in the pending map and written
/// [OcptShotListBloc.defaultFieldEditDebounce] after the last keystroke; the mode flushes it ahead
/// of anything that needs the database to be up to date.
///
/// **Reacting.** When the mode loads or selects another sequence, the palette's props are emptied
/// and read again for the new sequence. Nothing else here depends on the selection: the zoom, the
/// hidden layers and the onion skin stay as the user left them through any selection move or
/// reload, as they always have.
class OcptShotListFloorPlanSetsBloc
    extends AbsOcptViewBloc<OcptShotListFloorPlanSetsState, OcptShotListState, OcptShotListBloc>
    with MixinAsyncInitBloc<OcptShotListFloorPlanSetsState> {
  /// The centre X, in metres, a set's underlay is framed at the moment it is first imported —
  /// see [_onUnderlayImportRequested].
  static const _defaultUnderlayXM = 0.0;

  /// The centre Y, in metres, a set's underlay is framed at the moment it is first imported.
  static const _defaultUnderlayYM = 0.0;

  /// The width, in metres, a set's underlay is framed at the moment it is first imported — a
  /// plausible room width the user drags and resizes against the reference silhouette (ADR 0031).
  static const _defaultUnderlayWidthM = 6.0;

  /// The height, in metres, a set's underlay is framed at the moment it is first imported.
  static const _defaultUnderlayHeightM = 4.0;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to create, rename, link, unlink and duplicate a Resources set.
  final OcptLocationsService _locationsService;

  /// The service used to copy a shot's blocking and to write a set's underlay.
  final OcptFloorPlanService _floorPlanService;

  /// The service used to read the selected sequence's own breakdown props.
  final OcptElementsService _elementsService;

  /// The manager used to pick a set's underlay through the native "open" dialog.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last set name edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// {@macro open_cine_prod_tools.viewBlocConstructorWithDebounce}
  OcptShotListFloorPlanSetsBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptLocationsService? locationsService,
    OcptFloorPlanService? floorPlanService,
    OcptElementsService? elementsService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = OcptShotListBloc.defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _floorPlanService =
           floorPlanService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).floorPlanService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptShotListFloorPlanSetsState.init());

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  ///
  /// Reads the palette's props when the mode loaded before this bloc was built, which moves no
  /// selection this bloc could react to.
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptShotListFloorPlanSetsState> emit}) async {
    await super.initAsyncBloc(emit: emit);

    if (!modeBloc.state.isLoading) {
      await _onPropsLoadRequested(
        OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: modeBloc.state.selectedSequenceId),
        emit,
      );
    }
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListSetCreationRequestedEvent>(_onSetCreationRequested);
    on<OcptShotListSetLinkRequestedEvent>(_onSetLinkRequested);
    on<OcptShotListSetNameChangedEvent>(_onSetNameChanged);
    on<OcptShotListSetDeletionRequestedEvent>(_onSetDeletionRequested);
    on<OcptShotListSetDuplicationRequestedEvent>(_onSetDuplicationRequested);
    on<OcptShotListFloorPlanBlockingCopyRequestedEvent>(_onBlockingCopyRequested);
    on<OcptShotListFloorPlanZoomChangedEvent>(_onZoomChanged);
    on<OcptShotListFloorPlanActiveLayerChangedEvent>(_onActiveLayerChanged);
    on<OcptShotListFloorPlanActiveSetElementShapeChangedEvent>(_onActiveSetElementShapeChanged);
    on<OcptShotListFloorPlanActiveSetElementScopeChangedEvent>(_onActiveSetElementScopeChanged);
    on<OcptShotListFloorPlanActiveLabelChangedEvent>(_onActiveLabelChanged);
    on<OcptShotListFloorPlanLayerVisibilityToggledEvent>(_onLayerVisibilityToggled);
    on<OcptShotListFloorPlanUnderlayVisibilityToggledEvent>(_onUnderlayVisibilityToggled);
    on<OcptShotListFloorPlanUnderlayImportRequestedEvent>(_onUnderlayImportRequested);
    on<OcptShotListFloorPlanUnderlayTransformChangedEvent>(_onUnderlayTransformChanged);
    on<OcptShotListFloorPlanUnderlayClearRequestedEvent>(_onUnderlayClearRequested);
    on<OcptShotListFloorPlanShotWalkRequestedEvent>(_onShotWalkRequested);
    on<OcptShotListFloorPlanCameraVisibilityToggledEvent>(_onCameraVisibilityToggled);
    on<OcptShotListFloorPlanOnionSkinToggledEvent>(_onOnionSkinToggled);
    on<OcptShotListFloorPlanOnionSkinOpacityChangedEvent>(_onOnionSkinOpacityChanged);
    on<OcptShotListFloorPlanMetricsToggledEvent>(_onMetricsToggled);
    on<OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListFloorPlanPropsLoadRequestedEvent>(_onPropsLoadRequested);
    on<OcptShotListFloorPlanSetsWriteErrorDismissedEvent>(_onWriteErrorDismissed);
  }

  /// Read the palette's props again when the mode loads or selects another sequence, the only
  /// moves of the mode's state this bloc depends on.
  ///
  /// Waits for nothing: the read runs as an event of its own
  /// ([OcptShotListFloorPlanPropsLoadRequestedEvent]). The palette keeps the props it shows until
  /// the new ones land, then swaps them at once, as the screen always has: emptying it meanwhile
  /// would make the chips flicker.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptShotListState> event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final arePropsStale =
        event.hasSelectionMoved &&
        switch (event.modeState.selectionCause) {
          OcptShotListSelectionCause.sequence || OcptShotListSelectionCause.load => true,
          // A shot, a set, or the sequence already shown selected again keep the sequence's props.
          OcptShotListSelectionCause.sequenceReselected ||
          OcptShotListSelectionCause.shot ||
          OcptShotListSelectionCause.shotCreated ||
          OcptShotListSelectionCause.shotDeleted ||
          OcptShotListSelectionCause.set ||
          OcptShotListSelectionCause.setAdded ||
          OcptShotListSelectionCause.setRemoved ||
          OcptShotListSelectionCause.symbolRemoved ||
          OcptShotListSelectionCause.symbolHidden ||
          OcptShotListSelectionCause.arrowRemoved ||
          OcptShotListSelectionCause.none => false,
        };
    if (!arePropsStale) {
      return;
    }

    add(
      OcptShotListFloorPlanPropsLoadRequestedEvent(sequenceId: event.modeState.selectedSequenceId),
    );
  }

  /// Write every pending set name immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one, then has the mode read the floor plans and the
  /// catalogue again and only then forgets them, so what a tab shows never falls back to a stale
  /// stored name between the two. A no-op while nothing is pending.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<OcptPendingWritesStatus> onFlushRequested(
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return OcptPendingWritesStatus.nothingToWrite;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return OcptPendingWritesStatus.ok;
    }

    final written = await _writeAllPendingEdits(project: project, pending: pending);
    if (written.isError) {
      emitter(
        state.copyToFlushFailed(
          pendingFieldEdits: ocptPendingEditsAfterWrite(
            current: state.pendingFieldEdits,
            written: pending,
          ),
        ),
      );
      return OcptPendingWritesStatus.ok;
    }

    await modeBloc.reload({OcptShotListReloadScope.floorPlans, OcptShotListReloadScope.locations});
    emitter(
      state.copyWithFlushedFieldEdits(
        pendingFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingFieldEdits,
          written: pending,
        ),
      ),
    );

    return OcptPendingWritesStatus.ok;
  }

  /// Write every pending set name directly to the database, bypassing the debounce timer, the
  /// bloc's own event queue and its state — for the moments no handler can emit from (the mode
  /// leaving the tree, this bloc closing). A failure is logged here, and leaves the set names to be
  /// written again by the next flush.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final _ = await flushEditsWithoutState(
      pending,
      (edits) => _writeAllPendingEdits(project: project, pending: edits),
    );
  }

  /// Read the breakdown props of sequence `event.sequenceId` and offer them to the palette,
  /// unless the mode has moved to another sequence meanwhile.
  Future<void> _onPropsLoadRequested(
    OcptShotListFloorPlanPropsLoadRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final propsRead = await _loadPropsOfSequence(project: project, sequenceId: event.sequenceId);
    if (propsRead.isError) {
      // The props kept meanwhile belong to another sequence: none is better than a wrong one.
      emitter(state.copyWithSequencePropsCleared());
      return;
    }

    if (modeBloc.state.selectedSequenceId == event.sequenceId) {
      emitter(state.copyWithSequenceProps(props: propsRead.value!));
    }
  }

  /// Get [sequenceId]'s own breakdown props (`OcptElementsService.propsOfScene`), or an empty list
  /// while [sequenceId] is null or names the orphan group, which has no scene of its own to read —
  /// the floor plans palette's own `Sequence` group chips.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<List<OcptScenePropSummary>>> _loadPropsOfSequence({
    required OcptOpenProjectModel project,
    required String? sequenceId,
  }) async {
    if (sequenceId == null) {
      return const OcptDatabaseResult(status: OcptDatabaseStatus.ok, value: []);
    }
    for (final sequence in modeBloc.state.sequences) {
      if (sequence.id == sequenceId && sequence is OcptSceneShotSequence) {
        return _elementsService.propsOfScene(database: project.database, sceneId: sequence.sceneId);
      }
    }
    return const OcptDatabaseResult(status: OcptDatabaseStatus.ok, value: []);
  }

  /// Create a new Resources set named after the selected sequence's own heading place, in
  /// `event.locationId` (or a fresh location of its own, when null), link it to that sequence
  /// (`OcptLocationsService.createSetLinkedToScene`, the breakdown's own path), have the mode read
  /// the floor plans and the Resources catalogue again, and select it. Deliberately a no-op when
  /// the selected sequence is the orphan group (or when nothing is selected at all): see
  /// [OcptShotListSetCreationRequestedEvent].
  Future<void> _onSetCreationRequested(
    OcptShotListSetCreationRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sequence = modeBloc.state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    final created = await _locationsService.createSetLinkedToScene(
      database: project.database,
      sceneId: sequence.sceneId,
      name: ocptSceneHeadingPlaceOf(sequence.heading),
      locationId: event.locationId,
    );
    if (created.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    final setId = created.value;
    if (setId != null) {
      if (await modeBloc.reload({
        OcptShotListReloadScope.floorPlans,
        OcptShotListReloadScope.locations,
        OcptShotListReloadScope.setScopeSymbols,
      })) {
        await addToModeAndWait(OcptShotListSetAddedEvent(setId: setId));
      }
    }
  }

  /// Link Resources set `event.setId` to the selected sequence
  /// (`OcptLocationsService.assignSceneToSet`), have the mode read the floor plans again and select
  /// it — the empty-state gallery's own card click and the `＋ Set` menu's own suggestion/`Link an
  /// existing set ▸` entries. Deliberately a no-op when the selected sequence is the orphan group
  /// (or when nothing is selected at all), exactly like [_onSetCreationRequested].
  Future<void> _onSetLinkRequested(
    OcptShotListSetLinkRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sequence = modeBloc.state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    final linked = await _locationsService.assignSceneToSet(
      database: project.database,
      sceneId: sequence.sceneId,
      setId: event.setId,
    );
    if (linked.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    if (linked.value != null) {
      if (await modeBloc.reload({OcptShotListReloadScope.floorPlans})) {
        await addToModeAndWait(OcptShotListSetAddedEvent(setId: event.setId));
      }
    }
  }

  /// Record the raw text just typed into set `event.setId`'s own tab as a pending edit, and
  /// (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onSetNameChanged(
    OcptShotListSetNameChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final pending = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..[OcptShotListSetNameEditKey(setId: event.setId)] = event.rawValue;
    emitter(state.copyWithTypedFieldEdits(pendingFieldEdits: pending));

    restartDebounce(
      _fieldEditDebounce,
      const OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent(),
    );
  }

  /// Unlink set `event.setId` from the selected sequence
  /// (`OcptLocationsService.removeSceneFromSet`), dispatched once the tab's own close action has
  /// already been confirmed through `OcptConfirmDialog`, by the mode. The plan itself — its
  /// underlay, its symbols, its arrows — is untouched: relinking the same set brings every
  /// placement back. When it was the selected set, the mode selects the sequence's next first set
  /// once it holds the floor plans without it. Drops the name typed into the set's tab.
  Future<void> _onSetDeletionRequested(
    OcptShotListSetDeletionRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sceneId = modeBloc.state.selectedSequenceId;
    if (project == null || sceneId == null) {
      return;
    }

    final wasSelected = modeBloc.state.selectedSetId == event.setId;
    bool isOfSet(OcptShotListPendingEditKey key) =>
        key is OcptShotListSetNameEditKey && key.setId == event.setId;

    // The set's symbols leave the floor plans the mode holds without being deleted: a label
    // typed into one of them is written now, since the views would take it for a deleted
    // symbol's once the mode reads the plans again.
    await modeBloc.flushAllPendingWrites();
    final removed = await _locationsService.removeSceneFromSet(
      database: project.database,
      sceneId: sceneId,
      setId: event.setId,
    );
    if (removed.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    if (await modeBloc.reload({OcptShotListReloadScope.floorPlans})) {
      if (wasSelected) {
        await addToModeAndWait(const OcptShotListSetRemovedEvent());
      }

      emitter(
        state.copyWithUnlinkedSetEdits(
          // Taken now, not before the unlink: a keystroke typed meanwhile is not the set's.
          pendingFieldEdits: Map.of(state.pendingFieldEdits)..removeWhere((key, _) => isOfSet(key)),
        ),
      );
    }
  }

  /// Duplicate set `event.setId` into a new Resources set in the same location, named
  /// `event.newSetName`, copying its set-scope symbols only and linking it to the selected
  /// sequence — the set tabs' own `＋ Set` menu `Duplicate this set` entry, **one** atomic call
  /// (`OcptLocationsService.duplicateSetForScene`) that rules out an orphan set. Has the mode read
  /// the floor plans and the catalogue again and selects the freshly minted copy.
  Future<void> _onSetDuplicationRequested(
    OcptShotListSetDuplicationRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final sceneId = modeBloc.state.selectedSequenceId;
    if (project == null || sceneId == null) {
      return;
    }

    final duplicated = await _locationsService.duplicateSetForScene(
      database: project.database,
      sourceSetId: event.setId,
      name: event.newSetName,
      sceneId: sceneId,
    );
    if (duplicated.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    final newSetId = duplicated.value;
    if (newSetId != null) {
      if (await modeBloc.reload({
        OcptShotListReloadScope.floorPlans,
        OcptShotListReloadScope.locations,
        OcptShotListReloadScope.setScopeSymbols,
      })) {
        await addToModeAndWait(OcptShotListSetAddedEvent(setId: newSetId));
      }
    }
  }

  /// Copy shot `event.sourceShotId`'s own live blocking on set `event.setId` onto the currently
  /// focused shot (`OcptFloorPlanService.copyShotBlocking`), then have the mode read the floor
  /// plans again — the set tabs' own `＋ Set` menu `Copy blocking from another shot` entry,
  /// dispatched once the mode's own source-shot picker returns a pick. A no-op while no shot is
  /// focused (defensive only: the mode never offers the menu entry without one).
  Future<void> _onBlockingCopyRequested(
    OcptShotListFloorPlanBlockingCopyRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final destinationShotId = modeBloc.state.selectedShotId;
    if (project == null || destinationShotId == null) {
      return;
    }

    final copied = await _floorPlanService.copyShotBlocking(
      database: project.database,
      sourceSetId: event.setId,
      sourceShotId: event.sourceShotId,
      destinationSetId: event.setId,
      destinationShotId: destinationShotId,
    );
    if (copied.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    await modeBloc.reload({OcptShotListReloadScope.floorPlans});
  }

  /// Record the floor plans canvas's own zoom as last settled by
  /// `OcptFloorPlanViewportController`. A view preference; see
  /// `OcptShotListFloorPlanSetsState.floorPlanZoom`'s own doc comment.
  Future<void> _onZoomChanged(
    OcptShotListFloorPlanZoomChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithZoom(zoom: event.zoom));
  }

  /// Pick the sequence layer a placed set element lands on. A view preference.
  Future<void> _onActiveLayerChanged(
    OcptShotListFloorPlanActiveLayerChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithActiveLayer(layer: event.layer));
  }

  /// Pick the décor primitive a `setElement` placement carries. A view preference.
  Future<void> _onActiveSetElementShapeChanged(
    OcptShotListFloorPlanActiveSetElementShapeChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithActiveSetElementShape(shape: event.shape));
  }

  /// Pick the scope a `setElement` placement lands at. A view preference.
  Future<void> _onActiveSetElementScopeChanged(
    OcptShotListFloorPlanActiveSetElementScopeChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithActiveSetElementScope(scope: event.scope));
  }

  /// Pick the label a `prop` placement carries. A view preference.
  Future<void> _onActiveLabelChanged(
    OcptShotListFloorPlanActiveLabelChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithActiveLabel(label: event.label));
  }

  /// Toggle the visibility of sequence layer `event.layer` on the floor plans canvas. A view
  /// preference; never withheld under a read-only preview, since it only reads.
  Future<void> _onLayerVisibilityToggled(
    OcptShotListFloorPlanLayerVisibilityToggledEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final hidden = Set<OcptFloorPlanLayer>.of(state.floorPlanHiddenLayers);
    if (!hidden.remove(event.layer)) {
      hidden.add(event.layer);
    }
    emitter(state.copyWithHiddenLayers(hiddenLayers: hidden));
  }

  /// Toggle the selected set's underlay visibility on the floor plans canvas. A view preference;
  /// never withheld under a read-only preview.
  Future<void> _onUnderlayVisibilityToggled(
    OcptShotListFloorPlanUnderlayVisibilityToggledEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithUnderlayVisibilityToggled());
  }

  /// Pick a file through the native "open" dialog, filtered to JPEG and PNG
  /// (`ocptFloorPlanUnderlayImageFileExtensions`), and set set `event.setId`'s underlay to it,
  /// framed at a default rectangle centred on the canvas ([_defaultUnderlayXM]/…): the user drags
  /// and resizes it afterwards to match the reference silhouette (ADR 0031). A cancelled dialog
  /// changes nothing at all.
  Future<void> _onUnderlayImportRequested(
    OcptShotListFloorPlanUnderlayImportRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final path = await _pickUnderlayPath(fileTypeLabel: event.fileTypeLabel);
    if (path == null) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final imported = await _floorPlanService.setSetUnderlay(
      database: project.database,
      setId: event.setId,
      path: path,
      xM: _defaultUnderlayXM,
      yM: _defaultUnderlayYM,
      widthM: _defaultUnderlayWidthM,
      heightM: _defaultUnderlayHeightM,
    );
    if (imported.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    await modeBloc.reload({OcptShotListReloadScope.floorPlans});
  }

  /// Show the native "open" dialog filtered to [ocptFloorPlanUnderlayImageFileExtensions] and
  /// return the path picked, or null when the user cancelled it, when it failed, or when the
  /// platform gave a file with no path at all. The underlay's own sibling of
  /// `OcptShotListStoryboardBloc`'s panel frame picker.
  Future<String?> _pickUnderlayPath({required String fileTypeLabel}) async {
    final fileSelectorManager = _fileSelectorManager ?? globalGetIt().get<FileSelectorManager>();

    final selection = await fileSelectorManager.openSelector(
      allowedExtensions: ocptFloorPlanUnderlayImageFileExtensions,
      label: fileTypeLabel,
    );

    final file = selection.value;
    if (!selection.status.isSuccess || file == null) {
      return null;
    }

    return file.path.isEmpty ? null : file.path;
  }

  /// Re-frame set `event.setId`'s underlay to `event.xM`/`event.yM`/`event.widthM`/
  /// `event.heightM`, dispatched once a drag moving or resizing it ends.
  /// `OcptFloorPlanService.updateUnderlayFrame` — never `setSetUnderlay`, which would tombstone
  /// and re-mint the underlay's own `assets` row on every drag-end — is the one write this touches;
  /// its own current rotation is left alone, since no underlay rotate handle exists.
  /// A no-op while the set carries no underlay at all (nothing to move).
  Future<void> _onUnderlayTransformChanged(
    OcptShotListFloorPlanUnderlayTransformChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final floorPlanSet = modeBloc.state.floorPlanSnapshot?.setsById[event.setId];
    if (floorPlanSet?.underlayAssetId == null) {
      return;
    }

    final reframed = await _floorPlanService.updateUnderlayFrame(
      database: project.database,
      setId: event.setId,
      xM: Value(event.xM),
      yM: Value(event.yM),
      widthM: Value(event.widthM),
      heightM: Value(event.heightM),
    );
    if (reframed.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    await modeBloc.reload({OcptShotListReloadScope.floorPlans});
  }

  /// Clear set `event.setId`'s underlay for good, dispatched once the tray's own `Clear underlay`
  /// underlay` action has already been confirmed through `OcptConfirmDialog`, by the mode.
  Future<void> _onUnderlayClearRequested(
    OcptShotListFloorPlanUnderlayClearRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final cleared = await _floorPlanService.clearSetUnderlay(
      database: project.database,
      setId: event.setId,
    );
    if (cleared.isError) {
      emitter(state.copyToWriteFailed());
      return;
    }

    await modeBloc.reload({OcptShotListReloadScope.floorPlans});
  }

  /// Walk the selected sequence's own shots by `event.delta`, dispatched by the floor plans focus
  /// strip's own `←`/`→` keyboard shortcut: see [OcptShotListFloorPlanShotWalkRequestedEvent]'s own
  /// doc comment for the full rule. Walking to a neighbour is exactly selecting it, which the mode
  /// does (`OcptShotListShotSelectedEvent`): this only works out which shot that is.
  Future<void> _onShotWalkRequested(
    OcptShotListFloorPlanShotWalkRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final modeState = modeBloc.state;
    final sequence = modeState.selectedSequence;
    if (sequence is! OcptSceneShotSequence || sequence.shots.isEmpty) {
      return;
    }

    final selectedShotId = modeState.selectedShotId;
    if (selectedShotId == null) {
      if (event.delta > 0) {
        await addToModeAndWait(OcptShotListShotSelectedEvent(shotId: sequence.shots.first.id));
      }
      return;
    }

    final neighbour = event.delta < 0
        ? modeState.previousShotOfSelectedShot
        : modeState.nextShotOfSelectedShot;
    if (neighbour == null) {
      return;
    }

    await addToModeAndWait(OcptShotListShotSelectedEvent(shotId: neighbour.id));
  }

  /// Toggle the visibility of camera symbol `event.symbolId` on the floor plans canvas. A view
  /// preference; never withheld under a read-only preview, since it only reads.
  Future<void> _onCameraVisibilityToggled(
    OcptShotListFloorPlanCameraVisibilityToggledEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final hidden = Set<String>.of(state.floorPlanHiddenCameraSymbolIds);
    if (!hidden.remove(event.symbolId)) {
      hidden.add(event.symbolId);
    }
    emitter(state.copyWithHiddenCameraSymbols(symbolIds: hidden));
  }

  /// Toggle the onion skin's own previous or next ghost. A view preference.
  Future<void> _onOnionSkinToggled(
    OcptShotListFloorPlanOnionSkinToggledEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithOnionSkinToggled(isPrevious: event.isPrevious));
  }

  /// Set the onion skin's own ghost opacity, clamped to a visible range. A view preference.
  Future<void> _onOnionSkinOpacityChanged(
    OcptShotListFloorPlanOnionSkinOpacityChangedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithOnionSkinOpacity(opacity: event.opacity.clamp(0.05, 1.0)));
  }

  /// Toggle the metrics overlay. A view preference.
  Future<void> _onMetricsToggled(
    OcptShotListFloorPlanMetricsToggledEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithMetricsToggled());
  }

  /// Dismiss the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListFloorPlanSetsWriteErrorDismissedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    emitter(state.copyWithWriteErrorDismissed());
  }

  /// Write every pending set name once the debounce elapses with no further typing.
  ///
  /// When something was written and the `Versions` tab is the one showing, also asks the mode to
  /// refresh its working-copy card, as the mode itself does when a flush it runs lands.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListFloorPlanSetsState> emitter,
  ) async {
    final status = await onFlushRequested(emitter);

    if (status == OcptPendingWritesStatus.ok &&
        modeBloc.state.rightDockTab == OcptShotListRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Write every entry of [pending] through `OcptLocationsService.updateSet`.
  ///
  /// Stops at the first write that fails and answers its failure; the entries after it are not
  /// written.
  @useResult
  Future<OcptDatabaseOutcome> _writeAllPendingEdits({
    required OcptOpenProjectModel project,
    required Map<OcptShotListPendingEditKey, String> pending,
  }) async {
    for (final entry in pending.entries) {
      switch (entry.key) {
        case OcptShotListSetNameEditKey(:final setId):
          final written = await _locationsService.updateSet(
            database: project.database,
            setId: setId,
            name: Value(entry.value),
          );
          if (written.isError) {
            return written;
          }
        case OcptShotListShotFieldEditKey() ||
            OcptShotListPanelCommentEditKey() ||
            OcptShotListAnnotationTextEditKey() ||
            OcptShotListSymbolLabelEditKey():
          // The other kinds of edit belong to other blocs and are never recorded here.
          break;
      }
    }

    return const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok);
  }
}
