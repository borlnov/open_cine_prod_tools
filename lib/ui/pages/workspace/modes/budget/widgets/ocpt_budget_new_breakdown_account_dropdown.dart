// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A compact poste picker — the breakdown selector's header `File all under` control and every
/// row's own override share it. [value] is the poste currently in effect (an override, or the bulk
/// default), null drawing the `Choose a poste` hint; [enabled] greys it while its row is
/// unchecked.
class OcptBudgetNewBreakdownPosteDropdown extends StatelessWidget {
  /// The key given to the underlying [DropdownButton].
  final Key dropdownKey;

  /// The poste currently in effect, or null.
  final String? value;

  /// Whether the picker can be used.
  final bool enabled;

  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Called with the poste picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetNewBreakdownPosteDropdown({
    super.key,
    required this.dropdownKey,
    required this.value,
    required this.enabled,
    required this.postes,
    required this.isSimplified,
    required this.onChanged,
  });

  /// Build the budget new breakdown poste dropdown as a [DropdownButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return DropdownButton<String>(
      key: dropdownKey,
      value: value,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
      hint: Text(
        tr.budgetNewBreakdownPosteChooseHint,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      onChanged: enabled ? onChanged : null,
      items: [
        for (final poste in postes)
          DropdownMenuItem<String>(
            value: poste.id,
            child: Text(
              ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
