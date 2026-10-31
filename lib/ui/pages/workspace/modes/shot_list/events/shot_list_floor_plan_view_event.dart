// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListBloc` about floor plan sets and view settings.
sealed class OcptShotListFloorPlanViewEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanViewEvent();
}

/// Selects set `event.setId` on the floor plans view, dispatched by a click on its own tab.
/// Clears the symbol selection: a symbol only ever belongs to the set currently shown.
class OcptShotListSetSelectedEvent extends OcptShotListFloorPlanViewEvent {
  /// The id of the set to select.
  final String setId;

  /// Class constructor
  const OcptShotListSetSelectedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Requests creating a new Resources set named after the selected sequence's scene heading's
/// place, linked to it (`OcptLocationsService.createSetLinkedToScene`), then selects it. Does
/// nothing while no sequence is selected, or while the selected one is the orphan group: a set
/// tab only ever belongs to a real screenplay scene, exactly as a new shot only ever belongs to
/// one.
///
/// [locationId] names the location the `＋ Set` menu's own `Create a set ▸` submenu entry was
/// clicked under, or null for its own `New location…` entry — `OcptLocationsService
/// .createSetLinkedToScene`'s own reading of a null `locationId` (mint a location of its own) is
/// exactly what that entry asks for, so this event carries the field verbatim rather than
/// resolving it itself.
class OcptShotListSetCreationRequestedEvent extends OcptShotListFloorPlanViewEvent {
  /// The location to create the new set in, or null to mint one of its own.
  final String? locationId;

  /// Class constructor
  const OcptShotListSetCreationRequestedEvent({this.locationId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId];
}

/// Requests linking Resources set [setId] to the selected sequence
/// (`OcptLocationsService.assignSceneToSet`), then selects it — the empty-state gallery's own
/// card click and the `＋ Set` menu's own suggestion entry and `Link an existing set ▸` submenu
/// entries. Does nothing while no sequence is selected, or
/// while the selected one is the orphan group, exactly like
/// [OcptShotListSetCreationRequestedEvent].
class OcptShotListSetLinkRequestedEvent extends OcptShotListFloorPlanViewEvent {
  /// The id of the Resources set to link.
  final String setId;

  /// Class constructor
  const OcptShotListSetLinkRequestedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Records the raw text just typed into set `event.setId`'s own tab as a pending edit, and
/// (re)starts the field-edit debounce shared with every other typed field of the mode.
class OcptShotListSetNameChangedEvent extends OcptShotListFloorPlanViewEvent {
  /// The id of the set whose name was edited.
  final String setId;

  /// The set's new name, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListSetNameChangedEvent({required this.setId, required this.rawValue});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, rawValue];
}

/// Requests unlinking set `event.setId` from the selected sequence
/// (`OcptLocationsService.removeSceneFromSet`), dispatched once the tab's own close action has
/// already been confirmed through `OcptConfirmDialog`, by the mode. The plan itself is kept —
/// relinking the set brings its placements back. Clears the selection (and, with it, the symbol
/// selection) when it was the selected set.
class OcptShotListSetDeletionRequestedEvent extends OcptShotListFloorPlanViewEvent {
  /// The id of the set to unlink.
  final String setId;

  /// Class constructor
  const OcptShotListSetDeletionRequestedEvent({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId];
}

/// Duplicates set `event.setId` into a new Resources set named `event.newSetName`, in the same
/// location, linked to the selected sequence (`OcptFloorPlanService.duplicateSet`,
/// `OcptLocationsService.createSiblingSet`/`.assignSceneToSet`), dispatched by the set tabs' own
/// `＋ Set` menu's `Duplicate this set` entry. Selects the
/// freshly minted copy once written.
class OcptShotListSetDuplicationRequestedEvent extends OcptShotListFloorPlanViewEvent {
  /// The id of the set to duplicate.
  final String setId;

  /// The new set's own name — computed by the mode (which has `Tr`) from the source set's current
  /// name, no localisation happening in a service or a bloc.
  final String newSetName;

  /// Class constructor
  const OcptShotListSetDuplicationRequestedEvent({required this.setId, required this.newSetName});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, newSetName];
}

/// Copies shot `event.sourceShotId`'s own live blocking on set `event.setId` onto the currently
/// focused shot (`OcptFloorPlanService.copyShotBlocking`), dispatched by the set tabs' own
/// `＋ Set` menu's `Copy blocking from another shot` entry, once the mode's own source-shot picker
/// has returned a pick.
class OcptShotListFloorPlanBlockingCopyRequestedEvent extends OcptShotListFloorPlanViewEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, sourceShotId];
}

/// Records the floor plans canvas's own zoom as last **settled** by
/// `OcptFloorPlanViewportController`, dispatched once a zoom gesture (the tool bar's `−`/`+`
/// buttons, or the canvas's own scroll-wheel zoom, debounced) ends — never per frame. A view
/// preference, held for the session alone; see `OcptShotListState.floorPlanZoom`'s own doc comment.
class OcptShotListFloorPlanZoomChangedEvent extends OcptShotListFloorPlanViewEvent {
  /// The zoom just settled on.
  final double zoom;

  /// Class constructor
  const OcptShotListFloorPlanZoomChangedEvent({required this.zoom});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, zoom];
}

/// Picks the floor plans canvas's own active tool, dispatched by the tool bar.
class OcptShotListFloorPlanToolSelectedEvent extends OcptShotListFloorPlanViewEvent {
  /// The tool just picked.
  final OcptFloorPlanTool tool;

