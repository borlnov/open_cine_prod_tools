// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';

/// The twisty every poste and quote line row draws — an arrow while [isExpandable], nothing but
/// its own reserved width otherwise, so a row with nothing to expand still lines its own label up
/// with a sibling that does.
///
/// **Its own tap target is [ocptBudgetCostTrackingTwistyWidth] wide over the whole of [rowHeight]**, not
/// a square of the twisty's own width: the theme's own floor for an icon button already exceeds a
/// column this narrow, so the row's own height, whichever fixed figure the row it sits on draws at,
/// is what the tap target claims instead (`docs/architecture/budget.md`). The 18 px arrow itself
/// stays centred in that taller target — `Icon` centres its own glyph inside whatever box its
/// surrounding layout hands it.
class OcptBudgetCostTrackingTwisty extends StatelessWidget {
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
  const OcptBudgetCostTrackingTwisty({
    super.key,
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return const SizedBox(width: ocptBudgetCostTrackingTwistyWidth);
    }

    return SizedBox(
      width: ocptBudgetCostTrackingTwistyWidth,
      height: rowHeight,
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        child: Icon(
          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
