// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The point, in a frame's own printed pixel/point space, a normalised storyboard annotation
/// coordinate `(xNorm, yNorm)` maps to — the one place a mark's drawn position is derived from
/// its stored, normalised coordinate, read alike by
/// `OcptStoryboardAnnotationOverlayPainter` (the on-screen overlay,
/// `lib/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_annotation_painter.dart`) and
/// `OcptStoryboardPdfService` (the storyboard PDF), so a panel's marks can never draw at two
/// different places between screen and paper.
///
/// `OcptStoryboardAnnotationsTable`'s own doc comment is the contract this reads: every mark's
/// `x1`/`y1`/`x2`/`y2` is normalised 0..1 to the frame's own top-left origin — `(0, 0)` is the
/// frame's top-left corner, `(1, 1)` its bottom-right — mapped by a plain product against the
/// frame's own printed width/height. No other transform, offset or clamp is applied here: a caller
/// drawing into a coordinate space whose own origin or axis direction differs (`PdfGraphics`
/// measures Y from a page's own *bottom*, for one) applies that one further conversion itself,
/// once, at its own lowest drawing call — never by changing what this function returns.
({double x, double y}) ocptStoryboardAnnotationPointOf({
  required double xNorm,
  required double yNorm,
  required double widthPx,
  required double heightPx,
}) => (x: xNorm * widthPx, y: yNorm * heightPx);
