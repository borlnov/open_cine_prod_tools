// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart'
    show OcptFloorPlanOverrideLevel;
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListBloc` about floor plan symbols, arrows, scope and underlay.
sealed class OcptShotListFloorPlanSymbolEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanSymbolEvent();
}

/// Places a new set element symbol on set `event.setId`'s `event.layer`, at `event.xM`/`event.yM`
/// (metres), dispatched by a click on empty canvas while the `setElement` tool is on. Written
/// immediately (`OcptFloorPlanService.placeSymbol`), then selects the freshly minted symbol.
class OcptShotListFloorPlanSymbolPlacedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the set the symbol is placed on.
  final String setId;

  /// The layer the symbol is placed on — the tray's own current active sequence layer for
  /// [OcptFloorPlanTool.setElement], or the fixed layer a shot-scoped tool
  /// ([OcptFloorPlanTool.camera]/[OcptFloorPlanTool.character]/[OcptFloorPlanTool.light]) always
  /// places on.
  final OcptFloorPlanLayer layer;

  /// The id of the shot the symbol belongs to — null on a sequence layer, the focused shot's id on
  /// a shot layer (the scope invariant
  /// `OcptFloorPlanService.placeSymbol` enforces).
  final String? shotId;

  /// The id of the sequence the symbol belongs to — null on a set-scope or shot-scope symbol, the
  /// focused sequence's own scene id on a scene-scope one (a `set`-layer placement at
  /// [OcptFloorPlanScope.scene], or any `props` placement).
  final String? sceneId;

  /// The symbol's centre X, in metres.
  final double xM;

  /// The symbol's centre Y, in metres.
  final double yM;

  /// The décor primitive a `setElement` placement carries — from the placing entry's own
  /// (`OcptFloorPlanPaletteDragPayload`) or the click-to-armed
  /// `OcptShotListState.floorPlanActiveSetElementShape`. Null on every other layer.
  final OcptFloorPlanSetElementShape? setElementShape;

  /// A `prop` placement's own armed label — from the placing chip's own drag payload or the
  /// click-to-armed `OcptShotListState.floorPlanActiveLabel`. Empty on every other layer.
  final String label;

  /// Class constructor
  const OcptShotListFloorPlanSymbolPlacedEvent({
    required this.setId,
    required this.layer,
    required this.shotId,
    required this.sceneId,
    required this.xM,
    required this.yM,
    this.setElementShape,
    this.label = "",
  });

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    setId,
    layer,
    shotId,
    sceneId,
    xM,
    yM,
    setElementShape,
    label,
  ];
}

/// Selects symbol `event.symbolId` on the floor plans canvas, or clears the selection when
/// `event.symbolId` is null (a click on empty canvas while the `select` tool is on).
class OcptShotListFloorPlanSymbolSelectedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol to select, or null to clear the selection.
  final String? symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolSelectedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Moves symbol `event.symbolId` to `event.xM`/`event.yM` (metres), dispatched once a drag on it
/// ends. Written as a single row (`OcptFloorPlanService.updateSymbol`), never per frame: the live
/// drag position is a purely local widget concern, exactly as the underlay's own drag is.
class OcptShotListFloorPlanSymbolMovedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol being moved.
  final String symbolId;

  /// The symbol's new centre X, in metres.
  final double xM;

  /// The symbol's new centre Y, in metres.
  final double yM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolMovedEvent({
    required this.symbolId,
    required this.xM,
    required this.yM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, xM, yM];
}

/// Resizes set element symbol `event.symbolId` to `event.widthM`/`event.heightM` (metres),
/// dispatched once a drag on its own resize handle ends. Written as a single row, never per frame.
class OcptShotListFloorPlanSymbolResizedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol being resized.
  final String symbolId;

  /// The symbol's new footprint width, in metres.
  final double widthM;

  /// The symbol's new footprint height, in metres.
  final double heightM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolResizedEvent({
    required this.symbolId,
    required this.widthM,
    required this.heightM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, widthM, heightM];
}

/// Rotates symbol `event.symbolId` to `event.rotationDeg`, dispatched once a drag on its own
/// rotate handle ends. Written as a single row, never per frame.
class OcptShotListFloorPlanSymbolRotatedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol being rotated.
  final String symbolId;

  /// The symbol's new rotation, in degrees.
  final double rotationDeg;

  /// Class constructor
  const OcptShotListFloorPlanSymbolRotatedEvent({
    required this.symbolId,
    required this.rotationDeg,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, rotationDeg];
}

/// Requests deleting symbol `event.symbolId` for good, dispatched once the canvas's own delete
/// action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanSymbolDeletionRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol to delete.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolDeletionRequestedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Requests deleting set-scope symbol `event.symbolId` **everywhere** — itself (or, when it names
/// a scene-scope override instead, the set-scope original it overrides) and every live override of
/// it, in every sequence (`OcptFloorPlanService.deleteSymbolEverywhere`) — the destructive branch
/// of the extended delete confirmation for an element used by two or more sequences,
/// dispatched once it has already been confirmed through
/// `OcptConfirmDialog.showWithAlternative`, by the mode.
class OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent
    extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol (the original, or one of its overrides) to delete everywhere.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Masks set-scope symbol `event.symbolId` for sequence `event.targetSceneId` alone — a **hidden**
/// override, setting `isHidden` on one that already exists or creating one, copied from the
/// original's own geometry — the alternative branch ("Remove from sequence n") of the extended
/// delete confirmation, dispatched once it has already been confirmed through
/// `OcptConfirmDialog.showWithAlternative`, by the mode. Reversible: the inspector's own `Restore`
/// undoes it.
class OcptShotListFloorPlanSymbolHideRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol (the original, or one of its overrides) to mask.
  final String symbolId;

  /// The sequence to mask it for — the override's own `sceneId`, whichever sequence [symbolId]
  /// itself already belongs to when it already is one, or the focused sequence's own scene id when
  /// it is the set-scope original instead.
  final String targetSceneId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolHideRequestedEvent({
    required this.symbolId,
    required this.targetSceneId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, targetSceneId];
}

/// Masks scene-scope symbol `event.symbolId` for shot `event.targetShotId` alone — a **hidden**
/// shot-scope override, setting `isHidden` on one that already exists or creating one, copied from
/// the scene symbol's own geometry — the alternative
/// branch ("Remove from shot n") of the shot-level extended delete confirmation, dispatched once it
/// has already been confirmed through `OcptConfirmDialog.showWithAlternative`, by the mode.
/// Reversible: the inspector's own `Restore` undoes it. See
/// [OcptShotListFloorPlanSymbolHideRequestedEvent]'s own doc comment for the sequence-level
/// equivalent this mirrors one level down.
class OcptShotListFloorPlanSymbolHideForShotRequestedEvent
    extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol (the scene-scope symbol, or one of its own shot overrides) to mask.
  final String symbolId;

  /// The shot to mask it for — the override's own `shotId`, whichever shot [symbolId] itself
  /// already belongs to when it already is one, or the focused shot's own id when it is the
  /// scene-scope symbol instead.
  final String targetShotId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolHideForShotRequestedEvent({
    required this.symbolId,
    required this.targetShotId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, targetShotId];
}

/// Restores override `event.symbolId` as in the level above it — tombstones it
/// (`OcptFloorPlanService.deleteSymbol`), so the original it names reappears there: a set-scope
/// original for a scene-scope override, or a scene-scope symbol for a shot-scope one — the
/// canvas's own `Restore` handle and the inspector's own `Restore as in the set`/`Restore as in
/// the sequence` action. Reversible (the user can redo the change), so this never asks —
/// dispatched straight away.
class OcptShotListFloorPlanSymbolRestoreRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the override to restore.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolRestoreRequestedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Reports a move, rotate or resize awaiting the scope bubble's own answer, dispatched by the mode
/// instead of writing anything, the instant such a gesture ends — a **set-scope** symbol
/// belonging to a set linked to
/// `event.sequenceCount` (two or more) sequences ([OcptFloorPlanOverrideLevel.sequence]), or a
/// **scene-scope** symbol of a sequence with two or more shots ([OcptFloorPlanOverrideLevel.shot]).
/// Only stores `OcptShotListState.pendingFloorPlanScopeDecision`;
/// [OcptShotListFloorPlanScopeDecisionResolvedEvent] is what actually writes (or drops) it.
class OcptShotListFloorPlanScopeDecisionRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol being moved, rotated or resized.
  final String symbolId;

  /// The Resources set [symbolId] belongs to.
  final String setId;

  /// Which of the two levels this decision is at. See `OcptFloorPlanScopeDecision`'s own doc
  /// comment.
  final OcptFloorPlanOverrideLevel level;

  /// How many live sequences the symbol's own set is linked to — meaningless (0) at
  /// [OcptFloorPlanOverrideLevel.shot].
  final int sequenceCount;

  /// The symbol's own new centre X, in metres — null unless a move triggered this. See
  /// `OcptFloorPlanScopeDecision`'s own doc comment.
  final double? xM;

  /// The symbol's own new centre Y, in metres. See [xM].
  final double? yM;

  /// The symbol's own new footprint width, in metres — null unless a resize triggered this.
  final double? widthM;

  /// The symbol's own new footprint height, in metres. See [widthM].
  final double? heightM;

  /// The symbol's own new rotation, in degrees — null unless a rotate triggered this.
  final double? rotationDeg;

  /// Class constructor
  const OcptShotListFloorPlanScopeDecisionRequestedEvent({
    required this.symbolId,
    required this.setId,
    required this.level,
    this.sequenceCount = 0,
    this.xM,
    this.yM,
    this.widthM,
    this.heightM,
    this.rotationDeg,
  });

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    symbolId,
    setId,
    level,
    sequenceCount,
    xM,
    yM,
    widthM,
    heightM,
    rotationDeg,
  ];
}

