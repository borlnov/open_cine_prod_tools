// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListFloorPlanCanvasBloc`, about the gestures made on the floor plans
/// canvas: the tool, the selection, the placement, the move, resize and rotation of a symbol, the
/// arrows and the scope decision a shared symbol asks for.
sealed class OcptShotListFloorPlanCanvasEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanCanvasEvent();
}

/// Picks the floor plans canvas's own active tool, dispatched by the tool bar.
class OcptShotListFloorPlanToolSelectedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// The tool just picked.
  final OcptFloorPlanTool tool;

  /// Class constructor
  const OcptShotListFloorPlanToolSelectedEvent({required this.tool});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, tool];
}

/// Clears `OcptShotListFloorPlanCanvasState.pendingCharacterNamePromptSymbolId`, dispatched by the
/// mode's own `BlocListener` the moment it opens `OcptFloorPlanCharacterNamePickerDialog` for it —
/// see that field's own doc comment for why the clear happens before the dialog's own result is
/// known.
class OcptShotListFloorPlanCharacterNamePromptDismissedEvent
    extends OcptShotListFloorPlanCanvasEvent {
  /// Class constructor
  const OcptShotListFloorPlanCharacterNamePromptDismissedEvent();
}

/// Places a new set element symbol on set `event.setId`'s `event.layer`, at `event.xM`/`event.yM`
/// (metres), dispatched by a click on empty canvas while the `setElement` tool is on. Written
/// immediately (`OcptFloorPlanService.placeSymbol`), then selects the freshly minted symbol.
class OcptShotListFloorPlanSymbolPlacedEvent extends OcptShotListFloorPlanCanvasEvent {
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
  /// `OcptShotListFloorPlanSetsState.floorPlanActiveSetElementShape`. Null on every other layer.
  final OcptFloorPlanSetElementShape? setElementShape;

  /// A `prop` placement's own armed label — from the placing chip's own drag payload or the
  /// click-to-armed `OcptShotListFloorPlanSetsState.floorPlanActiveLabel`. Empty on every other layer.
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
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
class OcptShotListFloorPlanSymbolSelectedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// The id of the symbol to select, or null to clear the selection.
  final String? symbolId;

  /// Class constructor
  const OcptShotListFloorPlanSymbolSelectedEvent({required this.symbolId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Moves symbol `event.symbolId` to `event.xM`/`event.yM` (metres), dispatched once a drag on it
/// ends. Written as a single row (`OcptFloorPlanService.updateSymbol`), never per frame: the live
/// drag position is a purely local widget concern, exactly as the underlay's own drag is.
class OcptShotListFloorPlanSymbolMovedEvent extends OcptShotListFloorPlanCanvasEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId, xM, yM];
}

/// Resizes set element symbol `event.symbolId` to `event.widthM`/`event.heightM` (metres),
/// dispatched once a drag on its own resize handle ends. Written as a single row, never per frame.
class OcptShotListFloorPlanSymbolResizedEvent extends OcptShotListFloorPlanCanvasEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId, widthM, heightM];
}

/// Rotates symbol `event.symbolId` to `event.rotationDeg`, dispatched once a drag on its own
/// rotate handle ends. Written as a single row, never per frame.
class OcptShotListFloorPlanSymbolRotatedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// The id of the symbol being rotated.
  final String symbolId;

  /// The symbol's new rotation, in degrees.
  final double rotationDeg;

  /// Class constructor
  const OcptShotListFloorPlanSymbolRotatedEvent({
    required this.symbolId,
    required this.rotationDeg,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId, rotationDeg];
}

/// Reports a move, rotate or resize awaiting the scope bubble's own answer, dispatched by the mode
/// instead of writing anything, the instant such a gesture ends — a **set-scope** symbol
/// belonging to a set linked to
/// `event.sequenceCount` (two or more) sequences ([OcptFloorPlanOverrideLevel.sequence]), or a
/// **scene-scope** symbol of a sequence with two or more shots ([OcptFloorPlanOverrideLevel.shot]).
/// Only stores `OcptShotListFloorPlanCanvasState.pendingFloorPlanScopeDecision`;
/// [OcptShotListFloorPlanScopeDecisionResolvedEvent] is what actually writes (or drops) it.
class OcptShotListFloorPlanScopeDecisionRequestedEvent extends OcptShotListFloorPlanCanvasEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
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

