// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';

/// What [OcptStoryboardAnnotationTool] reads and writes as, and how it behaves — kept as an
/// extension rather than fields on the enum itself, since both only ever matter to the board's own
/// gesture layer.
extension OcptStoryboardAnnotationToolBehaviour on OcptStoryboardAnnotationTool {
  /// Get the kind of mark this tool draws.
  OcptStoryboardAnnotationKind get kind => switch (this) {
    OcptStoryboardAnnotationTool.movementArrow => OcptStoryboardAnnotationKind.movementArrow,
    OcptStoryboardAnnotationTool.cameraMoveArrow => OcptStoryboardAnnotationKind.cameraMoveArrow,
    OcptStoryboardAnnotationTool.label => OcptStoryboardAnnotationKind.label,
  };

  /// Tell whether this tool draws by dragging (an arrow, tail to head) rather than by a single
  /// click (a
  /// label): what the board's gesture layer wires its `onPan…` callbacks against.
  bool get isDrag => this != OcptStoryboardAnnotationTool.label;
}
