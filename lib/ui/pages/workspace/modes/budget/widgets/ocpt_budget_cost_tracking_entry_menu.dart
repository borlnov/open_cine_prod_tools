// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';

/// An entry's own `⋮` menu: edit and delete, each withheld while its callback is.
class OcptBudgetCostTrackingEntryMenu extends StatelessWidget {
  /// The cost tracking table whose callbacks the menu is wired to.
  final OcptBudgetCostTracking costTracking;

  /// The entry the menu acts on.
  final OcptBudgetEntry entry;

  /// Class constructor
  const OcptBudgetCostTrackingEntryMenu({
    super.key,
    required this.costTracking,
    required this.entry,
  });

  /// Build the entry menu as a [PopupMenuButton].
  @override
  Widget build(BuildContext context) {
    final isReadOnly = costTracking.isReadOnly;
    final onEdit = isReadOnly ? null : costTracking.onEntryEditRequested;
    final onDelete = isReadOnly ? null : costTracking.onEntryDeletionRequested;
    final tr = Tr.of(context);

    return PopupMenuButton<String>(
      tooltip: "",
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) => switch (value) {
        "edit" => onEdit?.call(entry),
        "delete" => onDelete?.call(entry.id),
        _ => null,
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
        if (onDelete != null)
          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetEntryDeleteAction)),
      ],
    );
  }
}