  /// Class constructor
  const OcptShotListFloorPlanToolSelectedEvent({required this.tool});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tool];
}

/// Picks the sequence layer a placed set element lands on, dispatched by a click on one of the
/// tray's own sequence layer rows.
class OcptShotListFloorPlanActiveLayerChangedEvent extends OcptShotListFloorPlanViewEvent {
  /// The layer just picked. Always sequence-scoped: the tray only ever offers sequence layer
  /// rows.
  final OcptFloorPlanLayer layer;

  /// Class constructor
  const OcptShotListFloorPlanActiveLayerChangedEvent({required this.layer});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, layer];
}

/// Picks the décor primitive a `setElement` placement carries, dispatched by a click on one of the
/// palette's own four typed set-element entries (wall/door/furniture/freeform).
class OcptShotListFloorPlanActiveSetElementShapeChangedEvent
    extends OcptShotListFloorPlanViewEvent {
  /// The shape just picked.
  final OcptFloorPlanSetElementShape shape;

  /// Class constructor
  const OcptShotListFloorPlanActiveSetElementShapeChangedEvent({required this.shape});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shape];
}

/// Picks the scope a `setElement` placement lands at, dispatched by a click on one of the
/// palette's own typed set-element entries — [OcptFloorPlanScope.set] for the `Set` group's own
/// four, [OcptFloorPlanScope.scene] for the `Sequence` group's own furniture/freeform pair.
class OcptShotListFloorPlanActiveSetElementScopeChangedEvent
    extends OcptShotListFloorPlanViewEvent {
  /// The scope just picked.
  final OcptFloorPlanScope scope;

  /// Class constructor
  const OcptShotListFloorPlanActiveSetElementScopeChangedEvent({required this.scope});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, scope];
}

/// Picks the label a `prop` placement carries, dispatched by a click on one of the palette's
/// own breakdown-props chips, or by the `Other…` chip's own name picker resolving.
class OcptShotListFloorPlanActiveLabelChangedEvent extends OcptShotListFloorPlanViewEvent {
  /// The label just picked.
  final String label;

  /// Class constructor
  const OcptShotListFloorPlanActiveLabelChangedEvent({required this.label});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, label];
}

/// Toggles the visibility of sequence layer `event.layer` on the floor plans canvas, dispatched by
/// the tray's own eye icon. A view preference; never withheld under a read-only preview, since it
/// only reads.
class OcptShotListFloorPlanLayerVisibilityToggledEvent extends OcptShotListFloorPlanViewEvent {
  /// The layer whose visibility is toggled.
  final OcptFloorPlanLayer layer;

  /// Class constructor
  const OcptShotListFloorPlanLayerVisibilityToggledEvent({required this.layer});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, layer];
}

/// Toggles the selected set's underlay visibility on the floor plans canvas, dispatched by the
/// tray's own underlay row eye icon. A view preference; never withheld under a read-only preview.
class OcptShotListFloorPlanUnderlayVisibilityToggledEvent extends OcptShotListFloorPlanViewEvent {
  /// Class constructor
  const OcptShotListFloorPlanUnderlayVisibilityToggledEvent();
}

/// Toggles the visibility of camera symbol `event.symbolId` on the floor plans canvas, dispatched
/// by the tray's own per-camera eye under the `Sequence` focus's expanded cameras row. A view
/// preference; never withheld under a read-only preview, since it only reads.
class OcptShotListFloorPlanCameraVisibilityToggledEvent extends OcptShotListFloorPlanViewEvent {
  /// The id of the camera symbol whose visibility is toggled.
  final String symbolId;

  /// Class constructor
  const OcptShotListFloorPlanCameraVisibilityToggledEvent({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, symbolId];
}

/// Toggles the onion skin's own previous (`event.isPrevious`) or next neighbour, dispatched by the
/// tray's own `Onion skin` block. A view preference.
class OcptShotListFloorPlanOnionSkinToggledEvent extends OcptShotListFloorPlanViewEvent {
  /// Whether the previous shot's own ghost is toggled (true) or the next shot's (false).
  final bool isPrevious;

  /// Class constructor
  const OcptShotListFloorPlanOnionSkinToggledEvent({required this.isPrevious});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isPrevious];
}

/// Sets the onion skin's own ghost opacity, dispatched by the tray's own `Onion skin` block slider.
/// A view preference.
class OcptShotListFloorPlanOnionSkinOpacityChangedEvent extends OcptShotListFloorPlanViewEvent {
  /// The new opacity, 0..1.
  final double opacity;

  /// Class constructor
  const OcptShotListFloorPlanOnionSkinOpacityChangedEvent({required this.opacity});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, opacity];
}

/// Toggles the metrics overlay, dispatched by the tray's own metrics toggle. A view preference.
class OcptShotListFloorPlanMetricsToggledEvent extends OcptShotListFloorPlanViewEvent {
  /// Class constructor
  const OcptShotListFloorPlanMetricsToggledEvent();
}

/// Clears `OcptShotListState.pendingCharacterNamePromptSymbolId`, dispatched by the mode's own
/// `BlocConsumer` listener the moment it opens `OcptFloorPlanCharacterNamePickerDialog` for it —
/// see that field's own doc comment for why the clear happens before the dialog's own result is
/// known.
class OcptShotListFloorPlanCharacterNamePromptDismissedEvent
    extends OcptShotListFloorPlanViewEvent {
  /// Class constructor
  const OcptShotListFloorPlanCharacterNamePromptDismissedEvent();
}
