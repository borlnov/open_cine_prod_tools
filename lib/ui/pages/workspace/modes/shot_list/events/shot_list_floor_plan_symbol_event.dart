// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListBloc` about floor plan symbols, arrows, scope and underlay.
sealed class OcptShotListFloorPlanSymbolEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanSymbolEvent();
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
