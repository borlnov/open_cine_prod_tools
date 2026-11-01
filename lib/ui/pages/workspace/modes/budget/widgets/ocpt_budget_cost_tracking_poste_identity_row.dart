// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_twisty.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The pinned pane's own row: one poste's `N°` and `Poste` cells, with a leading twisty while it
/// has anything at all to expand onto.
///
/// **This row is one half of the poste's own row** — [OcptBudgetCostTrackingPosteAmountsRow] draws the
/// other, in the scrolling pane, for the very same [poste]. The two share [isSelected], so they
/// paint the very same background, and each carries its own tap target calling the very same
/// [onTap], so a click on either half selects the poste: together they read as one row to the
/// user even though they are two separate widgets with no `RenderObject` in common.
class OcptBudgetCostTrackingPosteIdentityRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Whether this poste has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this poste is currently expanded.
  final bool isExpanded;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when this row's own twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback onTwistyTap;

  /// Class constructor
  const OcptBudgetCostTrackingPosteIdentityRow({
    super.key,
    required this.poste,
    required this.isSelected,
    required this.isSimplified,
    required this.posteWidth,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTap,
    required this.onTwistyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: ocptBudgetCostTrackingRowHeight,
          child: Row(
            children: [
              if (!isSimplified)
                SizedBox(
                  width: ocptBudgetCostTrackingNumberColumnWidth,
                  child: Text(
                    poste.code,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: posteWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(
                    children: [
                      OcptBudgetCostTrackingTwisty(
                        isExpandable: isExpandable,
                        isExpanded: isExpanded,
                        onTap: onTwistyTap,
                        rowHeight: ocptBudgetCostTrackingRowHeight,
                      ),
                      Expanded(
                        child: Text(
                          label.isEmpty ? tr.budgetPosteUnnamed : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: label.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
