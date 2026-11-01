// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_resource_status_pill.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One of `OcptBudgetRevenueStatus`'s own three badges — mirrors
/// [OcptBudgetFinancingResourceStatusPill], generic over a different enum.
class OcptBudgetFinancingRevenueStatusPill extends StatelessWidget {
  /// The status this pill paints.
  final OcptBudgetRevenueStatus status;

  /// Class constructor
  const OcptBudgetFinancingRevenueStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final accent = ocptBudgetRevenueStatusAccentColor(theme.colorScheme, status);
    final isSolid = status == OcptBudgetRevenueStatus.invoiced;
    final alpha = status.index / (OcptBudgetRevenueStatus.values.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? accent : accent.withValues(alpha: alpha),
        border: status == OcptBudgetRevenueStatus.expected
            ? Border.all(color: accent.withValues(alpha: 0.6))
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptBudgetRevenueStatusLabel(tr, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSolid ? theme.colorScheme.onPrimary : accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
