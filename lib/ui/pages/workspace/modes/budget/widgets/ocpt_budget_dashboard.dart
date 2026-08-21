// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The height of a poste's own share bar, in logical pixels.
const double _ocptDashboardBarHeight = 6;

/// The budget mode's own dashboard: M1's honest reading of what a project holds — a KPI row, then
/// the quote read poste by poste, each with its own share of the total.
///
/// **Nothing here may claim a figure the data cannot support** (`docs/plans/budget-mode.md` §5,
/// M1): no placeholder for M2's alerts, no needs/resources balance bar (M3), no "what feeds this
/// budget" card (M3) — those arrive with the milestones that give them content, exactly as this
/// view itself becomes the mockup's full dashboard once they do. Purely computed, like
/// `OcptBreakdownRecapTable`: a poste's click only selects it, which writes nothing, so this needs
/// no `isReadOnly` flag at all.
class OcptBudgetDashboard extends StatelessWidget {
  /// Every live poste, in display order.
  final List<OcptBudgetPoste> postes;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with a poste's id when its own row is clicked, opening the `Inspector` tab on it.
  final ValueChanged<String> onPosteSelected;

  /// Class constructor
  const OcptBudgetDashboard({
    super.key,
    required this.postes,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.onPosteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    if (postes.isEmpty) {
      return OcptWorkspaceEmptyMode(icon: Icons.payments_outlined, message: tr.budgetDashboardEmptyHint);
    }

    final allLines = [for (final poste in postes) ...poste.lines];
    final quotedTotal = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final excludingTaxTotal = ocptBudgetExcludingTaxTotalOf(
      allLines,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final lineCount = allLines.length;

    final posteAmounts = {
      for (final poste in postes)
        poste.id: ocptBudgetTotalOf(
          poste.lines,
          basis: taxBasis,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        ).amountCents,
    };
    final maxPosteAmount = posteAmounts.values.fold(0, (a, b) => a > b ? a : b);
    final orderedPostes = [...postes]
      ..sort((a, b) => (posteAmounts[b.id] ?? 0).compareTo(posteAmounts[a.id] ?? 0));

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _OcptDashboardKpi(
                label: tr.budgetDashboardQuotedTotalLabel,
                value: ocptBudgetAmountLabel(quotedTotal.amountCents, currencyCode),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardExcludingTaxTotalLabel,
                value: ocptBudgetAmountLabel(excludingTaxTotal.amountCents, currencyCode),
                caption: excludingTaxTotal.isComplete
                    ? null
                    : tr.budgetDashboardCoverageCaption(
                        excludingTaxTotal.coveredLineCount,
                        excludingTaxTotal.lineCount,
                      ),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardPosteCountLabel,
                value: "${postes.length}",
              ),
              _OcptDashboardKpi(label: tr.budgetDashboardLineCountLabel, value: "$lineCount"),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr.budgetDashboardPostesSectionTitle,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final poste in orderedPostes)
          _OcptDashboardPosteRow(
            poste: poste,
            amountCents: posteAmounts[poste.id] ?? 0,
            shareOfMax: maxPosteAmount <= 0 ? 0 : (posteAmounts[poste.id] ?? 0) / maxPosteAmount,
            currencyCode: currencyCode,
            onTap: () => onPosteSelected(poste.id),
          ),
      ],
    );
  }
}

/// One KPI of the dashboard's own top row: a muted label, a bold value, and an optional muted
/// caption underneath (the excluding-tax total's own coverage read-out).
class _OcptDashboardKpi extends StatelessWidget {
  /// The KPI's own label.
  final String label;

  /// The KPI's own value.
  final String value;

  /// A muted caption under [value], or null for a KPI with nothing further to say.
  final String? caption;

  /// Class constructor
  const _OcptDashboardKpi({required this.label, required this.value, this.caption});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = this.caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
        if (caption != null)
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// One poste of the dashboard's own read, poste by poste: its label, its amount and a small bar
/// for its own share of the largest poste's amount.
class _OcptDashboardPosteRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// This poste's own amount, in the header's own selected basis, in cents.
  final int amountCents;

  /// This poste's own share of the largest poste's amount, in `[0, 1]`.
  final double shareOfMax;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptDashboardPosteRow({
    required this.poste,
    required this.amountCents,
    required this.shareOfMax,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = poste.label.isEmpty ? tr.budgetPosteUnnamed : poste.label;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_ocptDashboardBarHeight / 2),
                child: LinearProgressIndicator(
                  value: shareOfMax.clamp(0.0, 1.0),
                  minHeight: _ocptDashboardBarHeight,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Text(
                ocptBudgetAmountLabel(amountCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
