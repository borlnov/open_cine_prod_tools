// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_view_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_wizard_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing.dart';

/// The resources view: the nesting tree of subsidies, contributions and takings, and its own
/// coverage band. Every revenue callback — the edit dialog, the receipt shortcut, the reorder and
/// the deletion — is this tree's own, the sharing view having lost its own copy of the takings.
class OcptBudgetFinancingView extends StatelessWidget {
  /// The mode's state, which the resources, the takings and what they received are read from.
  final OcptBudgetState state;

  /// Asks the mode to confirm, then delete, the financing resource with this id.
  final ValueChanged<String> onResourceDeletionRequested;

  /// Asks the mode to confirm, then undo, the last receipt recorded against this resource.
  final ValueChanged<OcptBudgetResource> onResourceReceiptUndoRequested;

  /// Asks the mode to confirm, then delete, the taking with this id.
  final ValueChanged<String> onRevenueDeletionRequested;

  /// Class constructor
  const OcptBudgetFinancingView({
    super.key,
    required this.state,
    required this.onResourceDeletionRequested,
    required this.onResourceReceiptUndoRequested,
    required this.onRevenueDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();
    final sharingBloc = context.read<OcptBudgetSharingBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetFinancing(
      resources: state.resources,
      revenues: state.revenues,
      entries: state.entries,
      postes: state.postes,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      receivedByResourceId: state.receivedByResourceId,
      receivedCentsOf: state.receivedCentsOf,
      receivedByRevenueId: state.receivedByRevenueId,
      currencyCode: state.currencyCode,
      selection: state.selection,
      expandedNodeIds: state.expandedNodeIds,
      isReadOnly: isReadOnly,
      onNodeExpansionToggled: (nodeId) =>
          bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
      onResourceSelected: (resourceId) =>
          bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId)),
      onResourceEditRequested: isReadOnly
          ? null
          : (resource) => unawaited(ocptBudgetEditResource(context, state, resource)),
      onResourceReceiptRequested: isReadOnly
          ? null
          : (resource) => unawaited(ocptBudgetReceiveResource(context, state, resource)),
      onResourceReceiptUndoRequested: isReadOnly ? null : onResourceReceiptUndoRequested,
      onResourceDeletionRequested: isReadOnly ? null : onResourceDeletionRequested,
      onRevenueSelected: (revenueId) =>
          bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId)),
      onRevenueEditRequested: isReadOnly
          ? null
          : (revenue) => unawaited(ocptBudgetEditRevenue(context, state, revenue)),
      onRevenueReceiptRequested: isReadOnly
          ? null
          : (revenue) => unawaited(ocptBudgetReceiveRevenue(context, state, revenue)),
      onRevenueReorderRequested: isReadOnly
          ? null
          : (revenueId, {required moveUp}) => sharingBloc.add(
              OcptBudgetRevenueReorderedEvent(
                revenueId: revenueId,
                newPosition: _revenueReorderedPosition(state, revenueId, moveUp),
              ),
            ),
      onRevenueDeletionRequested: isReadOnly ? null : onRevenueDeletionRequested,
      onReceiptSelected: (receiptId) =>
          bloc.add(OcptBudgetReceiptSelectedEvent(receiptId: receiptId)),
      onExpensesRequested: () =>
          bloc.add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.expenses)),
    );
  }
}

/// The 0-based position revenue [revenueId] moves to when its row's own `⋮` menu `▲`/`▼` entry
/// is clicked — one above or below its current position in [OcptBudgetState.revenues]' own order,
/// a revenue id no longer found there falling back to the first position.
int _revenueReorderedPosition(OcptBudgetState state, String revenueId, bool moveUp) {
  final currentIndex = state.revenues.indexWhere((revenue) => revenue.id == revenueId);
  if (currentIndex < 0) {
    return 0;
  }

  return moveUp ? currentIndex - 1 : currentIndex + 1;
}