/// Resolves `OcptShotListState.pendingFloorPlanScopeDecision` — the scope bubble's own `Every
/// sequence`/`Only sequence n`/`Cancel` — writing it (onto the original, or onto a scene-scope
/// override of the focused sequence, creating one if none exists yet) or simply dropping it.
/// A no-op while nothing is pending.
class OcptShotListFloorPlanScopeDecisionResolvedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// Which of the bubble's own three answers was picked.
  final OcptFloorPlanScopeChoice choice;

  /// Class constructor
  const OcptShotListFloorPlanScopeDecisionResolvedEvent({required this.choice});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, choice];
}

/// Requests importing set `event.setId`'s underlay, dispatched by the tool bar's own underlay
/// action.
///
/// The bloc picks the file through `FileSelectorManager`, filtered to JPEG and PNG
/// (`ocptFloorPlanUnderlayImageFileExtensions`), then places it at a default frame centred on the
/// canvas — the user drags and resizes it to match the reference silhouette afterwards (ADR 0031).
/// A cancelled dialog changes nothing at all. [fileTypeLabel] is the localized label the native
/// picker's own file type filter shows, resolved by the mode.
class OcptShotListFloorPlanUnderlayImportRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the set the underlay is set on.
  final String setId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayImportRequestedEvent({
    required this.setId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, fileTypeLabel];
}

