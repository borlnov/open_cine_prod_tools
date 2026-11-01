// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A promoted quote line's own payments section: every entry that has paid its commitment, one
/// instalment per row, date then amount — `docs/architecture/budget.md`. Read-only, like every
/// other figure this fiche prints: there is no affordance here to withhold under a preview.
class OcptBudgetCommitmentPayments extends StatelessWidget {
  /// The commitment's own payments, oldest first.
  final List<OcptBudgetEntry> payments;

  /// The project's default VAT rate, in basis points, or null — what a payment with no rate of its
  /// own reads its debit under.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCommitmentPayments({
    super.key,
    required this.payments,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.budgetFicheCommitmentPaymentsSectionTitle.toUpperCase(), style: labelStyle),
        const SizedBox(height: 4),
        for (final payment in payments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMd(locale).format(payment.date),
                  style: theme.textTheme.bodySmall,
                ),
                Text(_amountText(payment), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }

  /// [payment]'s own debit, tax-inclusive, formatted in [currencyCode] — [ocptBudgetEmptyValue]
  /// while its rate cannot be read.
  String _amountText(OcptBudgetEntry payment) {
    final debitCents = ocptBudgetEntryDebitCentsOf(
      payment,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    return debitCents == null
        ? ocptBudgetEmptyValue
        : ocptBudgetAmountLabel(debitCents, currencyCode);
  }
}
