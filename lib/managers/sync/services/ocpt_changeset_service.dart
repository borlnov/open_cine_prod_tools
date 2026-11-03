// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_sql_column_name.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_synchronised_tables.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_merge_failure.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:uuid/uuid.dart';

/// Turn a replica's own un-pushed local edits into a changeset and append it to a relay
/// ([pushLocalEdits]), and apply every changeset a relay holds that this replica hasn't seen yet
/// ([pullAndApply]) — the outbound and inbound halves of the changeset engine
/// (`docs/architecture/sync.md`). [syncOnce] is the two run back to back, which is what makes two
/// replicas pointed at the same [OcptRemoteStorage] converge.
///
/// A "relay" here is any [OcptRemoteStorage] this replica is paired with, named by a `relayId` —
/// the same identifier `sync_relay_cursors.relayId` keys a replica's own delivery state by, since a
/// device can be paired with more than one relay over its lifetime.
class OcptChangesetService extends AbsOcptService {
  /// The per-column merge every incoming changeset is applied through.
  final OcptMergeService mergeService;

  /// Class constructor
  const OcptChangesetService({required super.logger, required this.mergeService});

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await mergeService.initLifeCycle();
  }

  /// Generate the un-pushed local edits of [database] for [deviceId] and append them to [storage]
  /// as one changeset, then advance [relayId]'s own `outboxHighWaterMark` so the same
  /// edit is never sent to it twice.
  ///
  /// "Un-pushed" means every `row_field_versions` stamp this device itself wrote
  /// (`deviceId == deviceId`) at a version higher than what [relayId] has already been sent — a
  /// stamp a merge wrote for a change that arrived from another device is never re-emitted, which
  /// is exactly why `OcptRowStampService`'s version is a device-monotone clock rather than a
  /// per-column one (see its own doc comment). When there is nothing to push, this does nothing:
  /// no changeset is appended and [relayId]'s cursor is left untouched.
  ///
  /// A [storage] that cannot take the changeset is answered as its own status (and detail), with
  /// the cursor left untouched too; only a failure of [database] itself still throws. A stamp
  /// naming a table, a column or a row that does not exist is refused the same way: `unreachable`,
  /// its `extraInfo` an [OcptSyncMergeFailure] for the sync session to go offline on.
  ///
  /// Every stamped column is read back off its own table's **current** row — tombstones included,
  /// so a delete is pushed like any other edit — grouped by `(tableName, rowId)` first so a row
  /// edited on several columns in the same or different transactions still costs one row read. A
  /// row's own id is never parsed back out of anything: it is exactly what the stamp itself already
  /// carries under `row_field_versions.rowId`, `ocptCompositeRowStampKey`'s own encoding for the
  /// one composite case (`shot_characters`'s `{shotId, roleId}`) included, and what
  /// `_readCurrentRow` matches a table's own primary key against through
  /// `ocptCompositeRowStampKeySqlExpression` rather than splitting it back apart.
  @useResult
  Future<StatusWithExtraInfo<OcptRemoteStorageStatus>> pushLocalEdits({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
    required String deviceId,
  }) async {
    final highWaterMark = await _outboxHighWaterMark(database: database, relayId: relayId);

    final stamps =
        await (database.select(database.ocptRowFieldVersionsTable)..where(
              (table) =>
                  table.deviceId.equals(deviceId) & table.version.isBiggerThanValue(highWaterMark),
            ))
            .get();

    if (stamps.isEmpty) {
      return const StatusWithExtraInfo(status: OcptRemoteStorageStatus.ok);
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
        return _refusal(
          "row_field_versions names table '$tableName', which is not part of the "
          "synchronised table set",
        );
      }

      final row = await _readCurrentRow(database: database, table: table, rowId: rowId);
      if (row == null) {
        return _refusal(
          "No row '$rowId' found in '${table.actualTableName}' to build a changeset from",
        );
      }

      final columnsByDartName = {
        for (final column in table.$columns) ocptDartFieldName(column.name): column,
      };

      for (final stamp in rowStamps) {
        final column = columnsByDartName[stamp.columnName];
        if (column == null) {
          // Every stamp names a column of the very table it was written alongside
          // (`OcptRowStampService`), so this would mean a stamp and its own table's columns have
          // drifted apart — a bug worth failing loudly on rather than silently dropping the edit.
          return _refusal(
            "row_field_versions stamps column '${stamp.columnName}' of '$tableName', which no "
            "column of that table maps to",
          );
        }

        fieldStamps.add(
          OcptFieldStamp(
            tableName: tableName,
            rowId: rowId,
            columnName: stamp.columnName,
            value: row[column.name],
            version: stamp.version,
            deviceId: stamp.deviceId,
          ),
        );
      }
    }

    final maxVersion = stamps.map((stamp) => stamp.version).reduce((a, b) => a > b ? a : b);

    final appended = await storage.append(
      OcptChangesetEnvelope(
        changesetId: const Uuid().v4(),
        originDeviceId: deviceId,
        lamport: maxVersion,
        createdAt: DateTime.now(),
        payload: OcptChangeset(fieldStamps: fieldStamps).encode(),
      ),
    );
    if (!appended.status.isSuccess) {
      // Nothing was appended, so the high-water mark stays where it was and the same edits are
      // pushed again by the next run.
      return StatusWithExtraInfo(status: appended.status, extraInfo: appended.extraInfo);
    }

    await _advanceOutboxHighWaterMark(
      database: database,
      relayId: relayId,
      highWaterMark: maxVersion,
    );

    return const StatusWithExtraInfo(status: OcptRemoteStorageStatus.ok);
  }

  /// Apply every changeset [relayId] holds that this replica hasn't read yet to [database]'s own
  /// file, and advance [relayId]'s `lastAppliedSequence` past every one of them.
  ///
  /// This is a replica catching up: it reads [relayId]'s current `sync_relay_cursors.
  /// lastAppliedSequence` (`0` when this replica has never pulled from it before), asks [storage]
  /// for everything appended since, and hands each one's decoded [OcptChangeset] to
  /// [mergeService] in turn — a replica that was offline across several changesets catches up in
  /// this one call, not one per changeset. When [storage] has nothing new, this does nothing: no
  /// merge runs and [relayId]'s cursor is left untouched.
  ///
  /// Returns every [OcptScreenplayMergeConflict] raised while applying any of those changesets, in
  /// the order they were applied — empty when nothing conflicted, which is the ordinary case — or
  /// the status of a [storage] that could not be read, with nothing applied. A changeset the merge
  /// refuses answers `unreachable` with the merge's own detail and the cursor is not advanced, so
  /// the next pull reads the batch again; the changesets applied before it stay applied. A failure
  /// of the database itself is not answered but raised, for the caller to settle.
  @useResult
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>>
  pullAndApply({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
  }) async {
    final cursor = await _lastAppliedSequence(database: database, relayId: relayId);
    final read = await storage.readSince(cursor);
    final stored = read.value;
    if (!read.status.isSuccess || stored == null) {
      return ResultWithStatus(status: read.status, extraInfo: read.extraInfo);
    }
    if (stored.isEmpty) {
      return const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);
    }

    var highestSequence = cursor;
    final conflicts = <OcptScreenplayMergeConflict>[];
    for (final entry in stored) {
      final applied = await mergeService.applyChangeset(
        fileDatabase: database,
        changeset: OcptChangeset.decode(entry.envelope.payload),
      );
      final appliedConflicts = applied.value;
      if (applied.isError || appliedConflicts == null) {
        // The cursor stays where it was, so the next pull reads this changeset again.
        return ResultWithStatus(
          status: OcptRemoteStorageStatus.unreachable,
          extraInfo: applied.extraInfo,
        );
      }

      conflicts.addAll(appliedConflicts);
      if (entry.sequenceNumber > highestSequence) {
        highestSequence = entry.sequenceNumber;
      }
    }

    await _advanceLastAppliedSequence(
      database: database,
      relayId: relayId,
      sequence: highestSequence,
    );

    return ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: conflicts);
  }

  /// Run [pushLocalEdits] followed by [pullAndApply], against the very same [relayId]: what a
  /// replica
  /// runs to both publish what it changed and absorb what everyone else did, in one call. Returns
  /// whatever [pullAndApply] returns — [pushLocalEdits] never merges anything inbound, so it never
  /// raises a conflict of its own.
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>> syncOnce({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
    required String deviceId,
  }) async {
    final pushed = await pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );
    if (!pushed.status.isSuccess) {
      return ResultWithStatus(status: pushed.status, extraInfo: pushed.extraInfo);
    }

    return pullAndApply(database: database, storage: storage, relayId: relayId);
  }

  /// Count how many of [deviceId]'s own `row_field_versions` stamps against [database] have not
  /// been
  /// pushed to [relayId] yet — i.e. carry a version higher than [relayId]'s current
  /// `outboxHighWaterMark`.
  ///
  /// A read-only count, never a lookup [pushLocalEdits] itself needs: exactly the stamps that call
  /// would push on its very next run, without reading any of their rows back off their own
  /// tables — which is the part of [pushLocalEdits] this skips, and why this is cheap enough for a
  /// sync session's status to compute on every failed run. Behaviourally inert on its own: nothing
  /// about calling this changes [relayId]'s cursor or anything else in [database].
  Future<int> countUnpushedEdits({
    required OcptProjectDatabase database,
    required String relayId,
    required String deviceId,
  }) async {
    final highWaterMark = await _outboxHighWaterMark(database: database, relayId: relayId);

    final stamps =
        await (database.select(database.ocptRowFieldVersionsTable)..where(
              (table) =>
                  table.deviceId.equals(deviceId) & table.version.isBiggerThanValue(highWaterMark),
            ))
            .get();

    return stamps.length;
  }

  /// Get [relayId]'s current `outboxHighWaterMark` against [database], as [pushLocalEdits] itself
  /// would
  /// read it, wrapped as an [OcptSequenceNumber] — [OcptSequenceNumber.zero] when this replica has
  /// appended nothing to [relayId] yet.
  ///
  /// A read-only counterpart to [_outboxHighWaterMark], for a caller outside this service that
  /// needs the position a just-published changeset log stands at right now — the create-and-share
  /// orchestration reads this immediately after [pushLocalEdits] to know what a snapshot it
  /// publishes in the same breath should declare as its own [OcptSnapshotDescriptor.sequenceUpTo].
  /// Behaviourally inert on its own, exactly like [countUnpushedEdits]: nothing about calling this
  /// changes [relayId]'s cursor or anything else in [database].
  Future<OcptSequenceNumber> highestAppendedSequence({
    required OcptProjectDatabase database,
    required String relayId,
  }) async => OcptSequenceNumber(await _outboxHighWaterMark(database: database, relayId: relayId));

  /// Get [relayId]'s current `lastAppliedSequence` against [database], or [OcptSequenceNumber.zero]
  /// when this replica has never pulled anything from it yet.
  Future<OcptSequenceNumber> _lastAppliedSequence({
    required OcptProjectDatabase database,
    required String relayId,
  }) async {
    final row = await (database.select(
      database.ocptSyncRelayCursorsTable,
    )..where((table) => table.relayId.equals(relayId))).getSingleOrNull();

    return OcptSequenceNumber(row?.lastAppliedSequence ?? 0);
  }

  /// Upsert [relayId]'s `sync_relay_cursors` row so its `lastAppliedSequence` reads [sequence],
  /// leaving `outboxHighWaterMark` — the unrelated write-side cursor — untouched.
  Future<void> _advanceLastAppliedSequence({
    required OcptProjectDatabase database,
    required String relayId,
    required OcptSequenceNumber sequence,
  }) => database
      .into(database.ocptSyncRelayCursorsTable)
      .insertOnConflictUpdate(
        OcptSyncRelayCursorsTableCompanion.insert(
          relayId: relayId,
          lastAppliedSequence: Value(sequence.value),
        ),
      );

  /// Get [relayId]'s current `outboxHighWaterMark` against [database], or `0` when this replica has
  /// never pushed anything to it yet.
  Future<int> _outboxHighWaterMark({
    required OcptProjectDatabase database,
    required String relayId,
  }) async {
    final row = await (database.select(
      database.ocptSyncRelayCursorsTable,
    )..where((table) => table.relayId.equals(relayId))).getSingleOrNull();

    return row?.outboxHighWaterMark ?? 0;
  }

  /// Upsert [relayId]'s `sync_relay_cursors` row so its `outboxHighWaterMark` reads
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

  /// Get [table]'s current row named [rowId] out of [database], as its own raw SQL cell values
  /// keyed
  /// by SQL column name — tombstones included, no filter applied, and never run through a drift
  /// data class's `toJson()` (see `OcptFieldStamp`'s own doc comment for why) — by matching [rowId]
  /// against [table]'s own primary key through `ocptCompositeRowStampKeySqlExpression` rather than
  /// a typed, per-table query: this is what lets this service work over any [TableInfo]
  /// `ocptSynchronisedTables` hands it, with no hand-maintained per-table row lookup to keep in
  /// step with the schema.
  ///
  /// Answers null when no such row exists, which [pushLocalEdits] refuses.
  Future<Map<String, Object?>?> _readCurrentRow({
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
      logger.e(
        "row_field_versions stamps a row '$rowId' of '${table.actualTableName}' that no longer "
        "exists",
      );
      return null;
    }

    return row.data;
  }

  /// Answer the refusal of a push whose stamps and tables have drifted apart: the sync session
  /// quotes [message] when it goes offline, as it does for a changeset the merge refuses.
  StatusWithExtraInfo<OcptRemoteStorageStatus> _refusal(String message) => StatusWithExtraInfo(
    status: OcptRemoteStorageStatus.unreachable,
    extraInfo: OcptSyncMergeFailure(error: StateError(message), stackTrace: StackTrace.current),
  );

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await mergeService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
