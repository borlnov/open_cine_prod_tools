// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_entry_nature.dart';

/// The five documents the capture wizard's own step 1 groups its fifteen answers under — the
/// headings, not states of mind: each names the thing being worked on, exactly as the mode's own
/// four chips already do for the working surfaces themselves
/// (`docs/plans/budget-capture-wizard.md`'s own "step 1 — grouped by document, not by intent").
///
/// [ocptBudgetGestureFamilyOf] is the only way a caller ever asks which heading an
/// [OcptBudgetGesture] sits under — nothing else in this file switches over the fifteen answers by
/// hand.
enum OcptBudgetGestureFamily {
  /// `Le devis` — what the film is going to cost, poste by poste.
  quote,

  /// `L'argent qui a bougé` — what has already entered or left the account.
  cashMovement,

  /// `Le plan de financement` — what is promised, and not yet arrived.
  financingPlan,

  /// `Les défraiements` — what the production owes the people who advanced money for it.
  allowances,

  /// `Le partage des recettes` — who touches what of what the film earns.
  revenueSharing,
}

/// What the wizard's own step 2 asks for under a gesture, and the reason a gesture takes two steps
/// or three: a gesture attaching to [none] has nothing to name before its own form, a gesture
/// attaching to anything else names it first.
///
/// [ocptBudgetGestureAttachmentOf] is the only way a caller asks which of these a given
/// [OcptBudgetGesture] draws step 2 for.
enum OcptBudgetGestureAttachment {
  /// Step 2 is skipped outright — the wizard goes straight from step 1 to the form.
  none,

  /// A quote poste, answered — the wizard offers no `Hors devis` here, unlike [optionalPoste]: the
  /// gestures naming this attachment always price a real line of the quote.
  poste,

  /// A quote poste, left unanswered reading `Hors devis` exactly as the poste field of the existing
  /// entry dialog already does — a real fact an entry may carry on purpose, not an unfinished pick.
  optionalPoste,

  /// A quote poste and, optionally, one of its own lines — [OcptBudgetGesture.commitSpend] alone: a
  /// commitment may hang off the poste directly, which the model already allows and the expenses
  /// table already draws.
  posteAndLine,

  /// A financing resource — `budget_resources`.
  financingResource,

  /// A taking the finished film earns — `budget_revenues`.
  taking,

  /// A participant in the revenue-sharing split — `budget_shares`.
  participant,

  /// A person the production owes for having advanced money on its behalf — `people`.
  person,
}

/// The fifteen answers the capture wizard's own step 1 offers, one card each, grouped under the
/// five [OcptBudgetGestureFamily] headings — `docs/plans/budget-capture-wizard.md`'s own table,
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

  /// Adds one quote line, priced by hand, to a poste.
  addQuoteLine,

  /// Adds several quote lines at once, one per unpriced breakdown element the wizard offers against
  /// a poste — the breakdown selector, the one step 2 that creates more than one row.
  addQuoteLinesFromBreakdown,

  /// Promotes a quote line — or a poste directly — into a commitment: a debt now owed, to somebody,
  /// by some date, rather than merely estimated.
  commitSpend,

  // ---------------------------------------------------------------------------------------------
  // `L'argent qui a bougé`
  // ---------------------------------------------------------------------------------------------

  /// `J'ai payé quelque chose` — records a debit already paid, against a quote poste.
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
  /// optional quote poste.
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

/// Which [OcptBudgetGestureFamily] heading [gesture] is offered under — step 1's own grouping,
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

/// What the wizard's own step 2 asks for under [gesture] — every row of this answer is a decision
/// already taken, per the class doc comment's table; none of it is open.
OcptBudgetGestureAttachment ocptBudgetGestureAttachmentOf(OcptBudgetGesture gesture) =>
    switch (gesture) {
      OcptBudgetGesture.addQuoteLine => OcptBudgetGestureAttachment.poste,
      OcptBudgetGesture.addQuoteLinesFromBreakdown => OcptBudgetGestureAttachment.poste,
      OcptBudgetGesture.commitSpend => OcptBudgetGestureAttachment.posteAndLine,
      OcptBudgetGesture.recordExpense => OcptBudgetGestureAttachment.optionalPoste,
      OcptBudgetGesture.recordFinancingReceipt => OcptBudgetGestureAttachment.financingResource,
      OcptBudgetGesture.recordTakingReceipt => OcptBudgetGestureAttachment.taking,
      OcptBudgetGesture.reimbursePerson => OcptBudgetGestureAttachment.person,
      OcptBudgetGesture.payParticipantShare => OcptBudgetGestureAttachment.participant,
      OcptBudgetGesture.repayContribution => OcptBudgetGestureAttachment.financingResource,
      OcptBudgetGesture.recordOtherMovement => OcptBudgetGestureAttachment.optionalPoste,
      OcptBudgetGesture.planSubsidy => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.planContribution => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.planTaking => OcptBudgetGestureAttachment.none,
      // The defrayal form carries its own person picker already, so nothing is asked ahead of it.
      OcptBudgetGesture.defrayPerson => OcptBudgetGestureAttachment.none,
      OcptBudgetGesture.addSharingParticipant => OcptBudgetGestureAttachment.none,
    };

/// How many steps the wizard takes for [gesture]: `2` while [ocptBudgetGestureAttachmentOf] answers
/// [OcptBudgetGestureAttachment.none] — step 1, then straight to the form — `3` otherwise — step 1,
/// step 2 asking the attachment, then the form.
///
/// The wizard's own step counter must always tell the truth (`Étape 1 sur 2` where that is the
/// truth), which is the only reason this function exists rather than every screen assuming three.
int ocptBudgetGestureStepCountOf(OcptBudgetGesture gesture) =>
    ocptBudgetGestureAttachmentOf(gesture) == OcptBudgetGestureAttachment.none ? 2 : 3;

/// The [OcptBudgetEntryNature] [gesture] writes, for the seven
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
