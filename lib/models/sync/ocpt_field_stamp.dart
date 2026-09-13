// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

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
/// [value] is [tableName]'s row's own **raw SQL cell value** for [columnName] — read straight off a
/// `QueryRow`, never through a drift data class's `toJson()` — so it is always one of `int`,
/// `double`, `String`, `bool` (SQLite's own boolean-as-integer, already an `int` by the time it gets
/// here), `Uint8List` (a `BLOB` column) or `null`, whatever `columnName`'s declared Dart type or
/// `TypeConverter` says: a `TypeConverter`-backed enum column's raw value is the plain `String` its
/// converter's own `toSql` writes, and a `DateTime` column's is the ISO-8601 text
/// `storeDateTimeAsText` stores it as — carried opaquely, never re-interpreted as a `DateTime` or run
/// back through a converter, by anything in the changeset engine. This is what closes the gap the
/// Dart-side `toJson()` representation used to open: an enum instance or another non-JSON
/// `TypeConverter` result can never reach [toJson] in the first place, because [value] is never that
/// Dart-converted form to begin with.
class OcptFieldStamp extends Equatable {
  static const _tableNameKey = 'tableName';
  static const _rowIdKey = 'rowId';
  static const _columnNameKey = 'columnName';
  static const _valueKey = 'value';
  static const _versionKey = 'version';
  static const _deviceIdKey = 'deviceId';

  /// The JSON key a blob's base64 text is nested under inside [_valueKey] — see [_encodeValue] for
  /// why nesting it one level down is what makes the tag unambiguous.
  static const _blobKey = 'blobBase64';

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

  /// The raw SQL value [columnName] held when this stamp was generated — see this class's own doc
  /// comment for exactly what that means and why it is always JSON-encodable once [_encodeValue]
  /// has run on it.
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
    value: _decodeValue(json[_valueKey]),
    version: json[_versionKey] as int,
    deviceId: json[_deviceIdKey] as String,
  );

  /// Serialises this stamp to the JSON object an `OcptChangeset` carries it as.
  Map<String, dynamic> toJson() => {
    _tableNameKey: tableName,
    _rowIdKey: rowId,
    _columnNameKey: columnName,
    _valueKey: _encodeValue(value),
    _versionKey: version,
    _deviceIdKey: deviceId,
  };

  /// [value] turned into whatever `jsonEncode` can write: `int`, `double`, `String`, `bool` and
  /// `null` already are, and pass through untouched. A [Uint8List] is the one case that isn't — it
  /// is base64-encoded and nested one level under [_blobKey], which is what [_decodeValue] looks
  /// for to tell a blob apart from every other case: a raw SQL value is never itself a JSON object
  /// (a `TypeConverter`'s own `toSql` and every other column type in this schema write a bare
  /// scalar), so a single-key `{$_blobKey: ...}` object can never be mistaken for — or collide
  /// with — a legitimate `String` value, which `jsonEncode` always writes as a bare JSON string.
  static Object? _encodeValue(Object? value) => value is Uint8List ? {_blobKey: base64Encode(value)} : value;

  /// The inverse of [_encodeValue]: a JSON value shaped exactly like a tagged blob — a `Map`
  /// carrying [_blobKey] and nothing else — decodes back to the [Uint8List] it was base64-encoded
  /// from; every other JSON value (including a `Map` [_encodeValue] itself never produces) passes
  /// through unchanged.
  static Object? _decodeValue(Object? json) =>
      json is Map<String, dynamic> && json.length == 1 && json.containsKey(_blobKey)
          ? base64Decode(json[_blobKey] as String)
          : json;

  @override
  List<Object?> get props => [tableName, rowId, columnName, value, version, deviceId];

  @override
  String toString() =>
      'OcptFieldStamp(tableName: $tableName, rowId: $rowId, columnName: $columnName, '
      'value: $value, version: $version, deviceId: $deviceId)';
}
