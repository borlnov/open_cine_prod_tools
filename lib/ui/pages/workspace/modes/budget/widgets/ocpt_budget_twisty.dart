// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// The twisty every expandable row of the budget mode draws (the cost tracking accounts and quote
/// lines, the financing rows, the logistics allowance rows) — an arrow while [isExpandable],
/// nothing but its own reserved [width] otherwise, so a row with nothing to expand still lines its
/// own label up with a sibling that does.
///
/// **Its own tap target is [width] wide over the whole of [rowHeight]**, not a square of the
/// twisty's own width: the theme's own floor for an icon button already exceeds a column this
/// narrow, so the row's own height, whichever fixed figure the row it sits on draws at, is what the
/// tap target claims instead (`docs/architecture/budget.md`). The 18 px arrow itself stays centred
/// in that taller target — `Icon` centres its own glyph inside whatever box its surrounding layout
/// hands it.
class OcptBudgetTwisty extends StatelessWidget {
  /// This twisty's own column width, in logical pixels: the metrics constant of the view it sits
  /// in.
  final double width;

  /// Whether this row has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTap;

  /// The row this twisty sits on own fixed height, in logical pixels — its own tap target fills it
  /// edge to edge.
  final double rowHeight;

  /// Class constructor
  const OcptBudgetTwisty({
    super.key,
    required this.width,
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  /// Build the budget twisty as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return SizedBox(width: width);
    }

    return SizedBox(
      width: width,
      height: rowHeight,
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocpt_theme.ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
        child: Icon(
          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
