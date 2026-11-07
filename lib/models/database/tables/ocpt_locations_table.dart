// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/converters/ocpt_permit_status_converter.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';

/// A filming location: an address, and everything that decides whether a day there is shootable.
///
/// The six address columns are the same ones `people` carries, and for the same reasons — see
/// `OcptPeopleTable.addressLine1`'s own doc comment. An address is one shape wherever it appears
/// in the app, and a location's is the one printed at the top of a call sheet.
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

  /// Get the stable, unique id of this location (a UUID).
  TextColumn get id => text()();

  /// Get the location's display name.
  TextColumn get name => text()();

  /// Index `ocptCoveragePalette` (`lib/constants/ocpt_coverage_palette.dart`), so this location
  /// keeps one colour bar wherever it appears in the UI.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// Get the street part of the location's postal address, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get addressLine1 => text().withDefault(const Constant(''))();

  /// Get the second line of the location's postal address (building, floor, gate), free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get addressLine2 => text().withDefault(const Constant(''))();

  /// Get the location's postal code, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get postalCode => text().withDefault(const Constant(''))();

  /// Get the location's city, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get city => text().withDefault(const Constant(''))();

  /// Get the location's region, state, province or county, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get region => text().withDefault(const Constant(''))();

  /// Get the location's country, free text.
  ///
  /// {@macro open_cine_prod_tools.postalAddress}
  TextColumn get country => text().withDefault(const Constant(''))();

  /// Get the location's latitude, or null while it hasn't been pinned on a map.
  RealColumn get latitude => real().nullable()();

  /// Get the location's longitude, or null while it hasn't been pinned on a map.
  RealColumn get longitude => real().nullable()();

  /// Get the person to contact about this location, or null — the reference address book *does*
  /// list
  /// the owners of a location alongside the cast and crew, which is exactly why a location's
  /// contact is a link onto [OcptPeopleTable] rather than a name typed a second time.
  TextColumn get contactPersonId => text().nullable().references(OcptPeopleTable, #id)();

  /// Get the free-text notes about the contact (how to reach them, best times to call).
  TextColumn get contactNotes => text().withDefault(const Constant(''))();

  /// Tell where this location's filming permit stands.
  // The stored literal must match `OcptPermitStatus.toRequest.name` exactly, for the same reason
  // `shots.status`'s default does: an enum's `.name` getter isn't a compile-time constant
  // expression.
  TextColumn get permitStatus =>
      text().map(const OcptPermitStatusConverter()).withDefault(const Constant('toRequest'))();

  /// Get the permit's own reference/label as the issuing authority names it, free text.
  TextColumn get permitLabel => text().withDefault(const Constant(''))();

  /// Get the date [permitStatus] last changed (e.g. the date it was granted), or null.
  DateTimeColumn get permitDate => dateTime().nullable()();

  /// Get the signed/granted permit document, or null while there is none. → [OcptAssetsTable]
  TextColumn get permitAssetId => text().nullable().references(OcptAssetsTable, #id)();

  /// Tell where vehicles and the production truck can park, free text.
  TextColumn get parkingNotes => text().withDefault(const Constant(''))();

  /// Get what electrical power is available (amperage, outlet locations), free text.
  TextColumn get powerNotes => text().withDefault(const Constant(''))();

  /// Get the facilities available on site (toilets, running water, shelter), free text.
  TextColumn get facilitiesNotes => text().withDefault(const Constant(''))();

  /// Get the constraints on shooting here: noise limits, allowed hours, neighbour tolerance. Free
  /// text.
  TextColumn get constraintsNotes => text().withDefault(const Constant(''))();

  /// Get free-form notes about this location.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
