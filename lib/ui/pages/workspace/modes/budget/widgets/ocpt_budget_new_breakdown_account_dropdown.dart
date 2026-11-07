// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A compact account picker — the breakdown selector's header `File all under` control and every
/// row's own override share it. [value] is the account currently in effect (an override, or the
/// bulk default), null drawing the `Choose a poste` hint; [enabled] greys it while its row is
/// unchecked.
class OcptBudgetNewBreakdownAccountDropdown extends StatelessWidget {
  /// The key given to the underlying [DropdownButton].
  final Key dropdownKey;

  /// The account currently in effect, or null.
  final String? value;

  /// Whether the picker can be used.
  final bool enabled;

  /// Every live account of the project.
  final List<OcptBudgetAccount> accounts;

  /// Whether the mode's header currently reads simplified.
  final bool isSimplified;

  /// Called with the account picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetNewBreakdownAccountDropdown({
    super.key,
    required this.dropdownKey,
    required this.value,
    required this.enabled,
    required this.accounts,
    required this.isSimplified,
    required this.onChanged,
  });

  /// Build the budget new breakdown account dropdown as a [DropdownButton].
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
        tr.budgetNewBreakdownAccountChooseHint,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      onChanged: enabled ? onChanged : null,
      items: [
        for (final account in accounts)
          DropdownMenuItem<String>(
            value: account.id,
            child: Text(
              ocptBudgetAccountDisplayLabel(account, isSimplified: isSimplified),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
