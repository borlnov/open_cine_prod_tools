// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';

/// Converts a [OcptBudgetAllowanceKind] to and from the text stored in the
/// `budget_allowances.kind` column.
class OcptBudgetAllowanceKindConverter extends TypeConverter<OcptBudgetAllowanceKind, String> {
  /// Class constructor
  const OcptBudgetAllowanceKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptBudgetAllowanceKind fromSql(String fromDb) => OcptBudgetAllowanceKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptBudgetAllowanceKind value) => value.name;
}

/// One defrayal: what the production pays somebody back for, typed by hand.
///
/// **Nothing here is deduced from the schedule, and that is the whole point of the table.** The
/// régie view used to compute a traveller's cost as one return trip per day of presence, from their
/// own home-to-set distance and their own rate. A real shoot does not work that way: somebody
/// travels in on the first day, is housed near the set for a fortnight and travels home on the
/// last; somebody else is defrayed for two journeys out of fifteen days; a technician claims a
/// taxi and a crew member three meals. None of that is derivable from a presence, so none of it is
/// derived — it is written down, one row per thing actually owed.
///
/// **A person's own `commuteKmMilli` and `mileageRateId` did not become useless, they became a
/// pre-fill.** Opening the dialog on a person whose commute and rate are known offers the distance
/// and the rate already filled in; changing either is an ordinary edit, and neither is read again
/// afterwards. The rate suggests, it never decides — the very reading `OcptBudgetResourcesTable`
/// already argues for a status the user types.
///
/// [personId] is **nullable**, declared the way `OcptBudgetSharesTable.personId` is: a defrayal
/// usually names somebody, but a row reading "Taxis, semaine 2" that names nobody in particular is
/// a legitimate line of a régie budget, not an unfinished pick.
///
/// [quantityMilli] is in **thousandths** for the reason `OcptBudgetLinesTable.quantityMilli` is,
/// and [unitAmountMilliCents] in **thousandths of a cent** for the reason
/// `OcptBudgetMileageRatesTable.ratePerKmMilliCents` is: a mileage scale is published to three
/// decimals (0.529 €/km), and whole cents cannot state it. A nightly rate or a meal price sits in
/// the same column with two zeroes to spare.
///
/// **No money triple, like `budget_resources` and `budget_shares` before it.** A defrayal row is
/// what the provisioning reads to write a quote line, and it is that *line* that carries the tax
/// basis and the VAT rate — the amount a reader is owed is one figure, and asking for its VAT twice
/// would be asking the same question in two places.
@DataClassName('OcptBudgetAllowanceRow')
class OcptBudgetAllowancesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptBudgetAllowancesTable}
  @override
  String get tableName => 'budget_allowances';

  /// The stable, unique id of this defrayal (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The person this defrayal is owed to, or null — see this table's own doc comment.
  TextColumn get personId => text().nullable().references(OcptPeopleTable, #id)();

  /// What this defrayal is for.
  // The stored literal below must match `OcptBudgetAllowanceKind.travel.name` exactly, for the same
  // reason `budget_resources.groupKind`'s default does: an enum's `.name` getter isn't a
  // compile-time constant expression, so it can't be written as `Constant(…)`.
  TextColumn get kind => text()
      .map(const OcptBudgetAllowanceKindConverter())
      .withDefault(const Constant('travel'))();

  /// This defrayal's free-text wording, e.g. "Aller Paris — Le Havre".
  TextColumn get label => text().withDefault(const Constant(''))();

  /// The day this defrayal applies to, or the day a stay begins — null while nobody has said.
  DateTimeColumn get date => dateTime().nullable()();

  /// The day a stay ends, or null.
  ///
  /// Nullable **and normally null**: a journey and a meal happen on one day, and only a stay spans
  /// two. A row carrying an [endDate] reads as a span in the table; one carrying none reads as a
  /// single date, and neither is more complete than the other.
  DateTimeColumn get endDate => dateTime().nullable()();

  /// How many kilometres, nights or meals this defrayal covers, in thousandths — see this table's
  /// own doc comment.
  IntColumn get quantityMilli => integer().withDefault(const Constant(0))();

  /// What one kilometre, night or meal is paid back at, in thousandths of a cent — see this
  /// table's own doc comment.
  IntColumn get unitAmountMilliCents => integer().withDefault(const Constant(0))();

  /// Free-form notes about this defrayal.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
