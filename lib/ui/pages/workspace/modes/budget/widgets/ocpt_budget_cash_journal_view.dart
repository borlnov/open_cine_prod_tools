// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_view_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';

/// The tools drawer's own `Flux de trésorerie` page — read-only, and honouring no poste filter at
/// all, `OcptBudgetCashJournal`'s own class doc comment arguing why.
class OcptBudgetCashJournalView extends StatelessWidget {
  /// The mode's state, which the journal's entries, commitments and postes are read from.
  final OcptBudgetState state;

  /// Asks the mode to confirm, then delete, the cash-journal entry with this id.
  final ValueChanged<String> onEntryDeletionRequested;

  /// Class constructor
  const OcptBudgetCashJournalView({
    super.key,
    required this.state,
    required this.onEntryDeletionRequested,
  });

  /// Build the budget cash journal view as an [OcptBudgetCashJournal].
  @override
  Widget build(BuildContext context) {
    final isReadOnly = state.isPreviewingVersion;
    final bloc = context.read<OcptBudgetBloc>();

    return OcptBudgetCashJournal(
      entries: state.entries,
      commitments: state.commitments,
      postes: state.postes,
      receiptsByEntryId: state.receiptsByEntryId,
      selection: state.selection,
      isSimplified: state.isSimplified,
      defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
      currencyCode: state.currencyCode,
      isReadOnly: isReadOnly,
      onEntrySelected: (entryId) => bloc.add(OcptBudgetEntrySelectedEvent(entryId: entryId)),
      onEntryEditRequested: isReadOnly
          ? null
          : (entry) => unawaited(ocptBudgetEditEntry(context, state, entry)),
      onEntryDeletionRequested: isReadOnly ? null : onEntryDeletionRequested,
      // Never withheld under a preview: selecting only opens the right dock's own fiche, it writes
      // nothing.
      onCommitmentSelected: (commitmentId) =>
          bloc.add(OcptBudgetCommitmentSelectedEvent(commitmentId: commitmentId)),
      shareableCents: state.sharingPot.shareableCents,
      // Switching the drawer to the sharing page writes nothing, so it stands under a preview too.
      onOpenSharing: () =>
          bloc.add(const OcptBudgetToolsViewSelectedEvent(toolsView: OcptBudgetToolsView.sharing)),
    );
  }
}
