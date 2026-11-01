// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';

/// The twisty every family, resource and revenue row draws — an arrow while [isExpandable],
/// nothing but its own reserved width otherwise, so a row with nothing to expand still lines its
/// own label up with a sibling that does.
///
/// **Its own tap target is [ocptBudgetFinancingTwistyWidth] wide over the whole of [rowHeight]**, not a
/// square of the twisty's own width — mirrors `OcptBudgetCostTracking`'s own
/// `_OcptCostTrackingTwisty` exactly, the theme's own floor for an icon button already exceeding a
/// column this narrow (`docs/architecture/budget.md`).
class OcptBudgetFinancingTwisty extends StatelessWidget {
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
  const OcptBudgetFinancingTwisty({
    super.key,
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return const SizedBox(width: ocptBudgetFinancingTwistyWidth);
    }

    return SizedBox(
      width: ocptBudgetFinancingTwistyWidth,
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
