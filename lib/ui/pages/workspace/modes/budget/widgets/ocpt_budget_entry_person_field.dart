// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_link_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_entry_share_field.dart';

/// `Personne` — offered under [OcptBudgetEntryNature.personReimbursement] alone. Mirrors
/// [OcptBudgetEntryShareField] verbatim: the field that gives [OcptBudgetEntryLinkKind.person] a
/// real screen instead of a thrown error.
class OcptBudgetEntryPersonField extends StatelessWidget {
  /// Every person.
  final List<OcptPerson> people;

  /// The person currently picked, or null.
  final String? personId;

  /// Called with the person just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetEntryPersonField({
    super.key,
    required this.people,
    required this.personId,
    required this.onChanged,
  });

  /// Build the budget entry person field as a [DropdownButtonFormField].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: const Key("ocptBudgetEntryWizardPersonField"),
      initialValue: personId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogPersonFieldLabel),
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoPersonLabel)),
        for (final person in people)
          DropdownMenuItem(value: person.id, child: Text(person.displayName)),
      ],
      onChanged: onChanged,
    );
  }
}
