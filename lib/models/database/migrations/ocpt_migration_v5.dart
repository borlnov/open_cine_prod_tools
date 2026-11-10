// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// Run schema version 5's own `onUpgrade` step, called from [OcptProjectDatabase.migration] for a
/// file opened below it: renames the `labelText` stamps of `storyboard_annotations` to `text`.
///
/// Until `OcptStoryboardAnnotationsTable.labelText` carried a `@JsonKey('text')`, the row stamp
/// service named the stamps of an annotation after the row class's `toJson` keys, hence
/// `labelText`, while the changeset push and the merge look a stamp's column up by the Dart
/// spelling of its SQL name, `text`. A project holding such a stamp refused every push and stayed
/// offline for good. This step mends the stamps already written; the key keeps the new ones right.
///
/// **No table is reshaped**: only `row_field_versions` rows change, and the table's primary key is
/// `{table_name, row_id, column_name}`, so the rename has to settle the case where a `text` stamp
/// of the same row already exists. The higher stamp is kept, by version and then by device id, the
/// order the merge itself resolves a conflict with; the other one is dropped.
Future<void> ocptMigrateToSchemaV5({
  required Migrator migrator,
  required OcptProjectDatabase database,
}) async {
  const where = "table_name = 'storyboard_annotations'";

  // A `labelText` stamp that does not beat the `text` stamp of its own row is dropped.
  await database.customStatement(
    "DELETE FROM row_field_versions AS old WHERE $where AND column_name = 'labelText' "
    "AND EXISTS (SELECT 1 FROM row_field_versions AS kept WHERE kept.table_name = old.table_name "
    "AND kept.row_id = old.row_id AND kept.column_name = 'text' "
    "AND (kept.version > old.version OR (kept.version = old.version "
    "AND kept.device_id >= old.device_id)))",
  );
  // A `text` stamp that the `labelText` stamp of its own row beats is dropped in turn.
  await database.customStatement(
    "DELETE FROM row_field_versions AS old WHERE $where AND column_name = 'text' "
    "AND EXISTS (SELECT 1 FROM row_field_versions AS winner "
    "WHERE winner.table_name = old.table_name AND winner.row_id = old.row_id "
    "AND winner.column_name = 'labelText')",
  );
  await database.customStatement(
    "UPDATE row_field_versions SET column_name = 'text' WHERE $where AND column_name = 'labelText'",
  );
}
