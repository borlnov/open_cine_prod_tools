// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';

/// [entry]'s own [OcptBudgetEntry.debitCents], read **tax-inclusive**, given the project's own
/// [projectVatRateBasisPoints] — or null when that reading is impossible.
///
/// Money that moved is always read tax-inclusive (`docs/architecture/budget.md`): unlike the
/// quote, where a header toggle asks for either basis, there is no basis to pick for a payment —
/// only [ocptIncludingTaxAmountCentsOf] over an [OcptMoney] built from [entry]'s own
/// [OcptBudgetEntry.isTaxInclusive] and [OcptBudgetEntry.vatRateBasisPoints], which is this entry's
/// own answer whenever it is already typed tax-inclusive (the common case, needing no rate at all)
/// and null only when it is typed excluding tax and no rate — neither the entry's own override nor
/// the project's default — is there to gross it back up with.
///
/// See [ocptBudgetEntryCreditCentsOf]: both read the very same basis and rate, off the very same
/// entry, so **the two answer null together** — an entry never has one readable side and one
/// unreadable one.
int? ocptBudgetEntryDebitCentsOf(OcptBudgetEntry entry, {required int? projectVatRateBasisPoints}) =>
    ocptIncludingTaxAmountCentsOf(
      OcptMoney(
        amountCents: entry.debitCents,
        isTaxInclusive: entry.isTaxInclusive,
        vatRateBasisPoints: entry.vatRateBasisPoints,
      ),
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );

/// [entry]'s own [OcptBudgetEntry.creditCents], read **tax-inclusive**, given the project's own
/// [projectVatRateBasisPoints] — or null when that reading is impossible.
///
/// [ocptBudgetEntryDebitCentsOf]'s mirror, over [OcptBudgetEntry.creditCents] rather than
/// [OcptBudgetEntry.debitCents] — see that function's own doc comment for the argument and for why
/// both answer null together, since an entry carries one basis and one rate for both of its
/// figures.
int? ocptBudgetEntryCreditCentsOf(OcptBudgetEntry entry, {required int? projectVatRateBasisPoints}) =>
    ocptIncludingTaxAmountCentsOf(
      OcptMoney(
        amountCents: entry.creditCents,
        isTaxInclusive: entry.isTaxInclusive,
        vatRateBasisPoints: entry.vatRateBasisPoints,
      ),
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );

/// The cash journal's own totals: [debitCents] and [creditCents] summed **row by row, then summed**
/// (`docs/architecture/budget.md`'s own law), each already read tax-inclusive, paired with how many
/// of [entryCount] entries actually contributed to them.
class OcptBudgetCashTotals extends Equatable {
  /// The sum of every covered entry's own tax-inclusive [OcptBudgetEntry.debitCents].
  final int debitCents;

  /// The sum of every covered entry's own tax-inclusive [OcptBudgetEntry.creditCents].
  final int creditCents;

  /// How many of [entryCount] entries actually carried a known rate and were summed into
  /// [debitCents] and [creditCents].
  final int coveredEntryCount;

  /// How many entries this total was asked to sum, covered or not.
  final int entryCount;

  /// The journal's own balance: [creditCents] minus [debitCents], negative once the journal is, on
  /// balance, a cost.
  int get balanceCents => creditCents - debitCents;

  /// Whether every entry carried a known rate — [coveredEntryCount] equals [entryCount].
  bool get isComplete => coveredEntryCount == entryCount;

