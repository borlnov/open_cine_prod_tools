// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_share_split.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One participant's row: its own label (with the linked person's name underneath, when it names
/// one), its share as a percentage, what it is due, what has been paid, and what it reinvests.
class OcptBudgetSharingShareRow extends StatelessWidget {
  /// The split this row draws.
  final OcptBudgetShareSplit split;

  /// The person [split]'s own [OcptBudgetShare.personId] names, or null while it names nobody.
  final OcptPerson? person;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this share is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked — selects it, and only that.
  final VoidCallback onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to record a payout against it, or null while
  /// withheld.
  final VoidCallback? onPayoutRequested;

  /// Called when this row's own `⋮` menu asks to move it up, or null while withheld.
  final VoidCallback? onMoveUpRequested;

  /// Called when this row's own `⋮` menu asks to move it down, or null while withheld.
  final VoidCallback? onMoveDownRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const OcptBudgetSharingShareRow({
    super.key,
    required this.split,
    required this.person,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
    required this.onEditRequested,
    required this.onPayoutRequested,
    required this.onMoveUpRequested,
    required this.onMoveDownRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final hasMenu =
        onEditRequested != null ||
        onPayoutRequested != null ||
        onMoveUpRequested != null ||
        onMoveDownRequested != null ||
        onDeletionRequested != null;
    final share = split.share;
    final isReinvestedNonZero = split.reinvestedCents != 0;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: ocptTableRowHorizontalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        share.label.isEmpty ? tr.budgetPosteUnnamed : share.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (person != null)
                        Text(
                          person!.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: ocptBudgetSharingPercentColumnWidth,
                child: Text(
                  ocptBudgetSharePercentLabel(share.sharePermille),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: ocptBudgetSharingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(split.dueCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: ocptBudgetSharingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(split.paid.amountCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: ocptBudgetSharingAmountColumnWidth,
                child: Text(
                  ocptBudgetAmountLabel(split.reinvestedCents, currencyCode),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isReinvestedNonZero
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isReinvestedNonZero ? FontWeight.w600 : null,
                  ),
                ),
              ),
              SizedBox(
                width: ocptBudgetSharingMenuColumnWidth,
                child: !hasMenu
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "edit" => onEditRequested?.call(),
                          "payout" => onPayoutRequested?.call(),
                          "up" => onMoveUpRequested?.call(),
                          "down" => onMoveDownRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (onEditRequested != null)
                            PopupMenuItem<String>(
                              value: "edit",
                              child: Text(tr.budgetFinancingEditAction),
                            ),
                          if (onPayoutRequested != null)
                            PopupMenuItem<String>(
                              value: "payout",
                              child: Text(tr.budgetSharingRecordPayoutAction),
                            ),
                          if (onMoveUpRequested != null)
                            PopupMenuItem<String>(
                              value: "up",
                              child: Text(tr.budgetPosteMoveUpAction),
                            ),
                          if (onMoveDownRequested != null)
                            PopupMenuItem<String>(
                              value: "down",
                              child: Text(tr.budgetPosteMoveDownAction),
                            ),
                          if (onDeletionRequested != null)
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
      ),
    );
  }
}
