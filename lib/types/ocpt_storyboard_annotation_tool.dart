// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The board's active annotation editing tool, picked from the inspector's own `Annotate` control.
///
/// A **view/session state** value, exactly like `OcptStoryboardPanelSize`: held in
/// `OcptShotListState.activeAnnotationTool` for the session alone, never written to the project.
/// "Off" (no tool picked) is the field being null rather than a fourth value here, so a `switch`
/// over this type never has to name a no-op case. The tool is scoped to the currently selected
/// panel and is cleared whenever the selected panel, shot or sequence changes
/// (`OcptShotListState.activeAnnotationTool`'s own doc comment).
enum OcptStoryboardAnnotationTool {
  /// Draws a `OcptStoryboardAnnotationKind.movementArrow` on drag.
  movementArrow,

  /// Draws a `OcptStoryboardAnnotationKind.cameraMoveArrow` on drag.
  cameraMoveArrow,

  /// Places a `OcptStoryboardAnnotationKind.label` on click.
  label,
}
