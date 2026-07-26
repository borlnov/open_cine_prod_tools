// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// Converts a [OcptSnapshotReason] to and from the text stored in the
/// `screenplay_snapshots.reason` column.
class OcptSnapshotReasonConverter extends TypeConverter<OcptSnapshotReason, String> {
  /// Class constructor
  const OcptSnapshotReasonConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptSnapshotReason fromSql(String fromDb) => OcptSnapshotReason.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptSnapshotReason value) => value.name;
}

/// Safety copies of a screenplay's full text, taken before risky operations so a user can
/// recover from an unwanted edit, a crash, or a bad export.
///
/// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
@DataClassName('OcptScreenplaySnapshotRow')
class OcptScreenplaySnapshotsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptScreenplaySnapshotsTable}
  @override
  String get tableName => 'screenplay_snapshots';

  /// The unique id of this snapshot (a UUID).
  TextColumn get id => text()();

  /// The screenplay this snapshot was taken from.
  TextColumn get screenplayId => text().references(OcptScreenplaysTable, #id)();

  /// The date and time at which the snapshot was taken.
  DateTimeColumn get createdAt => dateTime()();

  /// Why this snapshot was taken.
  TextColumn get reason => text().map(const OcptSnapshotReasonConverter())();

  /// The full Fountain source text captured by this snapshot.
  TextColumn get fountainText => text()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
