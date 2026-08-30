// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_winner.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sql_column_name.dart';
import 'package:open_cine_prod_tools/utils/ocpt_synchronised_tables.dart';

/// Applies an incoming [OcptChangeset] to a project's own file, per column: the **inbound** half of
/// `docs/plans/collaboration-and-sync.md`'s M3 changeset engine, and the one that actually makes two
/// replicas converge — `OcptChangesetService.pushLocalEdits` only ever reads a project, this is what
/// writes one back.
///
/// [applyChangeset] runs in one transaction against **`OcptOpenProjectModel.fileDatabase`**, never
/// `database`: a changeset arriving while the user previews an old version belongs to the working
/// copy, not to the read-only replica on screen (see that model's own doc comment). Because
/// `fileDatabase` is never the preview connection, `OcptProjectDatabase.refusesUserWrite` is never
/// consulted here at all — that guard exists for user edits mistakenly handed the preview database,
/// and an incoming merge is not a user edit in the first place.
///
/// Per `(tableName, rowId)` group of the incoming changeset, the winning columns — those whose
/// incoming `(version, deviceId)` beats the column's own local stamp, or which carry no local stamp
/// at all ([ocptIncomingStampWins]) — are overlaid, as raw SQL cell values, onto the current row's
/// own complete raw state (or `{}` for a row this replica has never seen) and written back whole: a
/// losing column keeps its current value and its current stamp untouched, exactly where it stood
/// before this changeset arrived.
///
/// `screenplays.fountainText` is, for this step, one column like any other: last-writer-wins,
/// exactly as every other column resolves. The three-way line merge against the nearest common
/// `screenplay_snapshots` row — the one column ADR 0010 actually asks for something else — is a
/// later step; the column simply is not special-cased here yet. `scenes` is never named by an
/// incoming changeset in the first place ([ocptSynchronisedTables] excludes it), so nothing here
/// ever writes to it.
class OcptMergeService {
  /// Class constructor
  const OcptMergeService();

  /// Applies every field stamp [changeset] carries to [fileDatabase], row group by row group, in
  /// one transaction with `PRAGMA defer_foreign_keys = ON` — a changeset can legitimately arrive in
  /// an order that violates a foreign key part way through (ADR 0010), exactly the situation
  /// `OcptProjectVersionsService.restoreVersion` already defers the same way.
  Future<void> applyChangeset({
    required OcptProjectDatabase fileDatabase,
    required OcptChangeset changeset,
  }) async {
    if (changeset.fieldStamps.isEmpty) {
      return;
    }

    final tablesByName = {
      for (final table in ocptSynchronisedTables(fileDatabase)) table.actualTableName: table,
    };

    final grouped = <(String tableName, String rowId), List<OcptFieldStamp>>{};
    for (final stamp in changeset.fieldStamps) {
      grouped.putIfAbsent((stamp.tableName, stamp.rowId), () => []).add(stamp);
    }

    await fileDatabase.transaction(() async {
      await fileDatabase.customStatement('PRAGMA defer_foreign_keys = ON');

      for (final MapEntry(key: (tableName, rowId), value: incomingStamps) in grouped.entries) {
        final table = tablesByName[tableName];
        if (table == null) {
          // Every stamp inside a changeset was itself built off `ocptSynchronisedTables`
          // (`OcptChangesetService.pushLocalEdits`), so this means the sender and this replica
          // disagree about which tables are synchronised — a protocol-level bug worth failing
          // loudly on rather than silently dropping the edit.
          appLogger().e("An incoming changeset names table '$tableName', unknown to this replica");
          throw StateError("Table '$tableName' is not part of the synchronised table set");
        }

        await _applyRowGroup(database: fileDatabase, table: table, rowId: rowId, incoming: incomingStamps);
      }
    });
  }

