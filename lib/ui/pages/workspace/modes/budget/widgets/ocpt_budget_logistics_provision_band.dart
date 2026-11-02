// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_provision_figure.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_warning_color.dart';

/// The band under both columns: what this view computes, what the quote already carries for it, the
/// gap between the two, and the gesture that closes it.
///
/// **The gap is the whole reason this band exists.** The view used to compute figures and write
/// them nowhere, which the product owner named exactly: *"il fait des calculs mais ces calculs, où
/// sont-ils enregistrés ou provisionnés ?"* — they were nowhere. The `Quoted on this poste` figure
/// reads back the lines the provisioning itself wrote, so a reader can see at a glance whether what
/// the schedule and the defrayals imply has actually reached the budget.
///
/// A project holding no poste at all shows the reason instead of an inert picker: there is nowhere
/// to provision into until the quote has a poste.
class OcptBudgetLogisticsProvisionBand extends StatelessWidget {
  /// What the catering and the defrayals come to together, in cents.
  final int computedTotalCents;

  /// What the provisioned lines of the target poste currently hold, in cents.
  final int provisionedTotalCents;

  /// Every live poste of the quote.
  final List<OcptBudgetPoste> postes;

  /// The poste the provisioning would write into, or null.
  final String? provisionPosteId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with the id of the poste just picked, or null while withheld.
  final ValueChanged<String>? onPosteSelected;

  /// Called when the reader asks to provision, or null while withheld.
  final VoidCallback? onProvisionRequested;

  /// Why there is nothing to provision, or null while there is.
  final String? note;

  /// Class constructor
  const OcptBudgetLogisticsProvisionBand({
    super.key,
    required this.computedTotalCents,
    required this.provisionedTotalCents,
    required this.postes,
    required this.provisionPosteId,
    required this.currencyCode,
    required this.onPosteSelected,
    required this.onProvisionRequested,
    required this.note,
  });

  /// Build the budget logistics provision band as a [Card].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final note = this.note;
    final gapCents = computedTotalCents - provisionedTotalCents;
    final selectedPoste = postes.where((poste) => poste.id == provisionPosteId).firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 32,
          runSpacing: 12,
          children: [
            OcptBudgetLogisticsProvisionFigure(
              label: tr.budgetLogisticsProvisionComputedLabel,
              value: ocptBudgetAmountLabel(computedTotalCents, currencyCode),
            ),
            OcptBudgetLogisticsProvisionFigure(
              label: tr.budgetLogisticsProvisionQuotedLabel,
              value: ocptBudgetAmountLabel(provisionedTotalCents, currencyCode),
            ),
            OcptBudgetLogisticsProvisionFigure(
              label: tr.budgetLogisticsProvisionGapLabel,
              value: ocptBudgetAmountLabel(gapCents, currencyCode),
              valueColor: gapCents == 0 ? null : ocptWarningColor(context),
            ),
            if (postes.isEmpty)
              Text(
                tr.budgetLogisticsProvisionNoPosteHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (onPosteSelected != null)
                DropdownButton<String>(
                  value: selectedPoste?.id,
                  hint: Text(tr.budgetLogisticsProvisionPosteLabel),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final poste in postes)
                      DropdownMenuItem<String>(
                        value: poste.id,
                        child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: false)),
                      ),
                  ],
                  onChanged: (value) => value == null ? null : onPosteSelected?.call(value),
                ),
              if (note != null)
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (onProvisionRequested != null)
                FilledButton.icon(
                  onPressed: provisionPosteId == null ? null : onProvisionRequested,
                  icon: const Icon(Icons.playlist_add_check, size: 16),
                  label: Text(tr.budgetLogisticsProvisionAction),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
