// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_list_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';

/// This is the bloc class for the shot list mode's Placements group: the inspector's list of the
/// selected shot's symbols and arrows on the selected set, and the actions it offers on them.
///
/// The symbols and the arrows are the mode's data, in `OcptShotListState.floorPlanSnapshot`. This
/// bloc owns the writes that act on a placement: deleting a symbol or an arrow, deleting a symbol
/// everywhere, masking it for one sequence or one shot, restoring an override, a camera's field of
/// view and reach, and the label typed in place on the canvas, held in the pending map
/// ([OcptShotListFloorPlanPlacementsState.pendingFieldEdits]) and written
/// [OcptShotListBloc.defaultFieldEditDebounce] after the last keystroke; the mode flushes it ahead
/// of anything that needs the database to be up to date.
///
/// **Writing.** A write calls [OcptFloorPlanService], then waits for the mode to read the floor
/// plans again. A write that removes or masks a placement asks the mode to do that **and** move its
/// selection (`OcptShotListFloorPlanPlacementChangedEvent`), saying which row it was, and waits for
/// it: the canvas bloc, which this bloc does not know, then clears the selection exactly as the
/// gesture always cleared it. A field of view is written without moving the selection, which it
/// never cleared.
///
/// **Reacting.** When the mode reads the floor plans again, the labels typed for a symbol that is
/// no longer there are dropped. Nothing here depends on the mode's selection.
class OcptShotListFloorPlanPlacementsBloc
    extends
        AbsOcptViewBloc<OcptShotListFloorPlanPlacementsState, OcptShotListState, OcptShotListBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_floor_plan_placements_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to write the symbols and the arrows of the floor plans.
  final OcptFloorPlanService _floorPlanService;

  /// The delay between the last symbol label edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// {@macro open_cine_prod_tools.viewBlocConstructorWithDebounce}
  OcptShotListFloorPlanPlacementsBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptFloorPlanService? floorPlanService,
    Duration fieldEditDebounce = OcptShotListBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _floorPlanService =
           floorPlanService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).floorPlanService,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptShotListFloorPlanPlacementsState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListFloorPlanSymbolDeletionRequestedEvent>(_onSymbolDeletionRequested);
    on<OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent>(
      _onSymbolDeleteEverywhereRequested,
    );
    on<OcptShotListFloorPlanSymbolHideRequestedEvent>(_onSymbolHideRequested);
    on<OcptShotListFloorPlanSymbolHideForShotRequestedEvent>(_onSymbolHideForShotRequested);
    on<OcptShotListFloorPlanSymbolRestoreRequestedEvent>(_onSymbolRestoreRequested);
    on<OcptShotListFloorPlanArrowDeletionRequestedEvent>(_onArrowDeletionRequested);
    on<OcptShotListFloorPlanSymbolLabelChangedEvent>(_onSymbolLabelChanged);
    on<OcptShotListFloorPlanSymbolFovChangedEvent>(_onSymbolFovChanged);
    on<OcptShotListFloorPlanSymbolFovReachChangedEvent>(_onSymbolFovReachChanged);
    on<OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent>(_onWriteErrorDismissed);
  }

  /// Drop the labels typed for a symbol the mode's fresh floor plans no longer hold, and stop
  /// the debounce when none is left. Waits for nothing.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptShotListState> event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final floorPlanSnapshot = modeBloc.state.floorPlanSnapshot;
    if (!event.hasReloaded || floorPlanSnapshot == null || state.pendingFieldEdits.isEmpty) {
      return;
    }

    final symbolIds = {
      for (final floorPlanSet in floorPlanSnapshot.setsById.values)
        for (final symbol in floorPlanSet.symbols) symbol.id,
    };
    final pending = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..removeWhere(
        (key, _) => switch (key) {
          OcptShotListSymbolLabelEditKey(:final symbolId) => !symbolIds.contains(symbolId),
          OcptShotListShotFieldEditKey() => false,
          OcptShotListPanelCommentEditKey() => false,
          OcptShotListAnnotationTextEditKey() => false,
          OcptShotListSetNameEditKey() => false,
        },
      );
    if (pending.length == state.pendingFieldEdits.length) {
      return;
    }

    if (pending.isEmpty) {
      cancelDebounce();
    }
    emitter(state.copyWithPrunedFieldEdits(pendingFieldEdits: pending));
  }

  /// Write every pending symbol label immediately: cancels the debounce timer (a no-op if it
  /// already fired or there was none), writes each one, then has the mode read the floor plans
  /// again and only then forgets what was written, so what a label shows never falls back to a
  /// stale stored value between the two. A no-op while nothing is pending.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<OcptPendingWritesStatus> onFlushRequested(
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
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

    try {
      await _writeAllPendingEdits(project: project, pending: pending);
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
      emitter(
        state.copyWithFlushedFieldEdits(
          pendingFieldEdits: ocptPendingEditsAfterWrite(
            current: state.pendingFieldEdits,
            written: pending,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending symbol label of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyToFlushFailed(
          pendingFieldEdits: ocptPendingEditsAfterWrite(
            current: state.pendingFieldEdits,
            written: pending,
          ),
        ),
      );
    }

    return OcptPendingWritesStatus.ok;
  }

  /// Write every pending symbol label directly to the database, bypassing the debounce timer, the
  /// bloc's own event queue and its state — for the moments no handler can emit from (the mode
  /// leaving the tree, this bloc closing). A failure is only logged.
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

    try {
      await flushEditsWithoutStateUntilConverted(
        pending,
        (edits) => _writeAllPendingEdits(project: project, pending: edits),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending symbol label of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Delete symbol `event.symbolId` for good, dispatched once the canvas's own delete action has
  /// already been confirmed through `OcptConfirmDialog`, by the mode. The canvas bloc drops its
  /// selection of the symbol, and of the arrow, once the mode says the symbol was removed.
  Future<void> _onSymbolDeletionRequested(
    OcptShotListFloorPlanSymbolDeletionRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.deleteSymbol(database: project.database, symbolId: event.symbolId);
      await addToModeAndWait(
        OcptShotListFloorPlanPlacementChangedEvent(
          cause: OcptShotListSelectionCause.symbolRemoved,
          targetId: event.symbolId,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Delete set-scope symbol `event.symbolId` **everywhere** — itself (or, when it names a
  /// scene-scope override, the set-scope original it overrides) and every live override of it, in
  /// every sequence (`OcptFloorPlanService.deleteSymbolEverywhere`) — the destructive branch of the
  /// extended delete confirmation, dispatched once it has already been confirmed through
  /// `OcptConfirmDialog.showWithAlternative`, by the mode.
  Future<void> _onSymbolDeleteEverywhereRequested(
    OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.deleteSymbolEverywhere(
        database: project.database,
        symbolId: event.symbolId,
      );
      await addToModeAndWait(
        OcptShotListFloorPlanPlacementChangedEvent(
          cause: OcptShotListSelectionCause.symbolRemoved,
          targetId: event.symbolId,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete symbol ${event.symbolId} everywhere, of "
        "project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Mask set-scope symbol `event.symbolId` for sequence `event.targetSceneId` alone — a hidden
  /// override, setting `isHidden` on one that already exists or creating one copied from the
  /// original's own geometry — the alternative branch ("Remove from sequence n") of the extended
  /// delete confirmation, dispatched once it has already been confirmed through
  /// `OcptConfirmDialog.showWithAlternative`, by the mode.
  Future<void> _onSymbolHideRequested(
    OcptShotListFloorPlanSymbolHideRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final floorPlanSnapshot = modeBloc.state.floorPlanSnapshot;
    final selected = ocptFloorPlanSymbolById(
      floorPlanSnapshot: floorPlanSnapshot,
      symbolId: event.symbolId,
    );
    if (selected == null) {
      return;
    }
    final originalId = selected.overridesSymbolId ?? selected.id;
    final original = ocptFloorPlanSymbolById(
      floorPlanSnapshot: floorPlanSnapshot,
      symbolId: originalId,
    );
    if (original == null) {
      return;
    }

    final existingOverride = floorPlanSnapshot?.setsById[selected.setId]?.symbols.firstWhereOrNull(
      (symbol) => symbol.overridesSymbolId == originalId && symbol.sceneId == event.targetSceneId,
    );

    try {
      await _floorPlanService.hideSymbolForScope(
        database: project.database,
        original: original,
        existingOverride: existingOverride,
        sceneId: event.targetSceneId,
        shotId: null,
      );
      await addToModeAndWait(
        OcptShotListFloorPlanPlacementChangedEvent(
          cause: OcptShotListSelectionCause.symbolHidden,
          targetId: event.symbolId,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to hide symbol ${event.symbolId} for sequence "
        "${event.targetSceneId} of project ${project.primaryScreenplayId}: "
        "${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Mask scene-scope symbol `event.symbolId` for shot `event.targetShotId` alone — a hidden
  /// shot-scope override, mirroring [_onSymbolHideRequested] one level down: setting `isHidden` on
  /// one that already exists or creating one copied from the scene symbol's own geometry — the
  /// alternative branch ("Remove from shot n") of the shot-level extended delete confirmation.
  Future<void> _onSymbolHideForShotRequested(
    OcptShotListFloorPlanSymbolHideForShotRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final floorPlanSnapshot = modeBloc.state.floorPlanSnapshot;
    final selected = ocptFloorPlanSymbolById(
      floorPlanSnapshot: floorPlanSnapshot,
      symbolId: event.symbolId,
    );
    if (selected == null) {
      return;
    }
    // Only resolve "up" through `overridesSymbolId` when `selected` is itself a shot-scope
    // override — a scene-scope symbol's own `overridesSymbolId` (if any) names a *different*
    // level's original (a set-scope one) and is never followed here.
    final originalId = selected.shotId != null
        ? (selected.overridesSymbolId ?? selected.id)
        : selected.id;
    final original = ocptFloorPlanSymbolById(
      floorPlanSnapshot: floorPlanSnapshot,
      symbolId: originalId,
    );
    if (original == null) {
      return;
    }

    final existingOverride = floorPlanSnapshot?.setsById[selected.setId]?.symbols.firstWhereOrNull(
      (symbol) => symbol.overridesSymbolId == originalId && symbol.shotId == event.targetShotId,
    );

    try {
      await _floorPlanService.hideSymbolForScope(
        database: project.database,
        original: original,
        existingOverride: existingOverride,
        sceneId: null,
        shotId: event.targetShotId,
      );
      await addToModeAndWait(
        OcptShotListFloorPlanPlacementChangedEvent(
          cause: OcptShotListSelectionCause.symbolHidden,
          targetId: event.symbolId,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to hide symbol ${event.symbolId} for shot "
        "${event.targetShotId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Restore scene-scope override `event.symbolId` as in the set — tombstones it, so its own
  /// set-scope original reappears for that sequence. Reversible: never asks.
  Future<void> _onSymbolRestoreRequested(
    OcptShotListFloorPlanSymbolRestoreRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.deleteSymbol(database: project.database, symbolId: event.symbolId);
      await addToModeAndWait(
        OcptShotListFloorPlanPlacementChangedEvent(
          cause: OcptShotListSelectionCause.symbolRemoved,
          targetId: event.symbolId,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to restore override ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Delete arrow `event.arrowId` for good, dispatched once the Placements group's own remove
  /// action has already been confirmed through `OcptConfirmDialog`, by the mode. The canvas bloc
  /// drops its selection of the arrow if it was the selected one.
  Future<void> _onArrowDeletionRequested(
    OcptShotListFloorPlanArrowDeletionRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.deleteArrow(database: project.database, arrowId: event.arrowId);
      await addToModeAndWait(
        OcptShotListFloorPlanPlacementChangedEvent(
          cause: OcptShotListSelectionCause.arrowRemoved,
          targetId: event.arrowId,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete arrow ${event.arrowId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Record the raw text just typed into symbol `event.symbolId`'s own label as a pending edit,
  /// visible immediately, and (re)starts the field-edit debounce.
  Future<void> _onSymbolLabelChanged(
    OcptShotListFloorPlanSymbolLabelChangedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final pending = Map<OcptShotListPendingEditKey, String>.of(state.pendingFieldEdits)
      ..[OcptShotListSymbolLabelEditKey(symbolId: event.symbolId)] = event.rawValue;
    emitter(state.copyWithTypedFieldEdits(pendingFieldEdits: pending));

    restartDebounce(
      _fieldEditDebounce,
      const OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent(),
    );
  }

  /// Set camera symbol `event.symbolId`'s own field-of-view wedge to `event.fovDeg`, dispatched by
  /// a drag on one of its own edge handles ending, or by the inspector's own Placements group
  /// `−`/`+` stepper. Written immediately, one row (`OcptFloorPlanService.updateSymbol(fovDeg:)`).
  Future<void> _onSymbolFovChanged(
    OcptShotListFloorPlanSymbolFovChangedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        fovDeg: Value(event.fovDeg),
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the field of view of symbol ${event.symbolId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Set camera symbol `event.symbolId`'s own field-of-view wedge reach to `event.fovReachM`,
  /// dispatched by a drag on its own tip handle ending. Written immediately
  /// (`OcptFloorPlanService.updateSymbol(fovReachM:)`), one row.
  Future<void> _onSymbolFovReachChanged(
    OcptShotListFloorPlanSymbolFovReachChangedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        fovReachM: Value(event.fovReachM),
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to change the field-of-view reach of symbol "
        "${event.symbolId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyToWriteFailed());
    }
  }

  /// Dismiss the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    emitter(state.copyWithWriteErrorDismissed());
  }

  /// Write every pending symbol label once the debounce elapses with no further typing.
  ///
  /// When something was written and the `Versions` tab is the one showing, also asks the mode to
  /// refresh its working-copy card.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListFloorPlanPlacementsState> emitter,
  ) async {
    final status = await onFlushRequested(emitter);

    if (status == OcptPendingWritesStatus.ok &&
        modeBloc.state.rightDockTab == OcptShotListRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Write every entry of [pending] through `OcptFloorPlanService.updateSymbol`.
  Future<void> _writeAllPendingEdits({
    required OcptOpenProjectModel project,
    required Map<OcptShotListPendingEditKey, String> pending,
  }) async {
    for (final entry in pending.entries) {
      switch (entry.key) {
        case OcptShotListSymbolLabelEditKey(:final symbolId):
          await _floorPlanService.updateSymbol(
            database: project.database,
            symbolId: symbolId,
            label: Value(entry.value),
          );
        case OcptShotListShotFieldEditKey() ||
            OcptShotListPanelCommentEditKey() ||
            OcptShotListAnnotationTextEditKey() ||
            OcptShotListSetNameEditKey():
          // The other kinds of edit belong to other blocs and are never recorded here.
          break;
      }
    }
  }
}
