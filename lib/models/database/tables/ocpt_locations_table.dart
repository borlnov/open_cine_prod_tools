// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';

/// Converts a [OcptPermitStatus] to and from the text stored in the `locations.permitStatus`
/// column.
class OcptPermitStatusConverter extends TypeConverter<OcptPermitStatus, String> {
  /// Class constructor
  const OcptPermitStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptPermitStatus fromSql(String fromDb) => OcptPermitStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptPermitStatus value) => value.name;
}

/// A filming location: an address, and everything that decides whether a day there is shootable.
///
/// [parkingNotes], [powerNotes], [facilitiesNotes] and [constraintsNotes] are not padding: they are
/// exactly the four things the mock-up's location sheet shows, alongside [contactNotes], and the
/// four things that decide whether a day is shootable — where the truck goes, what amperage exists,
/// whether there is a toilet, and what the neighbours will tolerate.
@DataClassName('OcptLocationRow')
class OcptLocationsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptLocationsTable}
  @override
  String get tableName => 'locations';

  /// The stable, unique id of this location (a UUID).
  TextColumn get id => text()();

  /// The location's display name.
  TextColumn get name => text()();

  /// Indexes `ocptCoveragePalette` (`lib/constants/ocpt_coverage_palette.dart`), so this location
  /// keeps one colour bar wherever it appears in the UI.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// The location's city, free text.
  TextColumn get city => text().withDefault(const Constant(''))();

  /// The location's postal address, free text.
  TextColumn get address => text().withDefault(const Constant(''))();

  /// The location's latitude, or null while it hasn't been pinned on a map.
  RealColumn get latitude => real().nullable()();

  /// The location's longitude, or null while it hasn't been pinned on a map.
  RealColumn get longitude => real().nullable()();

  /// The person to contact about this location, or null — the reference address book *does* list
  /// the owners of a location alongside the cast and crew, which is exactly why a location's contact
  /// is a link onto [OcptPeopleTable] rather than a name typed a second time.
  TextColumn get contactPersonId => text().nullable().references(OcptPeopleTable, #id)();

  /// Free-text notes about the contact (how to reach them, best times to call).
  TextColumn get contactNotes => text().withDefault(const Constant(''))();

  /// Where this location's filming permit stands.
  // The stored literal must match `OcptPermitStatus.toRequest.name` exactly, for the same reason
  // `shots.status`'s default does: an enum's `.name` getter isn't a compile-time constant
  // expression.
  TextColumn get permitStatus => text()
      .map(const OcptPermitStatusConverter())
      .withDefault(const Constant('toRequest'))();

  /// The permit's own reference/label as the issuing authority names it, free text.
  TextColumn get permitLabel => text().withDefault(const Constant(''))();

  /// The date [permitStatus] last changed (e.g. the date it was granted), or null.
  DateTimeColumn get permitDate => dateTime().nullable()();

  /// The signed/granted permit document, or null while there is none. → [OcptAssetsTable]
  TextColumn get permitAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// Where vehicles and the production truck can park, free text.
  TextColumn get parkingNotes => text().withDefault(const Constant(''))();

  /// What electrical power is available (amperage, outlet locations), free text.
  TextColumn get powerNotes => text().withDefault(const Constant(''))();

  /// Facilities available on site (toilets, running water, shelter), free text.
  TextColumn get facilitiesNotes => text().withDefault(const Constant(''))();

  /// Constraints on shooting here: noise limits, allowed hours, neighbour tolerance. Free text.
  TextColumn get constraintsNotes => text().withDefault(const Constant(''))();

  /// Free-form notes about this location.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
