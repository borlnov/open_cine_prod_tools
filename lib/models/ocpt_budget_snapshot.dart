// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The whole budget mode's read, in one object: the [postes] with their lines, the cash journal's
/// own [entries] and [commitments], the financing plan's own [resources], the catering-and-travel
/// pass's own [regieDays] and [travelRows], the project's own [defaultVatRateBasisPoints] and
/// [currencyCode], and the counts the status bar and the mode's own reads need.
///
/// Built the same way `OcptResourcesSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. `OcptBudgetQuoteService.loadPostes` is what loads [postes],
/// `OcptBudgetJournalService.loadEntries`/`loadCommitments` are what load [entries] and
/// [commitments], `OcptBudgetFinancingService.loadResources`/`loadMileageRates` are what load
/// [resources] and the rates [travelRows] read, `OcptScheduleService.loadSchedule`,
/// `OcptRoleIndexService.loadRoles` and `OcptPeopleService.loadPeople` are what load the schedule,
/// the roles and the people [regieDays] and [travelRows] are built from; combining those reads with
/// the project's own settings into this one object is the mode's job.
class OcptBudgetSnapshot extends Equatable {
  /// Every poste of the project, in display order, each with its own quote lines.
  final List<OcptBudgetPoste> postes;

  /// Every live journal entry, in the chronological order `OcptBudgetJournalService.loadEntries`
  /// gives them — never reordered here.
  final List<OcptBudgetEntry> entries;

  /// Every live commitment, in the due-date order `OcptBudgetJournalService.loadCommitments` gives
  /// them — never reordered here.
  final List<OcptBudgetCommitment> commitments;

  /// Every live financing resource, in the `sortKey` order `OcptBudgetFinancingService
  /// .loadResources` gives them — never reordered here. Defaults to empty for every caller
  /// unconcerned with the financing plan, exactly as [receiptsByEntryId] already does for a caller
  /// unconcerned with vouchers.
  final List<OcptBudgetResource> resources;

  /// The project's default VAT rate, in basis points, or null meaning "nobody has recorded a
  /// rate" — `OcptProjectInfoTable.defaultVatRateBasisPoints`.
  final int? defaultVatRateBasisPoints;

  /// The project's own meal price, in cents, or null meaning "nobody has recorded one" —
  /// `OcptProjectInfoTable.mealPriceCents`, the same price [regieDays]' own cost is priced from.
  /// Carried here too, raw, for `OcptBudgetRegie`'s own caption naming the two unit prices in
  /// force.
  final int? mealPriceCents;

  /// The project's own snack price, in cents, or null — [mealPriceCents]'s sibling.
  final int? snackPriceCents;

  /// The ISO 4217 code of the currency the project counts its costs in.
  final String currencyCode;

  /// `postes.length`.
  final int posteCount;

  /// The total number of quote lines across every poste.
  final int lineCount;

  /// `entries.length`.
  final int entryCount;

  /// `commitments.length`.
  final int commitmentCount;

  /// `resources.length`.
  final int resourceCount;

  /// What has actually been paid against each poste, keyed by `OcptBudgetPoste.id` — a poste with
  /// no key here has had nothing move against it at all, which is different from a key present
  /// whose own amount is zero (`ocptBudgetPaidCentsByPosteId`'s own doc comment). [paidCentsOf] is
  /// what the mode reads instead of this map directly.
  final Map<String, OcptBudgetCoveredTotal> paidByPosteId;

  /// The total of every debit that names no poste at all — spending that happened but sits outside
  /// the quote — `ocptBudgetOffQuotePaidTotalOf`. Zero and complete while [entries] carries no such
  /// debit. The dashboard's own `Paid` KPI and the cost-tracking table's own total row both fold
  /// this in alongside [paidByPosteId], since together they are what actually left the account;
  /// `ocptComputeBudgetAlerts` never reads it — a poste's own strain against its own quote is a
  /// different question from money that prices no poste at all.
  final OcptBudgetCoveredTotal offQuotePaidTotal;

