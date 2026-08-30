// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_synchronised_tables.dart';
import 'package:uuid/uuid.dart';

/// Turns a replica's own un-pushed local edits into a changeset and appends it to a relay: the
/// **outbound** half of `docs/plans/collaboration-and-sync.md`'s M3 changeset engine. Applying an
/// incoming changeset — the inbound half — and the per-column and screenplay merges are later
/// steps; this service only ever reads the project, never writes to it.
///
/// A "relay" here is any [OcptRemoteStorage] this replica is paired with, named by a `relayId` —
/// the same identifier `sync_relay_cursors.relayId` keys a replica's own delivery state by, since a
/// device can be paired with more than one relay over its lifetime
/// (`docs/plans/collaboration-and-sync.md` §5.3).
class OcptChangesetService {
  /// Class constructor
  const OcptChangesetService();

  /// Generates the un-pushed local edits of [database] for [deviceId] and appends them to
  /// [storage] as one changeset, then advances [relayId]'s own `outboxHighWaterMark` so the same
  /// edit is never sent to it twice.
  ///
  /// "Un-pushed" means every `row_field_versions` stamp this device itself wrote
  /// (`deviceId == deviceId`) at a version higher than what [relayId] has already been sent — a
  /// stamp a merge wrote for a change that arrived from another device is never re-emitted, which
  /// is exactly why `OcptRowStampService`'s version is a device-monotone clock rather than a
  /// per-column one (see its own doc comment). When there is nothing to push, this does nothing:
  /// no changeset is appended and [relayId]'s cursor is left untouched.
  ///
  /// Every stamped column is read back off its own table's **current** row — tombstones included,
  /// so a delete is pushed like any other edit — grouped by `(tableName, rowId)` first so a row
  /// edited on several columns in the same or different transactions still costs one row read. A
  /// row's own id is never parsed back out of anything: it is exactly what the stamp itself already
  /// carries under `row_field_versions.rowId`, `ocptCompositeRowStampKey`'s own encoding for the one
  /// composite case (`shot_characters`'s `{shotId, characterName}`) included, and what
  /// `_readCurrentRow` matches a table's own primary key against through
  /// `ocptCompositeRowStampKeySqlExpression` rather than splitting it back apart.
  Future<void> pushLocalEdits({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
    required String deviceId,
  }) async {
    final highWaterMark = await _outboxHighWaterMark(database: database, relayId: relayId);

    final stamps = await (database.select(
      database.ocptRowFieldVersionsTable,
    )..where((table) => table.deviceId.equals(deviceId) & table.version.isBiggerThanValue(highWaterMark))).get();

    if (stamps.isEmpty) {
      return;
    }

    final tablesByName = {
      for (final table in ocptSynchronisedTables(database)) table.actualTableName: table,
    };

    final grouped = <(String tableName, String rowId), List<OcptRowFieldVersionRow>>{};
    for (final stamp in stamps) {
      grouped.putIfAbsent((stamp.targetTableName, stamp.rowId), () => []).add(stamp);
    }

    final fieldStamps = <OcptFieldStamp>[];
    for (final MapEntry(key: (tableName, rowId), value: rowStamps) in grouped.entries) {
      final table = tablesByName[tableName];
      if (table == null) {
        // Every stamp is written by `OcptRowStampService` alongside a write to the very table it
        // names, so this would mean the sidecar and the synchronised-table rule have drifted apart
        // — a bug worth failing loudly on rather than silently dropping an edit.
        throw StateError(
          "row_field_versions names table '$tableName', which is not part of the "
          "synchronised table set",
        );
      }

      final row = await _readCurrentRow(database: database, table: table, rowId: rowId);
      final json = (row as dynamic).toJson() as Map<String, dynamic>;

      for (final stamp in rowStamps) {
        fieldStamps.add(
          OcptFieldStamp(
            tableName: tableName,
            rowId: rowId,
            columnName: stamp.columnName,
            value: json[stamp.columnName],
            version: stamp.version,
            deviceId: stamp.deviceId,
          ),
        );
      }
    }

    final maxVersion = stamps.map((stamp) => stamp.version).reduce((a, b) => a > b ? a : b);

    await storage.append(
      OcptChangesetEnvelope(
        changesetId: const Uuid().v4(),
        originDeviceId: deviceId,
        lamport: maxVersion,
        createdAt: DateTime.now(),
        payload: OcptChangeset(fieldStamps: fieldStamps).encode(),
      ),
    );

    await _advanceOutboxHighWaterMark(database: database, relayId: relayId, highWaterMark: maxVersion);
  }

  /// [relayId]'s current `outboxHighWaterMark` against [database], or `0` when this replica has
  /// never pushed anything to it yet.
  Future<int> _outboxHighWaterMark({required OcptProjectDatabase database, required String relayId}) async {
    final row = await (database.select(
      database.ocptSyncRelayCursorsTable,
    )..where((table) => table.relayId.equals(relayId))).getSingleOrNull();

    return row?.outboxHighWaterMark ?? 0;
  }

  /// Upserts [relayId]'s `sync_relay_cursors` row so its `outboxHighWaterMark` reads
  /// [highWaterMark], leaving `lastAppliedSequence` — the unrelated read-side cursor — untouched.
  Future<void> _advanceOutboxHighWaterMark({
    required OcptProjectDatabase database,
    required String relayId,
    required int highWaterMark,
  }) => database
      .into(database.ocptSyncRelayCursorsTable)
      .insertOnConflictUpdate(
        OcptSyncRelayCursorsTableCompanion.insert(
          relayId: relayId,
          outboxHighWaterMark: Value(highWaterMark),
        ),
      );

  /// Reads [table]'s current row named [rowId] out of [database], raw — tombstones included, no
  /// filter applied — by matching [rowId] against [table]'s own primary key through
  /// `ocptCompositeRowStampKeySqlExpression` rather than a typed, per-table query: this is what
  /// lets this service work over any [TableInfo] `ocptSynchronisedTables` hands it, with no
  /// hand-maintained per-table row lookup to keep in step with the schema.
  Future<Object?> _readCurrentRow({
    required OcptProjectDatabase database,
    required TableInfo<Table, Object?> table,
    required String rowId,
  }) async {
    final primaryKeyColumns = table.$primaryKey.toList();
    final rowIdExpression = ocptCompositeRowStampKeySqlExpression(
      primaryKeyColumns.map((column) => '"${column.name}"'),
    );

    final row = await database
        .customSelect(
          'SELECT * FROM "${table.actualTableName}" WHERE $rowIdExpression = ?',
          variables: [Variable<String>(rowId)],
          readsFrom: {table},
        )
        .getSingleOrNull();

    if (row == null) {
      // No service ever deletes a synchronised row (CLAUDE.md): a tombstone is still a row, so a
      // stamped rowId with no matching row at all means the stamp and the table have drifted
      // apart — a bug worth surfacing rather than silently dropping the edit.
      appLogger().e(
        "row_field_versions stamps a row '$rowId' of '${table.actualTableName}' that no longer "
        "exists",
      );
      throw StateError("No row '$rowId' found in '${table.actualTableName}' to build a changeset from");
    }

    return table.mapFromRow(row);
  }
}
