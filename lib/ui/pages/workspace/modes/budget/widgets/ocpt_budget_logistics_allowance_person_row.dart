// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cents_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_allowance_tree_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_twisty.dart';

/// One person group row: a twisty, the person's own name with their role underneath in small muted
/// type, the three running-account figures, then their own `⋮` menu.
class OcptBudgetLogisticsAllowancePersonRow extends StatelessWidget {
  /// The person this row names, or null — see [OcptBudgetLogisticsAllowancePersonGroupRow.person]'s
  /// own doc comment.
  final OcptPerson? person;

  /// What that person is on the shoot, or null.
  final OcptRole? role;

  /// What this person has advanced.
  final int advancedCents;

  /// What this person has actually been reimbursed.
  final int reimbursedCents;

  /// What is still owed them.
  final int outstandingCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this group is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked.
  final VoidCallback onTwistyTap;

  /// Called when this row's own `⋮` menu asks to open the person's own sheet.
  final VoidCallback onPersonOpenRequested;

  /// Called when this row's own `⋮` menu asks to reimburse this person, or null while withheld.
  final VoidCallback? onReimburseRequested;

  /// Class constructor
  const OcptBudgetLogisticsAllowancePersonRow({
    super.key,
    required this.person,
    required this.role,
    required this.advancedCents,
    required this.reimbursedCents,
    required this.outstandingCents,
    required this.currencyCode,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onPersonOpenRequested,
    required this.onReimburseRequested,
  });

  /// Build the budget logistics allowance person row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final person = this.person;
    final role = this.role;

    return SizedBox(
      height: ocptBudgetLogisticsAllowanceRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                OcptBudgetTwisty(
                  width: ocptBudgetLogisticsAllowanceTwistyWidth,
                  isExpandable: true,
                  isExpanded: isExpanded,
                  onTap: onTwistyTap,
                  rowHeight: ocptBudgetLogisticsAllowanceRowHeight,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        person?.displayName ?? tr.budgetAccountUnnamed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (role != null && role.name.isNotEmpty)
                        Text(
                          role.name,
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
          OcptBudgetCentsCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            cents: advancedCents,
            currencyCode: currencyCode,
          ),
          OcptBudgetCentsCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            cents: reimbursedCents,
            currencyCode: currencyCode,
          ),
          OcptBudgetCentsCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            cents: outstandingCents,
            currencyCode: currencyCode,
          ),
          SizedBox(
            width: ocptBudgetLogisticsAllowanceMenuColumnWidth,
            child: PopupMenuButton<String>(
              tooltip: "",
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) => switch (value) {
                "person" => onPersonOpenRequested(),
                "reimburse" => onReimburseRequested?.call(),
                _ => null,
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: "person",
                  child: Text(tr.budgetLogisticsAllowanceOpenPersonAction),
                ),
                if (onReimburseRequested != null)
                  PopupMenuItem<String>(
                    value: "reimburse",
                    child: Text(tr.budgetLogisticsReimburseAction),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
