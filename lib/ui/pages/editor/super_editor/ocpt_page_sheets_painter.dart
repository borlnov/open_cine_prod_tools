// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_script_page_number.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';

/// Paint one white, lightly rounded rectangle per simulated page behind the styled editor's
/// document — and, on every sheet the printed screenplay numbers, that page's own number — with one
/// call site in `OcptStyledPageSimulationSurface`.
///
/// Positioned deterministically from [pageCount]/[pageHeight]/[pageGap] alone — page N starts at
/// `N * (pageHeight + pageGap)` — and shifted by [scrollOffset] to stay behind the actually
/// scrolled content. This is an estimate, like the rest of the page-simulation feature: the extra
/// top padding `OcptFountainEditorStylesheet` opens up above a page-starting node doesn't
/// necessarily sum to exactly `pageHeight + pageGap`, so a page boundary may drift a little from
/// the painted sheet as the document grows, which is acceptable since nothing here needs to be
/// pixel-exact (the PDF exporter is the source of truth for print pagination).
///
/// Which sheets show a number, and what it reads, is [ocptScriptPageNumberLabelOf]'s to say — the
/// exact same rule `OcptScriptPagePainter` prints on paper, down to the 0.5" the number sits below
/// the sheet's top edge: a number on screen that disagreed with the number on paper would be worse
/// than no number at all. The only thing this painter adds is the mapping from a *sheet* index to a
/// *script* page number, which is [titlePageSheetCount].
class OcptPageSheetsPainter extends CustomPainter {
  /// The number of simulated pages to paint.
  final int pageCount;

  /// How many leading sheets the title page occupies, i.e. how many of them are not script pages
  /// at all (see [OcptStyledPagination.titlePageSheetCount]).
  final int titlePageSheetCount;

  /// The height of one simulated page, in logical pixels.
  final double pageHeight;

  /// The themed gap left between two simulated pages, in logical pixels.
  final double pageGap;

  /// The distance from a sheet's top edge to the top of its page number, in logical pixels.
  final double pageNumberTop;

  /// The distance from a sheet's left edge to the right edge of its page number, in logical pixels:
  /// the number is right-aligned there, exactly where the printed page's own right margin starts.
  final double pageNumberRight;

  /// The text style a page number is painted with.
  final TextStyle pageNumberStyle;

  /// The current scroll offset of the document painted in front of this layer, in logical pixels.
  final double scrollOffset;

  /// Create an [OcptPageSheetsPainter].
  const OcptPageSheetsPainter({
    required this.pageCount,
    required this.titlePageSheetCount,
    required this.pageHeight,
    required this.pageGap,
    required this.pageNumberTop,
    required this.pageNumberRight,
    required this.pageNumberStyle,
    required this.scrollOffset,
  });

  /// Paint one white rounded sheet per page, shifted by the scroll offset, with its page number.
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    canvas.save();
    // `CustomPaint` does NOT clip its painter to its own bounds. Once the document is scrolled,
    // `translate` below pulls every sheet up by `scrollOffset`, so the sheets above the viewport
    // get a negative top and would be painted *outside* this widget — straight over the editor
    // toolbar sitting above it, which reads exactly like the page scrolling over the toolbar.
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -scrollOffset);
    for (var page = 0; page < pageCount; page++) {
      final top = page * (pageHeight + pageGap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width, pageHeight),
          const Radius.circular(3),
        ),
        paint,
      );
      _paintPageNumber(canvas: canvas, size: size, page: page, top: top);
    }
    canvas.restore();
  }

  /// Repaint when [oldDelegate] differs in the page count, the sheet geometry, the number style or
  /// the
  /// scroll offset.
  @override
  bool shouldRepaint(covariant OcptPageSheetsPainter oldDelegate) =>
      oldDelegate.pageCount != pageCount ||
      oldDelegate.titlePageSheetCount != titlePageSheetCount ||
      oldDelegate.pageHeight != pageHeight ||
      oldDelegate.pageGap != pageGap ||
      oldDelegate.pageNumberTop != pageNumberTop ||
      oldDelegate.pageNumberRight != pageNumberRight ||
      oldDelegate.pageNumberStyle != pageNumberStyle ||
      oldDelegate.scrollOffset != scrollOffset;

  /// Paint the number of the sheet at index [page], whose own top edge sits at [top] in the canvas'
  /// (already scroll-translated) coordinates, or paint nothing when that sheet shows no
  /// number — the title page and the first script page both do not.
  ///
  /// Sheets scrolled out of view are skipped, unlike the sheets themselves: the rectangles above
  /// are a handful of clipped canvas operations whatever the document's length, where laying a
  /// number's text out is CPU work this method would otherwise repeat, for every page of a
  /// hundred-page screenplay, on every single frame of a scroll.
  void _paintPageNumber({
    required Canvas canvas,
    required Size size,
    required int page,
    required double top,
  }) {
    if (top + pageHeight < scrollOffset || top > scrollOffset + size.height) {
      return;
    }

    final label = ocptScriptPageNumberLabelOf(page - titlePageSheetCount + 1);
    if (label == null) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: pageNumberStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(pageNumberRight - textPainter.width, top + pageNumberTop));
    textPainter.dispose();
  }
}
