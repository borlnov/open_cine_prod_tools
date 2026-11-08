// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListFloorPlanSetsBloc`, about the floor plans' sets, their underlays and
/// what the tray and the tool bar show of them.
sealed class OcptShotListFloorPlanSetsEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanSetsEvent();
}

/// Request creating a new Resources set named after the selected sequence's scene heading's place,
/// linked to it (`OcptLocationsService.createSetLinkedToScene`), then select it. Does
/// nothing while no sequence is selected, or while the selected one is the orphan group: a set
/// tab only ever belongs to a real screenplay scene, exactly as a new shot only ever belongs to
/// one.
///
/// [locationId] names the location the `＋ Set` menu's own `Create a set ▸` submenu entry was
/// clicked under, or null for its own `New location…` entry — `OcptLocationsService
/// .createSetLinkedToScene`'s own reading of a null `locationId` (mint a location of its own) is
/// exactly what that entry asks for, so this event carries the field verbatim rather than
/// resolving it itself.
class OcptShotListSetCreationRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The location to create the new set in, or null to mint one of its own.
  final String? locationId;

  /// Class constructor
  const OcptShotListSetCreationRequestedEvent({this.locationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Request linking Resources set [setId] to the selected sequence
/// (`OcptLocationsService.assignSceneToSet`), then select it — the empty-state gallery's own
/// card click and the `＋ Set` menu's own suggestion entry and `Link an existing set ▸` submenu
/// entries. Does nothing while no sequence is selected, or
/// while the selected one is the orphan group, exactly like
/// [OcptShotListSetCreationRequestedEvent].
class OcptShotListSetLinkRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the Resources set to link.
  final String setId;

  /// Class constructor
  const OcptShotListSetLinkRequestedEvent({required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Record the raw text just typed into set `event.setId`'s own tab as a pending edit, and
/// (re)starts the sets bloc's field-edit debounce.
class OcptShotListSetNameChangedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the set whose name was edited.
  final String setId;

  /// The set's new name, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListSetNameChangedEvent({required this.setId, required this.rawValue});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, rawValue];
}

/// Request unlinking set `event.setId` from the selected sequence
/// (`OcptLocationsService.removeSceneFromSet`), dispatched once the tab's own close action has
/// already been confirmed through `OcptConfirmDialog`, by the mode. The plan itself is kept —
/// relinking the set brings its placements back. Clears the selection (and, with it, the symbol
/// selection) when it was the selected set.
class OcptShotListSetDeletionRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the set to unlink.
  final String setId;

  /// Class constructor
  const OcptShotListSetDeletionRequestedEvent({required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Duplicate set `event.setId` into a new Resources set named `event.newSetName`, in the same
/// location, linked to the selected sequence (`OcptFloorPlanService.duplicateSet`,
/// `OcptLocationsService.createSiblingSet`/`.assignSceneToSet`), dispatched by the set tabs' own
/// `＋ Set` menu's `Duplicate this set` entry. Selects the
/// freshly minted copy once written.
class OcptShotListSetDuplicationRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the set to duplicate.
  final String setId;

  /// The new set's own name — computed by the mode (which has `Tr`) from the source set's current
  /// name, no localisation happening in a service or a bloc.
  final String newSetName;

  /// Class constructor
  const OcptShotListSetDuplicationRequestedEvent({required this.setId, required this.newSetName});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, newSetName];
}

/// Copy shot `event.sourceShotId`'s own live blocking on set `event.setId` onto the currently
/// focused shot (`OcptFloorPlanService.copyShotBlocking`), dispatched by the set tabs' own
/// `＋ Set` menu's `Copy blocking from another shot` entry, once the mode's own source-shot picker
/// has returned a pick.
class OcptShotListFloorPlanBlockingCopyRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the set the blocking is copied on (both the source and the destination — the menu
  /// only offers a same-set copy).
  final String setId;

  /// The id of the shot the blocking is copied from.
  final String sourceShotId;

  /// Class constructor
  const OcptShotListFloorPlanBlockingCopyRequestedEvent({
    required this.setId,
    required this.sourceShotId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, sourceShotId];
}

/// Record the floor plans canvas's own zoom as last **settled** by
/// `OcptFloorPlanViewportController`, dispatched once a zoom gesture (the tool bar's `−`/`+`
/// buttons, or the canvas's own scroll-wheel zoom, debounced) ends — never per frame. A view
/// preference, held for the session alone; see `OcptShotListFloorPlanSetsState.floorPlanZoom`'s own
/// doc comment.
class OcptShotListFloorPlanZoomChangedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The zoom just settled on.
  final double zoom;

  /// Class constructor
  const OcptShotListFloorPlanZoomChangedEvent({required this.zoom});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, zoom];
}

/// Pick the décor primitive a `setElement` placement carries, dispatched by a click on one of the
/// palette's own four typed set-element entries (wall/door/furniture/freeform).
class OcptShotListFloorPlanActiveSetElementShapeChangedEvent
    extends OcptShotListFloorPlanSetsEvent {
  /// The shape just picked.
  final OcptFloorPlanSetElementShape shape;

  /// Class constructor
  const OcptShotListFloorPlanActiveSetElementShapeChangedEvent({required this.shape});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shape];
}

/// Pick the scope a `setElement` placement lands at, dispatched by a click on one of the
/// palette's own typed set-element entries — [OcptFloorPlanScope.set] for the `Set` group's own
/// four, [OcptFloorPlanScope.scene] for the `Sequence` group's own furniture/freeform pair.
class OcptShotListFloorPlanActiveSetElementScopeChangedEvent
    extends OcptShotListFloorPlanSetsEvent {
  /// The scope just picked.
  final OcptFloorPlanScope scope;

  /// Class constructor
  const OcptShotListFloorPlanActiveSetElementScopeChangedEvent({required this.scope});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, scope];
}

