// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The revenue sharing's own readings: what the takings have actually brought in, what the
/// reimbursable contributions take back out of that before anything is split, and what each
/// participant is then due, has been paid and reinvests.
///
/// A **separate file from `ocpt_budget_financing.dart`**, for the reason M2 kept
/// `ocpt_budget_journal.dart` apart from `ocpt_budget_projection.dart` and M3 kept the financing
/// plan apart from the totals: money raised *to make* the film and money the finished film *earns*
/// are different subjects, read by different views, long apart in time.
///
/// Every reading here goes through [ocptBudgetEntryCreditCentsOf]/[ocptBudgetEntryDebitCentsOf] and
/// answers an [OcptBudgetCoveredTotal] wherever a rate could be missing — the "null, never zero"
/// discipline `lib/utils/ocpt_budget_vat.dart` sets for the whole mode. A share of a pot the app
/// cannot read in full is not a share it may guess at.

/// What has actually come in against each taking, given the project's own
/// [projectVatRateBasisPoints]: per revenue, the tax-inclusive sum of every `budget_entries`
/// **credit** naming it through `budget_entries.revenueId`.
///
/// The exact mirror of `ocptBudgetReceivedByResourceId` (`lib/utils/ocpt_budget_financing.dart`),
/// and for the same reason: `budget_revenues` stores no received amount of its own, so a taking's
/// own row states what was *expected* and the journal states what arrived. A prize announced in
/// February and paid in June is one row and one entry, and the view can tell the two apart.
///
/// **A debit naming a revenue is deliberately not subtracted**, exactly as a debit naming a
/// financing resource is not: a taking refunded is a movement in its own right, not a claim that
/// the money never came.
///
/// **A revenue with no entry naming it gets no key at all**, so a caller can tell "nothing has come
/// in yet" (absent key) apart from "money came and went and nets to zero" (a key whose own
/// [OcptBudgetCoveredTotal.amountCents] is zero).
Map<String, OcptBudgetCoveredTotal> ocptBudgetReceivedByRevenueId(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final entriesByRevenueId = <String, List<OcptBudgetEntry>>{};
  for (final entry in entries) {
    final revenueId = entry.revenueId;
    if (revenueId == null) {
      continue;
    }

    entriesByRevenueId.putIfAbsent(revenueId, () => []).add(entry);
  }

  return {
    for (final revenueEntries in entriesByRevenueId.entries)
      revenueEntries.key: _ocptBudgetCreditTotalOf(
        revenueEntries.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// What has actually been paid out to each participant, given the project's own
/// [projectVatRateBasisPoints]: per share, the tax-inclusive sum of every `budget_entries`
/// **debit** naming it through `budget_entries.shareId`.
///
/// The mirror image of [ocptBudgetReceivedByRevenueId], reading the other column of the same
/// journal: a participant is paid by money leaving the account, so it is the debits that count
/// here. `budget_shares` carries no `paidCents`, for the reason `OcptBudgetSharesTable`'s own doc
/// comment gives.
///
/// **A credit naming a share is deliberately not subtracted.** A participant handing money back is
/// a movement of its own — and, far more commonly, a stray credit on the wrong row — and neither is
/// a reason to claim that a payment already made was not made.
///
/// **A share nobody has been paid against gets no key at all**, the same distinction
/// [ocptBudgetReceivedByRevenueId] keeps.
Map<String, OcptBudgetCoveredTotal> ocptBudgetPaidByShareId(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final entriesByShareId = <String, List<OcptBudgetEntry>>{};
  for (final entry in entries) {
    final shareId = entry.shareId;
    if (shareId == null) {
      continue;
    }

    entriesByShareId.putIfAbsent(shareId, () => []).add(entry);
  }

  return {
    for (final shareEntries in entriesByShareId.entries)
      shareEntries.key: _ocptBudgetDebitTotalOf(
        shareEntries.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// [entries]' own credit total — row by row, then summed — paired with how many of them carried a
/// known rate.
OcptBudgetCoveredTotal _ocptBudgetCreditTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final credit = ocptBudgetEntryCreditCentsOf(
      entry,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
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

/// [entries]' own debit total — [_ocptBudgetCreditTotalOf]'s mirror, reading the other column.
OcptBudgetCoveredTotal _ocptBudgetDebitTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final debit = ocptBudgetEntryDebitCentsOf(
      entry,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
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

/// Every taking's own received total, summed: what the film has actually earned so far.
///
/// [receivedByRevenueId] is [ocptBudgetReceivedByRevenueId]'s own map, and [revenues] the live
/// takings it is read against — a revenue absent from the map contributes a zero amount and, since
/// nothing has been claimed for it, **no uncovered line either**: an announced prize nobody has
/// been paid for yet is not a figure the app failed to read, it is a figure that does not exist
/// yet. A key present but incomplete is the other case, and it is carried through: the app *tried*
/// to read an entry and could not, which the total has to say.
OcptBudgetCoveredTotal ocptBudgetRevenuesReceivedTotalOf({
  required List<OcptBudgetRevenue> revenues,
  required Map<String, OcptBudgetCoveredTotal> receivedByRevenueId,
}) {
  var amountCents = 0;
  var coveredLineCount = 0;
  var lineCount = 0;

  for (final revenue in revenues) {
    final received = receivedByRevenueId[revenue.id];
    if (received == null) {
      continue;
    }

    amountCents += received.amountCents;
    coveredLineCount += received.coveredLineCount;
    lineCount += received.lineCount;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: lineCount,
  );
}

/// The plain sum of every **reimbursable** resource's own amount: what the financing plan has to
/// give back out of the takings before anything at all is split.
///
/// No [OcptBudgetCoveredTotal] and no tax basis, for the reason `ocptBudgetResourcesTotalCents`
/// (`lib/utils/ocpt_budget_financing.dart`) gives: `budget_resources` carries no money triple, a
/// contribution being awarded at one figure.
///
/// **A contribution in kind counts if it is marked reimbursable, and only then.** Nothing here
/// branches on [OcptBudgetResource.groupKind] — the mode's standing rule that the code carries no
/// conditional branch on the state of the data. In practice an in-kind contribution is rarely
/// marked reimbursable, but it is the user who says so, not this function.
int ocptBudgetReimbursableTotalCents(List<OcptBudgetResource> resources) => resources
    .where((resource) => resource.isReimbursable)
    .fold(0, (sum, resource) => sum + resource.amountCents);

/// What the production has already paid back against its reimbursable contributions: the
/// tax-inclusive sum of every `budget_entries` **debit** naming one of them through
/// `budget_entries.resourceId`.
///
/// This is the other half of the sentence `ocpt_budget_financing.dart` already writes — "a debit
/// naming a resource is deliberately not subtracted … what a production has paid back is the
/// revenue-sharing view's own subject". It is that subject, and this is where it is read.
///
/// A debit naming a resource that is **not** reimbursable is not counted: money paid out against a
/// subsidy is a correction, an unspent balance handed back, or a mistake, and none of the three is
/// a repayment of a contribution the sharing has to clear first.
OcptBudgetCoveredTotal ocptBudgetRepaidContributionsTotalOf(
  List<OcptBudgetEntry> entries, {
  required List<OcptBudgetResource> resources,
  required int? projectVatRateBasisPoints,
}) {
  final reimbursableIds = {
    for (final resource in resources)
      if (resource.isReimbursable) resource.id,
  };

  final repayments = [
    for (final entry in entries)
      if (entry.resourceId != null && reimbursableIds.contains(entry.resourceId)) entry,
  ];

  return _ocptBudgetDebitTotalOf(
    repayments,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );
}

/// What there is to share, and what stands between the takings and it.
///
/// The order this states things in **is** the rule the view exists to make legible: the takings come
/// in, the reimbursable contributions are taken off the top in full, and only what is left is
/// anybody's to split.
class OcptBudgetSharingPot extends Equatable {
  /// What the takings have actually brought in — [ocptBudgetRevenuesReceivedTotalOf]'s own figure,
  /// carried whole so the view can say how much of it the app could read.
  final OcptBudgetCoveredTotal received;

  /// What the reimbursable contributions come to in total, in cents —
  /// [ocptBudgetReimbursableTotalCents].
  final int reimbursableCents;

  /// What has already been paid back against them —
  /// [ocptBudgetRepaidContributionsTotalOf]'s own figure.
  final OcptBudgetCoveredTotal repaid;

  /// What is still owed to the contributors: [reimbursableCents] less what [repaid] says has gone
  /// back, floored at zero — a production that has paid back more than it owed has finished
  /// repaying, not started being owed.
  int get outstandingRepaymentCents {
    final outstanding = reimbursableCents - repaid.amountCents;
    return outstanding < 0 ? 0 : outstanding;
  }

  /// What is left to share, in cents: the takings less the **whole** of [reimbursableCents], floored
  /// at zero.
  ///
  /// **The whole of it, not merely what is still outstanding.** Whether a contribution has been
  /// physically repaid yet is a question about the production's cash, not about what belongs to the
  /// participants: a film that has earned 4,000 € against 3,500 € of reimbursable contributions has
  /// 500 € to share, and it has 500 € to share whether the 3,500 € went back last week or has not
  /// gone back at all. Reading the outstanding figure here instead would let a production enlarge
  /// the pot simply by delaying a repayment.
  int get shareableCents {
    final shareable = received.amountCents - reimbursableCents;
    return shareable < 0 ? 0 : shareable;
  }

  /// Whether there is anything at all to share yet. False while the takings have not yet cleared the
  /// contributions, which is the ordinary state of a film for a long time — and the state in which
  /// every participant's own due is honestly zero rather than unknown.
  bool get hasSomethingToShare => shareableCents > 0;

  /// Class constructor
  const OcptBudgetSharingPot({
    required this.received,
    required this.reimbursableCents,
    required this.repaid,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetSharingPot(received: $received, reimbursableCents: $reimbursableCents, "
      "repaid: $repaid)";

  /// Object properties
  @override
  List<Object?> get props => [received, reimbursableCents, repaid];
}

/// Builds the pot from its three readings — see [OcptBudgetSharingPot]'s own doc comment.
OcptBudgetSharingPot ocptBudgetSharingPotOf({
  required OcptBudgetCoveredTotal received,
  required int reimbursableCents,
  required OcptBudgetCoveredTotal repaid,
}) => OcptBudgetSharingPot(
  received: received,
  reimbursableCents: reimbursableCents,
  repaid: repaid,
);

/// One participant's line in the split: what they are due out of the pot, what they have actually
/// been paid, and what of their due they reinvest.
///
/// Named `…Split` rather than `…Row` because `OcptBudgetShareRow` is already drift's own data class
/// for `budget_shares`, and a computed reading and a stored row must not wear one name.
class OcptBudgetShareSplit extends Equatable {
  /// The share this line reads.
  final OcptBudgetShare share;

  /// What this participant is due out of the pot, in cents —
  /// `shareableCents × sharePermille ÷ 1000`, rounded to the nearest cent.
  final int dueCents;

  /// What has actually been paid to them — [ocptBudgetPaidByShareId]'s own figure for this share,
  /// or a zero-amount total covering nothing when no entry names them.
  final OcptBudgetCoveredTotal paid;

  /// What of [dueCents] this participant reinvests in the next production, in cents —
  /// `dueCents × reinvestPermille ÷ 1000`, rounded to the nearest cent.
  final int reinvestedCents;

  /// [dueCents] less [reinvestedCents]: what is theirs to actually take.
  int get takeHomeCents => dueCents - reinvestedCents;

  /// Class constructor
  const OcptBudgetShareSplit({
    required this.share,
    required this.dueCents,
    required this.paid,
    required this.reinvestedCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetShareSplit(share: ${share.id}, dueCents: $dueCents, paid: $paid, "
      "reinvestedCents: $reinvestedCents)";

  /// Object properties
  @override
  List<Object?> get props => [share, dueCents, paid, reinvestedCents];
}

/// The split of [pot] across [shares], in the order they are handed in — never reordered, the
/// sharing view's own `sortKey` order being the order the participants agreed to read them in.
///
/// **Each line is computed on its own and no remainder is redistributed.** Three participants
/// splitting a pot of 1,000 cents in thirds are each due 333 cents, and the app says so: the
/// missing cent is a real fact about an indivisible pot, and silently handing it to whoever happens
/// to be listed last would be the app deciding a question the participants have not. The view
/// states the sum of the dues beside the pot, which is where a reader sees the gap and settles it
/// themselves.
///
/// **A share of a pot the app could not read in full is still computed**, from the amount it *did*
/// read: [OcptBudgetSharingPot.received] already says how many entries it covers, and repeating
/// that caveat per participant would say nothing new. It is the pot's own read-out, not this one's.
List<OcptBudgetShareSplit> ocptBudgetShareSplitsOf({
  required List<OcptBudgetShare> shares,
  required OcptBudgetSharingPot pot,
  required Map<String, OcptBudgetCoveredTotal> paidByShareId,
}) {
  final shareableCents = pot.shareableCents;

  return [
    for (final share in shares)
      () {
        final dueCents = _ocptBudgetPermilleOf(shareableCents, share.sharePermille);

        return OcptBudgetShareSplit(
          share: share,
          dueCents: dueCents,
          paid:
              paidByShareId[share.id] ??
              const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
          reinvestedCents: _ocptBudgetPermilleOf(dueCents, share.reinvestPermille),
        );
      }(),
  ];
}

/// [amountCents] times [permille] thousandths, rounded to the nearest cent, in integer arithmetic
/// throughout — the reason `quantityMilli` exists at all, applied to a fraction of a pot. Rounds
/// half away from zero, so a negative amount rounds the way its positive mirror does.
int _ocptBudgetPermilleOf(int amountCents, int permille) {
  final scaled = amountCents * permille;
  final half = scaled.isNegative ? -500 : 500;

  return (scaled + half) ~/ 1000;
}

/// The sum of every live share's own [OcptBudgetShare.sharePermille].
///
/// Offered so the view can **state** it rather than police it: `1000` means the plan adds up,
/// anything else means it does not, and `OcptBudgetSharesTable`'s own doc comment argues why the app
/// declines to refuse the second — a plan still being negotiated legitimately does not add up yet.
int ocptBudgetSharesPermilleTotal(List<OcptBudgetShare> shares) =>
    shares.fold(0, (sum, share) => sum + share.sharePermille);

/// What [splits] reinvest in the next production, in total — the sharing table's own footer.
///
/// Summed from each line's own already-rounded [OcptBudgetShareSplit.reinvestedCents], row by row,
/// exactly as every other total in this mode is: computing it from the pot and a summed reinvest
/// fraction instead would let it disagree, by a cent, with the column a reader adds up themselves.
int ocptBudgetReinvestedTotalCents(List<OcptBudgetShareSplit> splits) =>
    splits.fold(0, (sum, split) => sum + split.reinvestedCents);

/// What [splits] are due in total, in cents — summed row by row for [ocptBudgetReinvestedTotalCents]'
/// own reason.
///
/// This is deliberately **not** the same figure as [OcptBudgetSharingPot.shareableCents]: it is what
/// the shares as written actually claim, which falls short of the pot while they sum under `1000`
/// and exceeds it while they sum over. The view prints both, side by side, which is the only way a
/// reader can see that the plan does not add up.
int ocptBudgetDueTotalCents(List<OcptBudgetShareSplit> splits) =>
    splits.fold(0, (sum, split) => sum + split.dueCents);