/// Resolves `OcptShotListFloorPlanCanvasState.pendingFloorPlanScopeDecision` — the scope bubble's own `Every
/// sequence`/`Only sequence n`/`Cancel` — writing it (onto the original, or onto a scene-scope
/// override of the focused sequence, creating one if none exists yet) or simply dropping it.
/// A no-op while nothing is pending.
class OcptShotListFloorPlanScopeDecisionResolvedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// Which of the bubble's own three answers was picked.
  final OcptFloorPlanScopeChoice choice;

  /// Class constructor
  const OcptShotListFloorPlanScopeDecisionResolvedEvent({required this.choice});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, choice];
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
class OcptShotListFloorPlanArrowSymbolTappedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// The id of the symbol tapped.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanArrowSymbolTappedEvent({required this.symbolId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Cancels the arrow tool's own pending anchor, dispatched by `Escape` (only while an anchor is
/// pending) or a click on empty canvas while the anchor tool is on — mirroring
/// `OcptShotListCoverageAnchorCancelledEvent`.
class OcptShotListFloorPlanArrowAnchorCancelledEvent extends OcptShotListFloorPlanCanvasEvent {
  /// Class constructor
  const OcptShotListFloorPlanArrowAnchorCancelledEvent();
}

/// Selects arrow `event.arrowId` on the floor plans canvas, or clears the selection when it is
/// null — a click near the arrow's own shaft under the `select` tool, or a click on empty canvas or
/// on a symbol (the two selections are mutually exclusive). Never withheld: selecting only reads.
class OcptShotListFloorPlanArrowSelectedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// The id of the arrow to select, or null to clear the selection.
  final String? arrowId;

  /// Class constructor
  const OcptShotListFloorPlanArrowSelectedEvent({required this.arrowId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, arrowId];
}

/// Bends arrow `event.arrowId` through control point `event.ctrlXM`/`event.ctrlYM` (metres), or
/// straightens it back out when both are null, dispatched once a drag on its own midpoint handle
/// ends (`OcptFloorPlanService.updateArrowCurve`), or by the handle's own neighbouring straighten
/// button. Written as a single row, never per frame: the live drag position is a purely local
/// canvas concern, exactly as a symbol's own move/resize/rotate is.
class OcptShotListFloorPlanArrowCurveChangedEvent extends OcptShotListFloorPlanCanvasEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, arrowId, ctrlXM, ctrlYM];
}

/// Duplicates symbol `event.symbolId` into an independent copy on the very same set/shot/layer —
/// never a link, the copy carries no reference back to its source — dispatched by `Ctrl+D` (no
/// explicit position: the bloc offsets the copy from its source by `ocptFloorPlanDuplicateOffsetM`)
/// or by an `Alt`-drag ending (`event.xM`/`event.yM` the drag's own settled position, the source
/// symbol itself left untouched at its own original position). Written immediately
/// (`OcptFloorPlanService.placeSymbol`), then selects the new copy.
class OcptShotListFloorPlanSymbolDuplicatedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// The id of the symbol duplicated.
  final String symbolId;

  /// The copy's own centre X, in metres, or null to offset it from the source by
  /// `ocptFloorPlanDuplicateOffsetM`.
  final double? xM;

  /// The copy's own centre Y, in metres. See [xM].
  final double? yM;

  /// Class constructor
  const OcptShotListFloorPlanSymbolDuplicatedEvent({required this.symbolId, this.xM, this.yM});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId, xM, yM];
}

/// Dismisses the transient write error the floor plan canvas bloc raised.
class OcptShotListFloorPlanCanvasWriteErrorDismissedEvent extends OcptShotListFloorPlanCanvasEvent {
  /// Class constructor
  const OcptShotListFloorPlanCanvasWriteErrorDismissedEvent();
}