/// Pick the label a `prop` placement carries, dispatched by a click on one of the palette's
/// own breakdown-props chips, or by the `Other…` chip's own name picker resolving.
class OcptShotListFloorPlanActiveLabelChangedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The label just picked.
  final String label;

  /// Class constructor
  const OcptShotListFloorPlanActiveLabelChangedEvent({required this.label});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, label];
}

/// Toggle the visibility of sequence layer `event.layer` on the floor plans canvas, dispatched by
/// the tray's own eye icon. A view preference; never withheld under a read-only preview, since it
/// only reads.
class OcptShotListFloorPlanLayerVisibilityToggledEvent extends OcptShotListFloorPlanSetsEvent {
  /// The layer whose visibility is toggled.
  final OcptFloorPlanLayer layer;

  /// Class constructor
  const OcptShotListFloorPlanLayerVisibilityToggledEvent({required this.layer});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, layer];
}

/// Toggle the selected set's underlay visibility on the floor plans canvas, dispatched by the
/// tray's own underlay row eye icon. A view preference; never withheld under a read-only preview.
class OcptShotListFloorPlanUnderlayVisibilityToggledEvent extends OcptShotListFloorPlanSetsEvent {
  /// Class constructor
  const OcptShotListFloorPlanUnderlayVisibilityToggledEvent();
}

/// Toggle the visibility of camera symbol `event.symbolId` on the floor plans canvas, dispatched
/// by the tray's own per-camera eye under the `Sequence` focus's expanded cameras row. A view
/// preference; never withheld under a read-only preview, since it only reads.
class OcptShotListFloorPlanCameraVisibilityToggledEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the camera symbol whose visibility is toggled.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanCameraVisibilityToggledEvent({required this.symbolId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Toggle the onion skin's own previous (`event.isPrevious`) or next neighbour, dispatched by the
/// tray's own `Onion skin` block. A view preference.
class OcptShotListFloorPlanOnionSkinToggledEvent extends OcptShotListFloorPlanSetsEvent {
  /// Whether the previous shot's own ghost is toggled (true) or the next shot's (false).
  final bool isPrevious;

  /// Class constructor
  const OcptShotListFloorPlanOnionSkinToggledEvent({required this.isPrevious});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, isPrevious];
}

/// Set the onion skin's own ghost opacity, dispatched by the tray's own `Onion skin` block slider.
/// A view preference.
class OcptShotListFloorPlanOnionSkinOpacityChangedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The new opacity, 0..1.
  final double opacity;

  /// Class constructor
  const OcptShotListFloorPlanOnionSkinOpacityChangedEvent({required this.opacity});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, opacity];
}

