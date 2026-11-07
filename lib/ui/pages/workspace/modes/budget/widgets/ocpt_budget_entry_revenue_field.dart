// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_dialog_values.dart';

/// `Recette` — offered under [OcptBudgetEntryNature.revenue] alone. Carries the `New taking…`
/// entry: see `_OcptBudgetEntryDialogState._onRevenuePicked`.
class OcptBudgetEntryRevenueField extends StatelessWidget {
  /// Every live taking.
  final List<OcptBudgetRevenue> revenues;

  /// The taking currently picked, or null.
  final String? revenueId;

  /// The taking the `New taking…` entry just collected, or null.
  final OcptBudgetRevenueFormFields? newRevenue;

  /// Called with the taking just picked, or with the `New taking…` sentinel.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetEntryRevenueField({
    super.key,
    required this.revenues,
    required this.revenueId,
    required this.newRevenue,
    required this.onChanged,
  });

  /// Build the budget entry revenue field as a [DropdownButtonFormField].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: ValueKey("ocptBudgetEntryWizardRevenueField/$revenueId/${newRevenue?.label}"),
      initialValue: revenueId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogRevenueFieldLabel),
      isExpanded: true,
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoRevenueLabel)),
        for (final revenue in revenues)
          DropdownMenuItem(
            value: revenue.id,
            child: Text(revenue.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (newRevenue case final newRevenue?)
          DropdownMenuItem(
            value: ocptBudgetNewRevenuePickedValue,
            child: Text(
              tr.budgetEntryDialogNewRevenuePicked(newRevenue.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        DropdownMenuItem(
          value: ocptBudgetNewRevenueActionValue,
          child: Text(tr.budgetEntryDialogNewRevenueAction),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
