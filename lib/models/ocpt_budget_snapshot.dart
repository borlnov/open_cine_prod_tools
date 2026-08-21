// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The whole budget mode's read, in one object: the [postes] with their lines, the cash journal's
/// own [entries] and [commitments], the project's own [defaultVatRateBasisPoints] and
/// [currencyCode], and the counts the status bar and the mode's own reads need.
///
/// Built the same way `OcptResourcesSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. `OcptBudgetQuoteService.loadPostes` is what loads [postes],
/// `OcptBudgetJournalService.loadEntries`/`loadCommitments` are what load [entries] and
/// [commitments]; combining those reads with the project's own settings into this one object is
/// the mode's job.
class OcptBudgetSnapshot extends Equatable {
  /// Every poste of the project, in display order, each with its own quote lines.
  final List<OcptBudgetPoste> postes;

  /// Every live journal entry, in the chronological order `OcptBudgetJournalService.loadEntries`
  /// gives them — never reordered here.
  final List<OcptBudgetEntry> entries;

  /// Every live commitment, in the due-date order `OcptBudgetJournalService.loadCommitments` gives
  /// them — never reordered here.
  final List<OcptBudgetCommitment> commitments;

  /// The project's default VAT rate, in basis points, or null meaning "nobody has recorded a
  /// rate" — `OcptProjectInfoTable.defaultVatRateBasisPoints`.
  final int? defaultVatRateBasisPoints;

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

  /// What has actually been paid against each poste, keyed by `OcptBudgetPoste.id` — a poste with
  /// no key here has had nothing move against it at all, which is different from a key present
  /// whose own amount is zero (`ocptBudgetPaidCentsByPosteId`'s own doc comment). [paidCentsOf] is
  /// what the mode reads instead of this map directly.
  final Map<String, OcptBudgetCoveredTotal> paidByPosteId;

  /// What is committed against each poste, keyed by `OcptBudgetPoste.id`, settled commitments
  /// excluded outright (`ocptBudgetCommittedCentsByPosteId`'s own doc comment). [committedCentsOf]
  /// is what the mode reads instead of this map directly.
  final Map<String, OcptBudgetCoveredTotal> committedByPosteId;

  /// The cash journal's own debit, credit and balance, over [entries].
  final OcptBudgetCashTotals cashTotals;

  /// The dashboard's own two alerts — a poste over its quote, the cash projection going negative —
  /// computed once, here, by [ocptComputeBudgetAlerts] over this snapshot's own already-loaded
  /// data: **both computed, neither configured** (`docs/plans/budget-mode.md` §5, M2).
  final List<OcptBudgetAlert> alerts;

  /// Every live voucher, keyed by the `OcptBudgetEntry.id` it evidences —
  /// `OcptBudgetJournalService.loadReceipts` verbatim, at most one per entry. An entry with no key
  /// here carries no voucher at all.
  final Map<String, OcptAssetRef> receiptsByEntryId;

  /// Class constructor
  const OcptBudgetSnapshot({
    required this.postes,
    required this.entries,
    required this.commitments,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.posteCount,
    required this.lineCount,
    required this.entryCount,
    required this.commitmentCount,
    required this.paidByPosteId,
    required this.committedByPosteId,
    required this.cashTotals,
    required this.alerts,
    required this.receiptsByEntryId,
  });

  /// Builds an [OcptBudgetSnapshot] from [postes], [entries] and [commitments], the project's
  /// [defaultVatRateBasisPoints] and [currencyCode], deriving every count and every map from them.
  /// [receiptsByEntryId] is loaded the same way everything else here is
  /// (`OcptBudgetJournalService.loadReceipts`) and simply carried through — defaulted to empty for
  /// every caller unconcerned with vouchers, exactly as every one of this snapshot's own callers
  /// before this milestone still may be.
  ///
  /// [paidByPosteId], [committedByPosteId], [cashTotals] and [alerts] are derived here exactly as
  /// [posteCount]/[lineCount] are: a pure function of the lists already loaded, reading them under
  /// [defaultVatRateBasisPoints] — the project's own rate, which moves the whole reading with it
  /// exactly as every silent line already does — with no database access of its own.
  factory OcptBudgetSnapshot.build({
    required List<OcptBudgetPoste> postes,
    required List<OcptBudgetEntry> entries,
    required List<OcptBudgetCommitment> commitments,
    required int? defaultVatRateBasisPoints,
    required String currencyCode,
    Map<String, OcptAssetRef> receiptsByEntryId = const {},
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

    return OcptBudgetSnapshot(
      postes: postes,
      entries: entries,
      commitments: commitments,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
      posteCount: postes.length,
      lineCount: postes.fold(0, (sum, poste) => sum + poste.lines.length),
      entryCount: entries.length,
      commitmentCount: commitments.length,
      paidByPosteId: paidByPosteId,
      committedByPosteId: committedByPosteId,
      cashTotals: cashTotals,
      alerts: ocptComputeBudgetAlerts(
        postes: postes,
        paidCentsOf: (posteId) => paidByPosteId[posteId]?.amountCents ?? 0,
        committedCentsOf: (posteId) => committedByPosteId[posteId]?.amountCents ?? 0,
        commitments: commitments,
        cashTotals: cashTotals,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      ),
      receiptsByEntryId: receiptsByEntryId,
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

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetSnapshot(posteCount: $posteCount, lineCount: $lineCount, "
      "entryCount: $entryCount, commitmentCount: $commitmentCount, "
      "defaultVatRateBasisPoints: $defaultVatRateBasisPoints, currencyCode: $currencyCode)";

  /// Object properties
  @override
  List<Object?> get props => [
    postes,
    entries,
    commitments,
    defaultVatRateBasisPoints,
    currencyCode,
    posteCount,
    lineCount,
    entryCount,
    commitmentCount,
    paidByPosteId,
    committedByPosteId,
    cashTotals,
    alerts,
    receiptsByEntryId,
  ];
}
