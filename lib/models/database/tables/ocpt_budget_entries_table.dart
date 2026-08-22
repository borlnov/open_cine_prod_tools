// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_postes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_resources_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_revenues_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_shares_table.dart';

/// One movement of the production's cash journal: money that actually left or entered the account,
/// dated and, usually, priced against a poste.
///
/// **The money is the same three columns `OcptBudgetLinesTable`'s own doc comment argues for**,
/// split across a debit and a credit rather than carried as a single signed figure:
///
/// - [debitCents] is what left the account, [creditCents] is what came in, both exactly as typed
///   and never reconstructed — a payment and a refund of the same invoice are two different rows,
///   never one row whose sign flips;
/// - [isTaxInclusive] and [vatRateBasisPoints] read exactly as their `OcptBudgetLinesTable`
///   namesakes do: non-nullable, `true` by default, and a null rate means "inherit the project's
///   own", never "nobody has said" — an explicit **0 %** is wages or a copyright assignment stating
///   plainly that no VAT applies, and the two are different facts.
///
/// [posteId] is **nullable, and deliberately so**: an entry attached to no poste is a real fact,
/// not "nobody has said which poste yet" — most often money coming *in* rather than a cost against
/// the quote, a subsidy instalment, a contribution repaid, but not only that: this mode's own entry
/// dialog offers `Aucun poste` as a plain choice on a debit too, so a poste-less entry can just as
/// well be a real cost that simply prices nothing in the CNC nomenclature, the small-production
/// reading this whole mode is built for. `lib/utils/ocpt_budget_journal.dart`'s own
/// `ocptBudgetOffQuotePaidTotalOf` is what reads that spending back out, rather than the app
/// silently losing track of it the moment it names no poste. A line spent against the quote almost
/// always names one; a receipt almost never does.
///
/// [resourceId] names which financing resource this movement settles — a subsidy instalment coming
/// in, a contribution repaid — and is **nullable for the same reason [posteId] is**: most movements
/// settle no resource at all, which is a real fact rather than an unfinished pick, and this table's
/// own doc comment on `OcptBudgetResourcesTable` is what actually adds this figure up (there is no
/// stored `receivedCents` counter on that table to keep in step with it).
///
/// [revenueId] and [shareId] mirror [resourceId] exactly, one milestone later: [revenueId] names
/// which taking a credit is the actual cash for, and [shareId] names which participant a debit
/// actually pays — both nullable for the very same reason, and both are what a revenue's or a
/// share's own doc comment (`OcptBudgetRevenuesTable`, `OcptBudgetSharesTable`) reads to add up
/// what has actually come in or gone out, rather than a stored counter on either table.
@DataClassName('OcptBudgetEntryRow')
class OcptBudgetEntriesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetEntriesTable}
  @override
  String get tableName => 'budget_entries';

  /// The stable, unique id of this entry (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The date this movement is recorded under.
  ///
  /// Non-nullable: an entry always happened on a day, unlike [posteId] or [vatRateBasisPoints],
  /// whose absence is a real fact rather than an omission still to be filled in.
  DateTimeColumn get date => dateTime()();

  /// This entry's free-text wording, e.g. "Location camion — Transpalux".
  TextColumn get label => text()();

  /// The poste this entry is priced against, or null. → [OcptBudgetPostesTable]
  ///
  /// See this table's own doc comment: null is money that moved without pricing any one poste,
  /// most often cash coming in.
  TextColumn get posteId => text().nullable().references(OcptBudgetPostesTable, #id)();

  /// What left the account on [date], exactly as typed, in cents — see this table's own doc
  /// comment.
  IntColumn get debitCents => integer().withDefault(const Constant(0))();

  /// What came into the account on [date], exactly as typed, in cents — see this table's own doc
  /// comment.
  IntColumn get creditCents => integer().withDefault(const Constant(0))();

  /// Whether [debitCents]/[creditCents] already include tax — see this table's own doc comment.
  ///
  /// **Non-nullable, `true` by default**, for the same reason `OcptBudgetLinesTable.isTaxInclusive`
  /// is: the common case somebody types by hand off a till receipt or an invoice total already
  /// includes tax.
  BoolColumn get isTaxInclusive => boolean().withDefault(const Constant(true))();

  /// The VAT rate this entry's figures carry, in basis points (550 for 5.5 %), or null — see this
  /// table's own doc comment for the two facts a null and an explicit `0` state differently, read
  /// exactly as `OcptBudgetLinesTable.vatRateBasisPoints` reads them.
  IntColumn get vatRateBasisPoints => integer().nullable()();

  /// The accounting reference this entry was minted with (e.g. `J-014`), free text.
  ///
  /// Defaults to the empty string only for a row created by hand outside `OcptBudgetJournalService`
  /// (a test fixture, a future import); every entry `createEntry` mints carries a real one — see
  /// that method's own doc comment for the numbering scheme.
  TextColumn get voucherNumber => text().withDefault(const Constant(''))();

  /// The financing resource this movement settles, or null. → [OcptBudgetResourcesTable]
  ///
  /// See this table's own doc comment: null is the normal case, a movement that settles no
  /// resource, read exactly the way [posteId]'s own null is.
  TextColumn get resourceId => text().nullable().references(OcptBudgetResourcesTable, #id)();

  /// The taking this credit is the actual cash for, or null. → [OcptBudgetRevenuesTable]
  ///
  /// See this table's own doc comment: null is the normal case, a movement that is not a taking
  /// coming in, read exactly the way [resourceId]'s own null is.
  TextColumn get revenueId => text().nullable().references(OcptBudgetRevenuesTable, #id)();

  /// The participant this debit actually pays, or null. → [OcptBudgetSharesTable]
  ///
  /// See this table's own doc comment: null is the normal case, a movement that pays no share of
  /// the revenue sharing, read exactly the way [resourceId]'s own null is.
  TextColumn get shareId => text().nullable().references(OcptBudgetSharesTable, #id)();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
