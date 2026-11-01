// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';

/// `Ressource` — offered under [OcptBudgetEntryNature.financing] and
/// [OcptBudgetEntryNature.repayment] alike.
class OcptBudgetEntryResourceField extends StatelessWidget {
  /// Every live financing resource.
  final List<OcptBudgetResource> resources;

  /// The financing resource currently picked, or null.
  final String? resourceId;

  /// Called with the financing resource just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetEntryResourceField({
    super.key,
    required this.resources,
    required this.resourceId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: const Key("ocptBudgetEntryWizardResourceField"),
      initialValue: resourceId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogResourceFieldLabel),
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoResourceLabel)),
        for (final resource in resources)
          DropdownMenuItem(value: resource.id, child: Text(resource.label)),
      ],
      onChanged: onChanged,
    );
  }
}
