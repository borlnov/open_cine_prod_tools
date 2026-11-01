// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_poste_dropdown.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_row.dart';

/// Step 3 of `addQuoteLinesFromBreakdown`: the breakdown elements no quote line prices yet, a
/// search field, a `File all under` poste for every row and the per-row poste and quantity.
class OcptBudgetNewBreakdownStep extends StatelessWidget {
  /// Every live breakdown element no live quote line prices yet.
  final List<OcptElement> unpricedElements;

  /// The search field's current text.
  final String query;

  /// The ids of the checked elements.
  final Set<String> selectedIds;

  /// The poste every row inherits until it is given one of its own, or null.
  final String? bulkPosteId;

  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// The poste a row will be filed under: its own override, else the bulk default, else null.
  final String? Function(String elementId) posteIdOf;

  /// The quantity controller of an element, created by the wizard's state on first request.
  final TextEditingController Function(OcptElement element) quantityControllerOf;

  /// Called with the `File all under` poste picked.
  final ValueChanged<String?> onBulkPosteChanged;

  /// Called with the search field's text as it changes.
  final ValueChanged<String> onQueryChanged;

  /// Called when an element's checkbox changes, with the element and its new checked state.
  final void Function(OcptElement element, {required bool isChecked}) onElementCheckedChanged;

  /// Called when a row is given a poste of its own, with the element id and the poste.
  final void Function(String elementId, String? posteId) onElementPosteChanged;

  /// Called when a row's quantity text changes, with the element id and the text.
  final void Function(String elementId, String value) onQuantityChanged;

  /// Class constructor
  const OcptBudgetNewBreakdownStep({
    super.key,
    required this.unpricedElements,
    required this.query,
    required this.selectedIds,
    required this.bulkPosteId,
    required this.postes,
    required this.isSimplified,
    required this.posteIdOf,
    required this.quantityControllerOf,
    required this.onBulkPosteChanged,
    required this.onQueryChanged,
    required this.onElementCheckedChanged,
    required this.onElementPosteChanged,
    required this.onQuantityChanged,
  });

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
              tr.budgetNewBreakdownSetAllPosteLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OcptBudgetNewBreakdownPosteDropdown(
                dropdownKey: const Key("ocptBudgetNewBreakdownSetAllPoste"),
                value: bulkPosteId,
                enabled: true,
                postes: postes,
                isSimplified: isSimplified,
                onChanged: onBulkPosteChanged,
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
              posteId: posteIdOf(element.id),
              postes: postes,
              isSimplified: isSimplified,
              onCheckedChanged: (checked) =>
                  onElementCheckedChanged(element, isChecked: checked ?? false),
              onPosteChanged: (posteId) => onElementPosteChanged(element.id, posteId),
              onQuantityChanged: (value) => onQuantityChanged(element.id, value),
            ),
      ],
    );
  }
}
