// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/converters/ocpt_day_part_slot_converter.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

/// Converts an [OcptLocationAvailabilityKind] to and from the text stored in the
/// `location_availabilities.kind` column.
class OcptLocationAvailabilityKindConverter
    extends TypeConverter<OcptLocationAvailabilityKind, String> {
  /// Class constructor
  const OcptLocationAvailabilityKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptLocationAvailabilityKind fromSql(String fromDb) =>
      OcptLocationAvailabilityKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptLocationAvailabilityKind value) => value.name;
}

/// A window during which a location may be shot in, with what qualifies it.
///
/// The mirror image of `person_unavailabilities`: a person is entered by what they *cannot* do, a
/// location by what it *allows* — an owner lends their café on given days, a town hall grants a
/// street for given hours. Both are the raw material the schedule mode crosses against the shooting
/// days it plans, and neither is read by anything yet; capturing it while the location is being
/// entered is what saves re-entering it once scheduling exists.
///
/// A row is a **range of dates** ([startDate] → [endDate], the same day for a one-day window),
/// narrowed to the [weekdays] of that range it actually covers, crossed with a [slot] within each
/// covered day. "Every Monday and Tuesday of March, 08:00 to 19:00" is therefore one row rather
/// than nine, and a single date is one row with every weekday allowed. Several rows may cover the
/// same date: this is a set of windows, not a calendar with one entry per day.
///
/// [kind] is what an annotation is *for*. A window the production may use freely and one it may use
/// under a condition ("no noise after 22:00", "no vehicle in the courtyard") are both availabilities
/// — refusing the second would lose the day entirely — so the condition rides on the window it
/// applies to, in [note], and [kind] is what lets the schedule mode colour and warn rather than
/// merely print it.
///
/// No `sortKey` here, for `person_unavailabilities`' own reason: an unordered set of windows rather
/// than a list the user reorders (the UI shows them in date order).
@DataClassName('OcptLocationAvailabilityRow')
class OcptLocationAvailabilitiesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptLocationAvailabilitiesTable}
  @override
  String get tableName => 'location_availabilities';

  /// The stable, unique id of this availability (a UUID).
  TextColumn get id => text()();

  /// The location this window is about.
  TextColumn get locationId => text().references(OcptLocationsTable, #id)();

  /// The first date this window covers.
  DateTimeColumn get startDate => dateTime()();

  /// The last date this window covers, inclusive — the same value as [startDate] for a single day,
  /// never earlier than it.
  DateTimeColumn get endDate => dateTime()();

  /// Which days of the week, inside the range, this window actually covers, as the bit mask
  /// `ocptWeekdayMask*` reads and writes (see `lib/utils/ocpt_weekday_mask.dart`).
  ///
  /// A mask rather than a table of its own: seven booleans that are only ever read together, and a
  /// weekday has no identity to reference. The default is [ocptEveryWeekdayMask] — a range says
  /// every day of itself until the user says otherwise — and the mask is never empty, a window
  /// covering no day at all saying nothing.
  IntColumn get weekdays => integer().withDefault(const Constant(ocptEveryWeekdayMask))();

  /// Which part of each covered day this window takes.
  // The stored literal below must match `OcptDayPartSlot.fullDay.name` exactly, for the reason
  // `person_unavailabilities.slot`'s default spells out.
  TextColumn get slot =>
      text().map(const OcptDayPartSlotConverter()).withDefault(const Constant('fullDay'))();

  /// The start of the window, in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom]. Minutes rather than a timestamp, for the reason
  /// `person_unavailabilities.startMinute` spells out.
  IntColumn get startMinute => integer().nullable()();

  /// The end of the window, in minutes from midnight, or null unless [slot] is
  /// [OcptDayPartSlot.custom]. See [startMinute].
  IntColumn get endMinute => integer().nullable()();

  /// Whether the location may be used freely over this window, or only under the condition [note]
  /// spells out.
  // The stored literal must match `OcptLocationAvailabilityKind.available.name`, as above.
  TextColumn get kind => text()
      .map(const OcptLocationAvailabilityKindConverter())
      .withDefault(const Constant('available'))();

  /// What qualifies this window, free multi-line text: the condition attached to it, the way in,
  /// who to call — whatever the person who negotiated it needs to hand over.
  TextColumn get note => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
