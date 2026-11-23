// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// The scrolling a zoomed page needs: keep the point the zoom was made around where it was on
/// screen, and keep the caret in view sideways once the page is wider than its area.
///
/// The point is the one under the pointer for a Ctrl + wheel notch, the caret when it is in view
/// for any other way to zoom, and the centre of the area otherwise.
///
/// Zooming re-typesets the page, so everything in it moves away from (or towards) the origin by
/// the ratio of the two zooms: scrolling so `(offset + focal) * ratio - focal` leaves [focal] on
/// the same content. Between sheets that is not quite true, since the gap between two sheets does
/// not scale: [verticalTargetOf] walks the sheets. Horizontally the sheet may also move, since it
/// is centred while it fits the area, which [apply] takes into account.
final class OcptStyledZoomAnchor {
  /// The distance kept between the caret and the edge of the area when it is followed, in logical
  /// pixels.
  static const double _caretMargin = 24;

  /// The point, in the editor's own coordinates, the next zoom change is made around, or null to
  /// use the caret or the centre of the area; consumed by [apply].
  Offset? focal;

  /// The controller of the horizontal scroll a zoomed-in page wider than the area gets.
  final ScrollController horizontal = ScrollController();

  /// The controller of the vertical scroll.
  final ScrollController _vertical;

  /// The key of the editor's document layout, which tells where the caret is.
  final GlobalKey _layoutKey;

  /// Resolves the current selection.
  final DocumentSelection? Function() _selectionOf;

  /// Class constructor
  OcptStyledZoomAnchor({
    required ScrollController vertical,
    required GlobalKey layoutKey,
    required DocumentSelection? Function() selectionOf,
  }) : _vertical = vertical,
       _layoutKey = layoutKey,
       _selectionOf = selectionOf;

