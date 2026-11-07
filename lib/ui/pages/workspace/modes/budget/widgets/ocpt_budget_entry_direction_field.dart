// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';

/// [OcptBudgetEntryNature.other]'s own direction choice — the one nature that still asks it.
class OcptBudgetEntryDirectionField extends StatelessWidget {
  /// Whether the direction currently picked is a debit.
  final bool isDebit;

  /// Whether the simplified wording applies.
  final bool isSimplified;

  /// Called with the direction just picked.
  final ValueChanged<bool> onChanged;

  /// Class constructor
  const OcptBudgetEntryDirectionField({
    super.key,
    required this.isDebit,
    required this.isSimplified,
    required this.onChanged,
  });

  /// Build the budget entry direction field as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.budgetEntryDialogDirectionFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        OcptBudgetBinaryChoice(
          value: isDebit,
          trueLabel: isSimplified
              ? tr.budgetEntryDialogPaidOption
              : tr.budgetEntryDialogDebitOption,
          falseLabel: isSimplified
              ? tr.budgetEntryDialogReceivedOption
              : tr.budgetEntryDialogCreditOption,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