  /// Applies every incoming stamp of one `(tableName, rowId)` group: works out which of
  /// [incoming]'s columns win against [table]'s own local stamps for [rowId], overlays exactly
  /// those onto the row's current state, writes the whole row back, and advances
  /// `row_field_versions` for the columns that won.
  Future<void> _applyRowGroup({
    required OcptProjectDatabase database,
    required TableInfo<Table, Object?> table,
    required String rowId,
    required List<OcptFieldStamp> incoming,
  }) async {
    final localStamps = await _localStamps(
      database: database,
      tableName: table.actualTableName,
      rowId: rowId,
    );

    final winners = [
      for (final stamp in incoming)
        if (ocptIncomingStampWins(
          incomingVersion: stamp.version,
          incomingDeviceId: stamp.deviceId,
          localVersion: localStamps[stamp.columnName]?.version,
          localDeviceId: localStamps[stamp.columnName]?.deviceId,
        ))
          stamp,
    ];

    if (winners.isEmpty) {
      return;
    }

    final currentRow = await _readCurrentRow(database: database, table: table, rowId: rowId);
    final merged = currentRow == null ? <String, Object?>{} : Map<String, Object?>.of(currentRow);

    final columnsByDartName = {
      for (final column in table.$columns) ocptDartFieldName(column.name): column,
    };

    for (final winner in winners) {
      final column = columnsByDartName[winner.columnName];
      if (column == null) {
        // Every incoming stamp names a column of the very table it was generated from
        // (`OcptChangesetService.pushLocalEdits`), so this would mean the sender and this
        // replica's own schema have drifted apart — a bug worth failing loudly on rather than
        // silently dropping the edit.
        throw StateError(
          "An incoming changeset stamps column '${winner.columnName}' of '${table.actualTableName}', "
          "which no column of that table maps to",
        );
      }

      merged[column.name] = winner.value;
    }

    await _upsertWholeRow(database: database, table: table, merged: merged);

    await database.batch(
      (batch) => batch.insertAllOnConflictUpdate(database.ocptRowFieldVersionsTable, [
        for (final winner in winners)
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: table.actualTableName,
            rowId: rowId,
            columnName: winner.columnName,
            version: winner.version,
            deviceId: winner.deviceId,
          ),
      ]),
    );
  }

  /// Every local `row_field_versions` stamp already recorded for [tableName]'s row [rowId], keyed
  /// by its own `columnName` — what [_applyRowGroup] compares each incoming stamp against.
  Future<Map<String, OcptRowFieldVersionRow>> _localStamps({
    required OcptProjectDatabase database,
    required String tableName,
    required String rowId,
  }) async {
    final rows = await (database.select(
      database.ocptRowFieldVersionsTable,
    )..where((table) => table.targetTableName.equals(tableName) & table.rowId.equals(rowId))).get();

    return {for (final row in rows) row.columnName: row};
  }

  /// Writes [merged] — a complete row of [table], keyed by its columns' own SQL names, each value
  /// already the raw SQL cell value `OcptFieldStamp` itself carries (see its own doc comment) — back
  /// through a raw, parametrised `INSERT ... ON CONFLICT DO UPDATE`, naming every column by its own
  /// SQL name and its own primary key for the `ON CONFLICT` target: the generic upsert this merge
  /// needs for a table it only knows as a bare [TableInfo].
  ///
  /// A typed `Insertable`/`insertOnConflictUpdate` cannot do this generically: each generated table
  /// class overrides `validateIntegrity` (and `into()`'s own dispatch) against its **own** row type,
  /// fixed at build time, never the type this method was handed [table] as — so an `Insertable`
  /// built against the erased `TableInfo<Table, Object?>` this merge iterates over is rejected at
  /// runtime the moment drift's own generated code asks it for the concrete row type back.
  /// `GeneratedDatabase.customInsert` has no such row type to satisfy: it binds [Variable]s to `?`
  /// placeholders positionally and leaves interpreting them to SQLite itself, which is exactly the
  /// level this merge can stay generic at — and since every value is already the exact raw SQL
  /// primitive the column holds, a bare `Variable<Object>` is all a placeholder ever needs: drift's
  /// own `SqlTypes.mapToSqlVariable` dispatches on the value's own runtime type, not on a
  /// [Variable]'s static type argument, so an `int`, a `double`, a `String` (an enum's `toSql`
  /// output and a `storeDateTimeAsText` timestamp alike), a `Uint8List` or `null` all bind exactly
  /// as they already stand — with no per-`DriftSqlType` dispatch of this merge's own to keep in
  /// step with the schema.
  Future<void> _upsertWholeRow({
    required OcptProjectDatabase database,
    required TableInfo<Table, Object?> table,
    required Map<String, Object?> merged,
  }) async {
    final columns = table.$columns;
    final variables = [for (final column in columns) Variable<Object>(merged[column.name])];

    final columnNames = [for (final column in columns) '"${column.name}"'];
    final primaryKeyNames = table.$primaryKey.map((column) => column.name).toSet();
    final updateAssignments = [
      for (final column in columns)
        if (!primaryKeyNames.contains(column.name)) '"${column.name}" = excluded."${column.name}"',
    ];

    final conflictAction = updateAssignments.isEmpty
        ? 'DO NOTHING'
        : 'DO UPDATE SET ${updateAssignments.join(', ')}';

    await database.customInsert(
      'INSERT INTO "${table.actualTableName}" (${columnNames.join(', ')}) '
      'VALUES (${columns.map((_) => '?').join(', ')}) '
      'ON CONFLICT (${primaryKeyNames.map((name) => '"$name"').join(', ')}) $conflictAction',
      variables: variables,
      updates: {table},
    );
  }

  /// [table]'s current row named [rowId], as its own raw SQL cell values keyed by SQL column name
  /// (see `OcptChangesetService`'s own reader for why this reads raw rather than through a drift
  /// data class's `toJson()`), or `null` when this replica has never seen that row before — unlike
  /// `OcptChangesetService`'s own reader, a missing row is the ordinary case here, not a bug: it is
  /// exactly what a brand-new row inserted on another replica looks like on this one, the first
  /// time its changeset arrives.
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

    return row?.data;
  }
}
