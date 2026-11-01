// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_binary_choice.dart';

/// `Base`: the tax-inclusive/exclusive choice.
///
/// **Wrapped in [IntrinsicWidth]**: [OcptBudgetBinaryChoice]'s own `Row` reads
/// `MainAxisSize.max`, which would otherwise claim the whole width the outer `Row` offers a
/// non-flexible child before `Date` and `Montant` (both `Expanded`) are even sized.
class OcptBudgetEntryTaxBasisField extends StatelessWidget {
  /// Whether the amount currently picked includes tax.
  final bool isTaxInclusive;

  /// Called with the tax basis just picked.
  final ValueChanged<bool> onChanged;

  /// Class constructor
  const OcptBudgetEntryTaxBasisField({
    super.key,
    required this.isTaxInclusive,
    required this.onChanged,
  });

  /// Build the budget entry tax basis field as an [IntrinsicWidth].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.budgetEntryDialogTaxBasisFieldLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          OcptBudgetBinaryChoice(
            value: isTaxInclusive,
            trueLabel: tr.budgetLineTaxInclusiveOption,
            falseLabel: tr.budgetLineTaxExclusiveOption,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
