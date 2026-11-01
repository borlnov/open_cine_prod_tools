// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_share_split.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_sharing_pot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_distribution_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_share_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_total_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The right column: `Distribution`, a table over [shareSplits].
class OcptBudgetSharingDistributionColumn extends StatelessWidget {
  /// See [OcptBudgetSharing.shares].
  final List<OcptBudgetShare> shares;

  /// See [OcptBudgetSharing.shareSplits].
  final List<OcptBudgetShareSplit> shareSplits;

  /// See [OcptBudgetSharing.sharingPot].
  final OcptBudgetSharingPot sharingPot;

  /// See [OcptBudgetSharing.people].
  final List<OcptPerson> people;

  /// See [OcptBudgetSharing.currencyCode].
  final String currencyCode;

  /// See [OcptBudgetSharing.selectedShareId].
  final String? selectedShareId;

  /// See [OcptBudgetSharing.isReadOnly].
  final bool isReadOnly;

  /// See [OcptBudgetSharing.onShareSelected].
  final ValueChanged<String> onShareSelected;

  /// See [OcptBudgetSharing.onShareEditRequested].
  final ValueChanged<OcptBudgetShare>? onShareEditRequested;

  /// See [OcptBudgetSharing.onSharePayoutRequested].
  final ValueChanged<OcptBudgetShare>? onSharePayoutRequested;

  /// See [OcptBudgetSharing.onShareReorderRequested].
  final void Function(String shareId, {required bool moveUp})? onShareReorderRequested;

  /// See [OcptBudgetSharing.onShareDeletionRequested].
  final ValueChanged<String>? onShareDeletionRequested;

  /// Class constructor
  const OcptBudgetSharingDistributionColumn({
    super.key,
    required this.shares,
    required this.shareSplits,
    required this.sharingPot,
    required this.people,
    required this.currencyCode,
    required this.selectedShareId,
    required this.isReadOnly,
    required this.onShareSelected,
    required this.onShareEditRequested,
    required this.onSharePayoutRequested,
    required this.onShareReorderRequested,
    required this.onShareDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final personById = {for (final person in people) person.id: person};
    final sharesPermilleTotal = ocptBudgetSharesPermilleTotal(shares);
    final showsMismatch = shares.isNotEmpty && sharesPermilleTotal != 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetSharingDistributionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OcptBudgetSharingDistributionHeaderRow(),
                const Divider(height: 1),
                if (shareSplits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        tr.budgetSharingDistributionEmptyHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final (index, split) in shareSplits.indexed)
                    OcptBudgetSharingShareRow(
                      split: split,
                      person: split.share.personId == null
                          ? null
                          : personById[split.share.personId],
                      currencyCode: currencyCode,
                      isSelected: split.share.id == selectedShareId,
                      onTap: () => onShareSelected(split.share.id),
                      onEditRequested: isReadOnly || onShareEditRequested == null
                          ? null
                          : () => onShareEditRequested?.call(split.share),
                      onPayoutRequested: isReadOnly || onSharePayoutRequested == null
                          ? null
                          : () => onSharePayoutRequested?.call(split.share),
                      onMoveUpRequested: isReadOnly || onShareReorderRequested == null || index == 0
                          ? null
                          : () => onShareReorderRequested?.call(split.share.id, moveUp: true),
                      onMoveDownRequested:
                          isReadOnly ||
                              onShareReorderRequested == null ||
                              index == shareSplits.length - 1
                          ? null
                          : () => onShareReorderRequested?.call(split.share.id, moveUp: false),
                      onDeletionRequested: isReadOnly || onShareDeletionRequested == null
                          ? null
                          : () => onShareDeletionRequested?.call(split.share.id),
                    ),
                const Divider(height: 1),
                OcptBudgetSharingTotalRow(
                  label: tr.budgetSharingReinvestedTotalLabel,
                  valueText: ocptBudgetAmountLabel(
                    ocptBudgetReinvestedTotalCents(shareSplits),
                    currencyCode,
                  ),
                ),
                if (showsMismatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tr.budgetSharingSharesMismatchReadOut(
                        ocptBudgetAmountLabel(ocptBudgetDueTotalCents(shareSplits), currencyCode),
                        ocptBudgetAmountLabel(sharingPot.shareableCents, currencyCode),
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
