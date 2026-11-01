// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_repayment_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_sharing_pot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_pot_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_repayment_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_repayment_lender_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The left column: `Repaying the contributions`, the whole of it — the takings themselves are
/// drawn by the resources document's own tree these days.
class OcptBudgetSharingLeftColumn extends StatelessWidget {
  /// See [OcptBudgetSharing.sharingPot].
  final OcptBudgetSharingPot sharingPot;

  /// See [OcptBudgetSharing.repaymentLines].
  final List<OcptBudgetRepaymentLine> repaymentLines;

  /// Every live share of the project — read only to say, under a contributor's own name, what
  /// percentage of the takings that same person also holds.
  final List<OcptBudgetShare> shares;

  /// Called with a contributor's own line when `Record a repayment` is clicked, or null while the
  /// mode shows a version being previewed.
  final ValueChanged<OcptBudgetRepaymentLine>? onRepaymentRequested;

  /// See [OcptBudgetSharing.people].
  final List<OcptPerson> people;

  /// See [OcptBudgetSharing.currencyCode].
  final String currencyCode;

  /// Class constructor
  const OcptBudgetSharingLeftColumn({
    super.key,
    required this.sharingPot,
    required this.repaymentLines,
    required this.shares,
    required this.onRepaymentRequested,
    required this.people,
    required this.currencyCode,
  });

  /// Build the budget sharing left column as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetSharingRepayingTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (repaymentLines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      tr.budgetSharingRepaymentEmptyHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  const OcptBudgetSharingRepaymentHeaderRow(),
                  for (final line in repaymentLines)
                    OcptBudgetSharingRepaymentLenderRow(
                      line: line,
                      person: line.personId == null
                          ? null
                          : people.where((person) => person.id == line.personId).firstOrNull,
                      sharePermille: line.personId == null
                          ? null
                          : shares
                                .where((share) => share.personId == line.personId)
                                .fold<int?>(null, (sum, share) => (sum ?? 0) + share.sharePermille),
                      currencyCode: currencyCode,
                      onRepaymentRequested:
                          onRepaymentRequested == null || line.outstandingCents == 0
                          ? null
                          : () => onRepaymentRequested?.call(line),
                    ),
                ],
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 4),
                OcptBudgetSharingPotLine(
                  label: tr.budgetSharingReimbursableTotalLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.reimbursableCents, currencyCode),
                ),
                OcptBudgetSharingPotLine(
                  label: tr.budgetSharingRepaidLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.repaid.amountCents, currencyCode),
                ),
                OcptBudgetSharingPotLine(
                  label: tr.budgetSharingOutstandingRepaymentLabel,
                  valueText: ocptBudgetAmountLabel(
                    sharingPot.outstandingRepaymentCents,
                    currencyCode,
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 4),
                OcptBudgetSharingPotLine(
                  label: tr.budgetSharingLeftToShareLabel,
                  valueText: ocptBudgetAmountLabel(sharingPot.shareableCents, currencyCode),
                  isEmphasized: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
