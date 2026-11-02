// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_view_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_wizard_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';

/// The `Inspector` tab's own content: the polymorphic detail panel, wired to every handler its own
/// selection variant might need — the edit dialogs and wizard shortcuts the views already share,
/// and the mode's confirmations, which this widget only asks for.
///
/// **`onLineShowCommitmentRequested` opens the tools drawer's own `Flux de trésorerie` page and
/// selects the line's own commitment there**, under its own `À venir` section — the very reading
/// the logistics's feed row gives, plus the selection event
/// `OcptBudgetCostTracking.onCommitmentSelected` already dispatches.
///
/// It listens to `OcptBudgetExpensesBloc` alone, for the typed edits that bloc still holds, so a
/// keystroke in a field rebuilds the detail panel and nothing around it.
class OcptBudgetDetailView extends StatelessWidget {
  /// The mode's state, which the selection and everything the detail panel shows are read from.
  final OcptBudgetState state;

  /// Asks the mode to confirm, then delete, the quote line with this id.
  final ValueChanged<String> onLineDeletionRequested;

  /// Asks the mode to confirm, then undo, the promotion of the quote line with this id.
  final ValueChanged<String> onLineUncommitRequested;

  /// Asks the mode to confirm, then delete, the commitment with this id.
  final ValueChanged<String> onCommitmentDeletionRequested;

  /// Asks the mode to confirm, then delete, the cash-journal entry with this id.
  final ValueChanged<String> onEntryDeletionRequested;

  /// Asks the mode to confirm, then delete, the financing resource with this id.
  final ValueChanged<String> onResourceDeletionRequested;

  /// Asks the mode to confirm, then delete, the taking with this id.
  final ValueChanged<String> onRevenueDeletionRequested;

  /// Class constructor
  const OcptBudgetDetailView({
    super.key,
    required this.state,
    required this.onLineDeletionRequested,
    required this.onLineUncommitRequested,
    required this.onCommitmentDeletionRequested,
    required this.onEntryDeletionRequested,
    required this.onResourceDeletionRequested,
    required this.onRevenueDeletionRequested,
  });

  /// Build the budget detail panel view as a [BlocBuilder].
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OcptBudgetExpensesBloc, OcptBudgetExpensesState>(
        builder: (context, expensesState) => _OcptBudgetDetailBody(
          state: state,
          expensesState: expensesState,
          onLineDeletionRequested: onLineDeletionRequested,
          onLineUncommitRequested: onLineUncommitRequested,
          onCommitmentDeletionRequested: onCommitmentDeletionRequested,
          onEntryDeletionRequested: onEntryDeletionRequested,
          onResourceDeletionRequested: onResourceDeletionRequested,
          onRevenueDeletionRequested: onRevenueDeletionRequested,
        ),
      );
}

/// The polymorphic detail panel over [state] and the edits [expensesState] still holds.
class _OcptBudgetDetailBody extends StatelessWidget {
  /// The mode's state.
  final OcptBudgetState state;

  /// The expenses bloc's state, whose typed edits the fields read first.
  final OcptBudgetExpensesState expensesState;

  /// See [OcptBudgetDetailView.onLineDeletionRequested].
  final ValueChanged<String> onLineDeletionRequested;

  /// See [OcptBudgetDetailView.onLineUncommitRequested].
  final ValueChanged<String> onLineUncommitRequested;

  /// See [OcptBudgetDetailView.onCommitmentDeletionRequested].
  final ValueChanged<String> onCommitmentDeletionRequested;

  /// See [OcptBudgetDetailView.onEntryDeletionRequested].
  final ValueChanged<String> onEntryDeletionRequested;

  /// See [OcptBudgetDetailView.onResourceDeletionRequested].
  final ValueChanged<String> onResourceDeletionRequested;

  /// See [OcptBudgetDetailView.onRevenueDeletionRequested].
  final ValueChanged<String> onRevenueDeletionRequested;

  /// Class constructor
  const _OcptBudgetDetailBody({
    required this.state,
    required this.expensesState,
    required this.onLineDeletionRequested,
    required this.onLineUncommitRequested,
    required this.onCommitmentDeletionRequested,
    required this.onEntryDeletionRequested,
    required this.onResourceDeletionRequested,
    required this.onRevenueDeletionRequested,
  });

  /// Build the budget detail panel body as an [OcptBudgetDetail].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();
    final journalBloc = context.read<OcptBudgetCashJournalBloc>();
    final expensesBloc = context.read<OcptBudgetExpensesBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final elementNameByElementId = {for (final element in state.elements) element.id: element.name};
    // The off-line-debit banner's own two actions read the very same entry a receipt's own detail
    // panel shares with an ordinary entry's — `OcptBudgetReceiptSelection` names the same
    // `budget_entries` row as `OcptBudgetEntrySelection`, only through a different field.
    final selectedEntryId = switch (state.selection) {
      OcptBudgetEntrySelection(:final entryId) => entryId,
      OcptBudgetReceiptSelection(:final receiptId) => receiptId,
      _ => null,
    };
    final selectedCommitmentId = switch (state.selection) {
      OcptBudgetCommitmentSelection(:final commitmentId) => commitmentId,
      _ => null,
    };

