// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/converters/ocpt_snapshot_reason_converter.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';

/// Safety copies of a screenplay's full text, taken before risky operations so a user can
/// recover from an unwanted edit, a crash, or a bad export.
///
/// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
@DataClassName('OcptScreenplaySnapshotRow')
class OcptScreenplaySnapshotsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptScreenplaySnapshotsTable}
  @override
  String get tableName => 'screenplay_snapshots';

  /// Get the unique id of this snapshot (a UUID).
  TextColumn get id => text()();

  /// Get the screenplay this snapshot was taken from.
  TextColumn get screenplayId => text().references(OcptScreenplaysTable, #id)();

  /// Get the date and time at which the snapshot was taken.
  DateTimeColumn get createdAt => dateTime()();

  /// Tell why this snapshot was taken.
  TextColumn get reason => text().map(const OcptSnapshotReasonConverter())();

  /// Get the full Fountain source text captured by this snapshot, or the empty string once the
  /// snapshot has been pruned (see [isDeleted]).
  TextColumn get fountainText => text()();

  /// {@macro open_cine_prod_tools.isDeleted}
  ///
  /// A snapshot is tombstoned when `OcptScreenplayService` prunes it past the rolling cap, and its
  /// [fountainText] is cleared in the same write: pruning exists to bound the project file's size,
  /// which a tombstone still carrying a whole screenplay would defeat entirely. A tombstoned
  /// snapshot is a marker that the row is gone, nothing more.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