  /// Get the callback of a Ctrl + wheel notch (`OcptEditorZoomWheel`) that remembers where the
  /// pointer is and then forwards the way to step to [onZoomStepRequested], or null when that is.
  ///
  /// The position is only kept for the frame that follows: a step that is refused (at the end of
  /// the steps) changes nothing, and must not leave its position behind for the next zoom.
  void Function(int direction, Offset localPosition)? wheelCallback(
    ValueChanged<int>? onZoomStepRequested,
  ) {
    if (onZoomStepRequested == null) {
      return null;
    }

    return (direction, localPosition) {
      focal = localPosition;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => focal = null)
        ..scheduleFrame();
      onZoomStepRequested(direction);
    };
  }

  /// Scroll, once the page has been laid out at [newZoom] after having been laid out at [oldZoom],
  /// so the focal point keeps its place in the area [box] is the render object of.
  ///
  /// Does nothing when the zoom did not change. The page is made of sheets ([hasSheets]) centred in
  /// the area while they fit, and starting at its left edge otherwise.
  void apply({
    required RenderObject? box,
    required FountainLayoutMetrics metrics,
    required double oldZoom,
    required double newZoom,
    required bool hasSheets,
  }) {
    if (oldZoom == newZoom || box is! RenderBox || !box.hasSize) {
      return;
    }

    final viewport = box.size;
    final oldLayout = OcptEditorPreviewLayout(metrics: metrics, zoom: oldZoom);
    final newLayout = OcptEditorPreviewLayout(metrics: metrics, zoom: newZoom);
    final ratio = newLayout.pageWidth / oldLayout.pageWidth;
    final caret = _caretRectIn(box)?.center;
    final isCaretInView = caret != null && (Offset.zero & viewport).contains(caret);
    final point =
        focal ?? (isCaretInView ? caret : Offset(viewport.width / 2, viewport.height / 2));
    focal = null;
    // The line under the point and how far down it the point is: what is found again, once laid
    // out at the new zoom, wherever the text happens to land.
    final anchored = _lineAt(box, point);
    // What a sheet scaled down to fit a narrow area is drawn at: the scroll offset is in the units
    // it is laid out in, the rectangles in the ones it is drawn in.
    final fitScale = hasSheets && newZoom <= 1 && viewport.width < newLayout.pageWidth
        ? viewport.width / newLayout.pageWidth
        : 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vertical.hasClients && _vertical.position.hasContentDimensions) {
        final line = anchored == null ? null : _rectOf(box, anchored.position);
        final target = line == null
            ? verticalTargetOf(
                offset: _vertical.offset,
                focal: point.dy,
                oldLayout: oldLayout,
                newLayout: newLayout,
                hasSheets: hasSheets,
              )
            : _vertical.offset +
                  (line.top + anchored!.fraction * line.height - point.dy) / fitScale;
        _vertical.jumpTo(target.clamp(0, _vertical.position.maxScrollExtent));
      }

      if (horizontal.hasClients && horizontal.position.hasContentDimensions) {
        final oldLeft = hasSheets
            ? math.max<double>(0, (viewport.width - oldLayout.pageWidth) / 2)
            : 0.0;
        final newLeft = hasSheets
            ? math.max<double>(0, (viewport.width - newLayout.pageWidth) / 2)
            : 0.0;
        final inSheet = horizontal.offset + point.dx - oldLeft;
        final target = newLeft + inSheet * ratio - point.dx;
        horizontal.jumpTo(target.clamp(0, horizontal.position.maxScrollExtent));
      }
    });
  }

  /// Scroll sideways, once the next frame is laid out, so the caret is in view in the area [box] is
  /// the render object of, whenever the page is wider than the area. The area is the one the
  /// horizontal scrolling happens in.
  void followCaret(RenderObject? box) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!horizontal.hasClients || !horizontal.position.hasContentDimensions) {
        return;
      }
      if (box is! RenderBox || !box.attached || !box.hasSize) {
        return;
      }

      final caret = _caretRectIn(box);
      if (caret == null) {
        return;
      }

      final right = box.size.width - _caretMargin;
      final delta = caret.right > right
          ? caret.right - right
          : (caret.left < _caretMargin ? caret.left - _caretMargin : 0.0);
      if (delta != 0) {
        horizontal.jumpTo(
          (horizontal.offset + delta).clamp(0, horizontal.position.maxScrollExtent),
        );
      }
    });
  }

  /// Get the rectangle of the caret in [area]'s own coordinates, or null while there is none.
  Rect? _caretRectIn(RenderBox area) {
    final selection = _selectionOf();

    return selection == null ? null : _rectOf(area, selection.extent);
  }

  /// Get the rectangle of the text at [position] in [area]'s own coordinates, or null while the
  /// layout can't say.
  Rect? _rectOf(RenderBox area, DocumentPosition position) {
    final layout = _layoutKey.currentState as DocumentLayout?;
    final rect = layout?.getRectForPosition(position);
    if (layout == null || rect == null || !area.attached) {
      return null;
    }

    // Both corners, since a page scaled down to fit its area is drawn smaller than it is laid out.
    return Rect.fromPoints(
      layout.getAncestorOffsetFromDocumentOffset(rect.topLeft, area),
      layout.getAncestorOffsetFromDocumentOffset(rect.bottomRight, area),
    );
  }

  /// Get the line of text under [point] (in [area]'s own coordinates), and how far down that line
  /// [point] is, in lines.
  ({DocumentPosition position, double fraction})? _lineAt(RenderBox area, Offset point) {
    final layout = _layoutKey.currentState as DocumentLayout?;
    final position = layout?.getDocumentPositionNearestToOffset(
      layout.getDocumentOffsetFromAncestorOffset(point, area),
    );
    final rect = position == null ? null : _rectOf(area, position);
    if (position == null || rect == null || rect.height == 0) {
      return null;
    }

    return (position: position, fraction: (point.dy - rect.top) / rect.height);
  }

  /// Get the width the document's blocks need at [layout]'s zoom while page simulation is off:
  /// the widest block's right edge, plus the stylesheet's horizontal padding on both sides.
  static double fluidContentWidthOf(OcptEditorPreviewLayout layout) =>
      layout.pageWidth -
      layout.marginRight +
      OcptFountainEditorStylesheet.horizontalDocumentPaddingInset * 2;

  /// Get the vertical scroll offset that keeps the content at [focal] (a distance from the top of
  /// the area) where it is, once the page goes from [oldLayout] to [newLayout], from [offset].
  ///
  /// With [hasSheets] the content is a stack of sheets, a gap apart: a point on the sheet number
  /// `k`, a distance `r` below the top of that sheet, sits at `k` times a sheet and a gap, plus
  /// `r`.
  /// The sheet scales with the zoom and the gap does not, so the point is mapped sheet by sheet.
  /// Without sheets, everything scales.
  static double verticalTargetOf({
    required double offset,
    required double focal,
    required OcptEditorPreviewLayout oldLayout,
    required OcptEditorPreviewLayout newLayout,
    required bool hasSheets,
  }) {
    final y = offset + focal;
    if (!hasSheets) {
      return y * newLayout.pageHeight / oldLayout.pageHeight - focal;
    }

    const gap = OcptEditorPreviewLayout.pageGap;
    final oldExtent = oldLayout.pageHeight + gap;
    final sheet = math.max<double>(0, y / oldExtent).floor();
    final within = y - sheet * oldExtent;
    final newWithin = within <= oldLayout.pageHeight
        ? within * newLayout.pageHeight / oldLayout.pageHeight
        : newLayout.pageHeight + (within - oldLayout.pageHeight);

    return sheet * (newLayout.pageHeight + gap) + newWithin - focal;
  }

  /// Dispose the horizontal controller.
  void dispose() => horizontal.dispose();
}