/// Sets set `event.setId`'s underlay frame to `event.xM`/`event.yM`/`event.widthM`/
/// `event.heightM` (metres), dispatched once a drag moving or resizing it ends. Written as a
/// single call (`OcptFloorPlanService.setSetUnderlay`, re-pointed at the same already-imported
/// file), never per frame.
class OcptShotListFloorPlanUnderlayTransformChangedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the set whose underlay frame changed.
  final String setId;

  /// The underlay's new centre X, in metres.
  final double xM;

  /// The underlay's new centre Y, in metres.
  final double yM;

  /// The underlay's new width, in metres.
  final double widthM;

  /// The underlay's new height, in metres.
  final double heightM;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayTransformChangedEvent({
    required this.setId,
    required this.xM,
    required this.yM,
    required this.widthM,
    required this.heightM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, xM, yM, widthM, heightM];
}

/// Requests clearing set `event.setId`'s underlay for good, dispatched once the tray's own
/// `Clear underlay` action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanUnderlayClearRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the set whose underlay is cleared.
  final String setId;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayClearRequestedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Walks the selected sequence's own shots by `event.delta` (`-1` for `←`, `1` for `→`),
/// dispatched by the floor plans focus strip's own keyboard shortcut. Selects the sequence's first
/// shot when nothing is selected yet and `event.delta` is positive, does nothing at either end of
/// the list, and does nothing while the selected sequence is the orphan group (its shots have no
/// set to draw a floor plan on).
class OcptShotListFloorPlanShotWalkRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// `-1` to walk to the previous shot, `1` to walk to the next one.
  final int delta;

  /// Class constructor
  const OcptShotListFloorPlanShotWalkRequestedEvent({required this.delta});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, delta];
}

/// Records a tap on symbol `event.symbolId` while the canvas's own `arrow` tool is active,
/// dispatched by a symbol's own hit overlay.
///
/// One event backs the whole two-click interaction, the bloc rather than the widget deciding what
/// a click means — mirroring `OcptShotListCoverageWordClickedEvent`'s own three-state shape: with
/// no anchor pending, the tap picks `event.symbolId` as the arrow's first end; with an anchor
/// already pending and `event.symbolId` naming a different symbol, the tap completes a movement
/// arrow from the anchor to it (`OcptFloorPlanService.addArrow`, on the focused shot) and clears
/// the anchor; a tap on the anchor symbol itself is a no-op.
class OcptShotListFloorPlanArrowSymbolTappedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol tapped.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanArrowSymbolTappedEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Cancels the arrow tool's own pending anchor, dispatched by `Escape` (only while an anchor is
/// pending) or a click on empty canvas while the anchor tool is on — mirroring
/// `OcptShotListCoverageAnchorCancelledEvent`.
class OcptShotListFloorPlanArrowAnchorCancelledEvent extends OcptShotListFloorPlanSymbolEvent {
  /// Class constructor
  const OcptShotListFloorPlanArrowAnchorCancelledEvent();
}

/// Requests deleting arrow `event.arrowId` for good, dispatched once the Placements group's own
/// remove action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanArrowDeletionRequestedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the arrow to delete.
  final String arrowId;

  /// Class constructor
  const OcptShotListFloorPlanArrowDeletionRequestedEvent({required this.arrowId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, arrowId];
}

