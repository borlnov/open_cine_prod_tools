// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_prop_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_gallery.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_tray_sequence_camera.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_view.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The floor plans view of the shot list mode: the selected sequence's selected set drawn as an
/// [OcptFloorPlanView], or the [OcptFloorPlanSetGallery] while the sequence has no set linked yet.
///
/// It is wired to the mode bloc for what is shared (the sequence, the shot, the set, the snapshot)
/// and to the three floor plan view blocs for what each of their surfaces does with it: the sets
/// bloc for the tray, the visibility toggles and the underlay, the canvas bloc for the gestures,
/// the placements bloc for the field-of-view and label edits. Every write is withheld (a null
/// callback) under a version preview, reads (zoom, pan, layer visibility, symbol selection,
/// focusing a shot) staying available throughout.
///
/// Deleting a symbol and clearing an underlay are only *asked*, through [onSymbolDeleteRequested]
/// and [onUnderlayClearRequested]: the mode owns their confirmation dialogs.
class OcptShotListFloorPlanCentre extends StatelessWidget {
  /// The mode's state, which the sequence, the sets and the snapshots are read from.
  final OcptShotListState state;

  /// The selected sequence, whose shots the focus strip lists.
  final OcptShotSequence sequence;

  /// Called with the id of the symbol the user asked to delete; the mode confirms it, then
  /// dispatches the deletion.
  final ValueChanged<String> onSymbolDeleteRequested;

  /// Called with the id of the set whose underlay the user asked to clear; the mode confirms it,
  /// then dispatches the clearing.
  final ValueChanged<String> onUnderlayClearRequested;

  /// Class constructor
  const OcptShotListFloorPlanCentre({
    super.key,
    required this.state,
    required this.sequence,
    required this.onSymbolDeleteRequested,
    required this.onUnderlayClearRequested,
  });

