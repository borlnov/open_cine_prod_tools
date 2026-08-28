// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_entries_table.dart';
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
/// Exactly one of [personId], [locationId], [elementId] or [budgetEntryId] is set, naming this
/// asset's subject; which one tells a reader what kind of thumbnail to attempt alongside [kind].
/// [budgetEntryId] is the odd one of the four in one respect: the row it names is not a subject
/// with a photo of its own, but the journal movement this document evidences — a receipt asset's
/// "subject" is the entry it is the voucher *for*.
///
/// **Expect noise from `build_runner`.** The first three of those columns point back at tables that
/// themselves point here (`people.photoAssetId`, `locations.permitAssetId`,
/// `elements.photoAssetId`), so the schema holds a genuine foreign-key cycle. `drift_dev` logs an
/// `Internal error while deserializing … This is a bug in drift_dev!` for each one, then recovers
/// and emits correct code: a generation from a cold cache produces a database every test and every
/// migration path passes against. SQLite has no objection either — it only checks a foreign key at
/// the write that would violate it, never at `CREATE TABLE`, which is also what lets the migration
/// create these tables in any order. Do not try to break the cycle by dropping one side: an asset
/// has to know its subject for a location's fourteen scouting photos to be listable, and a person
/// has to name *which* of their assets is the headshot. [budgetEntryId] closes no cycle of its
/// own — `budget_entries` never references `assets` back — but the same `CREATE TABLE`-time
/// leniency is what lets it exist regardless of which of the two tables the migration or `onCreate`
/// happens to create first.
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

  /// The journal entry this asset is the voucher for, or null. → [OcptBudgetEntriesTable]
  ///
  /// Set on an `OcptAssetKind.receipt` asset, and left null on every other kind — see the class doc
  /// comment for why this is different in nature from [personId]/[locationId]/[elementId] even
  /// though it fills the same "exactly one of four" slot.
  TextColumn get budgetEntryId => text().nullable().references(OcptBudgetEntriesTable, #id)();

  /// The date this asset's document becomes valid, or null. Meaningful for a document with a
  /// validity window — a filming permit runs from a date to a date — and meaningless for a photo,
  /// which carries it as null forever.
  ///
  /// **Nullable, and deliberately so: null means "nobody has recorded one", never "valid from the
  /// start of time".** This is about the *document* the asset stands for, never about the
  /// referenced file on disk — the app never opens it (`docs/adr/0013-binary-assets-referenced-by-
  /// path.md`) and has no way to read a date off it. The permit alert that reads this pair (a
  /// coming milestone) fires only when both a window is recorded and the day being checked falls
  /// outside it, and stays silent otherwise: the same reading `people.maxDailyPresenceMinutes` and
  /// a location declaring no availability window already have — absence of data is not a claim
  /// that nothing is required.
  DateTimeColumn get validFrom => dateTime().nullable()();

  /// The date this asset's document stops being valid, or null. See [validFrom].
  DateTimeColumn get validUntil => dateTime().nullable()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
