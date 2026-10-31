// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// The floor plan canvas's own tool bar picker: which gesture a click or a drag on the canvas
/// currently means.
///
/// [select], [setElement] and [prop] are the **sequence-scoped** tools: [select] the default
/// (click a symbol to select it, drag to move it, drag a handle to rotate or resize it),
/// [setElement] click empty canvas to place a new décor/furniture symbol, either on the set's own
/// shared scope (the palette's `Set` group) or on the focused sequence's own scope alone (the
/// `Sequence` group), told apart by the placement's own scope rather than by this tool value
/// (`OcptFloorPlanPaletteDragPayload.sceneScope`/
/// `OcptShotListState.floorPlanActiveSetElementScope`); [prop] click empty canvas to place a new
/// breakdown prop, always on the focused sequence's own scope, carrying whichever label the
/// placing chip armed (`OcptFloorPlanPaletteDragPayload.label`/
/// `OcptShotListState.floorPlanActiveLabel`). The underlay import is a one-shot tool bar action,
/// not a tool of its own, so it has no case here.
///
/// [camera], [character] and [light] are **shot-scoped**: each places its own shot layer
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
