// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_header_row.dart';

/// The `À venir` section's own title row — one cell, unlike [OcptBudgetCashJournalHeaderRow]'s own
/// per-column headers, since every row under it borrows the statement's fixed widths rather than
/// declaring column headings of its own (mockup `4b`'s own single-cell header).
class OcptBudgetCashUpcomingHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetCashUpcomingHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        tr.budgetCashUpcomingSectionTitle,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
