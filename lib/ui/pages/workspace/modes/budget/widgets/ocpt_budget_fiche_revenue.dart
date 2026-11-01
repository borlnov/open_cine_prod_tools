// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_action.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_resource.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_fiche_scaffold.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The taking variant — mirrors [OcptBudgetFicheResource] with no `Dossier` group and no in-kind reading.
class OcptBudgetFicheRevenue extends StatelessWidget {
  /// The fiche this part belongs to: the catalogues it reads and the callbacks it asks.
  final OcptBudgetFiche fiche;

  /// The taking this variant draws.
  final OcptBudgetRevenue revenue;

  /// Class constructor
  const OcptBudgetFicheRevenue({super.key, required this.fiche, required this.revenue});

  /// Build the budget fiche revenue as an [OcptBudgetFicheScaffold].
  @override
  Widget build(BuildContext context) {
    final isReadOnly = fiche.isReadOnly;
    final receivedByRevenueId = fiche.receivedByRevenueId;
    final onRevenueReceiptRequested = fiche.onRevenueReceiptRequested;
    final onRevenueEditRequested = fiche.onRevenueEditRequested;
    final onRevenueDeletionRequested = fiche.onRevenueDeletionRequested;
    final tr = Tr.of(context);

    final received = receivedByRevenueId[revenue.id];
    final hasEntry = received != null;
    final receivedCents = received?.amountCents ?? 0;
    final outstandingCents = ocptBudgetResourceOutstandingCents(
      amountCents: revenue.amountCents,
      receivedCents: receivedCents,
    );
    final canReceive = !isReadOnly && outstandingCents > 0 && onRevenueReceiptRequested != null;

    return OcptBudgetFicheScaffold(
      breadcrumb: [
        tr.budgetHeaderResourcesSegmentLabel,
        ocptBudgetResourceFamilyLabel(tr, OcptBudgetResourceFamily.takings),
      ],
      title: revenue.label.isEmpty ? tr.budgetPosteUnnamed : revenue.label,
      amountText: fiche.amountLabelOf(revenue.amountCents),
      hint: revenue.notes.isEmpty ? null : revenue.notes,
      badge: ocptBudgetRevenueStatusLabel(tr, revenue.status),
      badgeColor: ocptBudgetRevenueStatusAccentColor(Theme.of(context).colorScheme, revenue.status),
      stepLabels: [tr.budgetFicheStepPromisedLabel, tr.budgetFinancingColumnReceived],
      reachedCount: hasEntry && receivedCents > 0 ? 2 : 1,
      figures: [
        (tr.budgetFicheStepPromisedLabel, fiche.amountLabelOf(revenue.amountCents)),
        (tr.budgetFinancingColumnReceived, fiche.amountLabelOf(receivedCents)),
      ],
      outstandingLabel: tr.budgetFinancingColumnOutstanding,
      outstandingValue: fiche.amountLabelOf(outstandingCents),
      primary: canReceive
          ? OcptBudgetFicheAction(
              label: tr.budgetFicheReceiveAction(
                fiche.amountLabelOf(outstandingCents < 0 ? 0 : outstandingCents),
              ),
              onTap: () => onRevenueReceiptRequested.call(revenue),
            )
          : null,
      secondaries: [
        if (!isReadOnly && onRevenueEditRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetFinancingEditAction,
            onTap: () => onRevenueEditRequested.call(revenue),
          ),
        if (!isReadOnly && onRevenueDeletionRequested != null)
          OcptBudgetFicheAction(
            label: tr.budgetCommittedDeleteAction,
            onTap: () => onRevenueDeletionRequested.call(revenue.id),
          ),
      ],
    );
  }
}
