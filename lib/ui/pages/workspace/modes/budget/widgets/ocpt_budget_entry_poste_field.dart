// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// `Poste du devis` — offered under [OcptBudgetEntryNature.expense] and
/// [OcptBudgetEntryNature.other] alike. **Its own "unanswered" item reads `Hors devis`, never a
/// generic "no poste"**: the very same label the expenses table draws for the very same synthetic
/// row, so a reader who leaves this field blank sees, in the field itself, exactly where the
/// entry will land.
class OcptBudgetEntryPosteField extends StatelessWidget {
  /// Every live poste.
  final List<OcptBudgetPoste> postes;

  /// Whether the simplified naming applies to the poste labels.
  final bool isSimplified;

  /// The poste currently picked, or null.
  final String? posteId;

  /// Called with the poste just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetEntryPosteField({
    super.key,
    required this.postes,
    required this.isSimplified,
    required this.posteId,
    required this.onChanged,
  });

  /// Build the budget entry poste field as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          key: const Key("ocptBudgetEntryWizardPosteField"),
          initialValue: posteId,
          decoration: InputDecoration(labelText: tr.budgetEntryDialogPosteFieldLabel),
          items: [
            DropdownMenuItem(child: Text(tr.budgetCostTrackingOffQuoteLabel)),
            for (final poste in postes)
              DropdownMenuItem(
                value: poste.id,
                child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)),
              ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        Text(
          tr.budgetEntryWizardPosteFieldHint(tr.budgetCostTrackingOffQuoteLabel),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
