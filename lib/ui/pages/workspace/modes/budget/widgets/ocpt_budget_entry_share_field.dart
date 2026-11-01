// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';

/// `Participant` — offered under [OcptBudgetEntryNature.payout] alone.
class OcptBudgetEntryShareField extends StatelessWidget {
  /// Every live share.
  final List<OcptBudgetShare> shares;

  /// The share currently picked, or null.
  final String? shareId;

  /// Called with the share just picked.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const OcptBudgetEntryShareField({
    super.key,
    required this.shares,
    required this.shareId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return DropdownButtonFormField<String?>(
      key: const Key("ocptBudgetEntryWizardShareField"),
      initialValue: shareId,
      decoration: InputDecoration(labelText: tr.budgetEntryDialogShareFieldLabel),
      items: [
        DropdownMenuItem(child: Text(tr.budgetEntryDialogNoShareLabel)),
        for (final share in shares) DropdownMenuItem(value: share.id, child: Text(share.label)),
      ],
      onChanged: onChanged,
    );
  }
}
