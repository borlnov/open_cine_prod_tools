// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
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

/// What has been paid against each commitment, given the project's own
/// [projectVatRateBasisPoints]: per commitment, the tax-inclusive sum of every `budget_entries`
/// debit naming it through `budget_entries.commitmentId`.
///
/// **This is the very reading `budget_commitments.settledEntryId` used to stand in for**, and the
/// reason it is gone: a commitment could only ever name one settling entry, so it could only ever be
/// paid in one instalment. Summing every entry that names it, off the journal, is what lets a
/// deposit and a balance both count — exactly the argument `ocptBudgetReceivedByResourceId`
/// (`lib/utils/ocpt_budget_financing.dart`) already makes for a financing resource's own "received"
/// figure, and this map mirrors it precisely: **only [OcptBudgetEntry.debitCents] is read** — a
/// commitment is paid by money leaving the account, never by a credit naming it — and **a commitment
/// with no entry naming it has no key at all**, the same "nothing has moved" / "something moved,
/// netting to zero" distinction [ocptBudgetPaidCentsByPosteId]
/// (`lib/utils/ocpt_budget_journal.dart`) already keeps for a poste.
Map<String, OcptBudgetCoveredTotal> ocptBudgetPaidByCommitmentId(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final entriesByCommitmentId = <String, List<OcptBudgetEntry>>{};
  for (final entry in entries) {
    final commitmentId = entry.commitmentId;
    if (commitmentId == null) {
      continue;
    }

    entriesByCommitmentId.putIfAbsent(commitmentId, () => []).add(entry);
  }

  return {
    for (final commitmentEntries in entriesByCommitmentId.entries)
      commitmentEntries.key: _ocptBudgetCommitmentPaidTotalOf(
        commitmentEntries.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// [entries]' own paid total against one commitment — the tax-inclusive sum of every debit, row by
/// row, then summed — paired with how many of them actually carried a known rate. The one
/// commitment-scoped loop [ocptBudgetPaidByCommitmentId] runs once per commitment, kept separate so
/// that function stays a plain grouping followed by one reading per group, exactly the shape
/// `_ocptBudgetReceivedTotalOf` (`lib/utils/ocpt_budget_financing.dart`) already keeps for a
/// resource.
OcptBudgetCoveredTotal _ocptBudgetCommitmentPaidTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    if (debit == null) {
      continue;
    }

    amountCents += debit;
    coveredEntryCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredEntryCount,
    lineCount: entries.length,
  );
}

/// [commitment]'s own paid total, read off [entries] — [ocptBudgetPaidByCommitmentId] narrowed to
/// this one commitment, and it does its own narrowing rather than asking every caller to group
/// [entries] itself first: a fiche or a tree row reads one commitment at a time, and only a caller
/// looping over every commitment of a poste or a project (`ocptBudgetCommittedCentsByPosteId`,
/// `ocptBudgetProjectionOf`) actually needs the grouped map.
OcptBudgetCoveredTotal ocptBudgetCommitmentPaidCentsOf(
  OcptBudgetCommitment commitment,
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) => _ocptBudgetCommitmentPaidTotalOf(
  [for (final entry in entries) if (entry.commitmentId == commitment.id) entry],
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

/// [commitment]'s own outstanding amount, read off the already-grouped [paidByCommitmentId] —
/// [ocptBudgetPaidByCommitmentId]'s own map — rather than a raw entries list: the one place this
/// arithmetic is written, so [ocptBudgetCommitmentOutstandingCentsOf], [ocptBudgetCommittedCentsByPosteId]
/// and [ocptBudgetProjectionOf] read the very same figure for "what a commitment still owes" and can
/// never drift apart on it — see [ocptBudgetCommittedCentsByPosteId]'s own doc comment for what
/// drifting apart used to cost.
///
/// Null when [commitment]'s own cash figure cannot be read (the rate it would need is unknown).
/// **Not clamped at zero**, for the reason `ocptBudgetResourceOutstandingCents`
/// (`lib/utils/ocpt_budget_financing.dart`) is not: an instalment can overshoot what was actually
/// committed, and clamping that away would erase exactly the fact a reader most wants from this
/// figure — that this commitment has been overpaid, not merely settled.
int? _ocptBudgetOutstandingCentsOf(
  OcptBudgetCommitment commitment,
  Map<String, OcptBudgetCoveredTotal> paidByCommitmentId, {
  required int? projectVatRateBasisPoints,
}) {
  final cashCents = ocptBudgetCommitmentCashCentsOf(
    commitment,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );
  if (cashCents == null) {
    return null;
  }

  return cashCents - (paidByCommitmentId[commitment.id]?.amountCents ?? 0);
}

/// What [commitment] still owes, read off [entries] — [_ocptBudgetOutstandingCentsOf] over a map
/// holding this one commitment's own paid total ([ocptBudgetCommitmentPaidCentsOf]), so a fiche or a
/// tree row reading a single commitment answers the very same figure the poste-wide and
/// project-wide aggregates below do, never a second calculation that could disagree with them.
int? ocptBudgetCommitmentOutstandingCentsOf(
  OcptBudgetCommitment commitment,
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) => _ocptBudgetOutstandingCentsOf(
  commitment,
  {
    commitment.id: ocptBudgetCommitmentPaidCentsOf(
      commitment,
      entries,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    ),
  },
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

/// Whether [commitment] has been paid in full: its own [ocptBudgetCommitmentOutstandingCentsOf]
/// reading zero or under, read off [entries].
///
/// **The replacement for the old, stored `settledEntryId != null` reading**
/// (`docs/architecture/budget.md`'s "A commitment settles by naming the entry that paid it"):
/// settlement is derived from the ledger now, never stored, exactly the reading a financing
/// resource's own "received" already is. **An outstanding figure this cannot read —
/// [ocptBudgetCommitmentOutstandingCentsOf] answering null — reads as unsettled, never as settled**:
/// the "null, never zero" discipline (`lib/utils/ocpt_budget_vat.dart`) applies here as everywhere
/// else in this mode. An amount nobody can currently compute is not the same fact as an amount known
/// to be zero, and a commitment this app cannot prove paid must not be shown paid.
bool ocptBudgetCommitmentIsSettledOf(
  OcptBudgetCommitment commitment,
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final outstandingCents = ocptBudgetCommitmentOutstandingCentsOf(
    commitment,
    entries,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );

  return outstandingCents != null && outstandingCents <= 0;
}

/// What is committed against each poste, given the project's own [projectVatRateBasisPoints]: per
/// poste, the tax-inclusive sum of every **unsettled** commitment's own **outstanding** amount —
/// [_ocptBudgetOutstandingCentsOf] — settlement itself read off [entries] through
/// [ocptBudgetCommitmentIsSettledOf].
///
/// **A settled commitment is excluded outright — from the map and from its coverage counts alike —
/// and a part-paid one contributes only what it still owes, never its own full amount.** Both read
/// as the same fact at different points on one line: the money already paid against a commitment
/// has left the account and is already counted as *paid* by `ocptBudgetPaidCentsByPosteId`
/// (`lib/utils/ocpt_budget_journal.dart`), so counting any of it here too, as still committed, would
/// show that same money twice — once owed, once actually spent. A settled commitment is simply the
/// case where nothing of it is left to double-count; summing its own outstanding cents, rather than
/// its cash figure, is what makes the exclusion the limit of this rule rather than a rule of its
/// own. Excluding a settled commitment "outright" rather than merely summing a zero means a poste
/// whose only commitment has since settled has **no key** in the map at all, exactly as
/// `ocptBudgetPaidCentsByPosteId` reads a poste with no entry: a settled commitment is, from this
/// map's point of view, as if it had never been made.
Map<String, OcptBudgetCoveredTotal> ocptBudgetCommittedCentsByPosteId(
  List<OcptBudgetCommitment> commitments, {
  required List<OcptBudgetEntry> entries,
  required int? projectVatRateBasisPoints,
}) {
  // Grouped once, rather than [_ocptBudgetOutstandingCentsOf] re-scanning the whole of [entries]
  // for every commitment in [commitments]: this loop runs once per poste's worth of commitments,
  // exactly the shape [ocptBudgetPaidCentsByPosteId] (`lib/utils/ocpt_budget_journal.dart`) already
  // keeps for its own poste-scoped grouping.
  final paidByCommitmentId = ocptBudgetPaidByCommitmentId(
    entries,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );

  final commitmentsByPosteId = <String, List<OcptBudgetCommitment>>{};
  for (final commitment in commitments) {
    final outstandingCents = _ocptBudgetOutstandingCentsOf(
      commitment,
      paidByCommitmentId,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (outstandingCents != null && outstandingCents <= 0) {
      continue;
    }

    commitmentsByPosteId.putIfAbsent(commitment.posteId, () => []).add(commitment);
  }

  return {
    for (final posteCommitments in commitmentsByPosteId.entries)
      posteCommitments.key: _ocptBudgetCommittedTotalOf(
        posteCommitments.value,
        paidByCommitmentId: paidByCommitmentId,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// [commitments]' own committed total — the tax-inclusive sum of every one's own **outstanding**
/// amount ([_ocptBudgetOutstandingCentsOf], read off [paidByCommitmentId]), row by row, then summed
/// — paired with how many of them actually carried a known rate. [commitments] is assumed already
/// filtered to the unsettled ones; the poste-scoped loop [ocptBudgetCommittedCentsByPosteId] runs
/// once per poste, kept separate so that function stays a plain grouping followed by one reading per
/// group.
OcptBudgetCoveredTotal _ocptBudgetCommittedTotalOf(
  List<OcptBudgetCommitment> commitments, {
  required Map<String, OcptBudgetCoveredTotal> paidByCommitmentId,
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredCommitmentCount = 0;

  for (final commitment in commitments) {
    final outstandingCents = _ocptBudgetOutstandingCentsOf(
      commitment,
      paidByCommitmentId,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (outstandingCents == null) {
      continue;
    }

    amountCents += outstandingCents;
    coveredCommitmentCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredCommitmentCount,
    lineCount: commitments.length,
  );
}

/// One instalment of a cash projection: a commitment's own outstanding figure falling due on its
/// own date, and the balance left once it has.
class OcptBudgetProjectionStep extends Equatable {
  /// The commitment this instalment stands for.
  final String commitmentId;

  /// The date this instalment falls due, or null — see `OcptBudgetCommitment.dueDate`'s own doc
  /// comment: null means "nobody has recorded a due date", never "due immediately", and this step
  /// still lowers the projected balance even though no date names when.
  final DateTime? dueDate;

  /// What this instalment's own commitment still owed at the time this projection was built, read
  /// tax-inclusive — [ocptBudgetCommitmentOutstandingCentsOf], never the commitment's own full cash
  /// figure: a commitment already partly paid, and still owed the rest, only takes the rest out of
  /// the balance here, exactly the reading `OcptBudgetProjection.openingBalanceCents` itself already
  /// carries (the paid part has already left the account, and is already reflected there).
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
  /// [firstNegativeStep] itself being null: the header's alerts band's own "the date the cash goes
  /// negative" alert has to tell "it goes negative, but on no date anybody has recorded" (a step
  /// here, its own [OcptBudgetProjectionStep.dueDate] null) apart from "it never goes negative at
  /// all" (no step here) — folding the two into one null would silently turn an undated risk into
  /// no risk at all.
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
/// second time here would double-count it. **A commitment already partly paid, and still owed the
/// rest, only takes the rest out** — [_ocptBudgetOutstandingCentsOf], the very same reading
/// `ocptBudgetCommittedCentsByPosteId` sums, never [ocptBudgetCommitmentCashCentsOf]'s own full
/// figure — for the very same reason: the part already paid is already reflected in
/// [openingBalanceCents]. **An unreadable commitment** — its own outstanding figure answering null —
/// produces **no step** (there is no figure to take out of the balance), but still counts towards
/// [OcptBudgetProjection.commitmentCount], so a caller can still say honestly how much of the
/// projection is complete, exactly as `OcptBudgetCashTotals.isComplete`
/// (`lib/utils/ocpt_budget_journal.dart`) does for the journal itself.
OcptBudgetProjection ocptBudgetProjectionOf({
  required int openingBalanceCents,
  required List<OcptBudgetCommitment> commitments,
  required List<OcptBudgetEntry> entries,
  required int? projectVatRateBasisPoints,
}) {
  final paidByCommitmentId = ocptBudgetPaidByCommitmentId(
    entries,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );

  var balanceCents = openingBalanceCents;
  var coveredCommitmentCount = 0;
  var commitmentCount = 0;
  final steps = <OcptBudgetProjectionStep>[];

  for (final commitment in commitments) {
    final outstandingCents = _ocptBudgetOutstandingCentsOf(
      commitment,
      paidByCommitmentId,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (outstandingCents != null && outstandingCents <= 0) {
      continue;
    }

    commitmentCount++;

    if (outstandingCents == null) {
      continue;
    }

    coveredCommitmentCount++;
    balanceCents -= outstandingCents;
    steps.add(
      OcptBudgetProjectionStep(
        commitmentId: commitment.id,
        dueDate: commitment.dueDate,
        amountCents: outstandingCents,
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
