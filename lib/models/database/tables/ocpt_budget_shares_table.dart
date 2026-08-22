// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';

/// One participant's share of the revenue sharing: what fraction of the pot they are due, and what
/// fraction of *their own* due share they reinvest in the next production.
///
/// [personId] is **nullable**: a share may name somebody in the resources catalogue (an actor, a
/// crew member) or nobody at all — a role such as "Production" or "Distributeur" is a perfectly
/// good participant that names no one person.
///
/// [sharePermille] and [reinvestPermille] are integers in **per mille** (400 is 40 %), for the
/// reason `OcptBudgetLinesTable.quantityMilli` is in thousandths: a share of 12.5 % has to be
/// sayable exactly, which a whole-percent column cannot do. [reinvestPermille] is per mille **of
/// this participant's own [sharePermille]**, never of the whole pot — a participant reinvesting
/// half of what they are due writes `500` here regardless of how large their own share of the pot
/// is.
///
/// **No column enforces that every live share's [sharePermille] sums to `1000`.** A sharing plan
/// still being negotiated legitimately does not add up yet, and refusing the write over it would
/// make the app unusable while the plan is still being built — the view that reads this table
/// states the sum for a human to check, it does not police it.
///
/// No money triple, and no `paidCents` column either, for the third time this mode makes the same
/// argument (`OcptBudgetResourcesTable`'s own `receivedCents`, `OcptBudgetCommitmentsTable`'s own
/// `settled`): what a participant has actually been paid is the sum of the `budget_entries` debits
/// naming them through `budget_entries.shareId`, never a stored counter kept in step by hand.
@DataClassName('OcptBudgetShareRow')
class OcptBudgetSharesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetSharesTable}
  @override
  String get tableName => 'budget_shares';

  /// The stable, unique id of this share (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The person this share names, or null — see this table's own doc comment: null is a real
  /// participant (a role rather than an individual), not "nobody has said yet".
  TextColumn get personId => text().nullable().references(OcptPeopleTable, #id)();

  /// This share's free-text wording, e.g. "Réalisatrice" or the participant's own role in the
  /// production.
  TextColumn get label => text()();

  /// This participant's share of the whole pot, in per mille — see this table's own doc comment.
  IntColumn get sharePermille => integer().withDefault(const Constant(0))();

  /// The fraction of this participant's *own* [sharePermille] they reinvest in the next
  /// production, in per mille — see this table's own doc comment.
  IntColumn get reinvestPermille => integer().withDefault(const Constant(0))();

  /// Free-form notes about this share.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