    return OcptBudgetDetail(
      selection: state.selection,
      postes: state.postes,
      commitments: state.commitments,
      entries: state.entries,
      resources: state.resources,
      revenues: state.revenues,
      taxBasis: state.taxBasis,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isSimplified: state.isSimplified,
      isReadOnly: isReadOnly,
      elementNameByElementId: elementNameByElementId,
      receiptsByEntryId: state.receiptsByEntryId,
      receivedByResourceId: state.receivedByResourceId,
      receivedByRevenueId: state.receivedByRevenueId,
      fieldValueOf: expensesState.fieldValueOf,
      onFieldChanged: isReadOnly
          ? null
          : (targetId, field, rawValue) => expensesBloc.add(
              OcptBudgetFieldChangedEvent(targetId: targetId, field: field, rawValue: rawValue),
            ),
      onPosteEstimateToCompleteDerivedRequested: isReadOnly
          ? null
          : (posteId) => expensesBloc.add(
              OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent(posteId: posteId),
            ),
      onLineTaxInclusiveChanged: isReadOnly
          ? null
          : (lineId, {required isTaxInclusive}) => expensesBloc.add(
              OcptBudgetLineTaxInclusiveChangedEvent(
                lineId: lineId,
                isTaxInclusive: isTaxInclusive,
              ),
            ),
      onLineVatRateInheritedRequested: isReadOnly
          ? null
          : (lineId) =>
                expensesBloc.add(OcptBudgetLineVatRateInheritedRequestedEvent(lineId: lineId)),
      onLineCommitRequested: isReadOnly
          ? null
          : (lineId) => unawaited(ocptBudgetCommitLine(context, state, lineId)),
      onLinePayDirectlyRequested: isReadOnly
          ? null
          : (lineId) => unawaited(ocptBudgetPayLineDirectly(context, state, lineId)),
      onLineSettleRequested: isReadOnly
          ? null
          : (lineId) => unawaited(ocptBudgetSettleLine(context, state, lineId)),
      onLineShowCommitmentRequested: (lineId) =>
          _handleLineShowCommitmentRequested(bloc, state, lineId),
      onLineUncommitRequested: isReadOnly ? null : onLineUncommitRequested,
      onLineDeletionRequested: isReadOnly ? null : onLineDeletionRequested,
      onCommitmentSettleRequested: isReadOnly
          ? null
          : (commitment) => unawaited(ocptBudgetSettleCommitment(context, state, commitment)),
      onCommitmentEditRequested: isReadOnly
          ? null
          : (commitment) => unawaited(ocptBudgetEditCommitment(context, state, commitment)),
      onCommitmentDeletionRequested: isReadOnly ? null : onCommitmentDeletionRequested,
      onCommitmentPromoteToQuoteRequested: isReadOnly || selectedCommitmentId == null
          ? null
          : () => journalBloc.add(
              OcptBudgetCommitmentPromotedToQuoteEvent(commitmentId: selectedCommitmentId),
            ),
      onEntryEditRequested: isReadOnly
          ? null
          : (entry) => unawaited(ocptBudgetEditEntry(context, state, entry)),
      onEntryDeletionRequested: isReadOnly ? null : onEntryDeletionRequested,
      onEntryPromoteToQuoteRequested: isReadOnly || selectedEntryId == null
          ? null
          : () => journalBloc.add(OcptBudgetEntryPromotedToQuoteEvent(entryId: selectedEntryId)),
      onEntryMoveOffQuoteRequested: isReadOnly || selectedEntryId == null
          ? null
          : () => journalBloc.add(OcptBudgetEntryMovedOffQuoteEvent(entryId: selectedEntryId)),
      onResourceReceiptRequested: isReadOnly
          ? null
          : (resource) => unawaited(ocptBudgetReceiveResource(context, state, resource)),
      onResourceEditRequested: isReadOnly
          ? null
          : (resource) => unawaited(ocptBudgetEditResource(context, state, resource)),
      onResourceDeletionRequested: isReadOnly ? null : onResourceDeletionRequested,
      onRevenueReceiptRequested: isReadOnly
          ? null
          : (revenue) => unawaited(ocptBudgetReceiveRevenue(context, state, revenue)),
      onRevenueEditRequested: isReadOnly
          ? null
          : (revenue) => unawaited(ocptBudgetEditRevenue(context, state, revenue)),
      onRevenueDeletionRequested: isReadOnly ? null : onRevenueDeletionRequested,
    );
  }

  /// Open the tools drawer's own `Flux de trésorerie` page and select [lineId]'s own commitment
  /// there, under its own `À venir` section — never withheld under a preview, since it only moves
  /// the reader. The commitment is the line's own unsettled one, `À venir` holding no other kind.
  void _handleLineShowCommitmentRequested(
    OcptBudgetBloc bloc,
    OcptBudgetState state,
    String lineId,
  ) {
    final commitment = state.commitments
        .where(
          (commitment) =>
              commitment.lineId == lineId &&
              !ocptBudgetCommitmentIsSettledOf(
                commitment,
                state.entries,
                projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
              ),
        )
        .firstOrNull;
    if (commitment == null) {
      return;
    }

    bloc
      ..add(const OcptBudgetViewSelectedEvent(view: OcptBudgetView.tools))
      ..add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.cashFlow))
      ..add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitment.id));
  }
}
