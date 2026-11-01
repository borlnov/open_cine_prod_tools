// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_repayment_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_share_split.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_sharing_pot.dart';

/// The revenue sharing's own readings: what the takings have actually brought in, what the
/// reimbursable contributions take back out of that before anything is split, and what each
/// participant is then due, has been paid and reinvests.
///
/// A **separate file from `ocpt_budget_financing.dart`**, for the reason
/// `ocpt_budget_journal.dart` is kept apart from `ocpt_budget_projection.dart` and the financing
/// plan apart from the totals: money raised *to make* the film and money the finished film *earns*
/// are different subjects, read by different views, long apart in time.
///
/// Every reading here goes through [ocptBudgetEntryCreditCentsOf]/[ocptBudgetEntryDebitCentsOf] and
/// answers an [OcptBudgetCoveredTotal] wherever a rate could be missing — the "null, never zero"
/// discipline `lib/models/rules/ocpt_budget_vat.dart` sets for the whole mode. A share of a pot the
/// app cannot read in full is not a share it may guess at.

/// What has actually come in against each taking, given the project's own
/// [projectVatRateBasisPoints]: per revenue, the tax-inclusive sum of every `budget_entries`
/// **credit** naming it through `budget_entries.revenueId`.
///
/// The exact mirror of `ocptBudgetReceivedByResourceId`
/// (`lib/models/rules/ocpt_budget_financing.dart`), and for the same reason: `budget_revenues`
/// stores no received amount of its own, so a taking's own row states what was *expected* and the
/// journal states what arrived. A prize announced in February and paid in June is one row and one
/// entry, and the view can tell the two apart.
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

/// Get what has actually been paid out to each participant, given the project's own
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

/// Get [entries]' own credit total — row by row, then summed — paired with how many of them carried
/// a
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

/// Get [entries]' own debit total — [_ocptBudgetCreditTotalOf]'s mirror, reading the other column.
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

/// Get every taking's own received total, summed: what the film has actually earned so far.
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

/// Get the plain sum of every **reimbursable** resource's own amount: what the financing plan has
/// to
/// give back out of the takings before anything at all is split.
///
/// No [OcptBudgetCoveredTotal] and no tax basis, for the reason `ocptBudgetResourcesTotalCents`
/// (`lib/models/rules/ocpt_budget_financing.dart`) gives: `budget_resources` carries no money
/// triple, a contribution being awarded at one figure.
///
/// **A contribution in kind counts if it is marked reimbursable, and only then.** Nothing here
/// branches on [OcptBudgetResource.groupKind] — the mode's standing rule that the code carries no
/// conditional branch on the state of the data. In practice an in-kind contribution is rarely
/// marked reimbursable, but it is the user who says so, not this function.
int ocptBudgetReimbursableTotalCents(List<OcptBudgetResource> resources) => resources
    .where((resource) => resource.isReimbursable)
    .fold(0, (sum, resource) => sum + resource.amountCents);

/// Get what the production has already paid back against its reimbursable contributions: the
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

  return _ocptBudgetDebitTotalOf(repayments, projectVatRateBasisPoints: projectVatRateBasisPoints);
}

/// Build the pot from its three readings — see [OcptBudgetSharingPot]'s own doc comment.
OcptBudgetSharingPot ocptBudgetSharingPotOf({
  required OcptBudgetCoveredTotal received,
  required int reimbursableCents,
  required OcptBudgetCoveredTotal repaid,
}) =>
    OcptBudgetSharingPot(received: received, reimbursableCents: reimbursableCents, repaid: repaid);

/// Get the split of [pot] across [shares], in the order they are handed in — never reordered, the
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

/// Get [amountCents] times [permille] thousandths, rounded to the nearest cent, in integer
/// arithmetic
/// throughout — the reason `quantityMilli` exists at all, applied to a fraction of a pot. Rounds
/// half away from zero, so a negative amount rounds the way its positive mirror does.
int _ocptBudgetPermilleOf(int amountCents, int permille) {
  final scaled = amountCents * permille;
  final half = scaled.isNegative ? -500 : 500;

  return (scaled + half) ~/ 1000;
}

/// Get the sum of every live share's own [OcptBudgetShare.sharePermille].
///
/// Offered so the view can **state** it rather than police it: `1000` means the plan adds up,
/// anything else means it does not, and `OcptBudgetSharesTable`'s own doc comment argues why the
/// app declines to refuse the second — a plan still being negotiated legitimately does not add up
/// yet.
int ocptBudgetSharesPermilleTotal(List<OcptBudgetShare> shares) =>
    shares.fold(0, (sum, share) => sum + share.sharePermille);

