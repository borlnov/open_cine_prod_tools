// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// Keep the point of the page the zoom was made around where it was on screen: the one under the
/// pointer for a Ctrl + wheel notch, the centre of the area for any other way to zoom.
///
/// Zooming re-typesets the page, so everything in it moves away from (or towards) the origin by the
/// ratio of the two zooms: scrolling to `(offset + focal) * ratio - focal` leaves [focal] on the
/// same content. Horizontally the sheet may also move, since it is centred while it fits the
/// area, which [apply] takes into account.
final class OcptStyledZoomAnchor {
  /// The point, in the editor's own coordinates, the next zoom change is made around, or null to
  /// use the centre of the area; consumed by [apply].
  Offset? focal;

  /// The controller of the vertical scroll.
  final ScrollController _vertical;

  /// The controller of the horizontal scroll.
  final ScrollController _horizontal;

  /// Class constructor
  OcptStyledZoomAnchor({
    required ScrollController vertical,
    required ScrollController horizontal,
  }) : _vertical = vertical,
       _horizontal = horizontal;

  /// Get the callback of a Ctrl + wheel notch (`OcptEditorZoomWheel`) that remembers where the
  /// pointer is and then forwards the way to step to [onZoomStepRequested], or null when that is.
  void Function(int direction, Offset localPosition)? wheelCallback(
    ValueChanged<int>? onZoomStepRequested,
  ) {
    if (onZoomStepRequested == null) {
      return null;
    }

    return (direction, localPosition) {
      focal = localPosition;
      onZoomStepRequested(direction);
    };
  }

  /// Scroll, once the page has been laid out at [newZoom] after having been laid out at [oldZoom],
  /// so the focal point keeps its place in the area [box] is the render object of.
  ///
  /// Does nothing when the zoom did not change. The sheet is [isCentred] in the area while it fits,
  /// and starts at its left edge otherwise.
  void apply({
    required RenderObject? box,
    required FountainLayoutMetrics metrics,
    required double oldZoom,
    required double newZoom,
    required bool isCentred,
  }) {
    if (oldZoom == newZoom || box is! RenderBox || !box.hasSize) {
      return;
    }

    final viewport = box.size;
    final ratio = newZoom / oldZoom;
    final oldSheetWidth = OcptEditorPreviewLayout(metrics: metrics, zoom: oldZoom).pageWidth;
    final newSheetWidth = OcptEditorPreviewLayout(metrics: metrics, zoom: newZoom).pageWidth;
    final point = focal ?? Offset(viewport.width / 2, viewport.height / 2);
    focal = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vertical.hasClients && _vertical.position.hasContentDimensions) {
        final target = (_vertical.offset + point.dy) * ratio - point.dy;
        _vertical.jumpTo(target.clamp(0, _vertical.position.maxScrollExtent));
      }

      if (_horizontal.hasClients && _horizontal.position.hasContentDimensions) {
        final oldLeft = isCentred ? math.max<double>(0, (viewport.width - oldSheetWidth) / 2) : 0.0;
        final newLeft = isCentred ? math.max<double>(0, (viewport.width - newSheetWidth) / 2) : 0.0;
        final inSheet = _horizontal.offset + point.dx - oldLeft;
        final target = newLeft + inSheet * ratio - point.dx;
        _horizontal.jumpTo(target.clamp(0, _horizontal.position.maxScrollExtent));
      }
    });
  }

  /// Get the width the document's blocks need at [layout]'s zoom while page simulation is off:
  /// the widest block's right edge, plus the stylesheet's horizontal padding on both sides.
  static double fluidContentWidthOf(OcptEditorPreviewLayout layout) =>
      layout.pageWidth -
      layout.marginRight +
      OcptFountainEditorStylesheet.horizontalDocumentPaddingInset * 2;
}
