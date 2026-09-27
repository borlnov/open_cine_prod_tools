// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// The floor plan canvas's own tool bar picker: which gesture a click or a drag on the canvas
/// currently means (`docs/plans/storyboard.md`, §4.3).
///
/// [select], [setElement] and [prop] are the **sequence-scoped** tools: [select] the default
/// (click a symbol to select it, drag to move it, drag a handle to rotate or resize it),
/// [setElement] click empty canvas to place a new décor/furniture symbol, either on the set's own
/// shared scope (the palette's `Set` group) or on the focused sequence's own scope alone (the
/// `Sequence` group — R5b, `docs/plans/storyboard.md`, §10.4), told apart by the placement's own
/// scope rather than by this tool value (`OcptFloorPlanPaletteDragPayload.sceneScope`/
/// `OcptShotListState.floorPlanActiveSetElementScope`); [prop] click empty canvas to place a new
/// breakdown prop, always on the focused sequence's own scope, carrying whichever label the
/// placing chip armed (`OcptFloorPlanPaletteDragPayload.label`/
/// `OcptShotListState.floorPlanActiveLabel`). The underlay import is a one-shot tool bar action,
/// not a tool of its own, so it has no case here.
///
/// [camera], [character] and [light] are **shot-scoped** (M6): each places its own shot layer
/// symbol under the focused shot only — the tool bar dims them under the `Sequence` focus, since
/// none has a shot to place into. [arrow] takes two clicks on two symbols (a pending anchor,
/// cancelled by `Escape` or a click on empty canvas) and adds a movement between them, always on
/// the focused shot; it is shot-scoped too, for the same reason. [label] edits the currently
/// selected symbol's own free-text label inline — the one tool with no scope of its own, since a
/// label may be set on a symbol of either scope.
enum OcptFloorPlanTool {
  /// The default tool: click a symbol to select it, drag to move it, drag a handle to rotate or
  /// resize it.
  select,

  /// Click empty canvas to place a new set element (décor or furniture), on the set's own shared
  /// scope or the focused sequence's own scope alone — see this enum's own doc comment.
  setElement,

  /// Click empty canvas to place a new breakdown prop, always on the focused sequence's own scope
  /// — see this enum's own doc comment.
  prop,

  /// Click empty canvas to place a new camera symbol on the focused shot.
  camera,

  /// Click empty canvas to place a new character symbol on the focused shot.
  character,

  /// Click empty canvas to place a new light symbol on the focused shot.
  light,

  /// Click two symbols in turn to draw a movement arrow between them, on the focused shot.
  arrow,

  /// Edits the currently selected symbol's own free-text label inline.
  label,
}

/// The fixed layer [tool] always places, or null for a tool whose own layer isn't fixed by the
/// tool alone ([OcptFloorPlanTool.setElement], always [OcptFloorPlanLayer.set] but placed at
/// either scope) or that places nothing ([OcptFloorPlanTool.select]/`.arrow`/`.label`).
OcptFloorPlanLayer? ocptFloorPlanFixedLayerOf(OcptFloorPlanTool tool) => switch (tool) {
  OcptFloorPlanTool.camera => OcptFloorPlanLayer.cameras,
  OcptFloorPlanTool.character => OcptFloorPlanLayer.characters,
  OcptFloorPlanTool.light => OcptFloorPlanLayer.lights,
  OcptFloorPlanTool.prop => OcptFloorPlanLayer.props,
  OcptFloorPlanTool.select ||
  OcptFloorPlanTool.setElement ||
  OcptFloorPlanTool.arrow ||
  OcptFloorPlanTool.label => null,
};

/// Whether a [OcptFloorPlanTool] only ever places or acts on the **focused shot**'s own shot
/// layers — [OcptFloorPlanTool.camera], [OcptFloorPlanTool.character], [OcptFloorPlanTool.light]
/// and [OcptFloorPlanTool.arrow] — the tool bar's own dimming rule under the `Sequence` focus.
extension OcptFloorPlanToolScope on OcptFloorPlanTool {
  /// True for the three shot-scoped tools plus [OcptFloorPlanTool.arrow]; false for
  /// [OcptFloorPlanTool.select], [OcptFloorPlanTool.setElement]/[OcptFloorPlanTool.prop]
  /// (sequence-scoped) and [OcptFloorPlanTool.label] (scope-free).
  bool get requiresShotFocus => switch (this) {
    OcptFloorPlanTool.select => false,
    OcptFloorPlanTool.setElement => false,
    OcptFloorPlanTool.prop => false,
    OcptFloorPlanTool.camera => true,
    OcptFloorPlanTool.character => true,
    OcptFloorPlanTool.light => true,
    OcptFloorPlanTool.arrow => true,
    OcptFloorPlanTool.label => false,
  };
}

/// One palette entry's own drag-and-drop payload (R3b, the typed set tools —
/// `docs/plans/storyboard.md`, §10.3): which [tool] a drop places, and — for one of the typed
/// [OcptFloorPlanTool.setElement] entries (wall/door/furniture/freeform) — which [setElementShape]
/// it places, which [sceneScope] it places at (R5b: the `Set` group's own four entries carry
/// [OcptFloorPlanScope.set], the `Sequence` group's own furniture/freeform pair carry
/// [OcptFloorPlanScope.scene]), or — for a [OcptFloorPlanTool.prop] chip — which [label] it places.
/// Carried on the drag itself rather than read back from a click-to-arm state, since a drag never
/// taps its source first: `OcptFloorPlanPalette`'s `Draggable<OcptFloorPlanPaletteDragPayload>` and
/// `OcptFloorPlanCanvas`'s own `DragTarget` of the same type are what carry it end to end.
class OcptFloorPlanPaletteDragPayload extends Equatable {
  /// The tool a drop of this payload places.
  final OcptFloorPlanTool tool;

  /// The set-element shape a drop of this payload places, or null for every entry but the typed
  /// set-element ones.
  final OcptFloorPlanSetElementShape? setElementShape;

  /// The scope a [OcptFloorPlanTool.setElement] drop places at ([OcptFloorPlanScope.set] or
  /// [OcptFloorPlanScope.scene]) — null for every entry but the typed set-element ones, which
  /// always set it.
  final OcptFloorPlanScope? sceneScope;

  /// A [OcptFloorPlanTool.prop] chip's own label — null for every other entry.
  final String? label;

  /// Class constructor
  const OcptFloorPlanPaletteDragPayload({
    required this.tool,
    this.setElementShape,
    this.sceneScope,
    this.label,
  });

  /// Object properties
  @override
  List<Object?> get props => [tool, setElementShape, sceneScope, label];
}