  /// What is committed against each poste, keyed by `OcptBudgetPoste.id`, settled commitments
  /// excluded outright (`ocptBudgetCommittedCentsByPosteId`'s own doc comment). [committedCentsOf]
  /// is what the mode reads instead of this map directly.
  final Map<String, OcptBudgetCoveredTotal> committedByPosteId;

  /// The cash journal's own debit, credit and balance, over [entries].
  final OcptBudgetCashTotals cashTotals;

  /// What has actually come in against each financing resource, keyed by `OcptBudgetResource.id` —
  /// a resource with no key here has had no entry name it at all, which is different from a key
  /// present whose own amount is zero (`ocptBudgetReceivedByResourceId`'s own doc comment, the same
  /// discipline [paidByPosteId] already keeps). [receivedCentsOf] is what the mode reads instead of
  /// this map directly for the ordinary reading; the financing view reads this map itself too, for
  /// the one reading that needs to tell the two facts apart — see [receivedCentsOf]'s own doc
  /// comment.
  final Map<String, OcptBudgetCoveredTotal> receivedByResourceId;

  /// The dashboard's own two alerts — a poste over its quote, the cash projection going negative —
  /// computed once, here, by [ocptComputeBudgetAlerts] over this snapshot's own already-loaded
  /// data: **both computed, neither configured** (ADR 0027).
  final List<OcptBudgetAlert> alerts;

  /// Every live voucher, keyed by the `OcptBudgetEntry.id` it evidences —
  /// `OcptBudgetJournalService.loadReceipts` verbatim, at most one per entry. An entry with no key
  /// here carries no voucher at all.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// Every live shooting day's own catering reading, in the schedule's own day-number order —
  /// `ocptBudgetRegieDaysOf` (`lib/utils/ocpt_budget_regie.dart`), read over the schedule's own
  /// days and slots, every role's own kind and the project's own meal and snack prices. Empty for
  /// every caller unconcerned with the catering-and-travel pass, exactly as [resources] already
  /// defaults for a caller unconcerned with the financing plan.
  final List<OcptBudgetRegieDay> regieDays;

  /// [regieDays] folded into one total — `ocptBudgetRegieTotalsOf`.
  final OcptBudgetRegieTotals regieTotals;

  /// Every traveller the schedule names, each with their own return-trip count and mileage
  /// reimbursement — `ocptBudgetTravelRowsOf`, read over the same schedule days as [regieDays],
  /// each person's own declared commute and mileage rate, and the project's own rate catalogue.
  final List<OcptBudgetTravelRow> travelRows;

  /// [travelRows] folded into one total — `ocptBudgetTravelTotalsOf`.
  final OcptBudgetTravelTotals travelTotals;

  /// Every live taking of the revenue sharing, in the `sortKey` order `OcptBudgetSharingService
  /// .loadRevenues` gives them — never reordered here. Defaults to empty for every caller
  /// unconcerned with the revenue sharing, exactly as [resources] already does for a caller
  /// unconcerned with the financing plan.
  final List<OcptBudgetRevenue> revenues;

  /// Every live share of the revenue sharing, in the `sortKey` order `OcptBudgetSharingService
  /// .loadShares` gives them — never reordered here. Defaults to empty, mirroring [revenues].
  final List<OcptBudgetShare> shares;

  /// What has actually come in against each taking, keyed by `OcptBudgetRevenue.id` —
  /// `ocptBudgetReceivedByRevenueId`, the sharing view's own mirror of [receivedByResourceId]. A
  /// taking with no key here has had no entry name it at all.
  final Map<String, OcptBudgetCoveredTotal> receivedByRevenueId;

  /// What has actually been paid against each share, keyed by `OcptBudgetShare.id` —
  /// `ocptBudgetPaidByShareId`. A share with no key here has had nobody pay against it at all.
  final Map<String, OcptBudgetCoveredTotal> paidByShareId;

