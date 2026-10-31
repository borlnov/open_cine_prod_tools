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
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_list_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';

/// This is the bloc class for the shot list mode's floor plan canvas: the gestures made on the
/// plan itself.
///
/// The sets, the symbols and the arrows are the mode's data, in
/// `OcptShotListState.floorPlanSnapshot`. This bloc owns what the canvas does with them: the tool
/// in hand, which symbol or arrow is selected, the first end of the arrow being drawn, the scope
/// question a move, a resize or a rotation of a shared symbol asks, the name prompt a freshly
/// placed character asks for, and the writes those gestures make — placing, moving, resizing,
/// rotating and duplicating a symbol, drawing and bending an arrow, resolving the scope question.
///
/// **Writing.** A write calls [OcptFloorPlanService], then waits for the mode to read the floor
/// plans again (`OcptShotListBloc.reload`), and only then emits the canvas's own state: the mode's
/// state already holds the symbol this bloc is about to select, so no widget ever sees a
/// selection naming a symbol the data does not have. A gesture is written when it ends, never per
/// frame: nothing here waits on the mode while a drag is going on.
///
/// **Reacting.** When the mode moves its selection this bloc clears what was scoped to the
/// previous one, as the mode bloc itself did before the canvas had a bloc of its own: a different
/// sequence clears the symbol, the arrow, the anchor and the scope question; a shot selected or
/// deleted, a set selected, added or removed, and a fresh load clear the symbol, the arrow and the
/// anchor; selecting the sequence already shown clears the anchor alone; creating a shot clears
/// nothing. A placement removed or masked from the Placements group clears the arrow with a deleted
/// symbol, and the selected symbol or arrow only when it is the row concerned (the mode's
/// `selectionTargetId`). When the mode reads its data again, a selected symbol or arrow that is gone, or a
/// selected symbol that a hidden override now masks where the canvas looks, is dropped. The scope question and
/// the character prompt are never touched by a reload.
class OcptShotListFloorPlanCanvasBloc
    extends AbsOcptViewBloc<OcptShotListFloorPlanCanvasState, OcptShotListState, OcptShotListBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_floor_plan_canvas_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to write the symbols and the arrows of the floor plans.
  final OcptFloorPlanService _floorPlanService;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  OcptShotListFloorPlanCanvasBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptFloorPlanService? floorPlanService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _floorPlanService =
           floorPlanService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).floorPlanService,
       super(const OcptShotListFloorPlanCanvasState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListFloorPlanToolSelectedEvent>(_onToolSelected);
    on<OcptShotListFloorPlanSymbolPlacedEvent>(_onSymbolPlaced);
    on<OcptShotListFloorPlanSymbolSelectedEvent>(_onSymbolSelected);
    on<OcptShotListFloorPlanSymbolMovedEvent>(_onSymbolMoved);
    on<OcptShotListFloorPlanSymbolResizedEvent>(_onSymbolResized);
    on<OcptShotListFloorPlanSymbolRotatedEvent>(_onSymbolRotated);
    on<OcptShotListFloorPlanScopeDecisionRequestedEvent>(_onScopeDecisionRequested);
    on<OcptShotListFloorPlanScopeDecisionResolvedEvent>(_onScopeDecisionResolved);
    on<OcptShotListFloorPlanArrowSymbolTappedEvent>(_onArrowSymbolTapped);
    on<OcptShotListFloorPlanArrowAnchorCancelledEvent>(_onArrowAnchorCancelled);
    on<OcptShotListFloorPlanArrowSelectedEvent>(_onArrowSelected);
    on<OcptShotListFloorPlanArrowCurveChangedEvent>(_onArrowCurveChanged);
    on<OcptShotListFloorPlanSymbolDuplicatedEvent>(_onSymbolDuplicated);
    on<OcptShotListFloorPlanCharacterNamePromptDismissedEvent>(_onCharacterNamePromptDismissed);
    on<OcptShotListFloorPlanCanvasWriteErrorDismissedEvent>(_onWriteErrorDismissed);
  }

  /// Clears what the mode's selection move invalidates, and drops what the mode's fresh data no
  /// longer holds.
  ///
  /// Reads the floor plans from [modeBloc]'s current state — the latest data — but the cause of
  /// the selection move from the state that moved it (`event.modeState`), so two quick moves are
  /// each reacted to for what they were. Waits for nothing: the mode's change and this reaction
  /// must land in the same turn of the event loop, or a frame could draw a selection that names a
  /// symbol of the previous shot.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptShotListState> event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final targetId = event.modeState.selectionTargetId;
    final selectedSymbolId = state.selectedFloorPlanSymbolId;
    final selectedArrowId = state.selectedFloorPlanArrowId;
    final (
      isSymbolCleared,
      isArrowCleared,
      isAnchorCleared,
      isDecisionCleared,
    ) = !event.hasSelectionMoved
        ? (false, false, false, false)
        : switch (event.modeState.selectionCause) {
            // A different sequence takes everything scoped to the previous one with it.
            OcptShotListSelectionCause.sequence => (true, true, true, true),
            // The sequence already shown, selected again: only the half-drawn arrow is dropped.
            OcptShotListSelectionCause.sequenceReselected => (false, false, true, false),
            OcptShotListSelectionCause.shot ||
            OcptShotListSelectionCause.shotDeleted ||
            OcptShotListSelectionCause.set ||
            OcptShotListSelectionCause.setAdded ||
            OcptShotListSelectionCause.setRemoved ||
            OcptShotListSelectionCause.load => (true, true, true, false),
            // A symbol deleted or restored drops the selection if it was the symbol, and always the
            // arrow: deleting a symbol cascades to every arrow touching it.
            OcptShotListSelectionCause.symbolRemoved => (
              selectedSymbolId == targetId,
              true,
              false,
              false,
            ),
            // A symbol masked drops the selection, arrow included, only if it was the symbol.
            OcptShotListSelectionCause.symbolHidden => (
              selectedSymbolId == targetId,
              selectedSymbolId == targetId,
              false,
              false,
            ),
            // An arrow deleted drops the selection only if it was the arrow.
            OcptShotListSelectionCause.arrowRemoved => (
              false,
              selectedArrowId == targetId,
              false,
              false,
            ),
            // Creating a shot selects it without clearing the canvas: it has always behaved so,
            // and it is kept as it is.
            OcptShotListSelectionCause.shotCreated ||
            OcptShotListSelectionCause.none => (false, false, false, false),
          };

    final modeState = modeBloc.state;
    final floorPlanSnapshot = modeState.floorPlanSnapshot;
    var isSymbolGone = false;
    var isArrowGone = false;
    if (event.hasReloaded && floorPlanSnapshot != null) {
      isSymbolGone =
          selectedSymbolId != null &&
          (ocptFloorPlanSymbolById(
                    floorPlanSnapshot: floorPlanSnapshot,
                    symbolId: selectedSymbolId,
                  ) ==
                  null ||
              ocptIsFloorPlanSymbolMaskedAt(
                floorPlanSnapshot: floorPlanSnapshot,
                symbolId: selectedSymbolId,
                sceneId: modeState.selectedSequenceId,
                shotId: modeState.selectedShotId,
              ));
      isArrowGone =
          selectedArrowId != null &&
          !ocptFloorPlanArrowExists(floorPlanSnapshot: floorPlanSnapshot, arrowId: selectedArrowId);
    }

    emitter(
      state.copyWith(
        forceSelectedFloorPlanSymbolIdValue: isSymbolCleared || isSymbolGone,
        // The arrow goes with the symbol: the two are never selected together.
        forceSelectedFloorPlanArrowIdValue:
            isArrowCleared || isSymbolCleared || isSymbolGone || isArrowGone,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: isAnchorCleared,
        forcePendingFloorPlanScopeDecisionValue: isDecisionCleared,
      ),
    );
  }

  /// Picks the floor plans canvas's own active tool. A view preference.
  ///
  /// Clears the arrow tool's own pending anchor whenever a different tool is picked: leaving the
  /// arrow tool abandons whatever first click was still waiting for its second.
  Future<void> _onToolSelected(
    OcptShotListFloorPlanToolSelectedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    emitter(
      state.copyWith(
        floorPlanActiveTool: event.tool,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: event.tool != OcptFloorPlanTool.arrow,
      ),
    );
  }

  /// Places a new symbol on set `event.setId`'s `event.layer`, at `event.xM`/`event.yM`, carrying
  /// `event.setElementShape` on a décor placement, then selects it once the mode holds it
  /// (`OcptFloorPlanService.placeSymbol`). Written immediately.
  ///
  /// `event.shotId` is null on a sequence layer (the `setElement` tool) and the focused shot's id
  /// on a shot layer (the `camera`/`character`/`light` tools), exactly what the canvas resolves
  /// from its own active tool before dispatching this — see `OcptFloorPlanCanvas`'s own doc
  /// comment. A freshly placed character symbol's own `ocptDefaultCharacterLabelOf` pre-fills its
  /// label from the shot's own characters field, the mock-up's "offered first as a convenience"
  /// — never a link, the placed symbol still carries no `roleId`
  /// — and also arms [OcptShotListFloorPlanCanvasState.pendingCharacterNamePromptSymbolId], so the
  /// mode opens `OcptFloorPlanCharacterNamePickerDialog` for it the moment placement lands,
  /// pre-filled with that very default and offering the shot's other characters too, letting the
  /// user confirm or change it on the spot rather than only through the inline label editor later.
  Future<void> _onSymbolPlaced(
    OcptShotListFloorPlanSymbolPlacedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final modeState = modeBloc.state;
    final shotId = event.shotId;
    final label = event.layer == OcptFloorPlanLayer.characters && shotId != null
        ? ocptDefaultCharacterLabelOf(
            shot: modeState.snapshot?.shotsById[shotId],
            floorPlanSet: modeState.floorPlanSnapshot?.setsById[event.setId],
          )
        : event.label;

    try {
      final symbolId = await _floorPlanService.placeSymbol(
        database: project.database,
        setId: event.setId,
        sceneId: event.sceneId,
        shotId: shotId,
        layer: event.layer,
        xM: event.xM,
        yM: event.yM,
        label: label,
        setElementShape: event.setElementShape,
      );
      if (symbolId == null) {
        return;
      }

      final isCharacter = event.layer == OcptFloorPlanLayer.characters && shotId != null;
      if (!await modeBloc.reload({OcptShotListReloadScope.floorPlans})) {
        return;
      }
      emitter(
        state.copyWith(
          selectedFloorPlanSymbolId: symbolId,
          forceSelectedFloorPlanArrowIdValue: true,
          pendingCharacterNamePromptSymbolId: isCharacter ? symbolId : null,
          forcePendingCharacterNamePromptSymbolIdValue: !isCharacter,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to place a ${event.layer} symbol on set ${event.setId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Selects symbol `event.symbolId`, or clears the selection when it is null. Also clears the
  /// arrow selection when a symbol actually gets selected: the two are mutually exclusive on the
  /// canvas.
  Future<void> _onSymbolSelected(
    OcptShotListFloorPlanSymbolSelectedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final symbolId = event.symbolId;
    emitter(
      state.copyWith(
        selectedFloorPlanSymbolId: symbolId,
        forceSelectedFloorPlanSymbolIdValue: symbolId == null,
        forceSelectedFloorPlanArrowIdValue: symbolId != null,
      ),
    );
  }

  /// Moves symbol `event.symbolId` to `event.xM`/`event.yM`, writing exactly one row, dispatched
  /// once a drag on it ends.
  Future<void> _onSymbolMoved(
    OcptShotListFloorPlanSymbolMovedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        xM: Value(event.xM),
        yM: Value(event.yM),
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to move symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Resizes symbol `event.symbolId` to `event.widthM`/`event.heightM`, writing exactly one row,
  /// dispatched once a drag on its own resize handle ends.
  Future<void> _onSymbolResized(
    OcptShotListFloorPlanSymbolResizedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        widthM: Value(event.widthM),
        heightM: Value(event.heightM),
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to resize symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Rotates symbol `event.symbolId` to `event.rotationDeg`, writing exactly one row, dispatched
  /// once a drag on its own rotate handle ends.
  Future<void> _onSymbolRotated(
    OcptShotListFloorPlanSymbolRotatedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateSymbol(
        database: project.database,
        symbolId: event.symbolId,
        rotationDeg: Value(event.rotationDeg),
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to rotate symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Stores the pending scope decision, dispatched by the mode the instant a set-scope move (or a
  /// scene-scope one — see `event.level`) rotate or resize ends on a symbol two-or-more
  /// sequences/shots share — no write yet, [_onScopeDecisionResolved] is what actually writes (or
  /// drops) it.
  Future<void> _onScopeDecisionRequested(
    OcptShotListFloorPlanScopeDecisionRequestedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    emitter(
      state.copyWith(
        pendingFloorPlanScopeDecision: OcptFloorPlanScopeDecision(
          symbolId: event.symbolId,
          setId: event.setId,
          level: event.level,
          sequenceCount: event.sequenceCount,
          xM: event.xM,
          yM: event.yM,
          widthM: event.widthM,
          heightM: event.heightM,
          rotationDeg: event.rotationDeg,
        ),
      ),
    );
  }

  /// Resolves `state.pendingFloorPlanScopeDecision` — writes it onto the original (`every`), onto
  /// an override of the focused sequence or shot, per `decision.level` (`only`, updating one that
  /// already exists or creating one), or simply drops it (`cancel`, the element snaps back since
  /// nothing was ever written). A no-op while nothing is pending, or the focused sequence isn't a
  /// scene-shot one, or (at shot level) no shot is focused (defensive only: the bubble that
  /// dispatches `only` never shows otherwise).
  Future<void> _onScopeDecisionResolved(
    OcptShotListFloorPlanScopeDecisionResolvedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final decision = state.pendingFloorPlanScopeDecision;
    if (decision == null) {
      return;
    }

    if (event.choice == OcptFloorPlanScopeChoice.cancel) {
      emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
      return;
    }

    try {
      final modeState = modeBloc.state;
      final onEveryScope = event.choice == OcptFloorPlanScopeChoice.every;
      String? targetSceneId;
      String? targetShotId;
      if (!onEveryScope) {
        if (decision.level == OcptFloorPlanOverrideLevel.sequence) {
          final sequence = modeState.selectedSequence;
          if (sequence is! OcptSceneShotSequence) {
            emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
            return;
          }
          targetSceneId = sequence.sceneId;
        } else {
          final shotId = modeState.selectedShotId;
          if (shotId == null) {
            emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
            return;
          }
          targetShotId = shotId;
        }
      }

      final existingOverride = onEveryScope
          ? null
          : modeState.floorPlanSnapshot?.setsById[decision.setId]?.symbols.firstWhereOrNull(
              (symbol) =>
                  symbol.overridesSymbolId == decision.symbolId &&
                  symbol.sceneId == targetSceneId &&
                  symbol.shotId == targetShotId,
            );
      final isWritten = await _floorPlanService.applyScopeDecision(
        database: project.database,
        decision: decision,
        onEveryScope: onEveryScope,
        original: ocptFloorPlanSymbolById(
          floorPlanSnapshot: modeState.floorPlanSnapshot,
          symbolId: decision.symbolId,
        ),
        existingOverride: existingOverride,
        targetSceneId: targetSceneId,
        targetShotId: targetShotId,
      );
      if (!isWritten) {
        emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
        return;
      }

      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
      emitter(state.copyWith(forcePendingFloorPlanScopeDecisionValue: true));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to resolve the scope decision on symbol "
        "${decision.symbolId} of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true, forcePendingFloorPlanScopeDecisionValue: true));
    }
  }

  /// Resolves a tap on symbol `event.symbolId` while the arrow tool is active, exactly as
  /// `OcptShotListFloorPlanArrowSymbolTappedEvent` documents: with no anchor pending, picks it as
  /// the arrow's first end; with one already pending and a different symbol tapped, completes a
  /// movement arrow from the anchor to it, on the focused shot; a tap on the anchor itself is a
  /// no-op. Written immediately; a stale tap (no set or no shot focused any more) is silently
  /// ignored, mirroring `OcptShotListInspectorBloc`'s coverage word click guard.
  Future<void> _onArrowSymbolTapped(
    OcptShotListFloorPlanArrowSymbolTappedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final selectedSetId = modeBloc.state.selectedSetId;
    final selectedShotId = modeBloc.state.selectedShotId;
    if (project == null || selectedSetId == null || selectedShotId == null) {
      return;
    }

    final anchor = state.pendingFloorPlanArrowAnchorSymbolId;
    if (anchor == null) {
      emitter(state.copyWith(pendingFloorPlanArrowAnchorSymbolId: event.symbolId));
      return;
    }

    if (anchor == event.symbolId) {
      return;
    }

    try {
      await _floorPlanService.addArrow(
        database: project.database,
        setId: selectedSetId,
        shotId: selectedShotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: anchor,
        toSymbolId: event.symbolId,
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
      emitter(state.copyWith(forcePendingFloorPlanArrowAnchorSymbolIdValue: true));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to add an arrow from symbol $anchor to ${event.symbolId} "
        "of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(hasWriteError: true, forcePendingFloorPlanArrowAnchorSymbolIdValue: true),
      );
    }
  }

  /// Cancels the arrow tool's own pending anchor, dispatched by `Escape` or a click on empty
  /// canvas while it is on. Leaves every arrow untouched, exactly as
  /// `OcptShotListInspectorBloc`'s coverage anchor cancellation leaves every coverage range
  /// untouched.
  Future<void> _onArrowAnchorCancelled(
    OcptShotListFloorPlanArrowAnchorCancelledEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    emitter(state.copyWith(forcePendingFloorPlanArrowAnchorSymbolIdValue: true));
  }

  /// Selects arrow `event.arrowId`, or clears the selection when it is null. A view preference;
  /// also clears the symbol selection, the two being mutually exclusive on the canvas.
  Future<void> _onArrowSelected(
    OcptShotListFloorPlanArrowSelectedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final arrowId = event.arrowId;
    emitter(
      state.copyWith(
        selectedFloorPlanArrowId: arrowId,
        forceSelectedFloorPlanArrowIdValue: arrowId == null,
        forceSelectedFloorPlanSymbolIdValue: arrowId != null,
      ),
    );
  }

  /// Bends arrow `event.arrowId` through `event.ctrlXM`/`event.ctrlYM`, or straightens it back out
  /// when both are null, writing exactly one row (`OcptFloorPlanService.updateArrowCurve`),
  /// dispatched once a drag on its own midpoint handle ends, or by its own straighten button.
  Future<void> _onArrowCurveChanged(
    OcptShotListFloorPlanArrowCurveChangedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _floorPlanService.updateArrowCurve(
        database: project.database,
        arrowId: event.arrowId,
        ctrlXM: event.ctrlXM == null ? const Value(null) : Value(event.ctrlXM),
        ctrlYM: event.ctrlYM == null ? const Value(null) : Value(event.ctrlYM),
      );
      await modeBloc.reload({OcptShotListReloadScope.floorPlans});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to bend arrow ${event.arrowId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Duplicates symbol `event.symbolId` into an independent copy — never a link — on the very same
  /// set/shot/layer, at `event.xM`/`event.yM` when given or offset from the source by
  /// `ocptFloorPlanDuplicateOffsetM` otherwise (`Ctrl+D`, which reports no position of its own),
  /// then selects the copy once the mode holds it. A no-op while the source symbol can no longer
  /// be found (a stale shortcut on a canvas rebuilt underneath).
  Future<void> _onSymbolDuplicated(
    OcptShotListFloorPlanSymbolDuplicatedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final source = ocptFloorPlanSymbolById(
      floorPlanSnapshot: modeBloc.state.floorPlanSnapshot,
      symbolId: event.symbolId,
    );
    if (source == null) {
      return;
    }

    try {
      final symbolId = await _floorPlanService.placeSymbol(
        database: project.database,
        setId: source.setId,
        sceneId: source.sceneId,
        shotId: source.shotId,
        layer: source.layer,
        xM: event.xM ?? source.xM + ocptFloorPlanDuplicateOffsetM,
        yM: event.yM ?? source.yM + ocptFloorPlanDuplicateOffsetM,
        rotationDeg: source.rotationDeg,
        widthM: source.widthM,
        heightM: source.heightM,
        fovDeg: source.fovDeg,
        fovReachM: source.fovReachM,
        label: source.label,
        setElementShape: source.setElementShape,
      );
      if (symbolId == null) {
        return;
      }

      if (!await modeBloc.reload({OcptShotListReloadScope.floorPlans})) {
        return;
      }
      emitter(
        state.copyWith(
          selectedFloorPlanSymbolId: symbolId,
          forceSelectedFloorPlanArrowIdValue: true,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to duplicate symbol ${event.symbolId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Clears [OcptShotListFloorPlanCanvasState.pendingCharacterNamePromptSymbolId], dispatched by
  /// the mode's own listener the moment it opens `OcptFloorPlanCharacterNamePickerDialog` for it.
  Future<void> _onCharacterNamePromptDismissed(
    OcptShotListFloorPlanCharacterNamePromptDismissedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    emitter(state.copyWith(forcePendingCharacterNamePromptSymbolIdValue: true));
  }

  /// Dismisses the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListFloorPlanCanvasWriteErrorDismissedEvent event,
    Emitter<OcptShotListFloorPlanCanvasState> emitter,
  ) async {
    emitter(state.copyWith(hasWriteError: false));
  }
}
