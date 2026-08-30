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
/// at all ([ocptIncomingStampWins]) — are overlaid onto the current row's own complete state (its
/// `toJson()` map, or `{}` for a row this replica has never seen) and written back whole: a losing
/// column keeps its current value and its current stamp untouched, exactly where it stood before
/// this changeset arrived.
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
    final merged = currentRow == null ? <String, dynamic>{} : Map<String, dynamic>.of((currentRow as dynamic).toJson() as Map<String, dynamic>);

    for (final winner in winners) {
      merged[winner.columnName] = winner.value;
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

  /// Writes [merged] — a complete row of [table], keyed by its columns' own Dart/JSON field names —
  /// back through a raw, parametrised `INSERT ... ON CONFLICT DO UPDATE`, naming every column by its
  /// own SQL name and its own primary key for the `ON CONFLICT` target: the generic upsert this
  /// merge needs for a table it only knows as a bare [TableInfo].
  ///
  /// A typed `Insertable`/`insertOnConflictUpdate` cannot do this generically: each generated table
  /// class overrides `validateIntegrity` (and `into()`'s own dispatch) against its **own** row type,
  /// fixed at build time, never the type this method was handed [table] as — so an `Insertable`
  /// built against the erased `TableInfo<Table, Object?>` this merge iterates over is rejected at
  /// runtime the moment drift's own generated code asks it for the concrete row type back.
  /// `GeneratedDatabase.customInsert` has no such row type to satisfy: it binds [Variable]s to `?`
  /// placeholders positionally and leaves interpreting them to SQLite itself, which is exactly the
  /// level this merge can stay generic at.
  Future<void> _upsertWholeRow({
    required OcptProjectDatabase database,
    required TableInfo<Table, Object?> table,
    required Map<String, dynamic> merged,
  }) async {
    final columns = table.$columns;
    final variables = [
      for (final column in columns) _expressionOf(column, merged[ocptDartFieldName(column.name)]),
    ];

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

  /// [table]'s current row named [rowId], mapped through its own generated data class, or `null`
  /// when this replica has never seen that row before — unlike
  /// `OcptChangesetService`'s own reader, a missing row is the ordinary case here, not a bug: it is
  /// exactly what a brand-new row inserted on another replica looks like on this one, the first
  /// time its changeset arrives.
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

    return row == null ? null : table.mapFromRow(row);
  }

  /// The [Variable] [column]'s own generated `toColumns()` would have written for [jsonValue] — the
  /// same shape a drift data class's `toJson()` produces for that column ([OcptFieldStamp]'s own doc
  /// comment) — turned back into a properly and concretely typed [Variable]: `DateTime` unwraps a
  /// JSON-serializer's millisecond timestamp back into a real `DateTime` (an ISO 8601 string is read
  /// as one too, since `ValueSerializer.defaults` itself accepts either) and a `BLOB` unwraps a JSON
  /// array back into `Uint8List`, so it is [Variable]'s own binding for [column]'s declared SQL type
  /// — not a hand-rolled guess at the database's raw on-disk representation — that actually reaches
  /// SQLite. A column carrying a `TypeConverter` (`GeneratedColumnWithTypeConverter`) is converted
  /// back to its SQL representation through that same converter's own `toSql` first, so this needs
  /// no per-table registry to stay generic.
  Variable<Object> _expressionOf(GeneratedColumn<Object> column, Object? jsonValue) {
    if (column is GeneratedColumnWithTypeConverter) {
      return _variableOf(column, jsonValue == null ? null : column.converter.toSql(jsonValue));
    }

    if (jsonValue != null && column.type == DriftSqlType.dateTime) {
      return _variableOf(
        column,
        jsonValue is int ? DateTime.fromMillisecondsSinceEpoch(jsonValue) : DateTime.parse(jsonValue.toString()),
      );
    }

    if (jsonValue != null && column.type == DriftSqlType.blob) {
      return _variableOf(column, Uint8List.fromList((jsonValue as List<dynamic>).cast<int>()));
    }

    return _variableOf(column, jsonValue);
  }

  /// A [Variable] of exactly [column]'s own declared `DriftSqlType` wrapping [value] — the one
  /// place this service names every `DriftSqlType` this schema uses, so that every [Variable] it
  /// ever builds carries a concrete, `DriftSqlType.forType`-resolvable type argument rather than the
  /// untyped `Object` a JSON value itself arrives as.
  Variable<Object> _variableOf(GeneratedColumn<Object> column, Object? value) {
    final type = column.type;

    if (type == DriftSqlType.string) {
      return Variable<String>(value as String?);
    }
    if (type == DriftSqlType.int) {
      return Variable<int>(value as int?);
    }
    if (type == DriftSqlType.bool) {
      return Variable<bool>(value as bool?);
    }
    if (type == DriftSqlType.double) {
      return Variable<double>((value as num?)?.toDouble());
    }
    if (type == DriftSqlType.dateTime) {
      return Variable<DateTime>(value as DateTime?);
    }
    if (type == DriftSqlType.blob) {
      return Variable<Uint8List>(value as Uint8List?);
    }
    if (type == DriftSqlType.bigInt) {
      return Variable<BigInt>(value == null ? null : BigInt.parse(value.toString()));
    }

    // `DriftSqlType.any` backs a STRICT-table `ANY` column, which no table of this schema declares.
    throw StateError("No synchronised column of this schema is expected to carry SQL type '$type'");
  }
}
