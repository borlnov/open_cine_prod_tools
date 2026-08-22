// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';

/// [commitment]'s own [OcptBudgetCommitment.amount], read **tax-inclusive**, given the project's own
/// [projectVatRateBasisPoints] — or null when that reading is impossible.
///
/// A commitment is money that has not yet moved, but it stands for the very cash a payment would
/// take out of the account the day it falls due, so it is read exactly as `ocpt_budget_journal.dart`
/// reads a movement — always tax-inclusive, with no basis to pick (`docs/architecture/budget.md`)
/// — through [ocptIncludingTaxAmountCentsOf] over [commitment]'s own
/// [OcptBudgetCommitment.amount]: its own figure whenever that is already typed tax-inclusive, and
/// null only when it is typed excluding tax and no rate, neither the commitment's own override nor
/// the project's default, is there to gross it back up with.
int? ocptBudgetCommitmentCashCentsOf(
  OcptBudgetCommitment commitment, {
  required int? projectVatRateBasisPoints,
}) => ocptIncludingTaxAmountCentsOf(
  commitment.amount,
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

/// What is committed against each poste, given the project's own [projectVatRateBasisPoints]: per
/// poste, the tax-inclusive sum of every **unsettled** commitment naming it.
///
/// **A settled commitment is excluded outright — from the map and from its coverage counts alike.**
/// [OcptBudgetCommitment.isSettled] means the `budget_entries` row named by
/// [OcptBudgetCommitment.settledEntryId] already paid it: the money it stood for has left the
/// account and is already counted as *paid* by `ocptBudgetPaidCentsByPosteId`
/// (`lib/utils/ocpt_budget_journal.dart`), so counting it here too, as still committed, would show
/// the very same money twice — once owed, once actually spent. Excluding it "outright" rather than
/// merely leaving its amount out means a poste whose only commitment has since settled has **no
/// key** in the map at all, exactly as `ocptBudgetPaidCentsByPosteId` reads a poste with no entry: a
/// settled commitment is, from this map's point of view, as if it had never been made.
Map<String, OcptBudgetCoveredTotal> ocptBudgetCommittedCentsByPosteId(
  List<OcptBudgetCommitment> commitments, {
  required int? projectVatRateBasisPoints,
}) {
  final commitmentsByPosteId = <String, List<OcptBudgetCommitment>>{};
  for (final commitment in commitments) {
    if (commitment.isSettled) {
      continue;
    }

    commitmentsByPosteId.putIfAbsent(commitment.posteId, () => []).add(commitment);
  }

  return {
    for (final posteCommitments in commitmentsByPosteId.entries)
      posteCommitments.key: _ocptBudgetCommittedTotalOf(
        posteCommitments.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// [commitments]' own committed total — the tax-inclusive sum, row by row, then summed — paired
/// with how many of them actually carried a known rate. [commitments] is assumed already filtered to
/// the unsettled ones; the poste-scoped loop [ocptBudgetCommittedCentsByPosteId] runs once per
/// poste, kept separate so that function stays a plain grouping followed by one reading per group.
OcptBudgetCoveredTotal _ocptBudgetCommittedTotalOf(
  List<OcptBudgetCommitment> commitments, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredCommitmentCount = 0;

  for (final commitment in commitments) {
    final cash = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (cash == null) {
      continue;
    }

    amountCents += cash;
    coveredCommitmentCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredCommitmentCount,
    lineCount: commitments.length,
  );
}

/// One instalment of a cash projection: a commitment's own cash figure falling due on its own date,
/// and the balance left once it has.
class OcptBudgetProjectionStep extends Equatable {
  /// The commitment this instalment stands for.
  final String commitmentId;

  /// The date this instalment falls due, or null — see `OcptBudgetCommitment.dueDate`'s own doc
  /// comment: null means "nobody has recorded a due date", never "due immediately", and this step
  /// still lowers the projected balance even though no date names when.
  final DateTime? dueDate;

  /// This instalment's own cash figure, read tax-inclusive.
  final int amountCents;

  /// The balance once this instalment has fallen due — [amountCents] taken out of the balance the
  /// projection stood at just before this step.
  final int balanceAfterCents;

  /// Class constructor
  const OcptBudgetProjectionStep({
    required this.commitmentId,
    required this.dueDate,
    required this.amountCents,
    required this.balanceAfterCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetProjectionStep(commitmentId: $commitmentId, dueDate: $dueDate, "
      "amountCents: $amountCents, balanceAfterCents: $balanceAfterCents)";

  /// Object properties
  @override
  List<Object?> get props => [commitmentId, dueDate, amountCents, balanceAfterCents];
}

/// The cash falling instalment by instalment, from [openingBalanceCents] through every unsettled
/// commitment in [steps]' own order, paired with how many of [commitmentCount] unsettled commitments
/// actually produced a step.
class OcptBudgetProjection extends Equatable {
  /// The balance the projection starts from — the journal's own `OcptBudgetCashTotals.balanceCents`
  /// (`lib/utils/ocpt_budget_journal.dart`), read once and handed in rather than recomputed here:
  /// this file has no journal of its own to read.
  final int openingBalanceCents;

  /// Every instalment the projection could read, in the order [ocptBudgetProjectionOf] was handed
  /// the commitments — see that function's own doc comment for why this never reorders them.
  final List<OcptBudgetProjectionStep> steps;

  /// How many unsettled commitments actually produced a step in [steps].
  final int coveredCommitmentCount;

  /// How many unsettled commitments this projection was asked to read, covered or not — a settled
  /// commitment is excluded outright and never counted here, exactly as
  /// `ocptBudgetCommittedCentsByPosteId` excludes it from its own coverage.
  final int commitmentCount;

  /// The balance once every step has fallen — [steps]' own last [OcptBudgetProjectionStep.balanceAfterCents],
  /// or [openingBalanceCents] itself when there is no step at all.
  int get finalBalanceCents => steps.isEmpty ? openingBalanceCents : steps.last.balanceAfterCents;

  /// The first step whose [OcptBudgetProjectionStep.balanceAfterCents] is negative, or null when the
  /// projection never goes under.
  ///
  /// Reading its own [OcptBudgetProjectionStep.dueDate] as null is a different fact from
  /// [firstNegativeStep] itself being null: the dashboard's own "the date the cash goes negative"
  /// alert has to tell "it goes negative, but on no date anybody has recorded" (a step here, its own
  /// [OcptBudgetProjectionStep.dueDate] null) apart from "it never goes negative at all" (no step
  /// here) — folding the two into one null would silently turn an undated risk into no risk at all.
  OcptBudgetProjectionStep? get firstNegativeStep {
    for (final step in steps) {
      if (step.balanceAfterCents < 0) {
        return step;
      }
    }

    return null;
  }

  /// Whether the projection ever goes under — [firstNegativeStep] answering something rather than
  /// null.
  bool get goesNegative => firstNegativeStep != null;

  /// Class constructor
  const OcptBudgetProjection({
    required this.openingBalanceCents,
    required this.steps,
    required this.coveredCommitmentCount,
    required this.commitmentCount,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetProjection(openingBalanceCents: $openingBalanceCents, steps: ${steps.length}, "
      "coveredCommitmentCount: $coveredCommitmentCount, commitmentCount: $commitmentCount)";

  /// Object properties
  @override
  List<Object?> get props => [openingBalanceCents, steps, coveredCommitmentCount, commitmentCount];
}

/// The cash projection built from [openingBalanceCents] and [commitments], given the project's own
/// [projectVatRateBasisPoints].
///
/// **Never reorders [commitments]**: `OcptBudgetJournalService.loadCommitments` has already put the
/// dated ones first, in due-date order, with the undated ones last, and this function reads them in
/// exactly that order rather than re-sorting by date itself — an undated commitment therefore still
/// takes its cash out at the very end of the projection, since money owed with no date recorded is
/// still owed, and a projection that silently dropped it, or moved it to the front for want of a
/// date to sort by, would understate what is actually at risk.
///
/// **A settled commitment is skipped outright**, exactly as `ocptBudgetCommittedCentsByPosteId`
/// skips it and for the same reason: the money it stood for has already left the account and is
/// already reflected in [openingBalanceCents] itself (the journal's own balance), so taking it out a
/// second time here would double-count it. **An unreadable commitment** — its own
/// [ocptBudgetCommitmentCashCentsOf] answering null — produces **no step** (there is no figure to
/// take out of the balance), but still counts towards
/// [OcptBudgetProjection.commitmentCount], so a caller can still say honestly how much of the
/// projection is complete, exactly as `OcptBudgetCashTotals.isComplete`
/// (`lib/utils/ocpt_budget_journal.dart`) does for the journal itself.
OcptBudgetProjection ocptBudgetProjectionOf({
  required int openingBalanceCents,
  required List<OcptBudgetCommitment> commitments,
  required int? projectVatRateBasisPoints,
}) {
  var balanceCents = openingBalanceCents;
  var coveredCommitmentCount = 0;
  var commitmentCount = 0;
  final steps = <OcptBudgetProjectionStep>[];

  for (final commitment in commitments) {
    if (commitment.isSettled) {
      continue;
    }

    commitmentCount++;

    final cash = ocptBudgetCommitmentCashCentsOf(
      commitment,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (cash == null) {
      continue;
    }

    coveredCommitmentCount++;
    balanceCents -= cash;
    steps.add(
      OcptBudgetProjectionStep(
        commitmentId: commitment.id,
        dueDate: commitment.dueDate,
        amountCents: cash,
        balanceAfterCents: balanceCents,
      ),
    );
  }

  return OcptBudgetProjection(
    openingBalanceCents: openingBalanceCents,
    steps: steps,
    coveredCommitmentCount: coveredCommitmentCount,
    commitmentCount: commitmentCount,
  );
}
