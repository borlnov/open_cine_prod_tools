// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_account_dropdown.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_row.dart';

/// Step 3 of `addQuoteLinesFromBreakdown`: the breakdown elements no quote line prices yet, a
/// search field, a `File all under` account for every row and the per-row account and quantity.
class OcptBudgetNewBreakdownStep extends StatelessWidget {
  /// Every live breakdown element no live quote line prices yet.
  final List<OcptElement> unpricedElements;

  /// The search field's current text.
  final String query;

  /// The ids of the checked elements.
  final Set<String> selectedIds;

  /// The account every row inherits until it is given one of its own, or null.
  final String? bulkAccountId;

  /// Every live account of the project.
  final List<OcptBudgetAccount> accounts;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// The account a row will be filed under: its own override, else the bulk default, else null.
  final String? Function(String elementId) accountIdOf;

  /// The quantity controller of an element, created by the wizard's state on first request.
  final TextEditingController Function(OcptElement element) quantityControllerOf;

  /// Called with the `File all under` account picked.
  final ValueChanged<String?> onBulkAccountChanged;

  /// Called with the search field's text as it changes.
  final ValueChanged<String> onQueryChanged;

  /// Called when an element's checkbox changes, with the element and its new checked state.
  final void Function(OcptElement element, {required bool isChecked}) onElementCheckedChanged;

  /// Called when a row is given an account of its own, with the element id and the account.
  final void Function(String elementId, String? accountId) onElementAccountChanged;

  /// Called when a row's quantity text changes, with the element id and the text.
  final void Function(String elementId, String value) onQuantityChanged;

  /// Class constructor
  const OcptBudgetNewBreakdownStep({
    super.key,
    required this.unpricedElements,
    required this.query,
    required this.selectedIds,
    required this.bulkAccountId,
    required this.accounts,
    required this.isSimplified,
    required this.accountIdOf,
    required this.quantityControllerOf,
    required this.onBulkAccountChanged,
    required this.onQueryChanged,
    required this.onElementCheckedChanged,
    required this.onElementAccountChanged,
    required this.onQuantityChanged,
  });

  /// Build the budget new breakdown step as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = normalizedQuery.isEmpty
        ? unpricedElements
        : [
            for (final element in unpricedElements)
              if (element.name.toLowerCase().contains(normalizedQuery)) element,
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              tr.budgetNewBreakdownSetAllAccountLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OcptBudgetNewBreakdownAccountDropdown(
                dropdownKey: const Key("ocptBudgetNewBreakdownSetAllAccount"),
                value: bulkAccountId,
                enabled: true,
                accounts: accounts,
                isSimplified: isSimplified,
                onChanged: onBulkAccountChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: tr.budgetLineFromElementSearchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tr.budgetLineFromElementEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final element in filtered)
            OcptBudgetNewBreakdownRow(
              element: element,
              isSelected: selectedIds.contains(element.id),
              quantityController: quantityControllerOf(element),
              accountId: accountIdOf(element.id),
              accounts: accounts,
              isSimplified: isSimplified,
              onCheckedChanged: (checked) =>
                  onElementCheckedChanged(element, isChecked: checked ?? false),
              onAccountChanged: (accountId) => onElementAccountChanged(element.id, accountId),
              onQuantityChanged: (value) => onQuantityChanged(element.id, value),
            ),
      ],
    );
  }
}
