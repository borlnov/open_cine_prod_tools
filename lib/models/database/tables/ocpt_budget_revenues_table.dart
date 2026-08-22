// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';

/// Converts a [OcptBudgetRevenueStatus] to and from the text stored in the
/// `budget_revenues.status` column.
class OcptBudgetRevenueStatusConverter extends TypeConverter<OcptBudgetRevenueStatus, String> {
  /// Class constructor
  const OcptBudgetRevenueStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetRevenueStatus fromSql(String fromDb) => OcptBudgetRevenueStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetRevenueStatus value) => value.name;
}

/// One taking the production expects — a sale, a broadcast fee, a share of the box office — dated,
/// worded and priced at the figure it is expected to bring in.
///
/// **No column holding what has actually come in.** What a taking has actually brought in is the
/// sum of the `budget_entries` credits naming it through `budget_entries.revenueId`, computed on
/// every read rather than stored beside it — the very same argument `OcptBudgetResourcesTable`'s
/// own doc comment already makes for a financing resource's `receivedCents`, and
/// `OcptBudgetCommitmentsTable`'s own doc comment makes for a commitment's `settled`: a stored
/// second copy of one truth has to be kept in step by a write nobody can guarantee never to forget.
/// This table holds the **expectation** only — its date, its wording, the amount expected and where
/// its paperwork stands ([status]) — never the cash.
///
/// **No money triple either — no `isTaxInclusive`, no `vatRateBasisPoints`.** A revenue is money
/// coming *in*, exactly the case `OcptBudgetResourcesTable`'s own doc comment already settles for a
/// financing resource: `docs/architecture/budget.md`'s "Money that has moved is read
/// tax-inclusive, always" leaves no second basis to read it in.
@DataClassName('OcptBudgetRevenueRow')
class OcptBudgetRevenuesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetRevenuesTable}
  @override
  String get tableName => 'budget_revenues';

  /// The stable, unique id of this revenue (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The date this taking is expected, declared exactly as `OcptBudgetEntriesTable.date` is:
  /// non-nullable, since a taking is always dated, unlike a status or a note whose absence is a
  /// real fact rather than an omission still to be filled in.
  DateTimeColumn get date => dateTime()();

  /// This taking's free-text wording, e.g. "Vente VOD — plateforme X".
  TextColumn get label => text()();

  /// The amount this taking is expected to bring in, exactly as typed, in cents.
  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  /// How far this taking's own paperwork has progressed — see this table's own doc comment for why
  /// this is never a claim about the cash.
  TextColumn get status => text()
      .map(const OcptBudgetRevenueStatusConverter())
      .withDefault(const Constant('expected'))();

  /// Free-form notes about this taking.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
