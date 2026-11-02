// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_creation_footer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_card.dart';

/// The compact reduction of the two-pane table — see [OcptBudgetCostTracking]'s class doc
/// comment's own "at a compact width" note: one [OcptBudgetCostTrackingPosteCard] per live poste,
/// in a plain scrolling list, above the very same `+ Poste` creation footer the table itself draws
/// below its own two panes. The tree — quote lines, commitments, entries, the off-quote reading —
/// is not offered here at all; a poste's own card opens straight onto its `Inspector` tab, where
/// that detail already lives.
class OcptBudgetCostTrackingCompactCards extends StatelessWidget {
  /// Every live poste, in display order.
  final List<OcptBudgetPoste> postes;

  /// Whether the simplified naming applies.
  final bool isSimplified;

  /// The tax basis the figures are read under.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null while none is set.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// What has been paid against each poste, keyed by its id.
  final Map<String, OcptBudgetCoveredTotal> paidByPosteId;

  /// What is committed against a poste, in cents.
  final int Function(String posteId) committedCentsOf;

  /// What in-kind contributions cover of a poste, in cents.
  final int Function(String posteId) inKindCoveredCentsOf;

  /// Whether a poste is the selected one.
  final bool Function(String posteId) isPosteSelected;

  /// Called with a poste's id when its card is clicked.
  final ValueChanged<String> onPosteSelected;

  /// Called when the creation footer is clicked, or null to withhold the footer.
  final VoidCallback? onPosteCreationRequested;

  /// Class constructor
  const OcptBudgetCostTrackingCompactCards({
    super.key,
    required this.postes,
    required this.isSimplified,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidByPosteId,
    required this.committedCentsOf,
    required this.inKindCoveredCentsOf,
    required this.isPosteSelected,
    required this.onPosteSelected,
    required this.onPosteCreationRequested,
  });

  /// Build the budget cost tracking compact cards as a [Column].
  @override
  Widget build(BuildContext context) {
    final onCreation = onPosteCreationRequested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(ocptBudgetCostTrackingCardSpacing),
            itemCount: postes.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: ocptBudgetCostTrackingCardSpacing),
            itemBuilder: (context, index) {
              final poste = postes[index];
              return OcptBudgetCostTrackingPosteCard(
                poste: poste,
                isSimplified: isSimplified,
                isSelected: isPosteSelected(poste.id),
                taxBasis: taxBasis,
                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                currencyCode: currencyCode,
                paidCents: paidByPosteId[poste.id]?.amountCents ?? 0,
                committedCents: committedCentsOf(poste.id),
                inKindCoveredCents: inKindCoveredCentsOf(poste.id),
                onTap: () => onPosteSelected(poste.id),
              );
            },
          ),
        ),
        if (onCreation != null) OcptBudgetCostTrackingCreationFooter(onTap: onCreation),
      ],
    );
  }
}
