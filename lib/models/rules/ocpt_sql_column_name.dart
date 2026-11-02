// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Get the Dart field name a drift table's own code generator derives [sqlColumnName] from, when no
/// column declares `.named(...)` to override it: the inverse of the `snake_case` conversion drift
/// itself applies to a column getter's name.
///
/// `OcptMergeService`'s whole-row reconstruction is the one caller: it holds a JSON map keyed by
/// Dart field names (a row's own `toJson()`, and `row_field_versions.columnName` — see
/// `OcptFieldStamp`'s own doc comment) and has to write it back through `GeneratedColumn`s, which
/// only ever carry their SQL name. So a synchronised column that declares `.named(...)` has to pin
/// its JSON key to what this returns for that name: the three `accountId` columns are stored as
/// `poste_id` and keep the JSON key `posteId` through `@JsonKey`.
String ocptDartFieldName(String sqlColumnName) {
  final words = sqlColumnName.split('_');

  return words.first + words.skip(1).map(_capitalise).join();
}

/// Get [word] with its first letter upper-cased, or [word] itself when empty — which a column name
/// with no double underscore never produces, kept only so this never throws on one that did.
String _capitalise(String word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
