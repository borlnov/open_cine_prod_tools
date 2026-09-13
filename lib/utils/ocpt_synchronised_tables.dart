// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// The SQL name of the tombstone column `docs/adr/0010-sync-ready-data-model-prerequisites.md`
/// puts on every synchronised table — the one column [ocptSynchronisedTables] tests for.
const _ocptTombstoneColumnSqlName = 'is_deleted';

/// The one table [ocptSynchronisedTables]' own tombstone test cannot rule out by itself: `scenes`
/// carries `isDeleted` like every synchronised table, but ADR 0010 keeps it out of the merge
/// entirely because it is derived from the screenplay text and recomputed locally after every
/// merge rather than edited directly — see `OcptScenesTable`'s own doc comment.
const _ocptDerivedTableName = 'scenes';

/// Every table of [database] the changeset engine may generate a changeset from, or apply one to:
/// every [TableInfo] carrying the tombstone column ADR 0010 puts on a synchronised table, minus
/// [_ocptDerivedTableName].
///
/// This is a **rule**, not a maintained list (`docs/plans/collaboration-and-sync.md`, M3): a table
/// with no `is_deleted` column drops out on its own for being local rather than synchronised —
/// `project_info`, `row_field_versions`, `project_versions`, `local_erasures` and
/// `sync_relay_cursors` all lack it today — and a future synchronised table is swept in the moment
/// its own migration adds that column, with nothing here to update for it.
Iterable<TableInfo<Table, Object?>> ocptSynchronisedTables(OcptProjectDatabase database) =>
    database.allTables.where(
      (table) =>
          table.actualTableName != _ocptDerivedTableName &&
          table.$columns.any((column) => column.name == _ocptTombstoneColumnSqlName),
    );
