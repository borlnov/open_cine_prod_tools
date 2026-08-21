// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// The budget mode's status band: `N postes · N lines · <quoted total>`, in the shape of
/// `OcptResourcesStatusBar`.
///
/// [quotedTotalCents] is always the plain, unconverted sum of every line's own typed amount
/// (`ocptBudgetProjectQuotedTotalCents`), never the header's own selected basis: a status band read
/// at a glance is not the place to explain which of the two bases a figure is in, and the untouched
/// sum needs no rate at all to be complete, unlike either converted reading.
class OcptBudgetStatusBar extends StatelessWidget {
  /// The number of live postes.
  final int posteCount;

  /// The total number of quote lines across every poste.
  final int lineCount;

  /// The project's quoted total, in cents, as typed — see the class doc comment.
  final int quotedTotalCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetStatusBar({
    super.key,
    required this.posteCount,
    required this.lineCount,
    required this.quotedTotalCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final totalText = ocptBudgetAmountLabel(quotedTotalCents, currencyCode);

    return OcptWorkspaceStatusBar(
      counters: [tr.budgetStatsPostes(posteCount), tr.budgetStatsLines(lineCount)],
      nonDroppableCount: 1,
      trailingText: totalText,
      trailing: Text(totalText, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
