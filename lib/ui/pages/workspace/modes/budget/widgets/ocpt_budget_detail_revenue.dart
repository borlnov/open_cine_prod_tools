// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_resource.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail_scaffold.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The taking variant — mirrors [OcptBudgetDetailResource] with no `Dossier` group and no in-kind
/// reading.
class OcptBudgetDetailRevenue extends StatelessWidget {
  /// The detail panel this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetDetail detail;

  /// The taking this variant draws.
  final OcptBudgetRevenue revenue;

  /// Class constructor
  const OcptBudgetDetailRevenue({super.key, required this.detail, required this.revenue});

  /// Build the budget detail panel revenue as an [OcptBudgetDetailScaffold].
  @override
  Widget build(BuildContext context) {
    final isReadOnly = detail.isReadOnly;
    final receivedByRevenueId = detail.receivedByRevenueId;
    final onRevenueReceiptRequested = detail.onRevenueReceiptRequested;
    final onRevenueEditRequested = detail.onRevenueEditRequested;
    final onRevenueDeletionRequested = detail.onRevenueDeletionRequested;
    final tr = Tr.of(context);

    final received = receivedByRevenueId[revenue.id];
    final hasEntry = received != null;
    final receivedCents = received?.amountCents ?? 0;
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: revenue.amountCents,
      receivedCents: receivedCents,
    );
    final canReceive = !isReadOnly && outstandingCents > 0 && onRevenueReceiptRequested != null;

    return OcptBudgetDetailScaffold(
      breadcrumb: [
        tr.budgetHeaderResourcesSegmentLabel,
        ocptBudgetResourceFamilyLabel(tr, OcptBudgetResourceFamily.takings),
      ],
      title: revenue.label.isEmpty ? tr.budgetPosteUnnamed : revenue.label,
      amountText: detail.amountLabelOf(revenue.amountCents),
      hint: revenue.notes.isEmpty ? null : revenue.notes,
      badge: ocptBudgetRevenueStatusLabel(tr, revenue.status),
      badgeColor: ocptBudgetRevenueStatusAccentColor(Theme.of(context).colorScheme, revenue.status),
      stepLabels: [tr.budgetDetailStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCount: hasEntry && receivedCents > 0 ? 2 : 1,
      figures: [
        (tr.budgetDetailStepPromisedLabel, detail.amountLabelOf(revenue.amountCents)),
        (tr.budgetFinancingColumnReceived, detail.amountLabelOf(receivedCents)),
      ],
      outstandingLabel: tr.budgetFinancingColumnOutstanding,
      outstandingValue: detail.amountLabelOf(outstandingCents),
      primary: canReceive
          ? OcptBudgetDetailAction(
              label: tr.budgetDetailReceiveAction(
                detail.amountLabelOf(outstandingCents < 0 ? 0 : outstandingCents),
              ),
              onTap: () => onRevenueReceiptRequested.call(revenue),
            )
          : null,
      secondaries: [
        if (!isReadOnly && onRevenueEditRequested != null)
          OcptBudgetDetailAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onRevenueEditRequested.call(revenue),
          ),
        if (!isReadOnly && onRevenueDeletionRequested != null)
          OcptBudgetDetailAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onRevenueDeletionRequested.call(revenue.id),
          ),
      ],
    );
  }
}
