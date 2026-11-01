// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_breakdown_poste_dropdown.dart';

/// One element of the breakdown selector: its checkbox, its name and scene count, the poste it
/// will be filed under and the quantity of the line to create.
class OcptBudgetNewBreakdownRow extends StatelessWidget {
  /// The element the row stands for.
  final OcptElement element;

  /// Whether the element is checked.
  final bool isSelected;

  /// The quantity field's controller, owned by the wizard's state.
  final TextEditingController quantityController;

  /// The poste the element will be filed under, or null while none is chosen.
  final String? posteId;

  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Called with the checkbox's new value.
  final ValueChanged<bool?> onCheckedChanged;

  /// Called with the poste picked for this row.
  final ValueChanged<String?> onPosteChanged;

  /// Called with the quantity field's text as it changes.
  final ValueChanged<String> onQuantityChanged;

  /// Class constructor
  const OcptBudgetNewBreakdownRow({
    super.key,
    required this.element,
    required this.isSelected,
    required this.quantityController,
    required this.posteId,
    required this.postes,
    required this.isSimplified,
    required this.onCheckedChanged,
    required this.onPosteChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            key: Key("ocptBudgetNewBreakdownCheckbox-${element.id}"),
            value: isSelected,
            onChanged: onCheckedChanged,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(element.name.isEmpty ? tr.resourcesElementUnnamed : element.name),
                Text(
                  tr.budgetNewBreakdownSceneCountHint(element.sceneLinks.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: OcptBudgetNewBreakdownPosteDropdown(
              dropdownKey: Key("ocptBudgetNewBreakdownPoste-${element.id}"),
              value: posteId,
              enabled: isSelected,
              postes: postes,
              isSimplified: isSimplified,
              onChanged: onPosteChanged,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              key: Key("ocptBudgetNewBreakdownQuantity-${element.id}"),
              controller: quantityController,
              enabled: isSelected,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true),
              onChanged: onQuantityChanged,
            ),
          ),
        ],
      ),
    );
  }
}
