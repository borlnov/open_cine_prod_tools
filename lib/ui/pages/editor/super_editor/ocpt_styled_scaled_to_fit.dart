// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';

/// Lay [page] out at its true [pageWidth] and, when [constraints] are narrower than that, scales
/// the whole thing down to fit rather than letting it be squeezed.
///
/// A page whose width is squeezed is not a smaller page: every block's `Styles.maxWidth` is an
/// absolute pixel width taken from the page metrics, so a narrower box makes each line wrap
/// several columns early, and those surplus lines make every simulated page render taller than
/// the sheet `computeOcptStyledPagination` sized for it — the text then runs out under the
/// sheet's bottom edge, page after page. Scaling instead keeps the page's proportions, its
/// margins and its wrap points exactly right at any panel width, which is what the raw preview
/// already does (`OcptEditorPreview`, whose doc comment explains why fitting beats cropping
/// here).
///
/// [BoxConstraints.maxHeight] is divided by the same scale so the scaled-down viewport still
/// fills the panel vertically, and this must be a [FittedBox] rather than a [Transform.scale]
/// around a wide [SizedBox]: under the tight width constraint the panel hands down, a plain
/// [SizedBox] silently clamps back to that width instead of achieving the page's own (see
/// `OcptEditorPreview` for the same trap).
class OcptStyledScaledToFit extends StatelessWidget {
  /// The constraints the panel hands down, compared against [pageWidth].
  final BoxConstraints constraints;

  /// The true width, in logical pixels, [page] is laid out at.
  final double pageWidth;

  /// The page content to lay out at [pageWidth].
  final Widget page;

  /// Create an [OcptStyledScaledToFit].
  const OcptStyledScaledToFit({
    super.key,
    required this.constraints,
    required this.pageWidth,
    required this.page,
  });

  /// Build the styled scaled to fit as a [FittedBox].
  @override
  Widget build(BuildContext context) {
    final sizedPage = SizedBox(width: pageWidth, child: page);
    if (constraints.maxWidth >= pageWidth) {
      return Center(child: sizedPage);
    }

    final scale = constraints.maxWidth / pageWidth;
    return FittedBox(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: pageWidth,
        // Only when the panel actually bounds this editor's height, which is what a workspace dock
        // row does; left to the child otherwise, since dividing an unbounded height by the scale
        // would size the box to infinity.
        height: constraints.hasBoundedHeight ? constraints.maxHeight / scale : null,
        child: sizedPage,
      ),
    );
  }
}
