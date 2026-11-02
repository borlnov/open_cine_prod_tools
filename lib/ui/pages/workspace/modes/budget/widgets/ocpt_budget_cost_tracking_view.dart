// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_view_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_wizard_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';

/// The expenses view: the cost-tracking table of postes, quote lines, commitments and entries.
class OcptBudgetCostTrackingView extends StatelessWidget {
  /// The mode's state, which the table's rows and figures are read from.
  final OcptBudgetState state;

  /// Asks the mode to confirm, then delete, the poste with this id.
  final ValueChanged<String> onPosteDeletionRequested;

  /// Asks the mode to confirm, then delete, the commitment with this id.
  final ValueChanged<String> onCommitmentDeletionRequested;

  /// Asks the mode to confirm, then delete, the cash-journal entry with this id.
  final ValueChanged<String> onEntryDeletionRequested;

  /// Class constructor
  const OcptBudgetCostTrackingView({
    super.key,
    required this.state,
    required this.onPosteDeletionRequested,
    required this.onCommitmentDeletionRequested,
    required this.onEntryDeletionRequested,
  });

  /// Build the budget cost tracking view as an [OcptBudgetCostTracking].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();
    final journalBloc = context.read<OcptBudgetCashJournalBloc>();
    final expensesBloc = context.read<OcptBudgetExpensesBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final elementLinkCounts = state.elementLinkCounts;

    return OcptBudgetCostTracking(
      // **The filter is applied here, not inside the view.** Every one of these widgets draws
      // exactly the rows it is handed and totals exactly those, so narrowing the list is the whole
      // of it: a filtered table's own `Total` reads the total of what is on screen, which is the
      // only honest thing it can say. The commitments and entries the tree reads its own sub-rows
      // from are handed in whole — a poste already outside the filter draws no row at all, so its
      // own commitments and entries never reach the screen either.
      postes: _filteredPostesOf(state),
      commitments: state.commitments,
      entries: state.entries,
      selection: state.selection,
      expandedNodeIds: state.expandedNodeIds,
      isSimplified: state.isSimplified,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      paidByPosteId: state.paidByPosteId,
      committedCentsOf: state.committedCentsOf,
      inKindCoveredCentsOf: state.inKindCoveredCentsOf,
      offQuoteTotal: state.offQuotePaidTotal,
      breakdownPricedElementCount: elementLinkCounts.pricedCount,
      breakdownUnpricedElementCount: elementLinkCounts.unpricedCount,
      shootingDayCount: state.logisticsDays.length,
      mealCount: state.logisticsTotals.mealCount,
      buffetCount: state.logisticsTotals.buffetCount,
      isReadOnly: isReadOnly,
      onPosteSelected: (posteId) => bloc.add(OcptBudgetPosteSelectedEvent(posteId: posteId)),
      onLineSelected: (lineId) => bloc.add(OcptBudgetLineSelectedEvent(lineId: lineId)),
      onCommitmentSelected: (commitmentId) =>
          bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId)),
      onEntrySelected: (entryId) => bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId)),
      onNodeExpansionToggled: (nodeId) =>
          bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
      onPosteCreationRequested: isReadOnly
          ? null
          : () => expensesBloc.add(const OcptBudgetPosteCreatedEvent()),
      onPosteReorderRequested: isReadOnly
          ? null
          : (posteId, {required moveUp}) => expensesBloc.add(
              OcptBudgetPosteReorderedEvent(
                posteId: posteId,
                newPosition: _posteReorderedPosition(state, posteId, moveUp),
              ),
            ),
      onPosteDeletionRequested: isReadOnly ? null : onPosteDeletionRequested,
      // Never withheld under a preview: it only ever reads the project — see
      // `OcptBudgetCostTracking.onPosteFilterRequested`'s own doc comment.
      onPosteFilterRequested: (posteId) =>
          bloc.add(OcptBudgetPosteFilterSelectedEvent(posteId: posteId)),
      onCommitmentEditRequested: isReadOnly
          ? null
          : (commitment) => unawaited(ocptBudgetEditCommitment(context, state, commitment)),
      onCommitmentSettleRequested: isReadOnly
          ? null
          : (commitment) => unawaited(ocptBudgetSettleCommitment(context, state, commitment)),
      onCommitmentUnsettleRequested: isReadOnly
          ? null
          : (commitmentId) => journalBloc.add(
              OcptBudgetCommitmentUnsettleRequestedEvent(commitmentId: commitmentId),
            ),
      onCommitmentDeletionRequested: isReadOnly ? null : onCommitmentDeletionRequested,
      onEntryEditRequested: isReadOnly
          ? null
          : (entry) => unawaited(ocptBudgetEditEntry(context, state, entry)),
      onEntryDeletionRequested: isReadOnly ? null : onEntryDeletionRequested,
      onBreakdownFeedRequested: () => ocptBudgetOpenBreakdownElements(context),
      onScheduleFeedRequested: () => ocptBudgetOpenSchedule(context),
      onCateringFeedRequested: () => ocptBudgetOpenCatering(bloc),
    );
  }
}

/// Get the 0-based position poste [posteId] moves to when its row's own `▲`/`▼` menu entry is
/// clicked — one above or below its current position in [OcptBudgetState.postes]' own order, a
/// poste id no longer found there (should not happen, the shell already refused to draw a stale
/// row's menu) falling back to leaving it where it is.
int _posteReorderedPosition(OcptBudgetState state, String posteId, bool moveUp) {
  final currentIndex = state.postes.indexWhere((poste) => poste.id == posteId);
  if (currentIndex < 0) {
    return 0;
  }

  return moveUp ? currentIndex - 1 : currentIndex + 1;
}

/// Get [state]'s own postes, narrowed to the one the header's filter names — or every one of them
/// while nothing is filtered.
///
/// See `ocptBudgetViewHonoursPosteFilter` for which views read this and which say they cannot.
List<OcptBudgetPoste> _filteredPostesOf(OcptBudgetState state) {
  final filterPosteId = state.filterPosteId;

  return filterPosteId == null
      ? state.postes
      : [
          for (final poste in state.postes)
            if (poste.id == filterPosteId) poste,
        ];
}
