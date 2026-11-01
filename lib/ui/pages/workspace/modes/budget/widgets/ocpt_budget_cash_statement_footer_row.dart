// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_upcoming_footer_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The statement's own closing row, in the very same tinted style [OcptBudgetCashUpcomingFooterRow]
/// closes `À venir` with: the closing label past a span of the leading columns, nothing under
/// `Debit` and `Credit`, and [balanceCents] under `Balance`. Mockup `4b` draws the two footers
/// answering each other — the account's past closed here, its future closed below.
///
/// **This replaced a top band carrying the whole journal's debit, credit and balance.** Only the
/// balance survives the move, which is the mockup's own reading and the honest one: on a running
/// statement the debit and credit totals are the two halves of the very figure the last line
/// already shows, and reading all three off a band pinned above a scrolled table invited comparing
/// them against whichever rows happened to be on screen. Stated at the foot of the rows they add
/// up, they can only be read as what they are. The coverage read-out the band carried under
/// `Balance` follows the figure down, drawn under this row exactly as `À venir` draws its own.
///
/// [closingDate] is the last drawn entry's own date, never today's: a statement closes on its last
/// movement, and a production that has recorded nothing this month holds a balance as of the day it
/// last did, not as of the day somebody happened to open the page.
class OcptBudgetCashStatementFooterRow extends StatelessWidget {
  /// The date the statement closes on — the last drawn entry's own.
  final DateTime closingDate;

  /// The whole journal's own balance (`OcptBudgetCashTotals.balanceCents`), in cents.
  final int balanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCashStatementFooterRow({
    super.key,
    required this.closingDate,
    required this.balanceCents,
    required this.currencyCode,
  });

  /// Build the budget cash statement footer row as a [DecoratedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: ocptBudgetCashJournalRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr.budgetCashJournalClosingBalanceLabel(
                  DateFormat.yMMMd(locale).format(closingDate),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: ocptBudgetCashJournalAmountColumnWidth),
            const SizedBox(width: ocptBudgetCashJournalAmountColumnWidth),
            SizedBox(
              width: ocptBudgetCashJournalAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(balanceCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: ocptBudgetCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}