/// Records the raw text just typed into symbol `event.symbolId`'s own label, dispatched by the
/// canvas's own `label` tool inline text field on every keystroke. Rides the mode's field-edit
/// autosave debounce, keyed by `OcptShotListSymbolLabelEditKey`.
class OcptShotListFloorPlanSymbolLabelChangedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol whose label was edited.
  final String symbolId;

  /// The label's raw text, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListFloorPlanSymbolLabelChangedEvent({
    required this.symbolId,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, rawValue];
}

/// Sets camera symbol `event.symbolId`'s own field-of-view wedge angle to `event.fovDeg`,
/// dispatched by a drag on one of its own edge handles ending, or by the inspector's Placements
/// group `−`/`+` stepper. Written immediately (`OcptFloorPlanService.updateSymbol(fovDeg:)`); a
/// drag reports once on end, never per frame — the live wedge shown while dragging is a purely
/// local canvas concern, exactly as a symbol's own move/resize/rotate is.
class OcptShotListFloorPlanSymbolFovChangedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the camera symbol whose field of view is changed.
  final String symbolId;

  /// The camera's new field-of-view angle, in degrees.
  final double fovDeg;

  /// Class constructor
  const OcptShotListFloorPlanSymbolFovChangedEvent({required this.symbolId, required this.fovDeg});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, fovDeg];
}

/// Sets camera symbol `event.symbolId`'s own field-of-view wedge reach to `event.fovReachM`,
/// dispatched by a drag on its own tip handle ending. Written immediately
/// (`OcptFloorPlanService.updateSymbol(fovReachM:)`); a drag reports once on end, never per frame
/// — the live wedge shown while dragging is a purely local canvas concern, exactly as
/// [OcptShotListFloorPlanSymbolFovChangedEvent] is for the angle.
class OcptShotListFloorPlanSymbolFovReachChangedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the camera symbol whose field-of-view reach is changed.
  final String symbolId;

  /// The camera's new field-of-view wedge reach, in metres.
  final double fovReachM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolFovReachChangedEvent({
    required this.symbolId,
    required this.fovReachM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, fovReachM];
}

/// Selects arrow `event.arrowId` on the floor plans canvas, or clears the selection when it is
/// null — a click near the arrow's own shaft under the `select` tool, or a click on empty canvas or
/// on a symbol (the two selections are mutually exclusive). Never withheld: selecting only reads.
class OcptShotListFloorPlanArrowSelectedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the arrow to select, or null to clear the selection.
  final String? arrowId;

  /// Class constructor
  const OcptShotListFloorPlanArrowSelectedEvent({required this.arrowId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, arrowId];
}

/// Bends arrow `event.arrowId` through control point `event.ctrlXM`/`event.ctrlYM` (metres), or
/// straightens it back out when both are null, dispatched once a drag on its own midpoint handle
/// ends (`OcptFloorPlanService.updateArrowCurve`), or by the handle's own neighbouring straighten
/// button. Written as a single row, never per frame: the live drag position is a purely local
/// canvas concern, exactly as a symbol's own move/resize/rotate is.
class OcptShotListFloorPlanArrowCurveChangedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the arrow being bent or straightened.
  final String arrowId;

  /// The bezier control point's new X, in metres, or null to straighten the arrow.
  final double? ctrlXM;

  /// The bezier control point's new Y, in metres. See [ctrlXM].
  final double? ctrlYM;

  /// Class constructor
  const OcptShotListFloorPlanArrowCurveChangedEvent({
    required this.arrowId,
    required this.ctrlXM,
    required this.ctrlYM,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, arrowId, ctrlXM, ctrlYM];
}

/// Duplicates symbol `event.symbolId` into an independent copy on the very same set/shot/layer —
/// never a link, the copy carries no reference back to its source — dispatched by `Ctrl+D` (no
/// explicit position: the bloc offsets the copy from its source by `ocptFloorPlanDuplicateOffsetM`)
/// or by an `Alt`-drag ending (`event.xM`/`event.yM` the drag's own settled position, the source
/// symbol itself left untouched at its own original position). Written immediately
/// (`OcptFloorPlanService.placeSymbol`), then selects the new copy.
class OcptShotListFloorPlanSymbolDuplicatedEvent extends OcptShotListFloorPlanSymbolEvent {
  /// The id of the symbol duplicated.
  final String symbolId;

  /// The copy's own centre X, in metres, or null to offset it from the source by
  /// `ocptFloorPlanDuplicateOffsetM`.
  final double? xM;

  /// The copy's own centre Y, in metres. See [xM].
  final double? yM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolDuplicatedEvent({required this.symbolId, this.xM, this.yM});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId, xM, yM];
}
