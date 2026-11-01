// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One of `OcptBudgetResourceStatus`'s own three badges, for a resource row's own `Dossier` cell —
/// mirrors `OcptBudgetCostTracking`'s own status pills: a bordered outline while merely in play,
/// growing into a solid fill once held on paper.
class OcptBudgetFinancingResourceStatusPill extends StatelessWidget {
  /// The group the resource this pill belongs to sits in — what its [status] is called depends on
  /// it.
  final OcptBudgetResourceGroupKind groupKind;

  /// The status this pill paints.
  final OcptBudgetResourceStatus status;

  /// Class constructor
  const OcptBudgetFinancingResourceStatusPill({
    super.key,
    required this.groupKind,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final accent = ocptBudgetResourceStatusAccentColor(theme.colorScheme, status);
    final isSolid = status == OcptBudgetResourceStatus.confirmed;
    final alpha = status.index / (OcptBudgetResourceStatus.values.length - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSolid ? accent : accent.withValues(alpha: alpha),
        border: status == OcptBudgetResourceStatus.pending
            ? Border.all(color: accent.withValues(alpha: 0.6))
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        ocptBudgetResourceStatusLabel(tr, groupKind, status),
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