/// Get what [splits] reinvest in the next production, in total — the sharing table's own footer.
///
/// Summed from each line's own already-rounded [OcptBudgetShareSplit.reinvestedCents], row by row,
/// exactly as every other total in this mode is: computing it from the pot and a summed reinvest
/// fraction instead would let it disagree, by a cent, with the column a reader adds up themselves.
int ocptBudgetReinvestedTotalCents(List<OcptBudgetShareSplit> splits) =>
    splits.fold(0, (sum, split) => sum + split.reinvestedCents);

/// Get what [splits] are due in total, in cents — summed row by row for
/// [ocptBudgetReinvestedTotalCents]' own reason.
///
/// This is deliberately **not** the same figure as [OcptBudgetSharingPot.shareableCents]: it is
/// what the shares as written actually claim, which falls short of the pot while they sum under
/// `1000` and exceeds it while they sum over. The view prints both, side by side, which is the only
/// way a reader can see that the plan does not add up.
int ocptBudgetDueTotalCents(List<OcptBudgetShareSplit> splits) =>
    splits.fold(0, (sum, split) => sum + split.dueCents);

/// Group [resources] by contributor, for the sharing view's own `What each person put in` card:
/// the product owner could not tell, from the plan's own three aggregate figures, that one person
/// having lent money three times over meant one debt rather than three (*"si Marie me donne de
/// l'argent... comment je fais pour voir qu'elle m'a prêté 3 fois 100 €, et que donc je dois la
/// rembourser de 300 € en priorité ?"*).
///
/// **Grouping key: [OcptBudgetResource.personId] when it is set, the resource's own
/// [OcptBudgetResource.label] otherwise.** A resource naming nobody still earns its own line rather
/// than being lumped into a single catch-all — a production owes that resource exactly as much as
/// it owes a named lender, and hiding it inside an "unnamed" bucket would make it invisible to
/// exactly the reading this function exists to give. Two resources naming nobody but sharing the
/// very same label group together, since the label is the only thing there is to tell one lender
/// from another when neither names a person.
///
/// **Every resource is read, reimbursable or not**, and the two figures are kept apart:
/// [OcptBudgetRepaymentLine.contributedCents] is what the person put in,
/// [OcptBudgetRepaymentLine.reimbursableCents] is how much of it has to come back. This function
/// used to skip everything not marked reimbursable, which meant a production that had marked
/// nothing — the ordinary state of a project the day it is created — read an empty card and could
/// not tell that anybody had contributed at all. Nothing here branches on
/// [OcptBudgetResource.groupKind] either: money and a valuation are both what somebody put in, and
/// an in-kind contribution is reimbursable if it is marked so, exactly as
/// [ocptBudgetReimbursableTotalCents] says.
///
/// Each line's own [OcptBudgetRepaymentLine.repaid] reads [entries] the very same way
/// [ocptBudgetRepaidContributionsTotalOf] does — every debit naming one of the line's own resources
/// through `budget_entries.resourceId` — so a repayment recorded against any one of several
/// resources grouped under the same lender lands on that lender's own line, never on a sibling's.
///
/// Ordered by [resources]' own order, each lender's line appearing the moment its **first**
/// resource is met: the plan's own `sortKey` order, since nothing here re-sorts by amount or by
/// name.
List<OcptBudgetRepaymentLine> ocptBudgetRepaymentLinesOf(
  List<OcptBudgetResource> resources,
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final orderedKeys = <String>[];
  final resourcesByKey = <String, List<OcptBudgetResource>>{};
  final personIdByKey = <String, String?>{};

  for (final resource in resources) {
    final personId = resource.personId;
    final key = personId ?? '#${resource.label}';
    if (!resourcesByKey.containsKey(key)) {
      orderedKeys.add(key);
      resourcesByKey[key] = [];
      personIdByKey[key] = personId;
    }
    resourcesByKey[key]!.add(resource);
  }

  return [
    for (final key in orderedKeys)
      () {
        final groupResources = resourcesByKey[key]!;
        final resourceIds = {for (final resource in groupResources) resource.id};
        final contributedCents = groupResources.fold(
          0,
          (sum, resource) => sum + resource.amountCents,
        );
        final reimbursableCents = groupResources.fold(
          0,
          (sum, resource) => sum + (resource.isReimbursable ? resource.amountCents : 0),
        );
        final repayments = [
          for (final entry in entries)
            if (entry.resourceId != null && resourceIds.contains(entry.resourceId)) entry,
        ];

        return OcptBudgetRepaymentLine(
          personId: personIdByKey[key],
          label: groupResources.first.label,
          contributedCents: contributedCents,
          reimbursableCents: reimbursableCents,
          repaid: _ocptBudgetDebitTotalOf(
            repayments,
            projectVatRateBasisPoints: projectVatRateBasisPoints,
          ),
        );
      }(),
  ];
}
