// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The Dart field name a drift table's own code generator derives [sqlColumnName] from, when no
/// column declares `.named(...)` to override it: the inverse of the `snake_case` conversion drift
/// itself applies to a column getter's name.
///
/// `OcptMergeService`'s whole-row reconstruction is the one caller: it holds a JSON map keyed by
/// Dart field names (a row's own `toJson()`, and `row_field_versions.columnName` — see
/// `OcptFieldStamp`'s own doc comment) and has to write it back through `GeneratedColumn`s, which
/// only ever carry their SQL name. Every synchronised table's column is auto-named this way today —
/// `row_field_versions.targetTableName` is the one column in the whole schema that overrides it
/// with `.named(...)`, and it sits on the one table the changeset engine never reads or writes a
/// row of (`ocptSynchronisedTables` excludes it for carrying no `isDeleted`) — so this conversion is
/// exact for every column this ever runs against, not a heuristic guess.
String ocptDartFieldName(String sqlColumnName) {
  final words = sqlColumnName.split('_');

  return words.first + words.skip(1).map(_capitalise).join();
}

/// [word] with its first letter upper-cased, or [word] itself when empty — which a column name
/// with no double underscore never produces, kept only so this never throws on one that did.
String _capitalise(String word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
