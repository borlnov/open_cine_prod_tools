// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_unavailability_slot.dart';

/// Converts a [OcptUnavailabilitySlot] to and from the text stored in the
/// `person_unavailabilities.slot` column.
class OcptUnavailabilitySlotConverter extends TypeConverter<OcptUnavailabilitySlot, String> {
  /// Class constructor
  const OcptUnavailabilitySlotConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptUnavailabilitySlot fromSql(String fromDb) => OcptUnavailabilitySlot.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptUnavailabilitySlot value) => value.name;
}

/// A stretch of time a person is known to be unavailable, with a reason.
///
/// A row is a **range of dates** ([startDate] → [endDate], the same day for a one-day conflict)
/// crossed with a [slot] within each of them: a week away is one row rather than seven, and
/// "unavailable from 14:00 to 17:30" is one row rather than an approximation. Several rows may
/// cover the same date, which is how two windows in one day are said — this is a set of
/// constraints, not a calendar with one entry per day.
///
/// Nothing in this step reads this table yet — the schedule mode is what will cross it against the
/// shooting days it plans — but capturing it as people are entered is worth doing from the start,
/// rather than asking a user to re-enter every actor's known conflicts once scheduling exists.
///
/// No `sortKey` column here: unlike `person_skills` and `person_positions`, this is an unordered
/// set of constraints rather than a list the user reorders (the UI shows them in date order).
@DataClassName('OcptPersonUnavailabilityRow')
class OcptPersonUnavailabilitiesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptPersonUnavailabilitiesTable}
  @override
  String get tableName => 'person_unavailabilities';

  /// The stable, unique id of this unavailability (a UUID).
  TextColumn get id => text()();

  /// The person who is unavailable.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The first date this unavailability covers.
  DateTimeColumn get startDate => dateTime()();

  /// The last date this unavailability covers, inclusive — the same value as [startDate] for a
  /// single day, never earlier than it.
  DateTimeColumn get endDate => dateTime()();

  /// Which part of each covered day this unavailability takes.
  // The stored literal below must match `OcptUnavailabilitySlot.fullDay.name` exactly, for the
  // same reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time
  // constant expression, so it can't be written as `Constant(OcptUnavailabilitySlot.fullDay)`.
  TextColumn get slot => text()
      .map(const OcptUnavailabilitySlotConverter())
      .withDefault(const Constant('fullDay'))();

  /// The start of the window, in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  ///
  /// Minutes rather than a `DateTime`, because this is a time of day repeated over every date of
  /// the range rather than one instant: a stored timestamp would carry a date that contradicts
  /// [startDate] the moment the range moves.
  IntColumn get startMinute => integer().nullable()();

  /// The end of the window, in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom]. See [startMinute].
  IntColumn get endMinute => integer().nullable()();

  /// Why this person is unavailable, free multi-line text.
  TextColumn get reason => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
