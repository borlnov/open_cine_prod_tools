// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:open_cine_prod_tools/models/database/converters/ocpt_day_part_slot_converter.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_assets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_breakdown_tags_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_local_erasures_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_location_availabilities_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_positions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_skills_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_unavailabilities_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_versions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_row_field_versions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scene_breakdowns_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scene_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scene_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplay_snapshots_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_day_blocks_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_day_groups_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_presences_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slot_cast_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slot_crew_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shot_characters_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shot_coverages_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
// These are only used through the type converters declared in the table files above
// (OcptPageFormatConverter, OcptSnapshotReasonConverter, OcptShotStatusConverter,
// OcptShotCheckReasonConverter, OcptImageRightsStatusConverter, OcptRoleKindConverter,
// OcptPermitStatusConverter, OcptElementCategoryConverter, OcptElementSourceKindConverter,
// OcptElementStatusConverter, OcptAssetKindConverter, OcptDayPartSlotConverter,
// OcptBreakdownTargetKindConverter, OcptBreakdownSceneStatusConverter,
// OcptShootingDayStatusConverter, OcptShootingBlockKindConverter, OcptPresenceCodeConverter), but
// the generated ocpt_project_database.g.dart
// part file below references them directly: since a part file shares its main library's imports
// rather than having its own, they must be imported here too for that generated code to resolve.
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_set_code.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

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
/// ([OcptLocalErasuresTable]). From schema version 9 it also holds the breakdown pass's own tables:
/// the tags anchoring a passage of a scene to a catalogue row ([OcptBreakdownTagsTable]) and each
/// scene's breakdown status ([OcptSceneBreakdownsTable]). From schema version 11 it holds the
/// schedule mode's own tables: the shooting days ([OcptShootingDaysTable]), the convocation windows
/// inside them ([OcptShootingSlotsTable]) and who is convoked during one, crew
/// ([OcptShootingSlotCrewTable]) and cast ([OcptShootingSlotCastTable]), each day's timetable
/// ([OcptShootingDayBlocksTable]) and the by-hand overrides of the presence grid
/// ([OcptShootingPresencesTable]). From schema version 12 it also holds the named lead times a day
/// carries ([OcptShootingDayGroupsTable]), that a `shooting_slot_crew`/`shooting_slot_cast` row may
/// point at. `OcptProjectsManager` owns the single instance open at a time.
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
    OcptLocationAvailabilitiesTable,
    OcptSetsTable,
    OcptSceneSetsTable,
    OcptElementsTable,
    OcptSceneElementsTable,
    OcptAssetsTable,
    OcptLocalErasuresTable,
    OcptBreakdownTagsTable,
    OcptSceneBreakdownsTable,
    OcptShootingDaysTable,
    OcptShootingDayGroupsTable,
    OcptShootingSlotsTable,
    OcptShootingSlotCrewTable,
    OcptShootingSlotCastTable,
    OcptShootingDayBlocksTable,
    OcptShootingPresencesTable,
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

    appLogger().w(
      "The write '$operation' was handed the read-only database of a project version "
      "being previewed: it's ignored, the version on screen isn't editable",
    );
    return true;
  }

  /// {@macro drift.GeneratedDatabase.schemaVersion}
  @override
  int get schemaVersion => 12;

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
  /// From 6 to 7 it creates [OcptLocationAvailabilitiesTable], the dated windows during which a
  /// location may be shot in. From 7 to 8 it adds `project_info.currencyCode`, defaulting an
  /// existing file to EUR exactly as a freshly created one would if the device locale couldn't
  /// suggest anything better. From 8 to 9 it creates [OcptBreakdownTagsTable] and
  /// [OcptSceneBreakdownsTable], the breakdown pass's own tables, and adds `elements.status`. From
  /// 9 to 10 it adds **no column at all**: it fills the `sets.code` a set now carries from the
  /// moment it is created (see [_backfillSetCodes]). From 10 to 11 it creates the six tables of the
  /// schedule mode — the shooting days ([OcptShootingDaysTable]), their convocation windows
  /// ([OcptShootingSlotsTable]) and who is convoked, crew ([OcptShootingSlotCrewTable]) and cast
  /// ([OcptShootingSlotCastTable]), each day's timetable ([OcptShootingDayBlocksTable]) and the
  /// presence grid's overrides ([OcptShootingPresencesTable]) — and, on a file that already had
  /// `shots` (see [_eraseLegacyShootingDays]), blanks every `shots.shootingDay` value: the schedule's
  /// placement is the only truth from here on, a shooting day is always dated, and a free-text `J3`
  /// carries no date to migrate from, so a blank column is the only honest reading. It needs no
  /// `row_field_versions` stamp — every replica performs the same erasure, deterministically, as
  /// part of the migration itself. From 11 to 12 it creates [OcptShootingDayGroupsTable] and, on a
  /// file that already had the other five schedule tables in their v11 shape (see
  /// [_assignOrphanBlocksToFirstSlot] and [_alterScheduleTablesToV12]), fixes up
  /// `shooting_day_blocks.slot_id` — assigning an orphan one (null, or naming a slot that isn't
  /// live) to its day's first live slot, or dropping the block outright when its day has no live
  /// slot at all — before reshaping the four tables
  /// `docs/plans/schedule-slots-and-computed-convocations.md` §4 (M1') describes: `shooting_slots`'
  /// `crewCallMinute` renamed `startMinute` and its `crewWrapMinute`/`castCallMinute`/
  /// `castWrapMinute` dropped, `shooting_day_blocks.slotId` made non-null, and
  /// `shooting_slot_crew`/`shooting_slot_cast` trading their own typed minute columns for a nullable
  /// `groupId`/`leadMinutes` pair. Every step is additive, as ADR 0007 requires: every new column
  /// carries a default (or is nullable), so the rows a project already had stay valid without being
  /// rewritten — the one exception being version 12's column drops and the `NOT NULL` it adds to
  /// `shooting_day_blocks.slotId`, which is why that step alone reshapes existing tables through
  /// [Migrator.alterTable] rather than a plain `addColumn`.
  ///
  /// The v3 and v4 columns are only *added* to the shot list tables when the file already had
  /// them: a file coming from version 1 has just had those three tables created above, from the
  /// current declarations, so they carry both generations of columns already. The v5 step needs no
  /// such guard: [OcptProjectVersionsTable] has never existed in a build a user could have run, so
  /// it is always created here rather than altered, and `project_info` has existed since version 1,
  /// so it can always be given its new pointer. The v9 step guards `elements.status` the same way
  /// the v3/v4 columns do: a file coming from before version 6 has just had `elements` created
  /// above, from the current declaration, so it already carries the column.
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

      if (from < 7) {
        await m.createTable(ocptLocationAvailabilitiesTable);
      }

      if (from < 8) {
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.currencyCode);
      }

      if (from < 9) {
        // Both new tables reference `scenes`, and `breakdown_tags` also references `elements`,
        // `roles` and `sets` — all of which exist by version 6, so nothing here is a forward
        // reference.
        await m.createTable(ocptBreakdownTagsTable);
        await m.createTable(ocptSceneBreakdownsTable);

        if (from >= 6) {
          await m.addColumn(ocptElementsTable, ocptElementsTable.status);
        }
      }

      if (from < 10 && from >= 6) {
        await _backfillSetCodes();
      }

      if (from < 11) {
        // Each `createTable` follows every table it references: `screenplays`, `locations`,
        // `sets`, `people`, `roles` and `shots` all exist by this point, whichever version the file
        // came from.
        await m.createTable(ocptShootingDaysTable);
        await m.createTable(ocptShootingSlotsTable);
        await m.createTable(ocptShootingSlotCrewTable);
        await m.createTable(ocptShootingSlotCastTable);
        await m.createTable(ocptShootingDayBlocksTable);
        await m.createTable(ocptShootingPresencesTable);

        if (from >= 2) {
          await _eraseLegacyShootingDays();
        }
      }

      if (from < 12) {
        await m.createTable(ocptShootingDayGroupsTable);

        if (from >= 11) {
          await _assignOrphanBlocksToFirstSlot();
          await _alterScheduleTablesToV12(m);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Writes a code onto every live `sets` row that has none, in the order the sets are already
  /// read in, so a project made before schema version 10 comes out of the migration looking exactly
  /// like one made after it.
  ///
  /// Only the empty ones are written: back when the field was typed by hand, somebody may have put
  /// something in it, and `ocptSetCodeOf` numbers around whatever it does not recognise rather than
  /// over it.
  ///
  /// Guarded by `from >= 6` at its call site, `sets` having been created by the version 6 step
  /// above — from which it comes out empty, so there is nothing to fill.
  ///
  /// Written in raw SQL rather than through the generated API, for the reason [_backfillSortKeys]
  /// gives.
  Future<void> _backfillSetCodes() async {
    final rows = await customSelect(
      'SELECT id, code FROM sets WHERE is_deleted = 0 ORDER BY sort_key, id',
    ).get();

    final codes = [for (final row in rows) row.data['code'] as String? ?? ""];

    for (var i = 0; i < rows.length; i++) {
      if (codes[i].trim().isNotEmpty) {
        continue;
      }

      codes[i] = ocptSetCodeOf(existingCodes: codes);
      await customStatement('UPDATE sets SET code = ? WHERE id = ?', [
        codes[i],
        rows[i].data['id'],
      ]);
    }
  }

  /// Blanks every `shots.shooting_day` value on the way to schema version 11: from here on, the
  /// schedule mode's own tables are the only truth about which day a shot is planned for, a
  /// shooting day is always dated, and this legacy free-text column never carried one — so a blank
  /// column and an empty schedule say the same true thing, where a migration that guessed a date
  /// from `J3` would fabricate a dated shoot out of nothing.
  ///
  /// Guarded by `from >= 2` at its call site: a file coming from before version 2 has just had
  /// `shots` created empty by the version 2 step above, so there is nothing to erase.
  ///
  /// Written in raw SQL rather than through the generated API, for the reason [_backfillSortKeys]
  /// gives. No `row_field_versions` stamp is written for it: every replica runs this same migration
  /// step, so the erasure is already deterministic across replicas without one.
  Future<void> _eraseLegacyShootingDays() async {
    await customStatement('UPDATE shots SET shooting_day = NULL');
  }

  /// Fixes up `shooting_day_blocks.slot_id` on the way to schema version 12, for a file whose
  /// schedule tables already exist in their v11 shape (guarded by `from >= 11` at its call site,
  /// since a file from below 11 has just had those tables created fresh, from the current — already
  /// v12 — declaration, above): a block that is an **orphan** — its `slot_id` null, *or* naming a
  /// slot that isn't live any more (the app itself never leaves one dangling like that, since the
  /// old `deleteSlot` nulled a block's `slotId` rather than tombstoning the slot out from under it,
  /// but a restored payload could) — gets its day's own first **live** slot: the lowest `sort_key`,
  /// ties broken by `id` so two machines migrating the same file land on the same slot. A block
  /// whose day carries no live slot at all is **hard-deleted** rather than tombstoned, since the
  /// column is `NOT NULL` from here on and even a tombstoned row would need a slot it hasn't got.
  /// This whole path is unreachable through the UI (`OcptScheduleService.createDay` always mints a
  /// slot with every day), but a restored payload could carry a day with none. It needs no
  /// `row_field_versions` stamp, for the same reason [_eraseLegacyShootingDays] needs none: every
  /// replica performs the same deterministic fix-up.
  ///
  /// Must run **before** [_alterScheduleTablesToV12], whose `NOT NULL` constraint on
  /// `shooting_day_blocks.slot_id` this is what satisfies.
  ///
  /// Written in raw SQL rather than through the generated API, for the reason [_backfillSortKeys]
  /// gives.
  Future<void> _assignOrphanBlocksToFirstSlot() async {
    final liveSlots = await customSelect(
      'SELECT id, shooting_day_id FROM shooting_slots WHERE is_deleted = 0 '
      'ORDER BY shooting_day_id, sort_key, id',
    ).get();

    final liveSlotIds = <String>{};
    final firstSlotIdByDay = <String, String>{};
    for (final row in liveSlots) {
      final slotId = row.data['id'] as String;
      liveSlotIds.add(slotId);
      firstSlotIdByDay.putIfAbsent(row.data['shooting_day_id'] as String, () => slotId);
    }

    final blocks = await customSelect(
      'SELECT id, shooting_day_id, slot_id FROM shooting_day_blocks',
    ).get();

    final blockIdsToDelete = <String>[];
    for (final block in blocks) {
      final slotId = block.data['slot_id'] as String?;
      if (slotId != null && liveSlotIds.contains(slotId)) {
        continue;
      }

      final blockId = block.data['id'] as String;
      final firstSlotId = firstSlotIdByDay[block.data['shooting_day_id']];

      if (firstSlotId == null) {
        blockIdsToDelete.add(blockId);
        continue;
      }

      await customStatement('UPDATE shooting_day_blocks SET slot_id = ? WHERE id = ?', [
        firstSlotId,
        blockId,
      ]);
    }

    for (final blockId in blockIdsToDelete) {
      await customStatement('DELETE FROM shooting_day_blocks WHERE id = ?', [blockId]);
    }
  }

  /// Reshapes the four tables `docs/plans/schedule-slots-and-computed-convocations.md` §4 (M1')
  /// changes in place, on the way to schema version 12 — guarded by `from >= 11` at its call site
  /// for the same reason [_assignOrphanBlocksToFirstSlot] is: a file from below 11 has just had
  /// these tables created fresh in their current (already v12) shape, so there is nothing left here
  /// to reshape.
  ///
  /// Drift's migrator has no plain "rename column" or "drop column" step — its picture of a table
  /// mid-migration is the *current* Dart declaration, which by this point already reads
  /// `startMinute` rather than `crewCallMinute` and no longer declares
  /// `crewWrapMinute`/`castCallMinute`/`castWrapMinute`/`callMinute`/`wrapMinute`/`arrivalMinute` at
  /// all — so each table goes through [Migrator.alterTable], sqlite's own twelve-step recipe for
  /// reshaping a table in place (create the new shape under a temporary name, copy the old rows
  /// across, drop the old table, rename the temporary one).
  ///
  /// `shooting_slots.crew_call_minute` is carried across as `start_minute` through a
  /// `TableMigration.columnTransformer` naming the column by its raw SQL name (the rename left it
  /// with no Dart getter to reference); `crew_wrap_minute`/`cast_call_minute`/`cast_wrap_minute` are
  /// simply absent from the target shape and therefore dropped with no further action.
  /// `shooting_day_blocks.slot_id` is carried across unchanged — [_assignOrphanBlocksToFirstSlot] has
  /// already made sure every row holds one, which is what lets the freshly `NOT NULL` column accept
  /// it. `shooting_slot_crew`/`shooting_slot_cast` each drop their own typed minute columns and gain
  /// a nullable `group_id`/`lead_minutes` pair: **nothing tries to reconstruct a lead time out of
  /// the dropped clocks** — a figure guessed from a timetable that has since moved would be worse
  /// than the zero every row starts at — so neither is given a transformer, and both simply come
  /// back null.
  ///
  /// `TableMigration` is drift's own documented recipe for exactly this kind of reshape, still
  /// marked `@experimental`; the four `// ignore: experimental_member_use` below accept that,
  /// there being no non-experimental way to rename or drop a column under ADR 0007's own
  /// additive-only policy having already been superseded for this one step.
  Future<void> _alterScheduleTablesToV12(Migrator m) async {
    await m.alterTable(
      // TableMigration is drift's documented, if still @experimental, recipe for a rename/drop:
      // see the method's own doc comment.
      // ignore: experimental_member_use
      TableMigration(
        ocptShootingSlotsTable,
        newColumns: [ocptShootingSlotsTable.startMinute],
        columnTransformer: {
          ocptShootingSlotsTable.startMinute: const CustomExpression<int>('crew_call_minute'),
        },
      ),
    );

    await m.alterTable(
      // Same as above: only the destination shape is new.
      // ignore: experimental_member_use
      TableMigration(ocptShootingDayBlocksTable),
    );

    await m.alterTable(
      // Same as above: only the destination shape is new.
      // ignore: experimental_member_use
      TableMigration(
        ocptShootingSlotCrewTable,
        newColumns: [ocptShootingSlotCrewTable.groupId, ocptShootingSlotCrewTable.leadMinutes],
      ),
    );

    await m.alterTable(
      // Same as above: only the destination shape is new.
      // ignore: experimental_member_use
      TableMigration(
        ocptShootingSlotCastTable,
        newColumns: [ocptShootingSlotCastTable.groupId, ocptShootingSlotCastTable.leadMinutes],
      ),
    );
  }

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
      selectSql:
          'SELECT shot_id, character_name FROM shot_characters '
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
