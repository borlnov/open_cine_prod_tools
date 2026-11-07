// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_match_suggestion.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_match_candidate_kind.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_reimbursements.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_repayment_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_share_split.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_flow.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_dialog.dart';

/// Tell which [OcptBudgetGestureFamily] the current route promotes to the top of step 1 — the group
/// whose document the route works on — or null for [OcptBudgetView.dashboard], which works on no
/// single document.
OcptBudgetGestureFamily? _promotedGestureFamilyOf(OcptBudgetState state) =>
    switch ((state.view, state.toolsView)) {
      (OcptBudgetView.expenses, _) => OcptBudgetGestureFamily.quote,
      (OcptBudgetView.resources, _) => OcptBudgetGestureFamily.financingPlan,
      (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => OcptBudgetGestureFamily.cashMovement,
      (OcptBudgetView.tools, OcptBudgetToolsView.logistics) => OcptBudgetGestureFamily.allowances,
      (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => OcptBudgetGestureFamily.revenueSharing,
      (OcptBudgetView.dashboard, _) => null,
    };

/// Get [family]'s own first answer, in [OcptBudgetGesture]'s own declared order — the promoted
/// group's own first card, which arrives pre-selected so the frequent gesture is one click.
OcptBudgetGesture _firstGestureOf(OcptBudgetGestureFamily family) =>
    OcptBudgetGesture.values.firstWhere((gesture) => ocptBudgetGestureFamilyOf(gesture) == family);

/// Tell which gestures the `+ New` wizard offers when opened from the current route — a semantic
/// filter by the direction money moves (`ocptBudgetGestureFlowsOf`), **transverse to the
/// families**: the expenses route offers everything that spends, the resources route everything
/// that brings money in, the drawer's cash-flow page its own movements, logistics its defrayal.
/// Sharing offers its own participants **and `Le film a rapporté de l'argent`**
/// (`recordTakingReceipt`): the split is of what the film earns, so recording a taking belongs
/// where that money is divided up. Null for the dashboard, which works on no document and filters
/// nothing. The reader lifts it from inside the wizard (`Show all`).
Set<OcptBudgetGesture>? _wizardGesturesForView(OcptBudgetState state) {
  Set<OcptBudgetGesture> spending(OcptBudgetGestureFlow flow) => {
    for (final gesture in OcptBudgetGesture.values)
      if (ocptBudgetGestureFlowsOf(gesture).contains(flow)) gesture,
  };
  Set<OcptBudgetGesture> ofFamily(OcptBudgetGestureFamily family) => {
    for (final gesture in OcptBudgetGesture.values)
      if (ocptBudgetGestureFamilyOf(gesture) == family) gesture,
  };

  return switch ((state.view, state.toolsView)) {
    (OcptBudgetView.dashboard, _) => null,
    (OcptBudgetView.expenses, _) => spending(OcptBudgetGestureFlow.spends),
    (OcptBudgetView.resources, _) => spending(OcptBudgetGestureFlow.brings),
    (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => ofFamily(
      OcptBudgetGestureFamily.cashMovement,
    ),
    (OcptBudgetView.tools, OcptBudgetToolsView.logistics) => ofFamily(
      OcptBudgetGestureFamily.allowances,
    ),
    (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => {
      ...ofFamily(OcptBudgetGestureFamily.revenueSharing),
      OcptBudgetGesture.recordTakingReceipt,
    },
  };
}

/// Get the word the wizard's own filter tag names the current filter by — the route's own header
/// segment label. Read only where [_wizardGesturesForView] is non-null.
String _wizardFilterLabelOf(Tr tr, OcptBudgetState state) =>
    switch ((state.view, state.toolsView)) {
      (OcptBudgetView.expenses, _) => tr.budgetHeaderExpensesSegmentLabel,
      (OcptBudgetView.resources, _) => tr.budgetHeaderResourcesSegmentLabel,
      (OcptBudgetView.tools, OcptBudgetToolsView.cashFlow) => tr.budgetHeaderCashFlowSegmentLabel,
      (OcptBudgetView.tools, OcptBudgetToolsView.logistics) => tr.budgetHeaderLogisticsSegmentLabel,
      (OcptBudgetView.tools, OcptBudgetToolsView.sharing) => tr.budgetHeaderSharingSegmentLabel,
      (OcptBudgetView.dashboard, _) => "",
    };

/// The blocs an [OcptBudgetNewOutcome] is written through, read from a context **before** the
/// wizard opens.
///
/// A flow awaits a dialog, and the view that started it can be gone when the dialog closes: below
/// the compact breakpoint the workspace shell swaps its dock row for a stack, which unmounts every
/// view of the mode. The blocs outlive the views, so a flow that holds them already writes what the
/// user confirmed, where one that reads them off its context after the `await` would give up.
class OcptBudgetNewOutcomeTargets {
  /// The bloc of the quote.
  final OcptBudgetExpensesBloc expensesBloc;

  /// The bloc of the cash journal.
  final OcptBudgetCashJournalBloc journalBloc;

  /// The bloc of the financing plan and of the defrayals.
  final OcptBudgetFinancingBloc financingBloc;

  /// The bloc of the revenue sharing.
  final OcptBudgetSharingBloc sharingBloc;

  /// Class constructor
  const OcptBudgetNewOutcomeTargets({
    required this.expensesBloc,
    required this.journalBloc,
    required this.financingBloc,
    required this.sharingBloc,
  });

  /// Read the four blocs off [context].
  factory OcptBudgetNewOutcomeTargets.of(BuildContext context) => OcptBudgetNewOutcomeTargets(
    expensesBloc: context.read<OcptBudgetExpensesBloc>(),
    journalBloc: context.read<OcptBudgetCashJournalBloc>(),
    financingBloc: context.read<OcptBudgetFinancingBloc>(),
    sharingBloc: context.read<OcptBudgetSharingBloc>(),
  );
}

/// Open the capture wizard fresh — no step already answered — promoted and pre-selected per the
/// current route (the header band's own `+ New` button). Dispatches whatever
/// [ocptBudgetApplyNewOutcome] says once the wizard closes with something.
Future<void> ocptBudgetOpenNewWizard(BuildContext context, OcptBudgetState state) async {
  final targets = OcptBudgetNewOutcomeTargets.of(context);
  final promotedFamily = _promotedGestureFamilyOf(state);
  final allowedGestures = _wizardGesturesForView(state);
  final outcome = await OcptBudgetNewDialog.show(
    context,
    promotedFamily: promotedFamily,
    allowedGestures: allowedGestures,
    filterLabel: allowedGestures == null ? null : _wizardFilterLabelOf(Tr.of(context), state),
    initialGesture: promotedFamily == null ? null : _firstGestureOf(promotedFamily),
    accounts: state.accounts,
    resources: state.resources,
    revenues: state.revenues,
    shares: state.shares,
    people: state.people,
    unpricedElements: state.unpricedElements,
    commitments: state.commitments,
    entries: state.entries,
    allowances: state.allowances,
    mileageRates: state.mileageRates,
    receivedByResourceId: state.receivedByResourceId,
    receivedByRevenueId: state.receivedByRevenueId,
    reimbursedByPersonId: state.reimbursedByPersonId,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (outcome == null) {
    return;
  }

  ocptBudgetApplyNewOutcome(targets, state, outcome);
}

/// Turn a fresh [OcptBudgetNewOutcome] into a write — every door that **creates** something
/// through the wizard converges here, one variant per [OcptBudgetGesture], each dispatching the
/// event that already exists for it. Nothing here writes to the project itself.
///
/// [OcptBudgetEntryWizardResult]'s own [OcptBudgetEntryWizardResult.acceptedSuggestion] null: an
/// ordinary [OcptBudgetEntryCreationConfirmedEvent]. Non-null:
/// [_handleEntryWizardSuggestionAccepted] turns its own draft and the accepted suggestion into
/// whichever of the two events its own kind calls for — see that method's own doc comment for the
/// mapping, carried over from the capture band the wizard replaced.
void ocptBudgetApplyNewOutcome(
  OcptBudgetNewOutcomeTargets targets,
  OcptBudgetState state,
  OcptBudgetNewOutcome outcome,
) {
  final expensesBloc = targets.expensesBloc;
  final journalBloc = targets.journalBloc;
  final financingBloc = targets.financingBloc;
  final sharingBloc = targets.sharingBloc;

  switch (outcome) {
    case OcptBudgetEntryWizardResult(:final fields, :final acceptedSuggestion):
      if (acceptedSuggestion == null) {
        journalBloc.add(OcptBudgetEntryCreationConfirmedEvent(fields: fields));
      } else {
        _handleEntryWizardSuggestionAccepted(journalBloc, state, acceptedSuggestion, fields);
      }
    case OcptBudgetNewLineOutcome(:final accountId, :final fields):
      expensesBloc.add(OcptBudgetLineCreatedEvent(accountId: accountId, fields: fields));
    case OcptBudgetNewLinesFromBreakdownOutcome(:final lines):
      for (final line in lines) {
        expensesBloc.add(
          OcptBudgetLineCreatedFromElementEvent(
            accountId: line.accountId,
            elementId: line.elementId,
            quantityMilli: line.quantityMilli,
          ),
        );
      }
    case OcptBudgetNewCommitmentOutcome(:final fields, :final lineId):
      journalBloc.add(OcptBudgetCommitmentCreationConfirmedEvent(fields: fields, lineId: lineId));
    case OcptBudgetNewResourceOutcome(:final fields):
      financingBloc.add(OcptBudgetResourceCreationConfirmedEvent(fields: fields));
    case OcptBudgetNewRevenueOutcome(:final fields):
      sharingBloc.add(OcptBudgetRevenueCreationConfirmedEvent(fields: fields));
    case OcptBudgetNewAllowanceOutcome(:final fields):
      financingBloc.add(OcptBudgetAllowanceCreationConfirmedEvent(fields: fields));
    case OcptBudgetNewShareOutcome(:final fields):
      sharingBloc.add(OcptBudgetShareCreationConfirmedEvent(fields: fields));
  }
}

/// Open the capture wizard's own step 3 directly, on [gesture], pre-filled with [prefill] — steps 1
/// and 2 both already answered — then dispatch whatever [ocptBudgetApplyNewOutcome] says once
/// it closes with something. The one shared shape behind every contextual shortcut that pre-fills
/// an ordinary movement: a resource's or a taking's own `Receive`, a participant's own payout, a
/// contribution's own repayment — every one of them an [OcptBudgetEntryCreationConfirmedEvent]
/// with nothing further to decide, unlike [ocptBudgetSettleCommitment], which dispatches a
/// settlement instead of a plain creation and so builds its own call to
/// `OcptBudgetNewDialog.show` rather than sharing this one.
///
/// **The matching strip is withheld here** (`offersMatching: false`), exactly as
/// [ocptBudgetSettleCommitment] and [ocptBudgetPayLineDirectly] withhold it: the
/// movement already belongs to the resource, taking, person or share [prefill] names, so every
/// candidate the strip could rank is a *different* object, and offering to reroute onto one only
/// invites a rapprochement the reader never meant. The strip stays on in the generic `+` capture
/// alone, where the movement is free-typed.
Future<void> ocptBudgetOpenEntryShortcut(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetGesture gesture,
  OcptBudgetEntryFormFields prefill,
) async {
  final targets = OcptBudgetNewOutcomeTargets.of(context);
  final outcome = await OcptBudgetNewDialog.show(
    context,
    initialGesture: gesture,
    entryPrefill: prefill,
    offersMatching: false,
    accounts: state.accounts,
    resources: state.resources,
    revenues: state.revenues,
    shares: state.shares,
    people: state.people,
    unpricedElements: state.unpricedElements,
    commitments: state.commitments,
    entries: state.entries,
    allowances: state.allowances,
    mileageRates: state.mileageRates,
    receivedByResourceId: state.receivedByResourceId,
    receivedByRevenueId: state.receivedByRevenueId,
    reimbursedByPersonId: state.reimbursedByPersonId,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (outcome == null) {
    return;
  }

  ocptBudgetApplyNewOutcome(targets, state, outcome);
}

/// Handle `C'est ça`: turns the wizard's own accepted [suggestion] and its plain [fields] into the
/// write
/// its own kind calls for. **This mapping is carried over unchanged from the quick-capture card
/// this wizard replaces**, whose own version of it first argued every line below: read it before
/// touching it.
///
/// **The commitment case is the only one adding fields the draft never carried**
/// ([OcptBudgetCommitment.accountId], its own tax basis and its own VAT rate) — mirrors
/// [ocptBudgetSettleCommitment]'s own prefill. The other three keep every one of [fields]'s
/// own values, only naming the matched row (`resourceId`/`revenueId`) or, for a defrayal,
/// adopting its own [OcptBudgetMatchSuggestion.label] in place of the draft's — the one asymmetry
/// that `OcptBudgetEntryDialog._headlineOf`'s own doc comment argues for: nothing in the schema
/// lets a defrayal be marked settled, so the label is the only trace this movement can leave of
/// it.
void _handleEntryWizardSuggestionAccepted(
  OcptBudgetCashJournalBloc journalBloc,
  OcptBudgetState state,
  OcptBudgetMatchSuggestion suggestion,
  OcptBudgetEntryFormFields fields,
) {
  switch (suggestion.kind) {
    case OcptBudgetMatchCandidateKind.commitment:
      final commitment = state.commitments
          .where((candidate) => candidate.id == suggestion.candidateId)
          .firstOrNull;
      if (commitment == null) {
        return;
      }
      journalBloc.add(
        OcptBudgetCommitmentSettlementConfirmedEvent(
          commitmentId: commitment.id,
          fields: OcptBudgetEntryFormFields(
            date: fields.date,
            label: fields.label,
            accountId: commitment.accountId,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: fields.isDebit,
            amountCents: fields.amountCents,
            isTaxInclusive: commitment.amount.isTaxInclusive,
            vatRateBasisPoints: commitment.amount.vatRateBasisPoints,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
    case OcptBudgetMatchCandidateKind.resource:
      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: fields.date,
            label: fields.label,
            accountId: null,
            resourceId: suggestion.candidateId,
            revenueId: null,
            shareId: null,
            isDebit: fields.isDebit,
            amountCents: fields.amountCents,
            isTaxInclusive: fields.isTaxInclusive,
            vatRateBasisPoints: fields.vatRateBasisPoints,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
    case OcptBudgetMatchCandidateKind.revenue:
      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: fields.date,
            label: fields.label,
            accountId: null,
            resourceId: null,
            revenueId: suggestion.candidateId,
            shareId: null,
            isDebit: fields.isDebit,
            amountCents: fields.amountCents,
            isTaxInclusive: fields.isTaxInclusive,
            vatRateBasisPoints: fields.vatRateBasisPoints,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
    case OcptBudgetMatchCandidateKind.defrayal:
      journalBloc.add(
        OcptBudgetEntryCreationConfirmedEvent(
          fields: OcptBudgetEntryFormFields(
            date: fields.date,
            label: suggestion.label,
            accountId: null,
            resourceId: null,
            revenueId: null,
            shareId: null,
            isDebit: fields.isDebit,
            amountCents: fields.amountCents,
            isTaxInclusive: fields.isTaxInclusive,
            vatRateBasisPoints: fields.vatRateBasisPoints,
            voucherNumber: null,
            pickedReceiptPath: null,
            isReceiptDetached: false,
          ),
        ),
      );
  }
}

/// Open the capture wizard's own step 3 directly, on [OcptBudgetGesture.recordExpense], pre-filled
/// from [commitment] (today's date, its own label, account, amount, tax basis and rate, as a debit)
/// — steps 1 and 2 both already answered, exactly as `OcptBudgetEntryDialog`'s own prefill used to
/// skip them — then dispatch the settlement if the user confirmed it — see
/// `OcptBudgetCommitmentSettlementConfirmedEvent`'s own doc comment for the combined write this
/// produces.
Future<void> ocptBudgetSettleCommitment(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetCommitment commitment,
) async {
  final journalBloc = context.read<OcptBudgetCashJournalBloc>();
  final now = DateTime.now();
  // Offer what is still owed rather than the full commitment, expressed in the commitment's own
  // tax basis and rate so the payment entry carries the very VAT reading the commitment does. The
  // outstanding is read as a tax-inclusive cash figure, so it is scaled back into the
  // commitment's basis by the fraction it is of the commitment's own cash — the whole typed
  // amount when nothing has been paid, proportional once it has. A commitment whose cash cannot
  // be read (unknown rate) keeps its full typed amount; an overpaid one offers nothing.
  final commitmentCashCents = ocptBudgetCommitmentCashCentsOf(
    commitment,
    projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
  );
  final outstandingCashCents = ocptBudgetCommitmentOutstandingCentsOf(
    commitment,
    state.entries,
    projectVatRateBasisPoints: state.defaultVatRateBasisPoints,
  );
  final int prefillAmountCents;
  if (commitmentCashCents == null || outstandingCashCents == null || commitmentCashCents <= 0) {
    prefillAmountCents = commitment.amount.amountCents;
  } else if (outstandingCashCents <= 0) {
    prefillAmountCents = 0;
  } else {
    prefillAmountCents =
        (commitment.amount.amountCents * outstandingCashCents / commitmentCashCents).round();
  }
  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: commitment.label,
    accountId: commitment.accountId,
    resourceId: null,
    revenueId: null,
    shareId: null,
    isDebit: true,
    amountCents: prefillAmountCents,
    isTaxInclusive: commitment.amount.isTaxInclusive,
    vatRateBasisPoints: commitment.amount.vatRateBasisPoints,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  final outcome = await OcptBudgetNewDialog.show(
    context,
    initialGesture: OcptBudgetGesture.recordExpense,
    entryPrefill: prefill,
    // The commitment being paid is explicitly designated, and the entry settles it below whatever
    // the reader does — so every matching candidate the strip could rank is a *different* object,
    // and offering to reroute the payment onto one only invites a rapprochement they never meant.
    // The strip stays on in the generic `+` capture, where the movement is free-typed.
    offersMatching: false,
    accounts: state.accounts,
    resources: state.resources,
    revenues: state.revenues,
    shares: state.shares,
    people: state.people,
    unpricedElements: state.unpricedElements,
    commitments: state.commitments,
    entries: state.entries,
    allowances: state.allowances,
    mileageRates: state.mileageRates,
    receivedByResourceId: state.receivedByResourceId,
    receivedByRevenueId: state.receivedByRevenueId,
    reimbursedByPersonId: state.reimbursedByPersonId,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (outcome is! OcptBudgetEntryWizardResult) {
    return;
  }

  // With the strip withheld the wizard can accept no suggestion, so settling this very commitment
  // is the only outcome left — no `acceptedSuggestion` branch is reachable here.
  journalBloc.add(
    OcptBudgetCommitmentSettlementConfirmedEvent(
      commitmentId: commitment.id,
      fields: outcome.fields,
    ),
  );
}

/// Open the capture wizard's own step 3 directly, on [OcptBudgetGesture.recordFinancingReceipt],
/// pre-filled from [resource] (today's date, its own label, as a credit, for whatever is still
/// outstanding against it, the resource already named) — mirrors
/// `ocptBudgetSettleCommitment`'s own gesture: see "A commitment settles by naming the
/// entry that paid it" in `docs/architecture/budget.md` for the reading this mirrors, a receipt
/// naming the resource that earned it instead of a commitment being paid.
Future<void> ocptBudgetReceiveResource(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetResource resource,
) async {
  final now = DateTime.now();
  final outstandingCents = ocptBudgetResourceOutstandingCents(
    amountCents: resource.amountCents,
    receivedCents: state.receivedCentsOf(resource.id),
  );
  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: resource.label,
    accountId: null,
    resourceId: resource.id,
    revenueId: null,
    shareId: null,
    isDebit: false,
    amountCents: outstandingCents < 0 ? 0 : outstandingCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  await ocptBudgetOpenEntryShortcut(
    context,
    state,
    OcptBudgetGesture.recordFinancingReceipt,
    prefill,
  );
}

/// Open the capture wizard's own step 3 directly, on [OcptBudgetGesture.reimbursePerson],
/// pre-filled from [personId] (today's date, the person's own display name, as a debit, for
/// whatever is still owed them, the person already named) — mirrors
/// `ocptBudgetReceiveResource`'s own gesture: a reimbursement can never exist as a figure
/// with no movement behind it.
Future<void> ocptBudgetReimbursePerson(
  BuildContext context,
  OcptBudgetState state,
  String personId,
) async {
  final person = state.people.where((row) => row.id == personId).firstOrNull;
  final now = DateTime.now();
  final advancedCents = ocptBudgetPersonAdvancedCents(personId, state.allowances);
  final reimbursedCents = state.reimbursedByPersonId[personId]?.amountCents ?? 0;
  final outstandingCents = ocptBudgetPersonOutstandingCents(
    advancedCents: advancedCents,
    reimbursedCents: reimbursedCents,
  );
  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: person?.displayName ?? "",
    accountId: null,
    resourceId: null,
    revenueId: null,
    shareId: null,
    personId: personId,
    isDebit: true,
    amountCents: outstandingCents < 0 ? 0 : outstandingCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  await ocptBudgetOpenEntryShortcut(context, state, OcptBudgetGesture.reimbursePerson, prefill);
}

/// Open the entry dialog pre-filled to repay [line]'s own contributor (today's date, their own
/// wording, as a debit, for whatever is still owed them, the resource already named), then dispatch
/// the creation if the user confirmed it.
///
/// **The card that says what is owed is the card that offers to pay it.** Every other figure in
/// this mode already had the gesture that produces it within reach of where it is read; this one
/// alone could only be watched. It is the same facilitator `Record a receipt` and `Record a
/// payout` already are, pointing the other way.
///
/// A contributor whose contributions are spread over several resources is repaid against the
/// **first one still owed**: the card groups them into one debt on purpose, and asking which of
/// three 100 € loans a 100 € repayment settles is a question nobody has an answer to.
Future<void> ocptBudgetRepayLine(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetRepaymentLine line,
) async {
  final now = DateTime.now();

  final resource = state.resources
      .where(
        (resource) =>
            resource.isReimbursable &&
            (line.personId == null
                ? resource.personId == null && resource.label == line.label
                : resource.personId == line.personId),
      )
      .firstOrNull;
  if (resource == null) {
    return;
  }

  final person = line.personId == null
      ? null
      : state.people.where((person) => person.id == line.personId).firstOrNull;
  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: person?.displayName ?? line.label,
    accountId: null,
    resourceId: resource.id,
    revenueId: null,
    shareId: null,
    isDebit: true,
    amountCents: line.outstandingCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  await ocptBudgetOpenEntryShortcut(context, state, OcptBudgetGesture.repayContribution, prefill);
}

/// Open the capture wizard's own step 3 directly, on [OcptBudgetGesture.recordTakingReceipt],
/// pre-filled from [revenue] (today's date, its own label, as a credit, for whatever is still
/// outstanding against it, the taking already named) — mirrors
/// `ocptBudgetReceiveResource`'s own gesture: a receipt can never exist as a figure with no
/// movement behind it.
Future<void> ocptBudgetReceiveRevenue(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetRevenue revenue,
) async {
  final now = DateTime.now();
  final outstandingCents = ocptBudgetResourceOutstandingCents(
    amountCents: revenue.amountCents,
    receivedCents: state.receivedRevenueCentsOf(revenue.id),
  );
  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: revenue.label,
    accountId: null,
    resourceId: null,
    revenueId: revenue.id,
    shareId: null,
    isDebit: false,
    amountCents: outstandingCents < 0 ? 0 : outstandingCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  await ocptBudgetOpenEntryShortcut(context, state, OcptBudgetGesture.recordTakingReceipt, prefill);
}

/// Open the capture wizard's own step 3 directly, on [OcptBudgetGesture.payParticipantShare],
/// pre-filled from [share] (today's date, its own label, as a debit, for whatever the participant
/// is still owed — its own due less what it has already been paid, the share already named) —
/// mirrors `ocptBudgetReceiveRevenue`'s own gesture: a payout can never exist as a figure
/// with no movement behind it.
Future<void> ocptBudgetPayShare(
  BuildContext context,
  OcptBudgetState state,
  OcptBudgetShare share,
) async {
  final now = DateTime.now();
  final split = state.shareSplits.firstWhere(
    (split) => split.share.id == share.id,
    orElse: () => OcptBudgetShareSplit(
      share: share,
      dueCents: 0,
      paid: const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
      reinvestedCents: 0,
    ),
  );
  final outstandingCents = ocptBudgetResourceOutstandingCents(
    amountCents: split.dueCents,
    receivedCents: split.paid.amountCents,
  );
  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: share.label,
    accountId: null,
    resourceId: null,
    revenueId: null,
    shareId: share.id,
    isDebit: true,
    amountCents: outstandingCents < 0 ? 0 : outstandingCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  await ocptBudgetOpenEntryShortcut(context, state, OcptBudgetGesture.payParticipantShare, prefill);
}

/// Promote quote line [lineId] into a commitment: opens the capture wizard's own step 3
/// directly, on [OcptBudgetGesture.commitSpend], seeded from the line — steps 1 and 2 both
/// already answered — and dispatches the creation naming the line it came from.
///
/// **A promotion, not a move.** The line stays in the quote, because comparing the estimate with
/// what is actually owed is the whole use of having both — and nothing is counted twice either,
/// the account's `Quote` column reading its lines and its `Committed` column reading commitments.
///
/// Everything a quote line holds is carried across; what is left to say is the two things a line
/// has no room for, and which are exactly what make a debt a debt: who is owed, and when.
Future<void> ocptBudgetCommitLine(
  BuildContext context,
  OcptBudgetState state,
  String lineId,
) async {
  final targets = OcptBudgetNewOutcomeTargets.of(context);
  final account = state.accounts
      .where((account) => account.lines.any((line) => line.id == lineId))
      .firstOrNull;
  final line = account?.lines.where((line) => line.id == lineId).firstOrNull;
  if (account == null || line == null) {
    return;
  }

  final outcome = await OcptBudgetNewDialog.show(
    context,
    commitmentPrefill: OcptBudgetCommitmentFormFields(
      dueDate: null,
      label: line.label,
      accountId: account.id,
      amountCents: ocptBudgetLineTotalCents(line),
      isTaxInclusive: line.unitPrice.isTaxInclusive,
      vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      status: OcptBudgetCommitmentStatus.quoteAccepted,
    ),
    commitmentPrefillLineId: lineId,
    accounts: state.accounts,
    resources: state.resources,
    revenues: state.revenues,
    shares: state.shares,
    people: state.people,
    unpricedElements: state.unpricedElements,
    commitments: state.commitments,
    entries: state.entries,
    allowances: state.allowances,
    mileageRates: state.mileageRates,
    receivedByResourceId: state.receivedByResourceId,
    receivedByRevenueId: state.receivedByRevenueId,
    reimbursedByPersonId: state.reimbursedByPersonId,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (outcome == null) {
    return;
  }

  ocptBudgetApplyNewOutcome(targets, state, outcome);
}

/// Open the capture wizard to pay quote line [lineId] directly — its own `Pay` action, pre-filled
/// from the line (its full quoted total, in the line's own tax basis and rate, as today's debit) —
/// and, on confirm, dispatch [OcptBudgetLinePaidDirectlyEvent], which creates
/// the commitment behind the payment so the reader only ever quoted and paid. The matching strip
/// is withheld here, exactly as [ocptBudgetSettleCommitment] withholds it: the payment
/// belongs to this very line, so rerouting it onto a different object is a rapprochement the
/// reader never meant.
Future<void> ocptBudgetPayLineDirectly(
  BuildContext context,
  OcptBudgetState state,
  String lineId,
) async {
  final expensesBloc = context.read<OcptBudgetExpensesBloc>();
  final now = DateTime.now();

  final account = state.accounts
      .where((account) => account.lines.any((line) => line.id == lineId))
      .firstOrNull;
  final line = account?.lines.where((line) => line.id == lineId).firstOrNull;
  if (account == null || line == null) {
    return;
  }

  final prefill = OcptBudgetEntryFormFields(
    date: DateTime(now.year, now.month, now.day),
    label: line.label,
    accountId: account.id,
    resourceId: null,
    revenueId: null,
    shareId: null,
    isDebit: true,
    amountCents: ocptBudgetLineTotalCents(line),
    isTaxInclusive: line.unitPrice.isTaxInclusive,
    vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
    voucherNumber: null,
    pickedReceiptPath: null,
    isReceiptDetached: false,
  );

  final outcome = await OcptBudgetNewDialog.show(
    context,
    initialGesture: OcptBudgetGesture.recordExpense,
    entryPrefill: prefill,
    // The line has not been promoted, so every matching candidate would be a different object —
    // rerouting the payment onto one is exactly the confusion this direct pay avoids. The strip
    // stays on in the generic `+` capture, where the movement is free-typed.
    offersMatching: false,
    accounts: state.accounts,
    resources: state.resources,
    revenues: state.revenues,
    shares: state.shares,
    people: state.people,
    unpricedElements: state.unpricedElements,
    commitments: state.commitments,
    entries: state.entries,
    allowances: state.allowances,
    mileageRates: state.mileageRates,
    receivedByResourceId: state.receivedByResourceId,
    receivedByRevenueId: state.receivedByRevenueId,
    reimbursedByPersonId: state.reimbursedByPersonId,
    currencyCode: state.currencyCode,
    defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
    isSimplified: state.isSimplified,
  );
  if (outcome is! OcptBudgetEntryWizardResult) {
    return;
  }

  // With the strip withheld the wizard can accept no suggestion, so the direct pay is the only
  // outcome left — no `acceptedSuggestion` branch is reachable here.
  expensesBloc.add(OcptBudgetLinePaidDirectlyEvent(lineId: lineId, fields: outcome.fields));
}

/// Open the entry dialog pre-filled from the commitment quote line [lineId] was promoted into
/// (today's date, its own label, account, amount, tax basis and rate, as a debit), then dispatch
/// the settlement if the user confirmed it — the quote line's own detail panel reaches the very
/// same gesture a commitment's own `Pay` action does, once it is promoted and unsettled.
Future<void> ocptBudgetSettleLine(
  BuildContext context,
  OcptBudgetState state,
  String lineId,
) async {
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

  await ocptBudgetSettleCommitment(context, state, commitment);
}
