// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// Lay [page] out at its true [pageWidth] and, when [constraints] are narrower than that, either
/// scale the whole thing down to fit ([scrollsSideways] false) or let the area scroll sideways over
/// it ([scrollsSideways] true), rather than letting it be squeezed.
///
/// A page whose width is squeezed is not a smaller page: every block's `Styles.maxWidth` is an
/// absolute pixel width taken from the page metrics, so a narrower box makes each line wrap
/// several columns early, and those surplus lines make every simulated page render taller than
/// the sheet `computeOcptStyledPagination` sized for it — the text then runs out under the
/// sheet's bottom edge, page after page. Scaling instead keeps the page's proportions, its
/// margins and its wrap points exactly right at any panel width, which is what the raw preview
/// already does (`OcptEditorPreview`, whose doc comment explains why fitting beats cropping
/// here). A page zoomed in is not scaled down, which would undo the zoom: it scrolls sideways,
/// the way a word processor does.
///
/// The three outcomes (the page fits and is centred, it is scaled down, it scrolls) share **one
/// tree**, and only change what the widgets in it are told: a page moving to another shape of tree
/// would be mounted again, and lose its scroll position, caret, focus and history whenever a zoom
/// or a resize crossed from one to the other. The scroll view is always there, its bar only
/// showing while the page really overflows.
///
/// [BoxConstraints.maxHeight] is divided by the same scale so the scaled-down viewport still
/// fills the panel vertically, and this must be a [FittedBox] rather than a [Transform.scale]
/// around a wide [SizedBox]: under the tight width constraint the panel hands down, a plain
/// [SizedBox] silently clamps back to that width instead of the page's own (see
/// `OcptEditorPreview` for the same trap).
///
/// With [scalesDown] false, there is no sheet to fit: [page] takes the width the area has, or
/// [pageWidth] when that is more and [scrollsSideways] is true.
class OcptStyledScaledToFit extends StatelessWidget {
  /// The constraints the panel hands down, compared against [pageWidth].
  final BoxConstraints constraints;

  /// The true width, in logical pixels, [page] is laid out at.
  final double pageWidth;

  /// The page content to lay out at [pageWidth].
  final Widget page;

  /// The controller of the horizontal scroll, owned by whoever has to move it.
  final ScrollController horizontalScrollController;

  /// Whether a page wider than the area scrolls sideways rather than being scaled down.
  final bool scrollsSideways;

  /// Whether [page] is a sheet of a fixed width that is scaled down to a narrow area, rather than
  /// content taking the width it is given.
  final bool scalesDown;

  /// Create an [OcptStyledScaledToFit].
  const OcptStyledScaledToFit({
    super.key,
    required this.constraints,
    required this.pageWidth,
    required this.page,
    required this.horizontalScrollController,
    required this.scrollsSideways,
    this.scalesDown = true,
  });

  /// Build the styled scaled to fit as an [OcptHorizontalScrollView] around a [FittedBox].
  @override
  Widget build(BuildContext context) {
    final isOverflowing = constraints.maxWidth < pageWidth;
    final scale = isOverflowing && !scrollsSideways && scalesDown
        ? constraints.maxWidth / pageWidth
        : 1.0;
    final contentWidth = isOverflowing && scrollsSideways ? pageWidth : constraints.maxWidth;
    // Only when the panel actually bounds this editor's height, which is what a workspace dock row
    // does; left to the child otherwise, since dividing an unbounded height by the scale would
    // size the box to infinity.
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : null;

    return OcptHorizontalScrollView(
      controller: horizontalScrollController,
      showsBar: isOverflowing && scrollsSideways,
      child: SizedBox(
        width: contentWidth,
        height: height,
        child: scalesDown
            ? FittedBox(
                alignment: Alignment.topCenter,
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: pageWidth,
                  height: height == null ? null : height / scale,
                  child: page,
                ),
              )
            : page,
      ),
    );
  }
}