  /// Build the shot list floor plan centre as an [OcptFloorPlanView].
  @override
  Widget build(BuildContext context) {
    final sequence = this.sequence;
    if (sequence is OcptSceneShotSequence && state.setsOfSelectedSequence.isEmpty) {
      return _FloorPlanGallery(state: state, sequence: sequence);
    }

    final bloc = context.read<OcptShotListBloc>();
    final setsBloc = context.read<OcptShotListFloorPlanSetsBloc>();
    final setsState = context.watch<OcptShotListFloorPlanSetsBloc>().state;
    final canvasBloc = context.read<OcptShotListFloorPlanCanvasBloc>();
    final canvasState = context.watch<OcptShotListFloorPlanCanvasBloc>().state;
    final placementsBloc = context.read<OcptShotListFloorPlanPlacementsBloc>();
    final placementsState = context.watch<OcptShotListFloorPlanPlacementsBloc>().state;
    final tr = Tr.of(context);
    final isReadOnly = state.isPreviewingVersion;
    final selectedSet = state.selectedSet;
    final selectedSetId = state.selectedSetId;
    final focusShotId = state.selectedShotId;

    final shotRankByShotId = <String, int>{
      for (var i = 0; i < sequence.shots.length; i++) sequence.shots[i].id: i + 1,
    };

    return OcptFloorPlanView(
      floorPlanSet: selectedSet,
      shots: sequence.shots,
      shotRankByShotId: shotRankByShotId,
      focusSceneId: state.selectedSequenceId ?? '',
      sequenceCode: ocptShotSequenceDisplayNumberOf(sequence),
      focusShotId: focusShotId,
      previousShotId: state.previousShotOfSelectedShot?.id,
      nextShotId: state.nextShotOfSelectedShot?.id,
      hasCameraOnSetOf: _hasCameraOnSetOf(sequence, selectedSet),
      sequenceCameras: _sequenceCamerasOf(selectedSet, state.selectedSequenceId, shotRankByShotId),
      initialZoom: setsState.floorPlanZoom,
      hiddenLayers: setsState.floorPlanHiddenLayers,
      hiddenCameraSymbolIds: setsState.floorPlanHiddenCameraSymbolIds,
      isUnderlayHidden: setsState.isFloorPlanUnderlayHidden,
      isOnionSkinPreviousShown: setsState.isFloorPlanOnionSkinPreviousShown,
      isOnionSkinNextShown: setsState.isFloorPlanOnionSkinNextShown,
      onionSkinOpacity: setsState.floorPlanOnionSkinOpacity,
      isMetricsShown: setsState.isFloorPlanMetricsShown,
      selectedSymbolId: canvasState.selectedFloorPlanSymbolId,
      selectedArrowId: canvasState.selectedFloorPlanArrowId,
      pendingArrowAnchorSymbolId: canvasState.pendingFloorPlanArrowAnchorSymbolId,
      activeTool: canvasState.floorPlanActiveTool,
      activeLayer: setsState.floorPlanActiveLayer,
      activeSetElementShape: setsState.floorPlanActiveSetElementShape,
      activeSetElementScope: setsState.floorPlanActiveSetElementScope,
      activeLabel: setsState.floorPlanActiveLabel,
      propsChips: [
        for (final prop in setsState.propsOfSelectedSequence)
          OcptFloorPlanPropChip(
            elementId: prop.elementId,
            name: prop.name,
            quantity: prop.quantity,
          ),
      ],
      isReadOnly: isReadOnly,
      symbolLabelValueOf: (symbolId) => symbolLabelValueOf(state, placementsState, symbolId),
      onToolSelected: (tool) => canvasBloc.add(OcptShotListFloorPlanToolSelectedEvent(tool: tool)),
      onLayerVisibilityToggled: (layer) =>
          setsBloc.add(OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: layer)),
      onActiveLayerChanged: (layer) =>
          setsBloc.add(OcptShotListFloorPlanActiveLayerChangedEvent(layer: layer)),
      onSetElementShapeSelected: (shape) =>
          setsBloc.add(OcptShotListFloorPlanActiveSetElementShapeChangedEvent(shape: shape)),
      onSetElementScopeSelected: (scope) =>
          setsBloc.add(OcptShotListFloorPlanActiveSetElementScopeChangedEvent(scope: scope)),
      onPropChipSelected: (label) =>
          setsBloc.add(OcptShotListFloorPlanActiveLabelChangedEvent(label: label)),
      onCameraVisibilityToggled: (symbolId) =>
          setsBloc.add(OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: symbolId)),
      onOnionSkinToggled: (isPrevious) =>
          setsBloc.add(OcptShotListFloorPlanOnionSkinToggledEvent(isPrevious: isPrevious)),
      onOnionSkinOpacityChanged: (opacity) =>
          setsBloc.add(OcptShotListFloorPlanOnionSkinOpacityChangedEvent(opacity: opacity)),
      onMetricsToggled: () => setsBloc.add(const OcptShotListFloorPlanMetricsToggledEvent()),
      onUnderlayVisibilityToggled: () =>
          setsBloc.add(const OcptShotListFloorPlanUnderlayVisibilityToggledEvent()),
      onUnderlayImportRequested: isReadOnly || selectedSetId == null
          ? null
          : () => setsBloc.add(
              OcptShotListFloorPlanUnderlayImportRequestedEvent(
                setId: selectedSetId,
                fileTypeLabel: tr.shotListFloorPlanUnderlayFileTypeLabel,
              ),
            ),
      onUnderlayClearRequested:
          isReadOnly || selectedSetId == null || selectedSet?.underlayAssetId == null
          ? null
          : () => onUnderlayClearRequested(selectedSetId),
      onSymbolSelected: (symbolId) =>
          canvasBloc.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: symbolId)),
      onSymbolPlaced: isReadOnly || selectedSetId == null
          ? null
          : (layer, shotId, sceneId, xM, yM, {setElementShape, label = ""}) => canvasBloc.add(
              OcptShotListFloorPlanSymbolPlacedEvent(
                setId: selectedSetId,
                layer: layer,
                shotId: shotId,
                sceneId: sceneId,
                xM: xM,
                yM: yM,
                setElementShape: setElementShape,
                label: label,
              ),
            ),
      onSymbolMoved: isReadOnly
          ? null
          : (symbolId, xM, yM) => _handleSymbolMoved(context, state, symbolId, xM, yM),
      onSymbolResized: isReadOnly
          ? null
          : (symbolId, widthM, heightM) =>
                _handleSymbolResized(context, state, symbolId, widthM, heightM),
      onSymbolRotated: isReadOnly
          ? null
          : (symbolId, rotationDeg) => _handleSymbolRotated(context, state, symbolId, rotationDeg),
      onSymbolFovChanged: isReadOnly
          ? null
          : (symbolId, fovDeg) => placementsBloc.add(
              OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: symbolId, fovDeg: fovDeg),
            ),
      onSymbolFovReachChanged: isReadOnly
          ? null
          : (symbolId, fovReachM) => placementsBloc.add(
              OcptShotListFloorPlanSymbolFovReachChangedEvent(
                symbolId: symbolId,
                fovReachM: fovReachM,
              ),
            ),
      onSymbolDeleteRequested: isReadOnly ? null : onSymbolDeleteRequested,
      onSymbolRestoreRequested: isReadOnly
          ? null
          : (symbolId) => placementsBloc.add(
              OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: symbolId),
            ),
      onArrowSymbolTapped: isReadOnly || selectedSetId == null || focusShotId == null
          ? null
          : (symbolId) =>
                canvasBloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: symbolId)),
      onArrowAnchorCancelled: isReadOnly
          ? null
          : () => canvasBloc.add(const OcptShotListFloorPlanArrowAnchorCancelledEvent()),
      onArrowSelected: (arrowId) =>
          canvasBloc.add(OcptShotListFloorPlanArrowSelectedEvent(arrowId: arrowId)),
      onArrowCurveChanged: isReadOnly
          ? null
          : (arrowId, ctrlXM, ctrlYM) => canvasBloc.add(
              OcptShotListFloorPlanArrowCurveChangedEvent(
                arrowId: arrowId,
                ctrlXM: ctrlXM,
                ctrlYM: ctrlYM,
              ),
            ),
      onSymbolDuplicateRequested: isReadOnly
          ? null
          : (symbolId) =>
                canvasBloc.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: symbolId)),
      onSymbolDuplicateDragged: isReadOnly
          ? null
          : (symbolId, xM, yM) => canvasBloc.add(
              OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: symbolId, xM: xM, yM: yM),
            ),
      onGhostShotFocusRequested: (shotId) =>
          bloc.add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onSymbolLabelChanged: isReadOnly
          ? null
          : (symbolId, rawValue) => placementsBloc.add(
              OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: rawValue),
            ),
      onUnderlayTransformChanged: isReadOnly || selectedSetId == null
          ? null
          : (xM, yM, widthM, heightM) => setsBloc.add(
              OcptShotListFloorPlanUnderlayTransformChangedEvent(
                setId: selectedSetId,
                xM: xM,
                yM: yM,
                widthM: widthM,
                heightM: heightM,
              ),
            ),
      onZoomSettled: (zoom) => setsBloc.add(OcptShotListFloorPlanZoomChangedEvent(zoom: zoom)),
      onShotChipSelected: (shotId) => bloc.add(OcptShotListShotSelectedEvent(shotId: shotId)),
      onShotWalkRequested: (delta) =>
          setsBloc.add(OcptShotListFloorPlanShotWalkRequestedEvent(delta: delta)),
      pendingScopeLiveOverride: _pendingScopeLiveOverrideOf(state, canvasState),
      scopeBubbleEveryLabel: _scopeBubbleEveryLabelOf(canvasState, tr),
      scopeBubbleOnlyLabel: _scopeBubbleOnlyLabelOf(state, canvasState, tr, sequence),
      scopeBubbleCancelLabel: canvasState.pendingFloorPlanScopeDecision == null
          ? null
          : tr.shotListFloorPlanScopeBubbleCancelAction,
      onScopeBubbleEveryRequested: canvasState.pendingFloorPlanScopeDecision == null
          ? null
          : () => canvasBloc.add(
              const OcptShotListFloorPlanScopeDecisionResolvedEvent(
                choice: OcptFloorPlanScopeChoice.every,
              ),
            ),
      onScopeBubbleOnlyRequested: canvasState.pendingFloorPlanScopeDecision == null
          ? null
          : () => canvasBloc.add(
              const OcptShotListFloorPlanScopeDecisionResolvedEvent(
                choice: OcptFloorPlanScopeChoice.only,
              ),
            ),
      onScopeBubbleCancelRequested: canvasState.pendingFloorPlanScopeDecision == null
          ? null
          : () => canvasBloc.add(
              const OcptShotListFloorPlanScopeDecisionResolvedEvent(
                choice: OcptFloorPlanScopeChoice.cancel,
              ),
            ),
    );
  }

  /// Get [canvasState]'s own pending scope decision, resolved into the live override the canvas
  /// draws (and
  /// hit-tests) instead of the symbol's own stored geometry while the scope bubble is showing — or
  /// null while nothing is pending. Falls back to the original symbol's own currently stored
  /// footprint (resolved exactly like `OcptFloorPlanSheet._shapeOf` would) for whichever field the
  /// triggering gesture didn't itself change.
  OcptFloorPlanSymbolLiveOverride? _pendingScopeLiveOverrideOf(
    OcptShotListState state,
    OcptShotListFloorPlanCanvasState canvasState,
  ) {
    final decision = canvasState.pendingFloorPlanScopeDecision;
    if (decision == null) {
      return null;
    }

    final original = state.floorPlanSnapshot?.setsById[decision.setId]?.symbols.firstWhereOrNull(
      (symbol) => symbol.id == decision.symbolId,
    );
    if (original == null) {
      return null;
    }

    final setElementDefault = ocptFloorPlanSetElementDefaultFootprintM(
      original.setElementShape ?? OcptFloorPlanSetElementShape.freeform,
    );

    return OcptFloorPlanSymbolLiveOverride(
      symbolId: decision.symbolId,
      xM: decision.xM ?? original.xM,
      yM: decision.yM ?? original.yM,
      widthM: decision.widthM ?? original.widthM ?? setElementDefault.widthM,
      heightM: decision.heightM ?? original.heightM ?? setElementDefault.heightM,
      rotationDeg: decision.rotationDeg ?? original.rotationDeg,
    );
  }

  /// Get the scope bubble's own broader-scope label — `Every sequence (n)` at
  /// [OcptFloorPlanOverrideLevel.sequence], `The whole sequence` at
  /// [OcptFloorPlanOverrideLevel.shot] — or null while nothing is pending.
  String? _scopeBubbleEveryLabelOf(OcptShotListFloorPlanCanvasState canvasState, Tr tr) {
    final decision = canvasState.pendingFloorPlanScopeDecision;
    if (decision == null) {
      return null;
    }
    return decision.level == OcptFloorPlanOverrideLevel.shot
        ? tr.shotListFloorPlanScopeBubbleWholeSequenceAction
        : tr.shotListFloorPlanScopeBubbleEveryAction(decision.sequenceCount);
  }

  /// Get the scope bubble's own narrower-scope label — `Only sequence n` at
  /// [OcptFloorPlanOverrideLevel.sequence], `Only shot n` at [OcptFloorPlanOverrideLevel.shot]
  /// — or null while nothing is pending.
  String? _scopeBubbleOnlyLabelOf(
    OcptShotListState state,
    OcptShotListFloorPlanCanvasState canvasState,
    Tr tr,
    OcptShotSequence? sequence,
  ) {
    final decision = canvasState.pendingFloorPlanScopeDecision;
    if (decision == null) {
      return null;
    }
    if (decision.level == OcptFloorPlanOverrideLevel.shot) {
      return tr.shotListFloorPlanScopeBubbleOnlyShotAction(state.selectedShot?.code ?? "");
    }
    return tr.shotListFloorPlanScopeBubbleOnlyAction(ocptShotSequenceDisplayNumberOf(sequence));
  }

  /// Tell whether each of [sequence]'s own shots has a live camera symbol on [selectedSet], keyed
  /// by
  /// shot id — the focus strip's own filled/hollow dots.
  Map<String, bool> _hasCameraOnSetOf(OcptShotSequence sequence, OcptFloorPlanSet? selectedSet) {
    if (selectedSet == null) {
      return const {};
    }
    final shotIdsWithCamera = {
      for (final symbol in selectedSet.symbols)
        if (symbol.layer == OcptFloorPlanLayer.cameras && symbol.shotId != null) symbol.shotId!,
    };
    return {for (final shot in sequence.shots) shot.id: shotIdsWithCamera.contains(shot.id)};
  }

  /// Get every live camera symbol of [selectedSet], numbered, for the tray's own expandable cameras
  /// row under the `Sequence` focus — built from the very same `OcptFloorPlanSheet.of` the canvas
  /// itself draws that focus from, so the tray's own labels can never disagree with the canvas.
  List<OcptFloorPlanTraySequenceCamera> _sequenceCamerasOf(
    OcptFloorPlanSet? selectedSet,
    String? focusSceneId,
    Map<String, int> shotRankByShotId,
  ) {
    if (selectedSet == null || focusSceneId == null) {
      return const [];
    }
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: selectedSet,
      focusSceneId: focusSceneId,
      focusShotId: null,
      shotRankByShotId: shotRankByShotId,
    );
    return [
      for (final symbol in sheet.symbols)
        if (symbol.layer == OcptFloorPlanLayer.cameras)
          OcptFloorPlanTraySequenceCamera(
            symbolId: symbol.symbolId,
            label: symbol.cameraLabel ?? "?",
          ),
    ];
  }

  /// Handle a move's own canvas callback: dispatches the plain move straight away, unless
  /// [symbolId]
  /// names a **set-scope** symbol whose own set is linked to two or more sequences, or a
  /// **scene-scope** one whose own sequence holds two or more shots, in which case it
  /// dispatches the scope decision instead — the scope bubble asks before anything is written.
  void _handleSymbolMoved(
    BuildContext context,
    OcptShotListState state,
    String symbolId,
    double xM,
    double yM,
  ) {
    final canvasBloc = context.read<OcptShotListFloorPlanCanvasBloc>();
    final decision = _scopeDecisionTargetOf(state, symbolId);
    if (decision == null) {
      canvasBloc.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: xM, yM: yM));
      return;
    }
    canvasBloc.add(
      OcptShotListFloorPlanScopeDecisionRequestedEvent(
        symbolId: symbolId,
        setId: decision.setId,
        level: decision.level,
        sequenceCount: decision.count,
        xM: xM,
        yM: yM,
      ),
    );
  }

  /// Handle a resize's own canvas callback. See [_handleSymbolMoved]'s own doc comment.
  void _handleSymbolResized(
    BuildContext context,
    OcptShotListState state,
    String symbolId,
    double widthM,
    double heightM,
  ) {
    final canvasBloc = context.read<OcptShotListFloorPlanCanvasBloc>();
    final decision = _scopeDecisionTargetOf(state, symbolId);
    if (decision == null) {
      canvasBloc.add(
        OcptShotListFloorPlanSymbolResizedEvent(
          symbolId: symbolId,
          widthM: widthM,
          heightM: heightM,
        ),
      );
      return;
    }
    canvasBloc.add(
      OcptShotListFloorPlanScopeDecisionRequestedEvent(
        symbolId: symbolId,
        setId: decision.setId,
        level: decision.level,
        sequenceCount: decision.count,
        widthM: widthM,
        heightM: heightM,
      ),
    );
  }

  /// Handle a rotate's own canvas callback. See [_handleSymbolMoved]'s own doc comment.
  void _handleSymbolRotated(
    BuildContext context,
    OcptShotListState state,
    String symbolId,
    double rotationDeg,
  ) {
    final canvasBloc = context.read<OcptShotListFloorPlanCanvasBloc>();
    final decision = _scopeDecisionTargetOf(state, symbolId);
    if (decision == null) {
      canvasBloc.add(
        OcptShotListFloorPlanSymbolRotatedEvent(symbolId: symbolId, rotationDeg: rotationDeg),
      );
      return;
    }
    canvasBloc.add(
      OcptShotListFloorPlanScopeDecisionRequestedEvent(
        symbolId: symbolId,
        setId: decision.setId,
        level: decision.level,
        sequenceCount: decision.count,
        rotationDeg: rotationDeg,
      ),
    );
  }

  /// Tell whether [symbolId] names a symbol whose move/rotate/resize should ask the scope bubble
  /// instead of writing straight away, and at which level:
  /// - A **live, set-scope** symbol (never an override) whose own set is linked to two or more
  ///   sequences — [OcptFloorPlanOverrideLevel.sequence].
  /// - A **live, scene-scope** symbol (a prop, the sequence's own furniture, or itself already a
  ///   sequence-scope override — never a shot-scope one) of a sequence holding two or more shots —
  ///   [OcptFloorPlanOverrideLevel.shot].
  ///
  /// Null otherwise: a single-sequence set's own set-scope symbol, a single-shot sequence's own
  /// scene-scope symbol, or any shot-scope symbol (already an override, or a camera/character/
  /// light) — all of which write straight away, exactly as before.
  ({String setId, int count, OcptFloorPlanOverrideLevel level})? _scopeDecisionTargetOf(
    OcptShotListState state,
    String symbolId,
  ) {
    final selectedSet = state.selectedSet;
    if (selectedSet == null) {
      return null;
    }
    final symbol = selectedSet.symbols.firstWhereOrNull((candidate) => candidate.id == symbolId);
    if (symbol == null || symbol.shotId != null) {
      return null;
    }

    if (symbol.sceneId == null) {
      final sequenceCount = state.floorPlanSnapshot?.sequenceCountOfSet(selectedSet.id) ?? 0;
      return sequenceCount >= 2
          ? (
              setId: selectedSet.id,
              count: sequenceCount,
              level: OcptFloorPlanOverrideLevel.sequence,
            )
          : null;
    }

    final sequence = state.selectedSequence;
    final shotCount = sequence is OcptSceneShotSequence ? sequence.shots.length : 0;
    return shotCount >= 2
        ? (setId: selectedSet.id, count: 0, level: OcptFloorPlanOverrideLevel.shot)
        : null;
  }

  /// Get [symbolId]'s current label value: a pending edit still in the bloc's debounce, or the
  /// symbol's own stored label.
  static String symbolLabelValueOf(
    OcptShotListState state,
    OcptShotListFloorPlanPlacementsState placementsState,
    String symbolId,
  ) {
    final pending =
        placementsState.pendingFieldEdits[OcptShotListSymbolLabelEditKey(symbolId: symbolId)];
    if (pending != null) {
      return pending;
    }
    for (final floorPlanSet in state.setsOfSelectedSequence) {
      for (final symbol in floorPlanSet.symbols) {
        if (symbol.id == symbolId) {
          return symbol.label;
        }
      }
    }
    return "";
  }
}

