// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';

/// Converts a [OcptAssetKind] to and from the text stored in the `assets.kind` column.
class OcptAssetKindConverter extends TypeConverter<OcptAssetKind, String> {
  /// Class constructor
  const OcptAssetKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptAssetKind fromSql(String fromDb) => OcptAssetKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptAssetKind value) => value.name;
}

/// A binary file the resources mode refers to — a headshot, a scouting photo, a signed release —
/// **by path, never by embedding it**: see `docs/adr/0013-binary-assets-referenced-by-path.md` for
/// the full argument. No byte of an image or a document ever enters the `.ocpt`; the app only reads
/// [path] to draw a thumbnail, and never copies, moves or writes the file it names.
///
/// [path] is an **absolute path on the machine that recorded it**. A `.ocpt` opened on another
/// machine, or after the referenced file was moved, resolves nothing — that is a normal state, not
/// an error, and the UI shows the reference with a "file not found" marker rather than treating the
/// absence as a failure to report.
///
/// Exactly one of [personId], [locationId], [elementId] is set, naming this asset's subject; which
/// one tells a reader what kind of thumbnail to attempt alongside [kind].
///
/// **Expect noise from `build_runner`.** Those three columns point back at tables that themselves
/// point here (`people.photoAssetId`, `locations.permitAssetId`, `elements.photoAssetId`), so the
/// schema holds a genuine foreign-key cycle. `drift_dev` logs an `Internal error while
/// deserializing … This is a bug in drift_dev!` for each one, then recovers and emits correct code:
/// a generation from a cold cache produces a database every test and every migration path passes
/// against. SQLite has no objection either — it only checks a foreign key at the write that would
/// violate it, never at `CREATE TABLE`, which is also what lets the migration create these tables in
/// any order. Do not try to break the cycle by dropping one side: an asset has to know its subject
/// for a location's fourteen scouting photos to be listable, and a person has to name *which* of
/// their assets is the headshot.
@DataClassName('OcptAssetRow')
class OcptAssetsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptAssetsTable}
  @override
  String get tableName => 'assets';

  /// The stable, unique id of this asset (a UUID).
  TextColumn get id => text()();

  /// What subject this asset illustrates or documents.
  TextColumn get kind => text().map(const OcptAssetKindConverter())();

  /// The absolute path of the referenced file on the machine that recorded it. See the class doc
  /// comment: nothing outside the service that resolves an asset may read this column directly, or
  /// the day the app stops storing bytes this way, every call site would have to change instead of
  /// just that service.
  TextColumn get path => text()();

  /// A user-facing label for this asset, free text.
  TextColumn get label => text().withDefault(const Constant(''))();

  /// The date and time at which this asset reference was added.
  DateTimeColumn get addedAt => dateTime()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// The person this asset belongs to, or null.
  TextColumn get personId => text().nullable().references(OcptPeopleTable, #id)();

  /// The location this asset belongs to, or null.
  TextColumn get locationId => text().nullable().references(OcptLocationsTable, #id)();

  /// The element this asset belongs to, or null.
  TextColumn get elementId => text().nullable().references(OcptElementsTable, #id)();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
