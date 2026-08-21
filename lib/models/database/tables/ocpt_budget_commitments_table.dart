// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_entries_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_postes_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

/// Converts a [OcptBudgetCommitmentStatus] to and from the text stored in the
/// `budget_commitments.status` column.
class OcptBudgetCommitmentStatusConverter extends TypeConverter<OcptBudgetCommitmentStatus, String> {
  /// Class constructor
  const OcptBudgetCommitmentStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetCommitmentStatus fromSql(String fromDb) =>
      OcptBudgetCommitmentStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetCommitmentStatus value) => value.name;
}

/// Money committed to a poste but not yet paid: a quote accepted, a contract signed, an invoice
/// received or a spend declared — [OcptBudgetCommitmentStatus] — that has not yet become a
/// `budget_entries` row.
///
/// Carries the same money triple `OcptBudgetLinesTable` and `OcptBudgetEntriesTable` both do
/// ([amountCents], [isTaxInclusive], [vatRateBasisPoints]), read exactly the same way: the figure
/// exactly as typed, whether it already includes tax, and a null rate meaning "inherit the
/// project's own", never "nobody has said".
///
/// [posteId] is **non-nullable, unlike `OcptBudgetEntriesTable.posteId`**: a commitment is always a
/// cost incurred against the quote — there is no "committed spending that prices nothing" the way a
/// subsidy instalment coming in prices no poste.
///
/// [settledEntryId] is how a commitment becomes paid: once it names a `budget_entries` row, the
/// commitment is settled (`OcptBudgetCommitment.isSettled`) — see [OcptBudgetCommitmentStatus]'s own
/// doc comment for why this is the one and only place that fact is recorded, rather than a fifth
/// status value duplicating it.
@DataClassName('OcptBudgetCommitmentRow')
class OcptBudgetCommitmentsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetCommitmentsTable}
  @override
  String get tableName => 'budget_commitments';

  /// The stable, unique id of this commitment (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The date this commitment falls due, or null.
  ///
  /// **Null means "nobody has recorded a due date"**, the same reading every other nullable figure
  /// in this schema carries (`OcptProjectInfoTable.minimumRestMinutes`) — **never** "due
  /// immediately". A commitment freshly typed in, before its invoice even names a date, is exactly
  /// this: real, committed, and simply not yet dated.
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// This commitment's free-text wording, e.g. "Assurance tournage — acompte".
  TextColumn get label => text()();

  /// The poste this commitment is priced against. → [OcptBudgetPostesTable]
  ///
  /// Non-nullable — see this table's own doc comment.
  TextColumn get posteId => text().references(OcptBudgetPostesTable, #id)();

  /// The amount committed, exactly as typed, in cents — see this table's own doc comment.
  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  /// Whether [amountCents] already includes tax — see this table's own doc comment.
  ///
  /// **Non-nullable, `true` by default**, for the same reason `OcptBudgetLinesTable.isTaxInclusive`
  /// is.
  BoolColumn get isTaxInclusive => boolean().withDefault(const Constant(true))();

  /// The VAT rate [amountCents] carries, in basis points (550 for 5.5 %), or null — see this
  /// table's own doc comment for the two facts a null and an explicit `0` state differently, read
  /// exactly as `OcptBudgetLinesTable.vatRateBasisPoints` reads them.
  IntColumn get vatRateBasisPoints => integer().nullable()();

  /// How far this commitment has progressed towards being paid.
  TextColumn get status => text()
      .map(const OcptBudgetCommitmentStatusConverter())
      .withDefault(const Constant('quoteAccepted'))();

  /// The `budget_entries` row that settled this commitment, or null while it remains unpaid.
  /// → [OcptBudgetEntriesTable]
  TextColumn get settledEntryId => text().nullable().references(OcptBudgetEntriesTable, #id)();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
