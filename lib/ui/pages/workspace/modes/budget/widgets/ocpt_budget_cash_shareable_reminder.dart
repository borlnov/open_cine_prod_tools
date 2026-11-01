// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A quiet reminder drawn under the closing balance: how much of the account is actually shareable,
/// so the bank balance right above it is not mistaken for the amount to distribute — the two are
/// different figures ([shareableCents] is the takings less the contributions to repay, the balance
/// is cash on hand), and a production reading its account here reported taking one for the other.
///
/// **Not a subtraction of the balance, a reference beside it.** The balance and the shareable pot
/// diverge on two independent terms — production spending the balance carries and the pot ignores,
/// contributions the pot deducts whole whether or not they have gone back — so no honest arithmetic
/// turns one into the other in a line. This states the pot as its own figure, worded as *of which*,
/// and points at the view that computes it, rather than pretending to break the balance down.
///
/// Drawn only while [shareableCents] is above zero (see [OcptBudgetCashJournal.shareableCents]).
class OcptBudgetCashShareableReminder extends StatelessWidget {
  /// The shareable pot, in cents — `OcptBudgetSharingPot.shareableCents`, always above zero here.
  final int shareableCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the `Revenue sharing` link is clicked, or null to draw the reminder without one.
  final VoidCallback? onOpenSharing;

  /// Class constructor
  const OcptBudgetCashShareableReminder({
    super.key,
    required this.shareableCents,
    required this.currencyCode,
    required this.onOpenSharing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final captionStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            tr.budgetCashJournalShareableReminder(
              ocptBudgetAmountLabel(shareableCents, currencyCode),
            ),
            style: captionStyle,
          ),
          if (onOpenSharing != null)
            InkWell(
              key: const Key("ocptBudgetCashShareableReminderLink"),
              onTap: onOpenSharing,
              borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
              mouseCursor: ocpt_theme.ocptClickableCursor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  tr.budgetHeaderSharingSegmentLabel,
                  style: captionStyle?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
