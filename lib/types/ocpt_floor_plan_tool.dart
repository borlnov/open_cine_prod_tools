// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The floor plan canvas's own tool bar picker: which gesture a click or a drag on the canvas
/// currently means (`docs/plans/storyboard.md`, §4.3).
///
/// [select] and [setElement] are the **sequence-scoped** tools (M5): [select] the default (click a
/// symbol to select it, drag to move it, drag a handle to rotate or resize it), [setElement] click
/// empty canvas to place a new décor/furniture/fixed-prop symbol on the tray's active sequence
/// layer. The underlay import is a one-shot tool bar action, not a tool of its own, so it has no
/// case here.
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

  /// Click empty canvas to place a new set element (décor, furniture or a fixed prop) on the
  /// tray's currently active sequence layer.
  setElement,

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

/// Whether a [OcptFloorPlanTool] only ever places or acts on the **focused shot**'s own shot
/// layers — [OcptFloorPlanTool.camera], [OcptFloorPlanTool.character], [OcptFloorPlanTool.light]
/// and [OcptFloorPlanTool.arrow] — the tool bar's own dimming rule under the `Sequence` focus.
extension OcptFloorPlanToolScope on OcptFloorPlanTool {
  /// True for the four shot-scoped tools; false for [OcptFloorPlanTool.select],
  /// [OcptFloorPlanTool.setElement] (sequence-scoped) and [OcptFloorPlanTool.label] (scope-free).
  bool get requiresShotFocus => switch (this) {
    OcptFloorPlanTool.select => false,
    OcptFloorPlanTool.setElement => false,
    OcptFloorPlanTool.camera => true,
    OcptFloorPlanTool.character => true,
    OcptFloorPlanTool.light => true,
    OcptFloorPlanTool.arrow => true,
    OcptFloorPlanTool.label => false,
  };
}
