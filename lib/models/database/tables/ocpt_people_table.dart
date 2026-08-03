// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
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

  /// The person's postal address, free text.
  TextColumn get address => text().withDefault(const Constant(''))();

  /// The person's city, free text.
  TextColumn get city => text().withDefault(const Constant(''))();

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

  /// Top/upper body clothing size, free text — real production lists mix `38`, `M` and `Haut 38`,
  /// so this is never a constrained size scale.
  TextColumn get sizeTop => text().withDefault(const Constant(''))();

  /// Bottom clothing size, free text. See [sizeTop].
  TextColumn get sizeBottom => text().withDefault(const Constant(''))();

  /// Shoe size, free text. See [sizeTop].
  TextColumn get sizeShoes => text().withDefault(const Constant(''))();

  /// Hair/make-up/costume continuity notes for this person, free multi-line text.
  TextColumn get hmcNotes => text().withDefault(const Constant(''))();

  /// Where this person's image rights release stands.
  // The stored literal below must match `OcptImageRightsStatus.notApplicable.name` exactly, for the
  // same reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time
  // constant expression, so it can't be written as `Constant(OcptImageRightsStatus.notApplicable)`.
  TextColumn get imageRightsStatus => text()
      .map(const OcptImageRightsStatusConverter())
      .withDefault(const Constant('notApplicable'))();

  /// The date [imageRightsStatus] last changed (e.g. the date the release was signed), or null.
  DateTimeColumn get imageRightsDate => dateTime().nullable()();

  /// The signed release document, or null while there is none. → [OcptAssetsTable]
  TextColumn get imageRightsAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// This person's photo, or null while there is none. → [OcptAssetsTable]
  TextColumn get photoAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// Free-form notes about this person.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
