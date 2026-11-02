// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_attachment.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_flow.dart';

/// The fifteen answers the capture wizard's own step 1 offers, one card each, grouped under the
/// five [OcptBudgetGestureFamily] headings — `docs/architecture/budget.md`,
/// carried into a type so the wizard, its step counter and its step-2 attachment all read one
/// source rather than three that could drift apart.
///
/// **This type wraps [OcptBudgetEntryNature] rather than replacing it.** [OcptBudgetEntryNature]
/// stays what it already is — the nature of a *movement*, read and written wherever a
/// `budget_entries` row is — and [ocptBudgetGestureNatureOf] is the one bridge between the two,
/// answering a nature for the seven [OcptBudgetGestureFamily.cashMovement] answers and `null` for
/// the other eight, which plan, quote or create a record rather than move money at all.
///
/// `lib/types/` stays pure here too: no `Tr`, no formatted string, no Flutter import — the wizard
/// resolves every word.
enum OcptBudgetGesture {
  // ---------------------------------------------------------------------------------------------
  // `Le devis`
  // ---------------------------------------------------------------------------------------------

  /// Adds one quote line, priced by hand, to an account.
  addQuoteLine,

  /// Adds several quote lines at once, one per unpriced breakdown element the wizard offers against
  /// an account — the breakdown selector, the one step 2 that creates more than one row.
  addQuoteLinesFromBreakdown,

  /// Promotes a quote line — or an account directly — into a commitment: a debt now owed, to
  /// somebody, by some date, rather than merely estimated.
  commitSpend,

  // ---------------------------------------------------------------------------------------------
  // `L'argent qui a bougé`
  // ---------------------------------------------------------------------------------------------

  /// `J'ai payé quelque chose` — records a debit already paid, against a quote account.
  recordExpense,

  /// `J'ai reçu un financement` — records a credit already received, against a financing resource.
  recordFinancingReceipt,

  /// `Le film a rapporté de l'argent` — records a credit already received, against a taking.
  recordTakingReceipt,

  /// `J'ai remboursé quelqu'un` — records a debit already paid, against a person the production
  /// owes for a défraiement — see [OcptBudgetEntryNature.personReimbursement]'s own doc comment for
  /// why this is not [repayContribution].
  reimbursePerson,

  /// `J'ai versé sa part à quelqu'un` — records a debit already paid, against a revenue-sharing
  /// participant.
  payParticipantShare,

  /// `J'ai remboursé un apport` — records a debit already paid, against a financing resource: the
  /// mirror image of [recordFinancingReceipt], the same row of the financing plan, the money going
  /// the other way.
  repayContribution,

  /// `Autre mouvement` — records a movement whose direction the wizard still has to ask, against an
  /// optional quote account.
  recordOtherMovement,

  // ---------------------------------------------------------------------------------------------
  // `Le plan de financement`
  // ---------------------------------------------------------------------------------------------

  /// Plans a subsidy the production expects but has not yet received.
  planSubsidy,

  /// Plans a cash contribution the production expects but has not yet received.
  planContribution,

  /// Plans a taking the film is expected to earn but has not yet cashed in.
  planTaking,

  // ---------------------------------------------------------------------------------------------
  // `Les défraiements`
  // ---------------------------------------------------------------------------------------------

  /// Types a défraiement owed to a person — the debt [reimbursePerson] later pays down.
  defrayPerson,

  // ---------------------------------------------------------------------------------------------
  // `Le partage des recettes`
  // ---------------------------------------------------------------------------------------------

  /// Adds a participant to the revenue-sharing split.
  addSharingParticipant,
}

/// Tell which [OcptBudgetGestureFamily] heading [gesture] is offered under — step 1's own grouping,
/// per the class doc comment's table.
OcptBudgetGestureFamily ocptBudgetGestureFamilyOf(OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.addQuoteLine => OcptBudgetGestureFamily.quote,
  OcptBudgetGesture.addQuoteLinesFromBreakdown => OcptBudgetGestureFamily.quote,
  OcptBudgetGesture.commitSpend => OcptBudgetGestureFamily.quote,
  OcptBudgetGesture.recordExpense => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.recordFinancingReceipt => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.recordTakingReceipt => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.reimbursePerson => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.payParticipantShare => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.repayContribution => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.recordOtherMovement => OcptBudgetGestureFamily.cashMovement,
  OcptBudgetGesture.planSubsidy => OcptBudgetGestureFamily.financingPlan,
  OcptBudgetGesture.planContribution => OcptBudgetGestureFamily.financingPlan,
  OcptBudgetGesture.planTaking => OcptBudgetGestureFamily.financingPlan,
  OcptBudgetGesture.defrayPerson => OcptBudgetGestureFamily.allowances,
  OcptBudgetGesture.addSharingParticipant => OcptBudgetGestureFamily.revenueSharing,
};

