// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// The board's active annotation editing tool, picked from the inspector's own `Annotate` control
/// (`docs/plans/storyboard.md`, §4.2).
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

/// What [OcptStoryboardAnnotationTool] reads and writes as, and how it behaves — kept as an
/// extension rather than fields on the enum itself, since both only ever matter to the board's own
/// gesture layer.
extension OcptStoryboardAnnotationToolBehaviour on OcptStoryboardAnnotationTool {
  /// The kind of mark this tool draws.
  OcptStoryboardAnnotationKind get kind => switch (this) {
    OcptStoryboardAnnotationTool.movementArrow => OcptStoryboardAnnotationKind.movementArrow,
    OcptStoryboardAnnotationTool.cameraMoveArrow => OcptStoryboardAnnotationKind.cameraMoveArrow,
    OcptStoryboardAnnotationTool.label => OcptStoryboardAnnotationKind.label,
  };

  /// Whether this tool draws by dragging (an arrow, tail to head) rather than by a single click (a
  /// label): what the board's gesture layer wires its `onPan…` callbacks against.
  bool get isDrag => this != OcptStoryboardAnnotationTool.label;
}
