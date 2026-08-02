// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_row_field_versions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplay_snapshots_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shot_characters_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shot_coverages_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
// These are only used through the type converters declared in the table files above
// (OcptPageFormatConverter, OcptSnapshotReasonConverter, OcptShotStatusConverter,
// OcptShotCheckReasonConverter), but the generated ocpt_project_database.g.dart part file below
// references them directly: since a part file shares its main library's imports rather than
// having its own, they must be imported here too for that generated code to resolve.
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';

part 'ocpt_project_database.g.dart';

/// The per-project SQLite database backing a single `.ocpt` project file.
///
/// Every Open Cine Prod Tools project is one such database: it holds the project metadata
/// ([OcptProjectInfoTable]), its screenplay(s) ([OcptScreenplaysTable]), safety copies of their
/// text ([OcptScreenplaySnapshotsTable]), the reconciled scene index ([OcptScenesTable]) and, from
/// schema version 2 onwards, the shot list built on top of that index ([OcptShotsTable],
/// [OcptShotCharactersTable], [OcptShotCoveragesTable]). From schema version 3 it also holds the
/// per-column version stamps a merge resolves conflicts with ([OcptRowFieldVersionsTable]).
/// `OcptProjectsManager` owns the single instance open at a time.
@DriftDatabase(
  tables: [
    OcptProjectInfoTable,
    OcptScreenplaysTable,
    OcptScreenplaySnapshotsTable,
    OcptScenesTable,
    OcptShotsTable,
    OcptShotCharactersTable,
    OcptShotCoveragesTable,
    OcptRowFieldVersionsTable,
  ],
)
class OcptProjectDatabase extends _$OcptProjectDatabase {
  /// Opens (creating it if needed) the project database stored at [file].
  OcptProjectDatabase(File file) : super(NativeDatabase(file));

  /// Opens a project database backed by an in-memory SQLite instance, for use in tests only: its
  /// content is lost as soon as the database is closed.
  OcptProjectDatabase.memory() : super(NativeDatabase.memory());

  /// {@macro drift.GeneratedDatabase.schemaVersion}
  @override
  int get schemaVersion => 4;