/// The empty-state gallery filling the centre while the sequence has no linked Resources set yet:
/// one card per live set of the project, the heading's own suggestion first and starred, a click
/// linking it and selecting its tab, a `Create a set…` action opening the very same menu the
/// `＋ Set` button does. Every write is withheld under a read-only preview.
class _FloorPlanGallery extends StatelessWidget {
  /// The mode's state.
  final OcptShotListState state;

  /// The selected sequence, whose heading the suggestion is made from.
  final OcptSceneShotSequence sequence;

  /// Class constructor
  const _FloorPlanGallery({required this.state, required this.sequence});

  /// Build the floor plan gallery as an [OcptFloorPlanSetGallery].
  @override
  Widget build(BuildContext context) {
    final setsBloc = context.read<OcptShotListFloorPlanSetsBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptFloorPlanSetGallery(
      locations: state.locations,
      symbolsBySetId: state.setScopeSymbolsBySetId,
      suggestedSetId: state.suggestedSetIdOf(sequence),
      onSetLinkRequested: isReadOnly
          ? null
          : (setId) => setsBloc.add(OcptShotListSetLinkRequestedEvent(setId: setId)),
      onSetCreationRequested: isReadOnly
          ? null
          : (locationId) =>
                setsBloc.add(OcptShotListSetCreationRequestedEvent(locationId: locationId)),
    );
  }
}