  /// What there is to share, and what stands between the takings and it —
  /// `ocptBudgetSharingPotOf`, read over [receivedByRevenueId]/[revenues], [resources]' own
  /// reimbursable total and the repayments already made against it.
  final OcptBudgetSharingPot sharingPot;

  /// The split of [sharingPot] across [shares], in the order they are handed in —
  /// `ocptBudgetShareSplitsOf`.
  final List<OcptBudgetShareSplit> shareSplits;

  /// `revenues.length`.
  final int revenueCount;

  /// `shares.length`.
  final int shareCount;

  /// Class constructor
  const OcptBudgetSnapshot({
    required this.postes,
    required this.entries,
    required this.commitments,
    required this.resources,
    required this.defaultVatRateBasisPoints,
    required this.mealPriceCents,
    required this.snackPriceCents,
    required this.currencyCode,
    required this.posteCount,
    required this.lineCount,
    required this.entryCount,
    required this.commitmentCount,
    required this.resourceCount,
    required this.paidByPosteId,
    required this.offQuotePaidTotal,
    required this.committedByPosteId,
    required this.cashTotals,
    required this.receivedByResourceId,
    required this.alerts,
    required this.receiptsByEntryId,
    required this.regieDays,
    required this.regieTotals,
    required this.travelRows,
    required this.travelTotals,
    required this.revenues,
    required this.shares,
    required this.receivedByRevenueId,
    required this.paidByShareId,
    required this.sharingPot,
    required this.shareSplits,
    required this.revenueCount,
    required this.shareCount,
  });

