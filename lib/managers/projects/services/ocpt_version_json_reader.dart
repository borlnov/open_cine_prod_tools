// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';

/// The field readers behind `OcptProjectVersionCodec.decode`, and the one place that records
/// what went wrong while it walks a payload.
///
/// The readers sit inside the expressions that build every row, so none of them can return early on
/// a bad field: each records the first failure and answers a neutral value, so the walk can finish.
/// The recorded failure is a single static, which is safe only because `decode` is synchronous and
/// calls [reset] on entry and on exit: nothing can interleave two decodes.
abstract final class OcptVersionJsonReader {
  /// The first thing a field reader found wrong while `OcptProjectVersionCodec.decode` walks a
  /// payload, or null while all is well.
  ///
  /// The readers below sit inside the expressions that build every row, so none of them can return
  /// early on a bad field: each records the first failure here and answers a neutral value (an
  /// empty string, zero, `false`, the first value of an enum…) so the walk can finish, and
  /// `OcptProjectVersionCodec.decode` reads this once it has, throwing the whole payload away if it
  /// is set. `OcptProjectVersionCodec.decode` is synchronous and resets this on entry and on exit,
  /// so one decode never sees another's.
  static String? _firstReadFailure;

  /// Get the first thing a field reader found wrong since the last [reset], or null while all is
  /// well.
  static String? get firstReadFailure => _firstReadFailure;

  /// Forget any recorded failure: `OcptProjectVersionCodec.decode` calls it on entry and on exit,
  /// so one decode never sees another's.
  static void reset() => _firstReadFailure = null;

  /// Record [reason] as the failure of the payload being decoded, unless one is already, and answer
  /// [neutral].
  static T unreadable<T>(String reason, T neutral) {
    _firstReadFailure ??= reason;

    return neutral;
  }

  /// Get the list of JSON objects stored at [key] in [json].
  static List<Map<String, dynamic>> readRows(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) {
      return unreadable("'$key' isn't a list", const []);
    }

    return [
      for (final element in value)
        if (element is Map<String, dynamic>)
          element
        else
          unreadable("an element of '$key' isn't a JSON object", const <String, dynamic>{}),
    ];
  }

  /// Get the JSON object stored at [key] in [json].
  static Map<String, dynamic> readObject(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      return unreadable("'$key' isn't a JSON object", const <String, dynamic>{});
    }

    return value;
  }

  /// Get the non-null string stored at [key] in [json].
  static String readString(Map<String, dynamic> json, String key) =>
      readNullableString(json, key) ?? unreadable("'$key' is missing", "");

  /// Get the string stored at [key] in [json], or null when the column it mirrors was null.
  static String? readNullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! String) {
      return unreadable("'$key' isn't a string", null);
    }

    return value;
  }

  /// Get the non-null integer stored at [key] in [json].
  static int readInt(Map<String, dynamic> json, String key) =>
      readNullableInt(json, key) ?? unreadable("'$key' is missing", 0);

  /// Get the integer stored at [key] in [json], or null when the column it mirrors was null.
  static int? readNullableInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! int) {
      return unreadable("'$key' isn't an integer", null);
    }

    return value;
  }

  /// Get the non-null boolean stored at [key] in [json].
  static bool readBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      return unreadable("'$key' isn't a boolean", false);
    }

    return value;
  }

  /// Get the non-null boolean stored at [key] in [json], or `false` when [key] is altogether absent
  /// —
  /// for a non-nullable column added mid schema-version-4 development cycle whose own SQL default
  /// is `false` ([OcptVersionJsonProductionKeys.isHiddenKey]): an older format-4 payload written
  /// before the column existed reads back at that very default instead of failing, the same
  /// courtesy [readNullableEnum] and [readNullableDouble] already give a *nullable* mid-cycle
  /// addition (see [OcptVersionJsonProductionKeys.setElementShapeKey]'s own doc comment). Still
  /// unreadable when [key] is present but isn't a boolean.
  static bool readBoolWithFalseDefault(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      return false;
    }
    return readBool(json, key);
  }

  /// Get the boolean stored at [key] in [json], or null when the column it mirrors was null — the
  /// tri-state `people.isTransportAutonomous` is the one column of the schema that needs this.
  static bool? readNullableBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! bool) {
      return unreadable("'$key' isn't a boolean", null);
    }

    return value;
  }

  /// Get the non-null number stored at [key] in [json], as a double.
  ///
  /// A whole margin written as `1` by an older build (or by a hand-edited file) reads back as an
  /// `int`, so this accepts any [num] rather than only what `jsonEncode` writes for a double.
  static double readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      return unreadable<double>("'$key' isn't a number", 0);
    }

    return value.toDouble();
  }

  /// Get the number stored at [key] in [json], as a double, or null when the column it mirrors was
  /// null — `locations.latitude`/`longitude` before a location has been pinned on a map.
  static double? readNullableDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! num) {
      return unreadable("'$key' isn't a number", null);
    }

    return value.toDouble();
  }

  /// Get the non-null date and time stored at [key] in [json], as an ISO 8601 string.
  static DateTime readDateTime(Map<String, dynamic> json, String key) =>
      DateTime.tryParse(readString(json, key)) ??
      unreadable("'$key' isn't an ISO 8601 date", DateTime.fromMillisecondsSinceEpoch(0));

  /// Get the date and time stored at [key] in [json], as an ISO 8601 string, or null when the
  /// column
  /// it mirrors was null.
  static DateTime? readNullableDateTime(Map<String, dynamic> json, String key) {
    final value = readNullableString(json, key);
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value) ?? unreadable("'$key' isn't an ISO 8601 date", null);
  }

  /// Get the non-null enum value stored at [key] in [json], looked up by name in [valuesByName].
  static T readEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    Map<String, T> valuesByName,
  ) =>
      readNullableEnum(json, key, valuesByName) ??
      unreadable("'$key' is missing", valuesByName.values.first);

  /// Get the enum value stored at [key] in [json], or null when the column it mirrors was null.
  static T? readNullableEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    Map<String, T> valuesByName,
  ) {
    final name = readNullableString(json, key);
    if (name == null) {
      return null;
    }

    return valuesByName[name] ?? unreadable("'$key' holds the unknown value '$name'", null);
  }
}
