// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/src/ocpt_sync_protocol_format_error.dart';

/// Small, shared JSON-decoding helpers every wire type's `fromJson` reads a required field
/// through, so a missing or mistyped key always fails the same way: an
/// [OcptSyncMalformedDataError] naming the key, never a raw [TypeError] leaking out of a cast.
///
/// Kept private to the package: a caller of `ocpt_sync_protocol` decodes a whole wire value
/// through its `fromJson` constructor, never a single field through this class.
abstract final class OcptSyncWireJson {
  /// Reads the [String] at [key] in [json], throwing [OcptSyncMalformedDataError] when it is
  /// missing or not a string.
  static String string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw OcptSyncMalformedDataError("'$key' is missing or isn't a string");
    }
    return value;
  }

  /// Reads the [int] at [key] in [json], throwing [OcptSyncMalformedDataError] when it is missing
  /// or not an integer.
  static int integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw OcptSyncMalformedDataError("'$key' is missing or isn't an integer");
    }
    return value;
  }

  /// Reads the ISO 8601 [DateTime] at [key] in [json], throwing [OcptSyncMalformedDataError] when
  /// it is missing or not a valid timestamp.
  static DateTime dateTime(Map<String, dynamic> json, String key) {
    final raw = string(json, key);
    return DateTime.tryParse(raw) ??
        (throw OcptSyncMalformedDataError("'$key' isn't an ISO 8601 timestamp"));
  }

  /// Reads the JSON object at [key] in [json], throwing [OcptSyncMalformedDataError] when it is
  /// missing or not an object.
  static Map<String, dynamic> object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw OcptSyncMalformedDataError("'$key' is missing or isn't a JSON object");
    }
    return value;
  }
}
