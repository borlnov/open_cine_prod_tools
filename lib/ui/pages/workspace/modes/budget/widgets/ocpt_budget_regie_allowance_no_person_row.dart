// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_allowance_twisty.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// One defrayal naming nobody, drawn as its own top-level row: the wording that has always said so,
/// in italics, its own amount under `ADVANCED` **and** `OWED` — it is owed in full, never paid back
/// through a running account — with `REIMBURSED` left blank. `OWED` reads its amount rather than a
/// blank precisely because the total row counts this defrayal in: a figure that is summed has to be
/// legible on the line it is summed from. No twisty: there is nothing to expand onto.
class OcptBudgetRegieAllowanceNoPersonRow extends StatelessWidget {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const OcptBudgetRegieAllowanceNoPersonRow({
    super.key,
    required this.allowance,
    required this.currencyCode,
    required this.onTap,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocpt_theme.ocptClickableCursor,
      child: SizedBox(
        height: ocptBudgetRegieAllowanceRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const OcptBudgetRegieAllowanceTwisty(
                    isExpandable: false,
                    isExpanded: false,
                    rowHeight: ocptBudgetRegieAllowanceRowHeight,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tr.budgetRegieAllowanceNoPerson,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (allowance.label.isNotEmpty)
                          Text(
                            allowance.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ocptBudgetRegieAllowanceAmountCell(
              context,
              ocptBudgetAllowanceCentsOf(allowance),
              currencyCode,
            ),
            ocptBudgetRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
            ocptBudgetRegieAllowanceAmountCell(
              context,
              ocptBudgetAllowanceCentsOf(allowance),
              currencyCode,
            ),
            SizedBox(
              width: ocptBudgetRegieAllowanceMenuColumnWidth,
              child: onDeletionRequested == null
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: "",
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (_) => onDeletionRequested?.call(),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: "delete",
                          child: Text(tr.budgetCommittedDeleteAction),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
