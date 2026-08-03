// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';

/// Converts a [OcptHalfDay] to and from the text stored in the `person_unavailabilities.halfDay`
/// column.
class OcptHalfDayConverter extends TypeConverter<OcptHalfDay, String> {
  /// Class constructor
  const OcptHalfDayConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptHalfDay fromSql(String fromDb) => OcptHalfDay.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptHalfDay value) => value.name;
}

/// A date a person is known to be unavailable, with a reason.
///
/// Nothing in this step reads this table yet — the schedule mode is what will cross it against the
/// shooting days it plans — but capturing it as people are entered is worth doing from the start,
/// rather than asking a user to re-enter every actor's known conflicts once scheduling exists.
///
/// No `sortKey` column here: unlike `person_skills` and `person_positions`, this is an unordered
/// set of dates rather than a list the user reorders.
@DataClassName('OcptPersonUnavailabilityRow')
class OcptPersonUnavailabilitiesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptPersonUnavailabilitiesTable}
  @override
  String get tableName => 'person_unavailabilities';

  /// The stable, unique id of this unavailability (a UUID).
  TextColumn get id => text()();

  /// The person who is unavailable.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The date this unavailability covers.
  DateTimeColumn get date => dateTime()();

  /// How much of [date] this unavailability covers.
  TextColumn get halfDay => text().map(const OcptHalfDayConverter())();

  /// Why this person is unavailable, free text.
  TextColumn get reason => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
