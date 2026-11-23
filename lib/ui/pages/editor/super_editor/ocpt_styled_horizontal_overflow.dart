// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// Lay [child] out at least [minWidth] wide and, when [constraints] are narrower than that, let
/// the area scroll horizontally over it instead of squeezing it, the way a word processor does
/// with a page zoomed past its window.
///
/// Used once the page is zoomed in: a smaller zoom keeps fitting the whole page into a narrow
/// panel instead (`OcptStyledScaledToFit`), which a zoomed-in page can't do without undoing the
/// zoom. While the area is wide enough, [child] gets the constraints as they are, so the page
/// stays centred.
///
/// The horizontal bar sits at the bottom of the area; the vertical one the page's own surface
/// draws filters its notifications by axis, so the two never read each other's scrolling.
class OcptStyledHorizontalOverflow extends StatelessWidget {
  /// The constraints the panel hands down, compared against [minWidth].
  final BoxConstraints constraints;

  /// The width, in logical pixels, [child] needs.
  final double minWidth;

  /// The controller of the horizontal scroll, owned by whoever has to move it.
  final ScrollController controller;

  /// The content, laid out at least [minWidth] wide.
  final Widget child;

  /// Create an [OcptStyledHorizontalOverflow].
  const OcptStyledHorizontalOverflow({
    super.key,
    required this.constraints,
    required this.minWidth,
    required this.controller,
    required this.child,
  });

  /// Build the horizontal overflow as a [Scrollbar] over a horizontal [SingleChildScrollView], or
  /// as [child] alone while it fits.
  @override
  Widget build(BuildContext context) {
    if (constraints.maxWidth >= minWidth) {
      return child;
    }

    return Scrollbar(
      controller: controller,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minWidth,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          child: child,
        ),
      ),
    );
  }
}