/// Tell which direction money moves under [gesture] — the semantic the `+ New` wizard filters by
/// when it
/// opens from a working view, **transverse to the families**: the `Expenses` view offers everything
/// that makes money go out whatever family it sits in, the `Resources` view everything that brings
/// money in. A gesture may do both ([OcptBudgetGesture.recordOtherMovement], whose direction the
/// wizard still asks) or neither ([OcptBudgetGesture.defrayPerson] and
/// [OcptBudgetGesture.addSharingParticipant], filed by their own view rather than a direction —
/// `budget_mode.dart`'s own `_wizardGesturesForView`, and `budget.md`).
Set<OcptBudgetGestureFlow> ocptBudgetGestureFlowsOf(OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.addQuoteLine => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.addQuoteLinesFromBreakdown => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.commitSpend => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.recordExpense => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.reimbursePerson => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.payParticipantShare => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.repayContribution => const {OcptBudgetGestureFlow.spends},
  OcptBudgetGesture.recordFinancingReceipt => const {OcptBudgetGestureFlow.brings},
  OcptBudgetGesture.recordTakingReceipt => const {OcptBudgetGestureFlow.brings},
  OcptBudgetGesture.planSubsidy => const {OcptBudgetGestureFlow.brings},
  OcptBudgetGesture.planContribution => const {OcptBudgetGestureFlow.brings},
  OcptBudgetGesture.planTaking => const {OcptBudgetGestureFlow.brings},
  OcptBudgetGesture.recordOtherMovement => const {
    OcptBudgetGestureFlow.spends,
    OcptBudgetGestureFlow.brings,
  },
  OcptBudgetGesture.defrayPerson => const {},
  OcptBudgetGesture.addSharingParticipant => const {},
};

/// Get what the wizard's own step 2 asks for under [gesture] — every row of this answer is a
/// decision
/// already taken, per the class doc comment's table; none of it is open.
OcptBudgetGestureAttachment ocptBudgetGestureAttachmentOf(OcptBudgetGesture gesture) =>
    switch (gesture) {
      OcptBudgetGesture.addQuoteLine => OcptBudgetGestureAttachment.account,
      // The breakdown selector picks an account per element on its own step, so nothing is asked
      // ahead of it: a single account answered here would be the very question the per-row picker
      // replaces.
      OcptBudgetGesture.addQuoteLinesFromBreakdown => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.commitSpend => OcptBudgetGestureAttachment.accountAndLine,
      OcptBudgetGesture.recordExpense => OcptBudgetGestureAttachment.optionalAccount,
      OcptBudgetGesture.recordFinancingReceipt => OcptBudgetGestureAttachment.financingResource,
      // A taking just paid is typed once, an amount and a label, and its own row is created from
      // them: the receipt form carries no attachment step, minting the taking behind the credit
      // rather than asking the reader to pick one and then retype its amount — `budget.md`.
      OcptBudgetGesture.recordTakingReceipt => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.reimbursePerson => OcptBudgetGestureAttachment.person,
      OcptBudgetGesture.payParticipantShare => OcptBudgetGestureAttachment.participant,
      OcptBudgetGesture.repayContribution => OcptBudgetGestureAttachment.financingResource,
      OcptBudgetGesture.recordOtherMovement => OcptBudgetGestureAttachment.optionalAccount,
      OcptBudgetGesture.planSubsidy => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.planContribution => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.planTaking => OcptBudgetGestureAttachment.none,
      // The defrayal form carries its own person picker already, so nothing is asked ahead of it.
      OcptBudgetGesture.defrayPerson => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.addSharingParticipant => OcptBudgetGestureAttachment.none,
    };

/// Count how many steps the wizard takes for [gesture]: `2` while [ocptBudgetGestureAttachmentOf]
/// answers
/// [OcptBudgetGestureAttachment.none] — step 1, then straight to the form — `3` otherwise — step 1,
/// step 2 asking the attachment, then the form.
///
/// The wizard's own step counter must always tell the truth (`Étape 1 sur 2` where that is the
/// truth), which is the only reason this function exists rather than every screen assuming three.
int ocptBudgetGestureStepCountOf(OcptBudgetGesture gesture) =>
    ocptBudgetGestureAttachmentOf(gesture) == OcptBudgetGestureAttachment.none ? 2 : 3;

/// Get the [OcptBudgetEntryNature] [gesture] writes, for the seven
/// [OcptBudgetGestureFamily.cashMovement] answers, or `null` for the other eight — a gesture that
/// plans, quotes or creates a record is not a movement, so it has no nature to write.
OcptBudgetEntryNature? ocptBudgetGestureNatureOf(OcptBudgetGesture gesture) => switch (gesture) {
  OcptBudgetGesture.recordExpense => OcptBudgetEntryNature.expense,
  OcptBudgetGesture.recordFinancingReceipt => OcptBudgetEntryNature.financing,
  OcptBudgetGesture.recordTakingReceipt => OcptBudgetEntryNature.revenue,
  OcptBudgetGesture.reimbursePerson => OcptBudgetEntryNature.personReimbursement,
  OcptBudgetGesture.payParticipantShare => OcptBudgetEntryNature.payout,
  OcptBudgetGesture.repayContribution => OcptBudgetEntryNature.repayment,
  OcptBudgetGesture.recordOtherMovement => OcptBudgetEntryNature.other,
  OcptBudgetGesture.addQuoteLine => null,
  OcptBudgetGesture.addQuoteLinesFromBreakdown => null,
  OcptBudgetGesture.commitSpend => null,
  OcptBudgetGesture.planSubsidy => null,
  OcptBudgetGesture.planContribution => null,
  OcptBudgetGesture.planTaking => null,
  OcptBudgetGesture.defrayPerson => null,
  OcptBudgetGesture.addSharingParticipant => null,
};
