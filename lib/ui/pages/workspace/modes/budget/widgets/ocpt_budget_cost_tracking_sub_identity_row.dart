// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_sub_label.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_twisty.dart';

/// The pinned pane's own generic sub-row: a quote line, a commitment, an entry or the muted "no
/// entry" hint — every one but the line one step smaller and muted, indented [depth] steps, a
/// twisty reserved only for a quote line. [builder] draws the row's own content (label, dot,
/// badge) — see [OcptBudgetCostTrackingSubLabel].
class OcptBudgetCostTrackingSubIdentityRow extends StatelessWidget {
  /// This row's own indentation, in steps from the poste.
  final int depth;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Whether this row is the currently selected one.
  final bool isSelected;

  /// Whether this row prints one step smaller than a line row — every commitment, entry and hint
  /// row does; a line row does not.
  final bool isSmall;

  /// Whether this row has anything at all to expand onto — a quote line alone.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked, or null while it draws none.
  final VoidCallback? onTwistyTap;

  /// Called when this row is clicked, or null while it draws no selection at all (the hint row).
  final VoidCallback? onTap;

  /// Builds this row's own content.
  final WidgetBuilder builder;

  /// Class constructor
  const OcptBudgetCostTrackingSubIdentityRow({
    super.key,
    required this.depth,
    required this.isSimplified,
    required this.posteWidth,
    required this.isSelected,
    required this.isSmall,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onTap,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onTap = this.onTap;

    final content = SizedBox(
      width: posteWidth,
      child: Padding(
        padding: EdgeInsets.only(left: 12 + depth * ocptBudgetCostTrackingIndentStep, right: 8),
        child: Row(
          children: [
            if (isExpandable || !isSmall)
              OcptBudgetCostTrackingTwisty(
                isExpandable: isExpandable,
                isExpanded: isExpanded,
                onTap: onTwistyTap,
                rowHeight: isSmall
                    ? ocptBudgetCostTrackingSubRowHeight
                    : ocptBudgetCostTrackingRowHeight,
              ),
            Expanded(child: builder(context)),
          ],
        ),
      ),
    );

    return SizedBox(
      height: isSmall ? ocptBudgetCostTrackingSubRowHeight : ocptBudgetCostTrackingRowHeight,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: onTap == null
            ? Row(
                children: [
                  if (!isSimplified) const SizedBox(width: ocptBudgetCostTrackingNumberColumnWidth),
                  content,
                ],
              )
            : InkWell(
                onTap: onTap,
                mouseCursor: ocptClickableCursor,
                child: Row(
                  children: [
                    if (!isSimplified)
                      const SizedBox(width: ocptBudgetCostTrackingNumberColumnWidth),
                    content,
                  ],
                ),
              ),
      ),
    );
  }
}
