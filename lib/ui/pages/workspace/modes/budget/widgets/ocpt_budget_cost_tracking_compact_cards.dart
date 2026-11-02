// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_account_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_creation_footer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';

/// The compact reduction of the two-pane table — see [OcptBudgetCostTracking]'s class doc
/// comment's own "at a compact width" note: one [OcptBudgetCostTrackingAccountCard] per live
/// account, in a plain scrolling list, above the very same `+ Poste` creation footer the table
/// itself draws below its own two panes. The tree — quote lines, commitments, entries, the
/// off-quote reading — is not offered here at all; an account's own card opens straight onto its
/// `Inspector` tab, where that detail already lives.
class OcptBudgetCostTrackingCompactCards extends StatelessWidget {
  /// Every live account, in display order.
  final List<OcptBudgetAccount> accounts;

  /// Whether the simplified naming applies.
  final bool isSimplified;

  /// The tax basis the figures are read under.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null while none is set.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// What has been paid against each account, keyed by its id.
  final Map<String, OcptBudgetCoveredTotal> paidByAccountId;

  /// What is committed against an account, in cents.
  final int Function(String accountId) committedCentsOf;

  /// What in-kind contributions cover of an account, in cents.
  final int Function(String accountId) inKindCoveredCentsOf;

  /// Whether an account is the selected one.
  final bool Function(String accountId) isAccountSelected;

  /// Called with an account's id when its card is clicked.
  final ValueChanged<String> onAccountSelected;

  /// Called when the creation footer is clicked, or null to withhold the footer.
  final VoidCallback? onAccountCreationRequested;

  /// Class constructor
  const OcptBudgetCostTrackingCompactCards({
    super.key,
    required this.accounts,
    required this.isSimplified,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidByAccountId,
    required this.committedCentsOf,
    required this.inKindCoveredCentsOf,
    required this.isAccountSelected,
    required this.onAccountSelected,
    required this.onAccountCreationRequested,
  });

  /// Build the budget cost tracking compact cards as a [Column].
  @override
  Widget build(BuildContext context) {
    final onCreation = onAccountCreationRequested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(ocptBudgetCostTrackingCardSpacing),
            itemCount: accounts.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: ocptBudgetCostTrackingCardSpacing),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return OcptBudgetCostTrackingAccountCard(
                account: account,
                isSimplified: isSimplified,
                isSelected: isAccountSelected(account.id),
                taxBasis: taxBasis,
                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                currencyCode: currencyCode,
                paidCents: paidByAccountId[account.id]?.amountCents ?? 0,
                committedCents: committedCentsOf(account.id),
                inKindCoveredCents: inKindCoveredCentsOf(account.id),
                onTap: () => onAccountSelected(account.id),
              );
            },
          ),
        ),
        if (onCreation != null) OcptBudgetCostTrackingCreationFooter(onTap: onCreation),
      ],
    );
  }
}
