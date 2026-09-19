// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The floor plan canvas's own tool bar picker: which gesture a click or a drag on the canvas
/// currently means (`docs/plans/storyboard.md`, §4.3).
///
/// Only the two tools the **sequence half** (M5) needs are declared here: [select] (the default —
/// click a symbol to select it, drag to move it, drag a handle to rotate or resize it) and
/// [setElement] (click empty canvas to place a new décor/furniture/fixed-prop symbol on the tray's
/// active sequence layer). The underlay import is a one-shot tool bar action, not a tool of its
/// own, so it has no case here. M6 (the shot half) adds `camera`, `character`, `light`, `arrow` and
/// `label` cases alongside these two — deliberately not added by this milestone, since none of them
/// has a write path yet and a case with nothing to place would be a dead branch in every `switch`
/// over this type.
enum OcptFloorPlanTool {
  /// The default tool: click a symbol to select it, drag to move it, drag a handle to rotate or
  /// resize it.
  select,

  /// Click empty canvas to place a new set element (décor, furniture or a fixed prop) on the
  /// tray's currently active sequence layer.
  setElement,
}
