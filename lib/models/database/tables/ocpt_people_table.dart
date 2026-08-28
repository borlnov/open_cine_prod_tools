// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_mileage_rates_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';

/// Converts a [OcptImageRightsStatus] to and from the text stored in the
/// `people.imageRightsStatus` column.
class OcptImageRightsStatusConverter extends TypeConverter<OcptImageRightsStatus, String> {
  /// Class constructor
  const OcptImageRightsStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptImageRightsStatus fromSql(String fromDb) => OcptImageRightsStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptImageRightsStatus value) => value.name;
}

/// The address book: one row per human involved in the production, whatever they do on it.
///
/// A person is never a copy — the cast and crew are **links onto this table**
/// (`roles.personId`, `person_positions.personId`), never a name typed a second time, because the
/// same person routinely wears more than one hat (the director who is also on set decoration, the
/// actor who holds the script on days they don't play).
@DataClassName('OcptPersonRow')
class OcptPeopleTable extends Table {
  /// {@macro open_cine_prod_tools.OcptPeopleTable}
  @override
  String get tableName => 'people';

  /// The stable, unique id of this person (a UUID).
  TextColumn get id => text()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  ///
  /// Deleting a person is an **erasure** (decision 6 of the plan this table ships under): the
  /// tombstone is written here and the personal columns below are blanked in the same write, so the
  /// file stops holding a phone number, a home address or an allergy for someone who asked to be
  /// removed. See `ocpt_local_erasures_table.dart` for how that erasure survives a version restore.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The person's first name, free text.
  ///
  /// The display name and the initials shown in the UI are **derived** from [firstName]/[lastName]
  /// at read time, never stored: a third column that could drift out of sync with the two it was
  /// computed from would only ever be a bug waiting to happen.
  TextColumn get firstName => text().withDefault(const Constant(''))();

  /// The person's last name, free text. See [firstName].
  TextColumn get lastName => text().withDefault(const Constant(''))();

  /// The person's email address, free text.
  TextColumn get email => text().withDefault(const Constant(''))();

  /// The person's phone number, free text.
  TextColumn get phone => text().withDefault(const Constant(''))();

  /// {@template open_cine_prod_tools.postalAddress}
  /// The street part of the postal address, free text.
  ///
  /// An address is stored as six columns rather than one free-text block — this one,
  /// [addressLine2], [postalCode], [city], [region] and [country] — which is the field set every
  /// international address form settles on. A call sheet prints them in the order the destination
  /// country uses (the postal code before the city in France, after it in the United Kingdom), an
  /// export gives each its own column, and the postal code is the one part of an address worth
  /// sorting or searching on. None of that is possible once the whole address is one string.
  ///
  /// Every column is free text, and none is required: half an address is a normal state in a
  /// production's address book, and refusing it would only mean the user keeps it somewhere else.
  /// {@endtemplate}
  TextColumn get addressLine1 => text().withDefault(const Constant(''))();

  /// The second line of the postal address (building, floor, care-of), free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get addressLine2 => text().withDefault(const Constant(''))();

  /// The postal code, free text — never a number: leading zeros are meaningful and half the world
  /// writes letters in theirs.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get postalCode => text().withDefault(const Constant(''))();

  /// The person's city, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get city => text().withDefault(const Constant(''))();

  /// The region, state, province or county, free text — empty in the countries that have no such
  /// level in an address.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get region => text().withDefault(const Constant(''))();

  /// The country, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get country => text().withDefault(const Constant(''))();

  /// Indexes `ocptCoveragePalette` (`lib/constants/ocpt_coverage_palette.dart`), exactly as a
  /// shot's colour does, so this person keeps one avatar colour wherever they appear in the UI.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// The person's date of birth, or null if unknown.
  ///
  /// Age and minor status are **derived** at read time from this, never stored: a stored "15 ans"
  /// would be wrong within a year, and this is the one piece of data that actually changes on its
  /// own as time passes rather than through an edit.
  DateTimeColumn get birthDate => dateTime().nullable()();

  /// The legal framing to observe when this person is a minor: working hours, guardian presence on
  /// set, the reference to a DDETS authorisation. Free text.
  TextColumn get minorNotes => text().withDefault(const Constant(''))();

  /// The longest presence this person may have on one shooting day, in minutes.
  ///
  /// A duration rather than an instant — the same reason `person_unavailabilities.startMinute` is —
  /// so it survives being compared against the span a day's own slots and blocks resolve to, itself
  /// never taken modulo anything.
  ///
  /// **Nullable, and deliberately so: null means "nobody has recorded one", never "no limit is
  /// imposed".** This is not restricted to minors — an adult under a medical restriction is the same
  /// fact — but it lives beside [minorNotes] because that is where the constraint is thought about
  /// on the sheet. The schedule mode's alert that reads it (a coming milestone) fires only when this
  /// column is filled *and* exceeded, and stays silent otherwise: the app must never advance a
  /// figure — a legal maximum, say — that nobody here validated.
  IntColumn get maxDailyPresenceMinutes => integer().nullable()();