/// Toggle the metrics overlay, dispatched by the tray's own metrics toggle. A view preference.
class OcptShotListFloorPlanMetricsToggledEvent extends OcptShotListFloorPlanSetsEvent {
  /// Class constructor
  const OcptShotListFloorPlanMetricsToggledEvent();
}

/// Request importing set `event.setId`'s underlay, dispatched by the tool bar's own underlay
/// action.
///
/// The bloc picks the file through `FileSelectorManager`, filtered to JPEG and PNG
/// (`ocptFloorPlanUnderlayImageFileExtensions`), then places it at a default frame centred on the
/// canvas — the user drags and resizes it to match the reference silhouette afterwards (ADR 0031).
/// A cancelled dialog changes nothing at all. [fileTypeLabel] is the localized label the native
/// picker's own file type filter shows, resolved by the mode.
class OcptShotListFloorPlanUnderlayImportRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the set the underlay is set on.
  final String setId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayImportRequestedEvent({
    required this.setId,
    required this.fileTypeLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, fileTypeLabel];
}

/// Set set `event.setId`'s underlay frame to `event.xM`/`event.yM`/`event.widthM`/
/// `event.heightM` (metres), dispatched once a drag moving or resizing it ends. Written as a
/// single call (`OcptFloorPlanService.setSetUnderlay`, re-pointed at the same already-imported
/// file), never per frame.
class OcptShotListFloorPlanUnderlayTransformChangedEvent extends OcptShotListFloorPlanSetsEvent {
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

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, xM, yM, widthM, heightM];
}

/// Request clearing set `event.setId`'s underlay for good, dispatched once the tray's own
/// `Clear underlay` action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListFloorPlanUnderlayClearRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the set whose underlay is cleared.
  final String setId;

  /// Class constructor
  const OcptShotListFloorPlanUnderlayClearRequestedEvent({required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Walk the selected sequence's own shots by `event.delta` (`-1` for `←`, `1` for `→`),
/// dispatched by the floor plans focus strip's own keyboard shortcut. Selects the sequence's first
/// shot when nothing is selected yet and `event.delta` is positive, does nothing at either end of
/// the list, and does nothing while the selected sequence is the orphan group (its shots have no
/// set to draw a floor plan on).
class OcptShotListFloorPlanShotWalkRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// `-1` to walk to the previous shot, `1` to walk to the next one.
  final int delta;

  /// Class constructor
  const OcptShotListFloorPlanShotWalkRequestedEvent({required this.delta});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, delta];
}

/// Write every set name still sitting in the sets bloc's autosave debounce, dispatched by the
/// debounce timer elapsing with no further typing.
class OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// Class constructor
  const OcptShotListFloorPlanSetsFieldEditFlushRequestedEvent();
}

/// Read the breakdown props of sequence [sequenceId] for the palette's `Sequence` group chips,
/// dispatched by the sets bloc to itself when the mode loads or moves to another sequence.
class OcptShotListFloorPlanPropsLoadRequestedEvent extends OcptShotListFloorPlanSetsEvent {
  /// The id of the sequence whose props are read, or null while none is selected.
  final String? sequenceId;

  /// Class constructor
  const OcptShotListFloorPlanPropsLoadRequestedEvent({required this.sequenceId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sequenceId];
}

/// Dismiss the transient write error the floor plan sets bloc raised.
class OcptShotListFloorPlanSetsWriteErrorDismissedEvent extends OcptShotListFloorPlanSetsEvent {
  /// Class constructor
  const OcptShotListFloorPlanSetsWriteErrorDismissedEvent();
}
