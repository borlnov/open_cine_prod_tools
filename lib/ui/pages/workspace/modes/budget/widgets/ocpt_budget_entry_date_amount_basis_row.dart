// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_tax_basis_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';

/// `Date`, `Montant` and `Base` on one row.
class OcptBudgetEntryDateAmountBasisRow extends StatelessWidget {
  /// The date currently picked.
  final DateTime date;

  /// Called with the date just picked, or null when it was cleared.
  final ValueChanged<DateTime?> onDateChanged;

  /// The controller of the amount field.
  final TextEditingController amountController;

  /// Called on every keystroke in the amount field.
  final VoidCallback onAmountChanged;

  /// The currency symbol drawn after the amount.
  final String currencySymbol;

  /// Whether the amount currently picked includes tax.
  final bool isTaxInclusive;

  /// Called with the tax basis just picked.
  final ValueChanged<bool> onTaxBasisChanged;

  /// Class constructor
  const OcptBudgetEntryDateAmountBasisRow({
    super.key,
    required this.date,
    required this.onDateChanged,
    required this.amountController,
    required this.onAmountChanged,
    required this.currencySymbol,
    required this.isTaxInclusive,
    required this.onTaxBasisChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: OcptPersonSheetDateField(
            label: tr.budgetEntryDialogDateFieldLabel,
            value: date,
            onChanged: onDateChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // `Amount`'s own label sits above the field, dense, exactly as `Date` and `Base` carry
          // theirs — a `labelText` inside the decoration would float the label into the box and drop
          // the field lower than its two `CrossAxisAlignment.start` siblings, which is what left the
          // three misaligned.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr.budgetEntryDialogAmountFieldLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const Key("ocptBudgetEntryWizardAmountField"),
                controller: amountController,
                decoration: InputDecoration(isDense: true, suffixText: currencySymbol),
                validator: (value) => ocptCostCentsOf(value ?? "") == null
                    ? tr.budgetEntryDialogAmountInvalidError
                    : null,
                onChanged: (_) => onAmountChanged(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OcptBudgetEntryTaxBasisField(isTaxInclusive: isTaxInclusive, onChanged: onTaxBasisChanged),
      ],
    );
  }
}
