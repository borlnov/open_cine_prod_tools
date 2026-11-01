// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_repayment_line.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One lender's own line in the `Repaying the contributions` card — `ocptBudgetRepaymentLinesOf`'s
/// own reading (`lib/models/rules/ocpt_budget_shares.dart`): who they are, what they contributed in
/// total, what has already gone back to them and what is still owed, the last one printed in the
/// error colour while positive — this is precisely the detail the product owner asked for: three
/// loans of 100 € from the same person read as one line owed 300 €, not three figures buried in the
/// plan's own aggregate.
class OcptBudgetSharingRepaymentLenderRow extends StatelessWidget {
  /// The line this row draws.
  final OcptBudgetRepaymentLine line;

  /// The person [line]'s own `personId` names, or null while it groups by its own [line].label
  /// instead, or while the person it once named has since been removed from the address book.
  final OcptPerson? person;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The share of the takings the very same person also holds, as a per-mille, or null while they
  /// hold none.
  ///
  /// **The one place in the mode where the two halves of a contract meet.** `budget_resources` and
  /// `budget_shares` both name a person, and until this caption nothing put the two together, so
  /// the reader had to hold "Marie put in 300 €" from one card and "Marie has 15 %" from another
  /// and join them in their head. Matched on `personId` alone: two rows that merely happen to
  /// share a typed label are not evidence of one person.
  final int? sharePermille;

  /// Called when this row's own `Record a repayment` action is clicked, or null while the mode
  /// shows a version being previewed.
  final VoidCallback? onRepaymentRequested;

  /// Class constructor
  const OcptBudgetSharingRepaymentLenderRow({
    super.key,
    required this.line,
    required this.person,
    required this.sharePermille,
    required this.currencyCode,
    required this.onRepaymentRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final person = this.person;
    final displayLabel = person != null
        ? person.displayName
        : (line.label.isEmpty ? tr.budgetPosteUnnamed : line.label);
    final isOutstanding = line.outstandingCents > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: ocpt_theme.ocptTableRowHorizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (sharePermille case final permille? when permille > 0)
                  Text(
                    tr.budgetSharingRepaymentShareCaption(ocptBudgetSharePercentLabel(permille)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(line.contributedCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              // A contribution nobody has to give back reads as a plain dash rather than as
              // 0.00 €: nothing is owed, which is not the same fact as a debt that came to zero.
              line.reimbursableCents == 0
                  ? ocptBudgetEmptyValue
                  : ocptBudgetAmountLabel(line.reimbursableCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: line.reimbursableCents == 0 ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(line.repaid.amountCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(line.outstandingCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOutstanding ? theme.colorScheme.error : null,
                fontWeight: isOutstanding ? FontWeight.w600 : null,
              ),
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentMenuColumnWidth,
            // Withheld, never disabled, under a previewed version — and withheld too on a
            // contributor with nothing left owed, there being no repayment left to record.
            child: onRepaymentRequested == null
                ? null
                : PopupMenuButton<String>(
                    tooltip: "",
                    icon: const Icon(Icons.more_vert, size: 16),
                    onSelected: (_) => onRepaymentRequested?.call(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "repay",
                        child: Text(tr.budgetSharingRepaymentRecordAction),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
