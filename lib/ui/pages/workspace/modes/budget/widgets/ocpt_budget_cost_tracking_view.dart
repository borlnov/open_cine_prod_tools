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

/// The expenses view: the cost-tracking table of accounts, quote lines, commitments and entries.
class OcptBudgetCostTrackingView extends StatelessWidget {
  /// The mode's state, which the table's rows and figures are read from.
  final OcptBudgetState state;

  /// Asks the mode to confirm, then delete, the account with this id.
  final ValueChanged<String> onAccountDeletionRequested;

  /// Asks the mode to confirm, then delete, the commitment with this id.
  final ValueChanged<String> onCommitmentDeletionRequested;

  /// Asks the mode to confirm, then delete, the cash-journal entry with this id.
  final ValueChanged<String> onEntryDeletionRequested;

  /// Class constructor
  const OcptBudgetCostTrackingView({
    super.key,
    required this.state,
    required this.onAccountDeletionRequested,
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
      // from are handed in whole — an account already outside the filter draws no row at all, so
      // its own commitments and entries never reach the screen either.
      accounts: _filteredAccountsOf(state),
      commitments: state.commitments,
      entries: state.entries,
      selection: state.selection,
      expandedNodeIds: state.expandedNodeIds,
      isSimplified: state.isSimplified,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      paidByAccountId: state.paidByAccountId,
      committedCentsOf: state.committedCentsOf,
      inKindCoveredCentsOf: state.inKindCoveredCentsOf,
      offQuoteTotal: state.offQuotePaidTotal,
      breakdownPricedElementCount: elementLinkCounts.pricedCount,
      breakdownUnpricedElementCount: elementLinkCounts.unpricedCount,
      shootingDayCount: state.logisticsDays.length,
      mealCount: state.logisticsTotals.mealCount,
      buffetCount: state.logisticsTotals.buffetCount,
      isReadOnly: isReadOnly,
      onAccountSelected: (accountId) =>
          bloc.add(OcptBudgetAccountSelectedEvent(accountId: accountId)),
      onLineSelected: (lineId) => bloc.add(OcptBudgetLineSelectedEvent(lineId: lineId)),
      onCommitmentSelected: (commitmentId) =>
          bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId)),
      onEntrySelected: (entryId) => bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId)),
      onNodeExpansionToggled: (nodeId) =>
          bloc.add(OcptBudgetRowExpansionToggledEvent(nodeId: nodeId)),
      onAccountCreationRequested: isReadOnly
          ? null
          : () => expensesBloc.add(const OcptBudgetAccountCreatedEvent()),
      onAccountReorderRequested: isReadOnly
          ? null
          : (accountId, {required moveUp}) => expensesBloc.add(
              OcptBudgetAccountReorderedEvent(
                accountId: accountId,
                newPosition: _accountReorderedPosition(state, accountId, moveUp),
              ),
            ),
      onAccountDeletionRequested: isReadOnly ? null : onAccountDeletionRequested,
      // Never withheld under a preview: it only ever reads the project — see
      // `OcptBudgetCostTracking.onAccountFilterRequested`'s own doc comment.
      onAccountFilterRequested: (accountId) =>
          bloc.add(OcptBudgetAccountFilterSelectedEvent(accountId: accountId)),
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

/// Get the 0-based position account [accountId] moves to when its row's own `▲`/`▼` menu entry is
/// clicked — one above or below its current position in [OcptBudgetState.accounts]' own order, an
/// account id no longer found there (should not happen, the shell already refused to draw a stale
/// row's menu) falling back to leaving it where it is.
int _accountReorderedPosition(OcptBudgetState state, String accountId, bool moveUp) {
  final currentIndex = state.accounts.indexWhere((account) => account.id == accountId);
  if (currentIndex < 0) {
    return 0;
  }

  return moveUp ? currentIndex - 1 : currentIndex + 1;
}

/// Get [state]'s own accounts, narrowed to the one the header's filter names — or every one of them
/// while nothing is filtered.
///
/// See `ocptBudgetViewHonoursAccountFilter` for which views read this and which say they cannot.
List<OcptBudgetAccount> _filteredAccountsOf(OcptBudgetState state) {
  final filterAccountId = state.filterAccountId;

  return filterAccountId == null
      ? state.accounts
      : [
          for (final account in state.accounts)
            if (account.id == filterAccountId) account,
        ];
}
