// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The financing plan's own readings: what each resource is meant to bring in, what has actually
/// come in against it, and how the whole plan stands against the quote.
///
/// A **separate file from `ocpt_budget_totals.dart`**, for exactly the reason M2 kept
/// `ocpt_budget_journal.dart` apart from `ocpt_budget_projection.dart`: money coming *in* (this
/// file) and a quote line (the totals file) are different subjects, read by different views, and
/// folding them together would blur that distinction rather than clarify it.

/// What has actually come in against each financing resource, given the project's own
/// [projectVatRateBasisPoints]: per resource, the tax-inclusive sum of every `budget_entries`
/// credit naming it through `budget_entries.resourceId`.
///
/// **This is the whole point of the milestone's data shape**: `budget_resources` stores no
/// `receivedCents` column of its own, so what has come in is summed here, off the journal, exactly
/// the way `ocptBudgetPaidCentsByPosteId` (`lib/utils/ocpt_budget_journal.dart`) already sums a
/// poste's own payments rather than reading a stored figure that could drift from the entries that
/// actually justify it.
///
/// Each entry naming this resource is read through [ocptBudgetEntryCreditCentsOf] — **never
/// `creditCents` raw** — so an entry missing the rate it would need to be grossed up leaves the
/// resource's own total *covered* rather than silently wrong: it contributes to neither
/// [OcptBudgetCoveredTotal.amountCents] nor [OcptBudgetCoveredTotal.coveredLineCount], and the
/// resource's own [OcptBudgetCoveredTotal.isComplete] reads false for as long as it is missing —
/// the same "null, never zero" discipline the rest of the mode already keeps.
///
/// **A debit naming a resource is deliberately not subtracted.** An entry can name a resource while
/// paying money *back out* — repaying a reimbursable cash contribution before the revenue sharing
/// splits what is left — and that repayment does not un-receive the money: it came in once, and it
/// is still true that it did. What a production has since paid back is the revenue-sharing view's
/// own subject, at a later milestone, not a correction to how much a resource brought in. Only
/// [OcptBudgetEntry.creditCents] is ever read here; [OcptBudgetEntry.debitCents] naming the same
/// resource is read by no line of this function at all.
///
/// **A resource with no entry naming it gets no key at all** in the returned map — the same
/// discipline `ocptBudgetPaidCentsByPosteId`'s own doc comment states: a caller can tell "nothing
/// has come in against this resource" (absent key) apart from "money came and went and it happens
/// to net to zero" (a key present, its own [OcptBudgetCoveredTotal.amountCents] zero). The `?? 0` a
/// caller applies on top is what turns the first fact into the zero it displays.
Map<String, OcptBudgetCoveredTotal> ocptBudgetReceivedByResourceId(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final entriesByResourceId = <String, List<OcptBudgetEntry>>{};
  for (final entry in entries) {
    final resourceId = entry.resourceId;
    if (resourceId == null) {
      continue;
    }

    entriesByResourceId.putIfAbsent(resourceId, () => []).add(entry);
  }

  return {
    for (final resourceEntries in entriesByResourceId.entries)
      resourceEntries.key: _ocptBudgetReceivedTotalOf(
        resourceEntries.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// [entries]' own received total — the tax-inclusive sum of every credit, row by row, then summed
/// — paired with how many of them actually carried a known rate. The one resource-scoped loop
/// [ocptBudgetReceivedByResourceId] runs once per resource, kept separate so that function stays a
/// plain grouping followed by one reading per group.
OcptBudgetCoveredTotal _ocptBudgetReceivedTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final credit = ocptBudgetEntryCreditCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    if (credit == null) {
      continue;
    }

    amountCents += credit;
    coveredEntryCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredEntryCount,
    lineCount: entries.length,
  );
}

/// The id of the most recently recorded live `budget_entries` credit naming [resourceId], read off
/// [entries] in the very same chronological order `OcptBudgetJournalService.loadEntries` already
/// establishes (`date` ascending, `sortKey` breaking a tie) — so the last matching entry in that
/// order is the most recent movement against the resource. Null while no live credit names it,
/// which is exactly when `OcptBudgetFinancing`'s own `Undo the last receipt` gesture is withheld.
///
/// **A debit naming [resourceId] is not a candidate**, mirroring [ocptBudgetReceivedByResourceId]'s
/// own reading: a debit repaying a reimbursable contribution never un-receives it, so undoing it is
/// not what this gesture is for — only [OcptBudgetEntry.creditCents] is ever read here.
String? ocptBudgetLatestReceiptEntryIdOf(List<OcptBudgetEntry> entries, {required String resourceId}) {
  String? latestEntryId;
  for (final entry in entries) {
    if (entry.resourceId == resourceId && entry.creditCents > 0) {
      latestEntryId = entry.id;
    }
  }
  return latestEntryId;
}

/// The plain sum of [resources]' own [OcptBudgetResource.amountCents].
///
/// **No tax basis at all — never a [OcptBudgetCoveredTotal], never a rate to resolve.**
/// `budget_resources` carries no money triple, because a financing resource is money coming *in*,
/// and `docs/architecture/budget.md`'s own "Money that has moved is read tax-inclusive, always"
/// already settles that there is no second basis to read it in: a subsidy or a contribution is
/// awarded at one figure, not a figure that needs converting between an excluding-tax and an
/// including-tax reading the way a quoted line does. Summing it is therefore a plain fold, exactly
/// as flat as [OcptBudgetResource.amountCents] itself already is.
int ocptBudgetResourcesTotalCents(List<OcptBudgetResource> resources) =>
    resources.fold(0, (sum, resource) => sum + resource.amountCents);

/// [resources]' own [OcptBudgetResource.amountCents], grouped by [OcptBudgetResource.groupKind] —
/// the financing view's own subsidy/cash/in-kind split.
///
/// **A group with no resource of its own has no key at all**, the same discipline
/// [ocptBudgetReceivedByResourceId] keeps for a resource with no entry: a caller can tell "this
/// production has no in-kind contribution at all" apart from "it has one, valued at nothing", which
/// folding the two into a zero-valued key would lose.
Map<OcptBudgetResourceGroupKind, int> ocptBudgetResourcesTotalByGroupKind(
  List<OcptBudgetResource> resources,
) {
  final totals = <OcptBudgetResourceGroupKind, int>{};
  for (final resource in resources) {
    totals[resource.groupKind] = (totals[resource.groupKind] ?? 0) + resource.amountCents;
  }

  return totals;
}

/// What is left of a resource meant to bring in [amountCents], having actually received
/// [receivedCents] against it.
///
/// **May be negative, and that is a real fact, never clamped to zero**: a grant notified at one
/// figure can pay out at a higher one, a co-producer can put in more cash than the plan asked for,
/// and a resource that has already over-delivered has nothing left outstanding — it has the
/// opposite. Clamping that to zero would erase exactly the fact a reader most wants from this
/// figure, the same register `lib/utils/ocpt_budget_vat.dart` argues for "null, never zero":
/// [ocptBudgetVarianceCents] (`lib/utils/ocpt_budget_totals.dart`) already reads the same way for a
/// poste that has gone over its quote, positive rather than floored.
int ocptBudgetResourceOutstandingCents({required int amountCents, required int receivedCents}) =>
    amountCents - receivedCents;

/// The needs/resources balance the financing-plan and financial-report PDFs print: the quote's own
/// [needs] against the financing plan's own [resourcesCents].
///
/// [needs] is carried as a whole [OcptBudgetCoveredTotal] rather than a plain `int` **on purpose**,
/// so the bar can expose whether the needs side is complete — `docs/architecture/budget.md`'s own
/// `tr.budgetCostTrackingCoverageReadOut` reading, "for as long as any line lacks a rate" — through
/// [OcptBudgetCoveredTotal.isComplete], rather than this class inventing a second way to say the
/// same thing.
class OcptBudgetNeedsResourcesBalance extends Equatable {
  /// The quote's own total, and how much of it is actually known — see the class doc comment for
  /// why this is a whole [OcptBudgetCoveredTotal] rather than a plain amount.
  final OcptBudgetCoveredTotal needs;

  /// The financing plan's own total, in cents — [ocptBudgetResourcesTotalCents]'s own figure,
  /// carrying no coverage of its own since it needs no rate to be complete (see that function's own
  /// doc comment).
  final int resourcesCents;

  /// [resourcesCents] minus [needs]' own [OcptBudgetCoveredTotal.amountCents] — positive once the
  /// plan raises more than the quote asks for, negative while it still falls short.
  final int differenceCents;

  /// Whether the financing plan covers the quote — [differenceCents] at or above zero. A real
  /// financing plan rarely lands on exactly zero, and over-financing is still a plan that holds: it
  /// is a shortfall alone that this reads as unbalanced.
  bool get isBalanced => differenceCents >= 0;

  /// Class constructor
  const OcptBudgetNeedsResourcesBalance({
    required this.needs,
    required this.resourcesCents,
    required this.differenceCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetNeedsResourcesBalance(needs: $needs, resourcesCents: $resourcesCents, "
      "differenceCents: $differenceCents)";

  /// Object properties
  @override
  List<Object?> get props => [needs, resourcesCents, differenceCents];
}

/// Builds the balance between [needs] and [resourcesCents] — see [OcptBudgetNeedsResourcesBalance]'s
/// own doc comment.
OcptBudgetNeedsResourcesBalance ocptBudgetNeedsResourcesBalanceOf({
  required OcptBudgetCoveredTotal needs,
  required int resourcesCents,
}) => OcptBudgetNeedsResourcesBalance(
  needs: needs,
  resourcesCents: resourcesCents,
  differenceCents: resourcesCents - needs.amountCents,
);

/// The resources document's own coverage band: does the financing plan — together with the
/// takings the resources document now also holds — cover the quote, and how much of that cover
/// has really arrived rather than merely been promised.
///
/// **A different question from [OcptBudgetNeedsResourcesBalance], which stays exactly as it is**:
/// the financing-plan and financial-report PDFs still read that one, comparing the quote against
/// the financing plan's own resources alone, as a single total. This one adds the takings the
/// resources document now holds too, and splits what has really come in from what is only
/// promised — a split
/// [OcptBudgetNeedsResourcesBalance]'s own single [OcptBudgetNeedsResourcesBalance.resourcesCents]
/// cannot state.
class OcptBudgetResourcesCoverage extends Equatable {
  /// The quote's own total, and how much of it is actually known — the same reason
  /// [OcptBudgetNeedsResourcesBalance.needs] is carried whole rather than as a plain amount: the
  /// band can say the needs side is still incomplete through [OcptBudgetCoveredTotal.isComplete]
  /// rather than inventing a second way to say it.
  ///
  /// **Handed in tax-inclusive, and read as such.** Money coming in is always read tax-inclusive
  /// — the tax-basis switch lives on the expenses document alone
  /// (`docs/architecture/budget.md`'s "Money that has moved is read tax-inclusive, always") — so
  /// [ocptBudgetResourcesCoverageOf] never sees a basis and never applies one: [needs] is resolved
  /// by the caller, the same tax-inclusive reading [OcptBudgetNeedsResourcesBalance] already uses.
  final OcptBudgetCoveredTotal needs;

  /// What has really come in, folded row by row out of every resource's and every revenue's own
  /// received total: a credit whose tax-inclusive reading is unknown is *not covered*, exactly as
  /// [ocptBudgetReceivedByResourceId] already reports per resource, so the receipts side keeps its
  /// own coverage too.
  final OcptBudgetCoveredTotal received;

  /// What is promised and has not come in yet — the per-row shortfall of every resource and every
  /// revenue, summed. See [ocptBudgetResourcesCoverageOf]'s own doc comment for why an in-kind
  /// contribution needs no branch here.
  final int promisedCents;

  /// [received]'s own amount plus [promisedCents] — the plan as it stands, arrived or not.
  int get plannedCents => received.amountCents + promisedCents;

  /// How far [plannedCents] still falls short of [needs]' own amount, floored at zero.
  final int missingCents;

  /// Whether the plan, arrived or promised, covers the quote — [plannedCents] at or above
  /// [needs]' own amount. Over-financing is still a plan that holds; a shortfall alone reads as
  /// uncovered, the same register [OcptBudgetNeedsResourcesBalance.isBalanced] already reads in.
  bool get isCovered => plannedCents >= needs.amountCents;

  /// Class constructor
  const OcptBudgetResourcesCoverage({
    required this.needs,
    required this.received,
    required this.promisedCents,
    required this.missingCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetResourcesCoverage(needs: $needs, received: $received, "
      "promisedCents: $promisedCents, missingCents: $missingCents)";

  /// Object properties
  @override
  List<Object?> get props => [needs, received, promisedCents, missingCents];
}

/// Builds the resources document's own coverage band — see [OcptBudgetResourcesCoverage]'s own
/// doc comment for the question it answers and how it differs from
/// [OcptBudgetNeedsResourcesBalance].
///
/// [receivedByResourceId] and [receivedByRevenueId] are read directly —
/// [ocptBudgetReceivedByResourceId]'s and `ocptBudgetReceivedByRevenueId`'s
/// (`lib/utils/ocpt_budget_shares.dart`) own maps — never re-derived from the underlying entries
/// here: a row no map carries a key for contributes nothing at all, which is the same
/// "null, never zero" reading the maps themselves already keep.
///
/// **An in-kind contribution needs no branch here, and that is worth a sentence.**
/// A valued contribution counts as promised and never as still to come, and the ordinary formula
/// already says exactly that: no credit names such a
/// resource (`docs/architecture/budget.md`'s "An in-kind contribution is valued, not collected"),
/// so [receivedByResourceId] carries no key for it, and its whole
/// [OcptBudgetResource.amountCents] therefore falls on the promised side through the very same
/// `max(0, amount − received)` every other row goes through. The moment an entry does name that
/// resource, its real figures are read like any other row's — the nuance
/// `docs/architecture/budget.md`'s own "An in-kind contribution is valued, not collected" already
/// argues, kept here rather than re-decided.
OcptBudgetResourcesCoverage ocptBudgetResourcesCoverageOf({
  required OcptBudgetCoveredTotal needs,
  required List<OcptBudgetResource> resources,
  required List<OcptBudgetRevenue> revenues,
  required Map<String, OcptBudgetCoveredTotal> receivedByResourceId,
  required Map<String, OcptBudgetCoveredTotal> receivedByRevenueId,
}) {
  final received = ocptBudgetCoveredTotalsFoldOf([
    for (final resource in resources)
      if (receivedByResourceId[resource.id] case final total?) total,
    for (final revenue in revenues)
      if (receivedByRevenueId[revenue.id] case final total?) total,
  ]);

  var promisedCents = 0;
  for (final resource in resources) {
    final receivedCents = receivedByResourceId[resource.id]?.amountCents ?? 0;
    promisedCents += math.max(0, resource.amountCents - receivedCents);
  }
  for (final revenue in revenues) {
    final receivedCents = receivedByRevenueId[revenue.id]?.amountCents ?? 0;
    promisedCents += math.max(0, revenue.amountCents - receivedCents);
  }

  return OcptBudgetResourcesCoverage(
    needs: needs,
    received: received,
    promisedCents: promisedCents,
    missingCents: math.max(0, needs.amountCents - (received.amountCents + promisedCents)),
  );
}