  /// The database options used by this database.
  ///
  /// `DriftDatabaseOptions.storeDateTimeAsText` is turned on so `dateTime()` columns (e.g.
  /// `screenplay_snapshots.createdAt`) keep full, sub-second precision instead of drift's default
  /// whole-second unix timestamp: several snapshots can otherwise be taken within the same
  /// second (e.g. a burst of saves), which would make them tie when ordered by `createdAt` and
  /// break `OcptScreenplayService`'s "most recent" pruning.
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// How an existing `.ocpt` file is brought up to the current [schemaVersion]. See
  /// `docs/adr/0007-schema-migration-policy.md` for what a schema version means for a user's
  /// project file and why migrations are additive-only for now.
  ///
  /// `onUpgrade` from 1 to 2 creates exactly the three shot list tables and nothing else: no
  /// existing table is touched, so every screenplay, snapshot and scene a project already had
  /// survives untouched. From 2 to 3 it adds the sync-ready columns of
  /// `docs/adr/0010-sync-ready-data-model-prerequisites.md` — an `isDeleted` tombstone flag on
  /// every synchronised table, a `sortKey` fractional index beside `position` on the two ordered
  /// ones — creates [OcptRowFieldVersionsTable], and backfills the new keys from the order
  /// `position` already held (see [_backfillSortKeys]). From 3 to 4 it adds `shots.abbreviation`,
  /// the short label the scenario coverage export marks its bars with. Every step is additive, as
  /// ADR 0007 requires: every new column carries a default, so the rows a project already had stay
  /// valid without being rewritten.
  ///
  /// The v3 and v4 columns are only *added* to the shot list tables when the file already had
  /// them: a file coming from version 1 has just had those three tables created above, from the
  /// current declarations, so they carry both generations of columns already.
  ///
  /// `beforeOpen` turns SQLite's `foreign_keys` pragma on: `NativeDatabase` leaves it at SQLite's
  /// own default, which is off, so the `references()` declared on the tables above would otherwise
  /// never actually be enforced.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(ocptShotsTable);
        await m.createTable(ocptShotCharactersTable);
        await m.createTable(ocptShotCoveragesTable);
      }

      if (from < 3) {
        await m.addColumn(ocptScreenplaysTable, ocptScreenplaysTable.isDeleted);
        await m.addColumn(ocptScreenplaySnapshotsTable, ocptScreenplaySnapshotsTable.isDeleted);
        await m.addColumn(ocptScenesTable, ocptScenesTable.isDeleted);

        if (from >= 2) {
          await m.addColumn(ocptShotsTable, ocptShotsTable.sortKey);
          await m.addColumn(ocptShotsTable, ocptShotsTable.isDeleted);
          await m.addColumn(ocptShotCharactersTable, ocptShotCharactersTable.sortKey);
          await m.addColumn(ocptShotCharactersTable, ocptShotCharactersTable.isDeleted);
          await m.addColumn(ocptShotCoveragesTable, ocptShotCoveragesTable.isDeleted);
        }

        await m.createTable(ocptRowFieldVersionsTable);
        await _backfillSortKeys();
      }

      if (from < 4 && from >= 2) {
        await m.addColumn(ocptShotsTable, ocptShotsTable.abbreviation);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Writes a `sortKey` onto every `shots` and `shot_characters` row that predates schema version
  /// 3, preserving the order those rows already had under `position`.
  ///
  /// Each group is keyed independently — a scene's shots (the orphan group, whose `scene_id` is
  /// null, counting as one of its own per screenplay), then a shot's characters — because a
  /// fractional index only ever has to be unique and ordered *within* the group it orders.
  /// Ties on `position` (which nothing forbade before this version) are broken by the row's own
  /// key, so the backfill is deterministic and two machines migrating the same file land on the
  /// same keys.
  ///
  /// Written in raw SQL rather than through the generated API: this runs part way through a
  /// migration, at a point where it is the columns just added by hand, and not drift's picture of
  /// the schema, that describe what the file actually holds.
  Future<void> _backfillSortKeys() async {
    await _backfillGroups(
      selectSql: 'SELECT id, screenplay_id, scene_id FROM shots ORDER BY position, id',
      groupKeyOf: (row) => "${row.data['screenplay_id']}/${row.data['scene_id']}",
      updateSql: 'UPDATE shots SET sort_key = ? WHERE id = ?',
      updateArgsOf: (row) => [row.data['id']],
    );

    await _backfillGroups(
      selectSql: 'SELECT shot_id, character_name FROM shot_characters '
          'ORDER BY position, character_name',
      groupKeyOf: (row) => "${row.data['shot_id']}",
      updateSql: 'UPDATE shot_characters SET sort_key = ? WHERE shot_id = ? AND character_name = ?',
      updateArgsOf: (row) => [row.data['shot_id'], row.data['character_name']],
    );
  }

  /// Runs one table's half of [_backfillSortKeys]: reads every row with [selectSql] (already in
  /// the order the keys must follow), splits them into groups by [groupKeyOf], and writes the
  /// [ocptFractionalKeySequence] of each group through [updateSql], whose first placeholder is the
  /// key and whose remaining ones are filled by [updateArgsOf].
  Future<void> _backfillGroups({
    required String selectSql,
    required String Function(QueryRow row) groupKeyOf,
    required String updateSql,
    required List<Object?> Function(QueryRow row) updateArgsOf,
  }) async {
    final rows = await customSelect(selectSql).get();

    final rowsByGroup = <String, List<QueryRow>>{};
    for (final row in rows) {
      rowsByGroup.putIfAbsent(groupKeyOf(row), () => []).add(row);
    }

    for (final group in rowsByGroup.values) {
      final keys = ocptFractionalKeySequence(group.length);
      for (var i = 0; i < group.length; i++) {
        await customStatement(updateSql, [keys[i], ...updateArgsOf(group[i])]);
      }
    }
  }
}
