// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// The twisty a person group row draws — mirrors `OcptBudgetFinancing`'s own `_OcptResourcesTwisty`
/// exactly: an arrow while [isExpandable], nothing but its own reserved width otherwise, its own
/// tap target running the full height of the row it sits on.
class OcptBudgetRegieAllowanceTwisty extends StatelessWidget {
  /// Whether this row has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTap;

  /// The row this twisty sits on own fixed height, in logical pixels.
  final double rowHeight;

  /// Class constructor
  const OcptBudgetRegieAllowanceTwisty({
    super.key,
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return const SizedBox(width: ocptBudgetRegieAllowanceTwistyWidth);
    }

    return SizedBox(
      width: ocptBudgetRegieAllowanceTwistyWidth,
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