  /// Builds an [OcptBudgetSnapshot] from [postes], [entries], [commitments] and [resources], the
  /// project's [defaultVatRateBasisPoints] and [currencyCode], deriving every count and every map
  /// from them. [receiptsByEntryId] is loaded the same way everything else here is
  /// (`OcptBudgetJournalService.loadReceipts`) and simply carried through — defaulted to empty for
  /// every caller unconcerned with vouchers, exactly as every one of this snapshot's own callers
  /// before this milestone still may be; [resources] is defaulted the same way, for every caller
  /// unconcerned with the financing plan.
  ///
  /// [paidByPosteId], [offQuotePaidTotal], [committedByPosteId], [cashTotals],
  /// [receivedByResourceId] and [alerts] are derived here exactly as [posteCount]/[lineCount] are:
  /// a pure function of the lists already
  /// loaded, reading them under [defaultVatRateBasisPoints] — the project's own rate, which moves
  /// the whole reading with it exactly as every silent line already does — with no database access
  /// of its own.
  ///
  /// [regieDays] and [travelRows] are derived the same way, over [scheduleDays]/[slotsByDayId] —
  /// `OcptScheduleService.loadSchedule`'s own `OcptScheduleSnapshot.days`/`.slotsByDayId`, **never**
  /// an `OcptSchedulePlanSnapshot`: a head count needs no shot list and no episode list, which is
  /// everything else that type joins in, and building one here would make this mode load the whole
  /// découpage to count meals. [roles], [people] and [mileageRates] are turned into the id-keyed
  /// maps `ocptBudgetRegieDaysOf`/`ocptBudgetTravelRowsOf` read, [mealPriceCents]/[snackPriceCents]
  /// passed straight through — every one of the six defaults empty/null for every caller unconcerned
  /// with the catering-and-travel pass, exactly as [resources] already does for the financing plan.
  factory OcptBudgetSnapshot.build({
    required List<OcptBudgetPoste> postes,
    required List<OcptBudgetEntry> entries,
    required List<OcptBudgetCommitment> commitments,
    List<OcptBudgetResource> resources = const [],
    required int? defaultVatRateBasisPoints,
    required String currencyCode,
    Map<String, OcptAssetRef> receiptsByEntryId = const {},
    List<OcptShootingDay> scheduleDays = const [],
    Map<String, List<OcptShootingSlot>> slotsByDayId = const {},
    List<OcptRole> roles = const [],
    List<OcptPerson> people = const [],
    List<OcptBudgetMileageRate> mileageRates = const [],
    int? mealPriceCents,
    int? snackPriceCents,
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
  }) {
    final paidByPosteId = ocptBudgetPaidCentsByPosteId(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final committedByPosteId = ocptBudgetCommittedCentsByPosteId(
      commitments,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final cashTotals = ocptBudgetCashTotalsOf(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final offQuotePaidTotal = ocptBudgetOffQuotePaidTotalOf(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final receivedByResourceId = ocptBudgetReceivedByResourceId(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    final receivedByRevenueId = ocptBudgetReceivedByRevenueId(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidByShareId = ocptBudgetPaidByShareId(
      entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final sharingPot = ocptBudgetSharingPotOf(
      received: ocptBudgetRevenuesReceivedTotalOf(
        revenues: revenues,
        receivedByRevenueId: receivedByRevenueId,
      ),
      reimbursableCents: ocptBudgetReimbursableTotalCents(resources),
      repaid: ocptBudgetRepaidContributionsTotalOf(
        entries,
        resources: resources,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      ),
    );
    final shareSplits = ocptBudgetShareSplitsOf(
      shares: shares,
      pot: sharingPot,
      paidByShareId: paidByShareId,
    );

    final regieDays = ocptBudgetRegieDaysOf(
      days: scheduleDays,
      slotsByDayId: slotsByDayId,
      roleKindById: {for (final role in roles) role.id: role.kind},
      mealPriceCents: mealPriceCents,
      snackPriceCents: snackPriceCents,
    );
    final travelRows = ocptBudgetTravelRowsOf(
      days: scheduleDays,
      slotsByDayId: slotsByDayId,
      personIdByRoleId: {for (final role in roles) role.id: role.personId},
      commuteKmMilliByPersonId: {for (final person in people) person.id: person.commuteKmMilli},
      mileageRateIdByPersonId: {for (final person in people) person.id: person.mileageRateId},
      ratePerKmMilliCentsByRateId: {
        for (final rate in mileageRates) rate.id: rate.ratePerKmMilliCents,
      },
    );

    return OcptBudgetSnapshot(
      postes: postes,
      entries: entries,
      commitments: commitments,
      resources: resources,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      mealPriceCents: mealPriceCents,
      snackPriceCents: snackPriceCents,
      currencyCode: currencyCode,
      posteCount: postes.length,
      lineCount: postes.fold(0, (sum, poste) => sum + poste.lines.length),
      entryCount: entries.length,
      commitmentCount: commitments.length,
      resourceCount: resources.length,
      paidByPosteId: paidByPosteId,
      offQuotePaidTotal: offQuotePaidTotal,
      committedByPosteId: committedByPosteId,
      cashTotals: cashTotals,
      receivedByResourceId: receivedByResourceId,
      alerts: ocptComputeBudgetAlerts(
        postes: postes,
        paidCentsOf: (posteId) => paidByPosteId[posteId]?.amountCents ?? 0,
        committedCentsOf: (posteId) => committedByPosteId[posteId]?.amountCents ?? 0,
        commitments: commitments,
        cashTotals: cashTotals,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      ),
      receiptsByEntryId: receiptsByEntryId,
      regieDays: regieDays,
      regieTotals: ocptBudgetRegieTotalsOf(regieDays),
      travelRows: travelRows,
      travelTotals: ocptBudgetTravelTotalsOf(travelRows),
      revenues: revenues,
      shares: shares,
      receivedByRevenueId: receivedByRevenueId,
      paidByShareId: paidByShareId,
      sharingPot: sharingPot,
      shareSplits: shareSplits,
      revenueCount: revenues.length,
      shareCount: shares.length,
    );
  }

  /// [posteId]'s own paid total, in cents, tax-inclusive — [paidByPosteId]'s own entry for
  /// [posteId], or **0** while it carries none.
  ///
  /// This `?? 0` is honest where M1's own zero was not: at M1 the app could not know what had
  /// moved against a poste at all, so printing `0 €` would have claimed a figure the data did not
  /// support. The journal exists now and is kept, so a poste with no entry against it genuinely has
  /// had nothing move against it — zero is the true answer here, not a stand-in for one.
  int paidCentsOf(String posteId) => paidByPosteId[posteId]?.amountCents ?? 0;

  /// [posteId]'s own committed total, in cents, tax-inclusive — [committedByPosteId]'s own entry
  /// for [posteId], or **0** while it carries none. See [paidCentsOf]'s own doc comment for why
  /// `?? 0` is the honest reading now that the journal exists.
  int committedCentsOf(String posteId) => committedByPosteId[posteId]?.amountCents ?? 0;

  /// [resourceId]'s own received total, in cents, tax-inclusive — [receivedByResourceId]'s own
  /// entry for [resourceId], or **0** while it carries none.
  ///
  /// **This `?? 0` is the ordinary reading, not the one an in-kind resource's own row needs.** A
  /// subsidy or a cash contribution with no entry naming it genuinely has had nothing come in yet —
  /// zero is the true answer, the same honesty [paidCentsOf]'s own doc comment argues for a poste
  /// with no entry against it. An in-kind contribution is different: it is valued, not collected,
  /// so "how much has come in" is not a question with an answer until an entry actually names it —
  /// which is exactly why the financing view reads [receivedByResourceId] itself, raw, for that one
  /// row kind, rather than through this method (`OcptBudgetFinancing`'s own class doc comment).
  int receivedCentsOf(String resourceId) => receivedByResourceId[resourceId]?.amountCents ?? 0;

  /// [revenueId]'s own received total, in cents, tax-inclusive — [receivedByRevenueId]'s own entry
  /// for [revenueId], or **0** while it carries none. Mirrors [receivedCentsOf]'s own honest-zero
  /// reading: a taking with no entry naming it genuinely has had nothing come in yet.
  int receivedRevenueCentsOf(String revenueId) => receivedByRevenueId[revenueId]?.amountCents ?? 0;

  /// [shareId]'s own paid total, in cents, tax-inclusive — [paidByShareId]'s own entry for
  /// [shareId], or **0** while it carries none. Mirrors [receivedCentsOf]'s own honest-zero
  /// reading: a share nobody has been paid against genuinely has had nothing move against it yet.
  int paidShareCentsOf(String shareId) => paidByShareId[shareId]?.amountCents ?? 0;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetSnapshot(posteCount: $posteCount, lineCount: $lineCount, "
      "entryCount: $entryCount, commitmentCount: $commitmentCount, resourceCount: $resourceCount, "
      "defaultVatRateBasisPoints: $defaultVatRateBasisPoints, currencyCode: $currencyCode, "
      "regieDayCount: ${regieDays.length}, travelRowCount: ${travelRows.length}, "
      "revenueCount: $revenueCount, shareCount: $shareCount)";

  /// Object properties
  @override
  List<Object?> get props => [
    postes,
    entries,
    commitments,
    resources,
    defaultVatRateBasisPoints,
    mealPriceCents,
    snackPriceCents,
    currencyCode,
    posteCount,
    lineCount,
    entryCount,
    commitmentCount,
    resourceCount,
    paidByPosteId,
    offQuotePaidTotal,
    committedByPosteId,
    cashTotals,
    receivedByResourceId,
    alerts,
    receiptsByEntryId,
    regieDays,
    regieTotals,
    travelRows,
    travelTotals,
    revenues,
    shares,
    receivedByRevenueId,
    paidByShareId,
    sharingPot,
    shareSplits,
    revenueCount,
    shareCount,
  ];
}