  /// Whether this person can travel to set on their own.
  ///
  /// **Tri-state on purpose**: null means "not asked yet", which is the reference address book's
  /// own third value beside yes and no — a boolean with a `false` default would silently claim
  /// "not autonomous" for everyone nobody has asked.
  BoolColumn get isTransportAutonomous => boolean().nullable()();

  /// Where this person stays during the shoot (e.g. "Chez Camille"), free text.
  TextColumn get accommodationNotes => text().withDefault(const Constant(''))();

  /// Travel logistics for this person: the birth date and the loyalty card number a train booking
  /// needs, arrival/departure details. Free text, deliberately not modelled field by field.
  TextColumn get travelNotes => text().withDefault(const Constant(''))();

  /// Dietary requirements for catering, free text.
  TextColumn get dietaryNotes => text().withDefault(const Constant(''))();

  /// Allergies, free text: both reference address books track them beside diet, and a catering line
  /// on a call sheet depends on them.
  TextColumn get allergies => text().withDefault(const Constant(''))();

  /// The person's height, free text.
  ///
  /// {@template open_cine_prod_tools.hmcMeasurement}
  /// **Never a number**: real production lists mix `38`, `M`, `Haut 38`, `178`, `1m78` and
  /// `5'10"`, so a numeric column would have to pick a unit nobody agreed to and would reject half
  /// of what a costume designer actually writes down.
  /// {@endtemplate}
  TextColumn get measurementHeight => text().withDefault(const Constant(''))();

  /// The person's chest measurement.
  ///
  /// {@macro open_cine_prod_tools.hmcMeasurement}
  TextColumn get measurementChest => text().withDefault(const Constant(''))();

  /// The person's waist measurement.
  ///
  /// {@macro open_cine_prod_tools.hmcMeasurement}
  TextColumn get measurementWaist => text().withDefault(const Constant(''))();

  /// The person's hip measurement.
  ///
  /// {@macro open_cine_prod_tools.hmcMeasurement}
  TextColumn get measurementHips => text().withDefault(const Constant(''))();

  /// Top/upper body clothing size.
  ///
  /// {@macro open_cine_prod_tools.hmcMeasurement}
  TextColumn get sizeTop => text().withDefault(const Constant(''))();

  /// Bottom clothing size.
  ///
  /// {@macro open_cine_prod_tools.hmcMeasurement}
  TextColumn get sizeBottom => text().withDefault(const Constant(''))();

  /// Shoe size.
  ///
  /// {@macro open_cine_prod_tools.hmcMeasurement}
  TextColumn get sizeShoes => text().withDefault(const Constant(''))();

  /// Hair/make-up/costume continuity notes for this person, free multi-line text — shown on the
  /// same sheet card as the measurements and sizes above, which is where a fitting reads them.
  TextColumn get hmcNotes => text().withDefault(const Constant(''))();

  /// Where this person's image rights release stands.
  // The stored literal below must match `OcptImageRightsStatus.notApplicable.name` exactly, for the
  // same reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time
  // constant expression, so it can't be written as `Constant(OcptImageRightsStatus.notApplicable)`.
  TextColumn get imageRightsStatus => text()
      .map(const OcptImageRightsStatusConverter())
      .withDefault(const Constant('notApplicable'))();

  /// The date [imageRightsStatus] was reached — the day the release was drafted while it is
  /// `generated`, the day it came back signed once it is `signed` — or null while nobody has
  /// recorded one.
  ///
  /// One column rather than one per status: a release is drafted once and signed once, and the
  /// only date a call sheet or a rights audit ever asks for is the one attached to where it stands
  /// now. The sheet labels it after the current status rather than showing a bare `Date`.
  DateTimeColumn get imageRightsDate => dateTime().nullable()();

  /// The signed release document, or null while there is none. → [OcptAssetsTable]
  TextColumn get imageRightsAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// This person's photo, or null while there is none. → [OcptAssetsTable]
  TextColumn get photoAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// Free-form notes about this person.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// This person's **one-way** commute to set, in **thousandths of a kilometre** — `1,484 km` is
  /// `1484000` — for the same reason `budget_lines.quantityMilli` is: a distance the catering-and-
  /// travel pass crosses with the presence grid has to be said exactly.
  ///
  /// **Nullable, and deliberately so: null means "nobody has recorded a distance", never "this
  /// person travels nothing"** — the same reading [maxDailyPresenceMinutes] already carries.
  IntColumn get commuteKmMilli => integer().nullable()();

  /// Which of the project's own `budget_mileage_rates` applies to this person, or null.
  /// → [OcptBudgetMileageRatesTable]
  ///
  /// Nullable because somebody who does not drive claims nothing.
  TextColumn get mileageRateId => text().nullable().references(OcptBudgetMileageRatesTable, #id)();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