  /// Class constructor
  const OcptBudgetCashTotals({
    required this.debitCents,
    required this.creditCents,
    required this.coveredEntryCount,
    required this.entryCount,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetCashTotals(debitCents: $debitCents, creditCents: $creditCents, "
      "coveredEntryCount: $coveredEntryCount, entryCount: $entryCount)";

  /// Object properties
  @override
  List<Object?> get props => [debitCents, creditCents, coveredEntryCount, entryCount];
}

/// [entries]' own debit, credit and balance, given the project's own [projectVatRateBasisPoints].
///
/// **Row by row, then summed** — [ocptBudgetEntryDebitCentsOf] and [ocptBudgetEntryCreditCentsOf]
/// are read for each entry individually before the covered ones are added together, exactly the
/// reading `ocptBudgetExcludingTaxTotalOf` already gives the quote: a journal mixing tax-inclusive
/// and tax-exclusive entries, or entries at different rates, still totals correctly. An entry that
/// cannot be read — [ocptBudgetEntryDebitCentsOf] or [ocptBudgetEntryCreditCentsOf] answering null,
/// which happens to both or neither since they share one basis and rate — contributes to neither
/// [OcptBudgetCashTotals.debitCents] nor [OcptBudgetCashTotals.creditCents] nor
/// [OcptBudgetCashTotals.coveredEntryCount].
OcptBudgetCashTotals ocptBudgetCashTotalsOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var debitCents = 0;
  var creditCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    final credit = ocptBudgetEntryCreditCentsOf(
      entry,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (debit == null || credit == null) {
      continue;
    }

    debitCents += debit;
    creditCents += credit;
    coveredEntryCount++;
  }

  return OcptBudgetCashTotals(
    debitCents: debitCents,
    creditCents: creditCents,
    coveredEntryCount: coveredEntryCount,
    entryCount: entries.length,
  );
}

/// One row of the cash journal view: [entry] itself, its debit and credit read tax-inclusive, and
/// the running balance once it has fallen — each null together when [entry] cannot be read.
class OcptBudgetJournalRow extends Equatable {
  /// The entry this row prints.
  final OcptBudgetEntry entry;

  /// [entry]'s own [OcptBudgetEntry.debitCents], read tax-inclusive, or null when unreadable.
  final int? debitCents;

  /// [entry]'s own [OcptBudgetEntry.creditCents], read tax-inclusive, or null when unreadable.
  final int? creditCents;

  /// The running balance once [entry] has been taken into account, or null when [entry] is
  /// unreadable — see [ocptBudgetJournalRowsOf]'s own doc comment for why a hole in this one column,
  /// rather than a guess, is what an unreadable movement earns.
  final int? balanceAfterCents;

  /// Class constructor
  const OcptBudgetJournalRow({
    required this.entry,
    required this.debitCents,
    required this.creditCents,
    required this.balanceAfterCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetJournalRow(entry: ${entry.id}, debitCents: $debitCents, "
      "creditCents: $creditCents, balanceAfterCents: $balanceAfterCents)";

  /// Object properties
  @override
  List<Object?> get props => [entry, debitCents, creditCents, balanceAfterCents];
}

/// [entries], each paired with its own debit, credit and the running balance once it has fallen,
/// given the project's own [projectVatRateBasisPoints].
///
/// **Never reorders [entries]**: `OcptBudgetJournalService.loadEntries` has already ordered them
/// chronologically (`date` ascending, `sortKey` breaking a tie), and a running balance only means
/// anything read in the order money actually moved — reordering it here, even by a rule that looked
/// harmless, would silently invent an account history that never happened.
///
/// **An unreadable entry leaves the running balance exactly where it was**, and its own
/// [OcptBudgetJournalRow.balanceAfterCents] is null rather than a repeat of the balance before it or
/// a guess at what it might become: the balance *after* a movement of unknown size is itself
/// unknown, and printing the old figure again would claim this movement changed nothing, which is
/// not the fact on hand either. The balance the reader already had, by contrast, is not in doubt —
/// it was computed from every entry read so far, all of them known — so the row below the hole
/// keeps counting from exactly where the journal actually stood, rather than every later row being
/// poisoned by the one gap above it.
List<OcptBudgetJournalRow> ocptBudgetJournalRowsOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var balanceCents = 0;
  final rows = <OcptBudgetJournalRow>[];

  for (final entry in entries) {
    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    final credit = ocptBudgetEntryCreditCentsOf(
      entry,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );

    if (debit == null || credit == null) {
      rows.add(
        OcptBudgetJournalRow(
          entry: entry,
          debitCents: null,
          creditCents: null,
          balanceAfterCents: null,
        ),
      );
      continue;
    }

    balanceCents += credit - debit;
    rows.add(
      OcptBudgetJournalRow(
        entry: entry,
        debitCents: debit,
        creditCents: credit,
        balanceAfterCents: balanceCents,
      ),
    );
  }

  return rows;
}

/// What has actually been paid against each poste, given the project's own
/// [projectVatRateBasisPoints]: per poste, [OcptBudgetCoveredTotal.amountCents] is the tax-inclusive
/// sum of [OcptBudgetEntry.debitCents] minus [OcptBudgetEntry.creditCents] over every entry naming
/// that poste — a refund credited back against a poste genuinely reduces what that poste has cost,
/// it is not a second poste's income, which is why it is subtracted here rather than tracked as its
/// own inflow.
///
/// **An entry naming no poste is not in this map at all**: `OcptBudgetEntriesTable.posteId`'s own
/// doc comment reads a null poste as money that priced nothing, most often cash coming in, and money
/// coming in prices nothing.
///
/// **A poste with no entry at all has no key in the map** — this is the whole reason this answers a
/// map rather than a single total: a caller can tell "nothing has moved against this poste" (absent
/// key) apart from "movement happened here but it cancelled out to zero" (a key present, its
/// [OcptBudgetCoveredTotal.amountCents] zero), which `docs/architecture/budget.md`'s own rule
/// ("nothing having moved against a poste is not the same fact as zero having moved against it")
/// otherwise loses the moment the two are folded into the same absent-or-zero figure.
Map<String, OcptBudgetCoveredTotal> ocptBudgetPaidCentsByPosteId(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final entriesByPosteId = <String, List<OcptBudgetEntry>>{};
  for (final entry in entries) {
    final posteId = entry.posteId;
    if (posteId == null) {
      continue;
    }

    entriesByPosteId.putIfAbsent(posteId, () => []).add(entry);
  }

  return {
    for (final posteEntries in entriesByPosteId.entries)
      posteEntries.key: _ocptBudgetPaidTotalOf(
        posteEntries.value,
        projectVatRateBasisPoints: projectVatRateBasisPoints,
      ),
  };
}

/// The total of every debit that names **no poste at all** — spending that happened but that
/// prices no line of the quote — given the project's own [projectVatRateBasisPoints].
///
/// `OcptBudgetEntriesTable.posteId`'s own doc comment reads a poste-less entry as "typically money
/// coming in", and that is true of the common case — a subsidy instalment, a contribution repaid.
/// It is not the whole story: this mode's own entry dialog offers `Aucun poste` as a plain choice,
/// so a poste-less entry can just as well be a real **cost** that simply prices nothing in the CNC
/// nomenclature, the small-production reading the whole mode is built for
/// (`docs/architecture/budget.md`). [ocptBudgetPaidCentsByPosteId] only ever keys an entry that
/// names a poste, so this spending was counted nowhere at all until this function existed —
/// `OcptBudgetCashTotals.balanceCents` was the only reading that ever saw it, over every live
/// entry rather than by poste.
///
/// **Debits only.** A credit naming no poste is money coming *in* — a subsidy instalment, a
/// contribution — which is not off-quote spending; it belongs to the financing and revenue
/// readings (`ocptBudgetReceivedByResourceId`, `ocptBudgetReceivedByRevenueId`,
/// `lib/utils/ocpt_budget_financing.dart`/`ocpt_budget_shares.dart`), which already count it.
/// [OcptBudgetEntry.creditCents] is read by no line of this function at all — only
/// [OcptBudgetEntry.debitCents], and only through [ocptBudgetEntryDebitCentsOf], **never the raw
/// column**, so an entry missing the rate it would need to be grossed up leaves this total
/// *covered-but-incomplete* ([OcptBudgetCoveredTotal.isComplete] false) rather than silently
/// wrong — the very same "null, never zero" discipline every other reading in this file keeps.
///
/// A poste-less **credit** never reaches [OcptBudgetCoveredTotal.lineCount] either: it is not
/// off-quote spending at all, so it is not one of the "lines" this total was asked to sum in the
/// first place, exactly as an entry naming a poste never reaches it.
OcptBudgetCoveredTotal ocptBudgetOffQuotePaidTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  final offQuoteDebits = entries
      .where((entry) => entry.posteId == null && entry.debitCents != 0)
      .toList();

  var amountCents = 0;
  var coveredLineCount = 0;

  for (final entry in offQuoteDebits) {
    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    if (debit == null) {
      continue;
    }

    amountCents += debit;
    coveredLineCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: offQuoteDebits.length,
  );
}

/// [entries]' own paid total — the tax-inclusive sum of debit minus credit, row by row, then summed
/// — paired with how many of them actually carried a known rate. The one poste-scoped loop
/// [ocptBudgetPaidCentsByPosteId] runs once per poste, kept separate so that function stays a plain
/// grouping followed by one reading per group.
OcptBudgetCoveredTotal _ocptBudgetPaidTotalOf(
  List<OcptBudgetEntry> entries, {
  required int? projectVatRateBasisPoints,
}) {
  var amountCents = 0;
  var coveredEntryCount = 0;

  for (final entry in entries) {
    final debit = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: projectVatRateBasisPoints);
    final credit = ocptBudgetEntryCreditCentsOf(
      entry,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    if (debit == null || credit == null) {
      continue;
    }

    amountCents += debit - credit;
    coveredEntryCount++;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredEntryCount,
    lineCount: entries.length,
  );
}
