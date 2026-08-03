// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// The per-column version stamps a merge resolves conflicts with: one row per (row, column) of a
/// synchronised table.
///
/// This sidecar is what carries the **entire** merge granularity of the project
/// (`docs/adr/0010-sync-ready-data-model-prerequisites.md`), which is why no synchronised table
/// gains a version column of its own: the director editing a shot's `framing` and the assistant
/// director setting that same shot's `shootingDay` touch one row, and a stamp per row rather than
/// per column would drop one of the two edits.
///
/// Schema version 3 creates it. The one thing writing to it so far is
/// `OcptProjectVersionsService.restoreVersion`, which stamps every column it puts back — a restore
/// that left the stamps behind would be undone by the next merge — and the changeset engine
/// (`docs/plans/collaboration-and-sync.md`, M3) is what will fill it for every other edit. Whoever
/// writes here writes in the same transaction as the row being stamped, or the two drift apart
/// silently.
///
/// [rowId] holds the stamped row's primary key rendered as text. Every synchronised table this
/// project has keys its rows by a single text column except `shot_characters`, whose key is
/// `{shotId, characterName}`; a composite key is written through `ocptCompositeRowStampKey`, the
/// single encoding of such a key in the app — and the one whoever parses it back must read it
/// with.
@DataClassName('OcptRowFieldVersionRow')
class OcptRowFieldVersionsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptRowFieldVersionsTable}
  @override
  String get tableName => 'row_field_versions';

  /// The name of the table the stamped row lives in.
  ///
  /// Named apart from its SQL column because `tableName` is already how a drift table declares its
  /// own name, right above.
  TextColumn get targetTableName => text().named('table_name')();

  /// The primary key of the stamped row, rendered as text. See the class doc comment.
  TextColumn get rowId => text()();

  /// The name of the stamped column, as the Dart side of the schema spells it.
  TextColumn get columnName => text()();

  /// The version this column was last written at: a merge keeps the higher of two, and falls back
  /// to [deviceId] to break a tie.
  IntColumn get version => integer()();

  /// The `OcptPropertiesManager.deviceId` of the replica that wrote that version.
  TextColumn get deviceId => text()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {targetTableName, rowId, columnName};
}
