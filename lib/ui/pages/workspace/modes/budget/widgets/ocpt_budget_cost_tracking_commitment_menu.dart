// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';

/// A commitment's own `⋮` menu: edit, settle or unsettle, delete — each entry withheld on its own
/// terms (see `OcptBudgetCostTracking`'s class doc comment).
class OcptBudgetCostTrackingCommitmentMenu extends StatelessWidget {
  /// The cost tracking table whose callbacks and entries the menu is wired to.
  final OcptBudgetCostTracking costTracking;

  /// The commitment the menu acts on.
  final OcptBudgetCommitment commitment;

  /// Class constructor
  const OcptBudgetCostTrackingCommitmentMenu({
    super.key,
    required this.costTracking,
    required this.commitment,
  });

  /// Build the commitment menu as a [PopupMenuButton].
  @override
  Widget build(BuildContext context) {
    final isSettled = ocptBudgetCommitmentIsSettledOf(
      commitment,
      costTracking.entries,
      projectVatRateBasisPoints: costTracking.defaultVatRateBasisPoints,
    );
    final isReadOnly = costTracking.isReadOnly;
    final onEdit = isReadOnly ? null : costTracking.onCommitmentEditRequested;
    final onSettle = isReadOnly || isSettled ? null : costTracking.onCommitmentSettleRequested;
    final onUnsettle = isReadOnly || !isSettled ? null : costTracking.onCommitmentUnsettleRequested;
    final onDelete = isReadOnly ? null : costTracking.onCommitmentDeletionRequested;
    final tr = Tr.of(context);

    return PopupMenuButton<String>(
      tooltip: "",
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) => switch (value) {
        "edit" => onEdit?.call(commitment),
        "settle" => onSettle?.call(commitment),
        "unsettle" => onUnsettle?.call(commitment.id),
        "delete" => onDelete?.call(commitment.id),
        _ => null,
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem<String>(value: "edit", child: Text(tr.budgetFinancingEditAction)),
        if (onSettle != null)
          PopupMenuItem<String>(value: "settle", child: Text(tr.budgetCommittedSettleAction)),
        if (onUnsettle != null)
          PopupMenuItem<String>(value: "unsettle", child: Text(tr.budgetCommittedUnsettleAction)),
        if (onDelete != null)
          PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
      ],
    );
  }
}
