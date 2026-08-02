// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// The named, permanent checkpoints of a whole project: the production history a user creates on
/// purpose, browses read-only and can come back to.
///
/// {@template open_cine_prod_tools.OcptProjectVersionsTable.versusSnapshots}
/// **A version is not a snapshot.** `screenplay_snapshots` is a rolling, invisible safety net the
/// app fills by itself (project open, save, before an export or an import), holding one
/// screenplay's text, pruned past 30 entries. A version is created by the user with a name and a
/// note, covers the **whole project** (screenplays, scene index, shot list and scenario coverage),
/// is listed in the workspace's `Versions` dock tab, and lives until the user deletes it. The two
/// coexist and neither replaces the other.
/// {@endtemplate}
///
/// **This table is local and is never synchronised.** It carries no `isDeleted` tombstone, no
/// `sortKey` and no `row_field_versions` stamps, unlike every table of
/// `docs/adr/0010-sync-ready-data-model-prerequisites.md`'s synchronised set: a version is one
/// person's working history of their own replica, and its [payload] is hundreds of kilobytes that
/// would dominate the sync traffic for no collaborative gain. A "delete" here is therefore a real
/// `delete()`, the only one left in the app — do not copy this precedent onto a table that *is*
/// synchronised. Sharing a version with someone else is what exporting the project file is for.
@DataClassName('OcptProjectVersionRow')
class OcptProjectVersionsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptProjectVersionsTable}
  @override
  String get tableName => 'project_versions';

  /// The stable, unique id of this version (a UUID).
  TextColumn get id => text()();

  /// The user-facing name of this version, e.g. `v4 — Shot list seq. 1 to 3`.
  TextColumn get name => text()();

  /// The user's free-text description of this version; empty when they wrote none.
  TextColumn get note => text().withDefault(const Constant(''))();

  /// The date and time at which the user created this version.
  ///
  /// The database stores date times as text (`DriftDatabaseOptions.storeDateTimeAsText`), so this
  /// keeps its sub-second precision: two versions created within the same second still order
  /// correctly in the list, which is ordered by this column alone.
  DateTimeColumn get createdAt => dateTime()();

  /// The version of Open Cine Prod Tools that created this version.
  TextColumn get appVersion => text()();

  /// The format [payload] is written in, **independent of the database's own schema version**: a
  /// payload outlives the app build that wrote it, and `OcptProjectVersionCodec` upgrades any older
  /// format it knows on decode rather than only rejecting what it doesn't.
  IntColumn get payloadFormat => integer()();

  /// The serialized state of the whole project at the moment this version was created, as the JSON
  /// text `OcptProjectVersionCodec` writes and is the only thing to read.
  TextColumn get payload => text()();

  /// The counters shown on this version's card (its page count, how many sequences were broken
  /// down), as JSON.
  ///
  /// They are computed **once**, when the version is created, and stored here: drawing the list
  /// must never mean deserializing every payload.
  TextColumn get summaryJson => text()();

  /// The `OcptPropertiesManager.deviceId` of the replica that created this version.
  ///
  /// Recorded for provenance, **never shown**: the app has no accounts and no identities, and a
  /// device id names a machine's copy of the app rather than a person. Nothing reads this column
  /// yet; it exists from the start because adding it later would cost a [payloadFormat] migration
  /// on every version already stored in users' files.
  TextColumn get createdByDeviceId => text()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
