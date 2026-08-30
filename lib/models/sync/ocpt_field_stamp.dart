// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One column's own version stamp, as carried inside an `OcptChangeset`'s `fieldStamps`: one
/// synchronised table's row, one of its columns, the value that column held when this stamp was
/// generated, and the `row_field_versions` version/device pair that write was recorded under.
///
/// This is the app's own domain shape for what `docs/adr/0010-sync-ready-data-model-prerequisites.md`
/// calls a per-column version stamp — deliberately kept out of `packages/ocpt_sync_protocol`, which
/// stays domain-blind and never learns a table or column name
/// (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`). An `OcptChangeset` made of
/// these is what a device serialises into an `OcptChangesetEnvelope.payload`, opaque to that
/// protocol package and meaningful only here.
///
/// [value] is [tableName]'s row, read back through its drift data class's own `toJson()` under
/// [columnName]'s Dart name — whatever a `TypeConverter` or a `DateTime` column turns into there is
/// exactly what round-trips back through the matching `fromJson()` a future merge reads it with, so
/// this class never has to know a column's Dart type to carry its value faithfully.
class OcptFieldStamp extends Equatable {
  static const _tableNameKey = 'tableName';
  static const _rowIdKey = 'rowId';
  static const _columnNameKey = 'columnName';
  static const _valueKey = 'value';
  static const _versionKey = 'version';
  static const _deviceIdKey = 'deviceId';

  /// The synchronised table this stamp's column belongs to, spelled as
  /// `row_field_versions.table_name` — and as a drift `TableInfo.actualTableName` — spells it.
  final String tableName;

  /// The stamped row's primary key, rendered as text exactly as
  /// `docs/adr/0010-sync-ready-data-model-prerequisites.md` and `ocptCompositeRowStampKey` encode
  /// it: a single-column key as is, a composite one (`shot_characters`'s `{shotId, characterName}`
  /// today) joined by that same function.
  final String rowId;

  /// The stamped column's own Dart name — the same string `row_field_versions.columnName` and a
  /// drift data class's `toJson()` key both spell it as.
  final String columnName;

  /// The value [columnName] held when this stamp was generated, as [tableName]'s row's own
  /// `toJson()` renders that column: opaque to this class beyond being JSON-encodable.
  final Object? value;

  /// The device-local Lamport counter this column was written at — `row_field_versions.version`.
  final int version;

  /// The device that wrote this stamp — `row_field_versions.deviceId`.
  final String deviceId;

  /// Creates a field stamp.
  const OcptFieldStamp({
    required this.tableName,
    required this.rowId,
    required this.columnName,
    required this.value,
    required this.version,
    required this.deviceId,
  });

  /// Parses a field stamp from the JSON object [toJson] writes.
  factory OcptFieldStamp.fromJson(Map<String, dynamic> json) => OcptFieldStamp(
    tableName: json[_tableNameKey] as String,
    rowId: json[_rowIdKey] as String,
    columnName: json[_columnNameKey] as String,
    value: json[_valueKey],
    version: json[_versionKey] as int,
    deviceId: json[_deviceIdKey] as String,
  );

  /// Serialises this stamp to the JSON object an `OcptChangeset` carries it as.
  Map<String, dynamic> toJson() => {
    _tableNameKey: tableName,
    _rowIdKey: rowId,
    _columnNameKey: columnName,
    _valueKey: value,
    _versionKey: version,
    _deviceIdKey: deviceId,
  };

  @override
  List<Object?> get props => [tableName, rowId, columnName, value, version, deviceId];

  @override
  String toString() =>
      'OcptFieldStamp(tableName: $tableName, rowId: $rowId, columnName: $columnName, '
      'value: $value, version: $version, deviceId: $deviceId)';
}
