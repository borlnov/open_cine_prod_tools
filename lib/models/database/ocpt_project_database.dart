// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_local_erasures_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_positions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_skills_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_unavailabilities_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_versions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_row_field_versions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scene_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scene_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplay_snapshots_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shot_characters_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shot_coverages_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
// These are only used through the type converters declared in the table files above
// (OcptPageFormatConverter, OcptSnapshotReasonConverter, OcptShotStatusConverter,
// OcptShotCheckReasonConverter, OcptImageRightsStatusConverter, OcptRoleKindConverter,
// OcptPermitStatusConverter, OcptElementCategoryConverter, OcptElementSourceKindConverter,
// OcptAssetKindConverter, OcptHalfDayConverter), but the generated ocpt_project_database.g.dart
// part file below references them directly: since a part file shares its main library's imports
// rather than having its own, they must be imported here too for that generated code to resolve.
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
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
/// per-column version stamps a merge resolves conflicts with ([OcptRowFieldVersionsTable]), and
/// from schema version 5 the user's named project versions ([OcptProjectVersionsTable]). From
/// schema version 6 it holds the resources mode's catalogue: the address book
/// ([OcptPeopleTable]) and its [OcptPersonPositionsTable]/[OcptPersonSkillsTable]/
/// [OcptPersonUnavailabilitiesTable] siblings, the cast ([OcptRolesTable]), locations and their
/// sets ([OcptLocationsTable], [OcptSetsTable], [OcptSceneSetsTable]), the physical elements
/// catalogue ([OcptElementsTable], [OcptSceneElementsTable]), the binary asset references
/// ([OcptAssetsTable]) and the local, never-synchronised record of erased people
/// ([OcptLocalErasuresTable]). `OcptProjectsManager` owns the single instance open at a time.
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
    OcptProjectVersionsTable,
    OcptPeopleTable,
    OcptPersonPositionsTable,
    OcptPersonSkillsTable,
    OcptPersonUnavailabilitiesTable,
    OcptRolesTable,
    OcptLocationsTable,
    OcptSetsTable,
    OcptSceneSetsTable,
    OcptElementsTable,
    OcptSceneElementsTable,
    OcptAssetsTable,
    OcptLocalErasuresTable,
  ],
)
class OcptProjectDatabase extends _$OcptProjectDatabase {
  /// Whether this connection holds the read-only state of a project version being previewed,
  /// rather than the working copy.
  ///
  /// Only `OcptProjectsManager.previewVersion` ever opens one: it hydrates an in-memory database
  /// from a version's payload and hands it to the modes as `OcptOpenProjectModel.database`, while
  /// the project file stays open, untouched, as `OcptOpenProjectModel.fileDatabase`. Everything
  /// the user may not do to a version they are only reading is refused by [refusesUserWrite].
  final bool isPreview;

  /// Opens (creating it if needed) the project database stored at [file].
  OcptProjectDatabase(File file) : isPreview = false, super(NativeDatabase(file));

  /// Opens a project database backed by an in-memory SQLite instance: the connection a version
  /// preview is hydrated into ([isPreview] true), and the one the tests run against.
  ///
  /// Its content is lost as soon as the database is closed, which is precisely what a preview
  /// wants: it never touches the project file.
  OcptProjectDatabase.memory({bool isPreview = false})
    : isPreview = isPreview,
      super(_memoryExecutor(isPreview: isPreview));

  /// The in-memory executor [OcptProjectDatabase.memory] runs on.
  ///
  /// Opening a preview is the one moment the app holds two [OcptProjectDatabase] at once — the
  /// project file and the version being read — which is exactly what drift's
  /// "database class created multiple times" warning looks for. That warning is about two
  /// databases sharing a [QueryExecutor], and these two never can: this one is a private in-memory
  /// instance, and the file stays behind `OcptOpenProjectModel.fileDatabase`. So the preview
  /// silences it, rather than teaching everyone reading a debug log to ignore it.
  static QueryExecutor _memoryExecutor({required bool isPreview}) {
    if (isPreview) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    }

    return NativeDatabase.memory();
  }

  /// Whether the user-driven write named [operation] must be refused because it was handed a
  /// preview connection, logging it when it is.
  ///
  /// {@template open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  /// **What this gates, precisely: the user may not edit what is on screen.** It is not a global
  /// write lock on the project, and the difference matters as soon as the collaboration engine
  /// exists: a merge applying an incoming changeset is not a user edit, it targets
  /// `OcptOpenProjectModel.fileDatabase` rather than the previewed connection, and it must go
  /// through whether or not a preview is up — a gate that swallowed it would silently drop
  /// somebody else's work. Hence the question asked here is "was this call handed the preview
  /// database?", never "is this project currently read-only?".
  /// {@endtemplate}
  ///
  /// A refusal is a logged no-op rather than a thrown error: the UI is supposed to have hidden the
  /// affordance already (a mode gates itself on `OcptOpenProjectModel.isReadOnly`), so reaching
  /// here is a bug to be seen in the logs, not a failure the user can act on.
  bool refusesUserWrite(String operation) {
    if (!isPreview) {
      return false;
    }

    appLogger().w("The write '$operation' was handed the read-only database of a project version "
        "being previewed: it's ignored, the version on screen isn't editable");
    return true;
  }

  /// {@macro drift.GeneratedDatabase.schemaVersion}
  @override
  int get schemaVersion => 6;

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
  /// the short label the scenario coverage export marks its bars with. From 4 to 5 it creates
  /// [OcptProjectVersionsTable] and adds the `project_info.currentVersionId` column pointing into
  /// it. From 5 to 6 it creates the twelve tables of the resources mode — the address book, its
  /// positions/skills/unavailabilities, the cast, locations and sets, elements, asset references
  /// and the local erasures record — and nothing else: no table a project already had is altered.
  /// Every step is additive, as ADR 0007 requires: every new column carries a default (or is
  /// nullable), so the rows a project already had stay valid without being rewritten.
  ///
  /// The v3 and v4 columns are only *added* to the shot list tables when the file already had
  /// them: a file coming from version 1 has just had those three tables created above, from the
  /// current declarations, so they carry both generations of columns already. The v5 step needs no
  /// such guard: [OcptProjectVersionsTable] has never existed in a build a user could have run, so
  /// it is always created here rather than altered, and `project_info` has existed since version 1,
  /// so it can always be given its new pointer.
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

      if (from < 5) {
        await m.createTable(ocptProjectVersionsTable);
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.currentVersionId);
      }

      if (from < 6) {
        // Each `createTable` follows every table it references, so a fresh foreign key never
        // points at a table that doesn't exist in the migration yet — except for the forward
        // references onto `assets` (`people.imageRightsAssetId`/`photoAssetId`,
        // `locations.permitAssetId`, `elements.photoAssetId`), which SQLite never validates at
        // `CREATE TABLE` time, only at the `INSERT`/`UPDATE` that would violate them.
        await m.createTable(ocptPeopleTable);
        await m.createTable(ocptPersonPositionsTable);
        await m.createTable(ocptPersonSkillsTable);
        await m.createTable(ocptPersonUnavailabilitiesTable);
        await m.createTable(ocptRolesTable);
        await m.createTable(ocptLocationsTable);
        await m.createTable(ocptSetsTable);
        await m.createTable(ocptSceneSetsTable);
        await m.createTable(ocptElementsTable);
        await m.createTable(ocptSceneElementsTable);
        await m.createTable(ocptAssetsTable);
        await m.createTable(ocptLocalErasuresTable);
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
