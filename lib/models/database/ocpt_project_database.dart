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
import 'package:open_cine_prod_tools/models/database/tables/ocpt_role_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_role_episodes_table.dart';
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
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_day_events_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slot_cast_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slot_crew_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slot_guests_table.dart';
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
// OcptShootingDayStatusConverter, OcptShootingBlockKindConverter,
// OcptShootingSlotAnchorEdgeConverter), but
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
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
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
/// ([OcptPeopleTable], gaining a person's maximum daily presence at schema version 16) and its
/// [OcptPersonPositionsTable]/[OcptPersonSkillsTable]/
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
/// ([OcptShootingDayBlocksTable]) and, briefly, the by-hand overrides of the presence grid
/// (`shooting_presences`, dropped again at schema version 17 below). Schema version 12 briefly
/// added the named lead times a day carried (`shooting_day_groups`), that a
/// `shooting_slot_crew`/`shooting_slot_cast` row could point at; schema version 13 drops that table
/// again, and the `groupId`/`leadMinutes` columns of those two convocation tables with it — a
/// convocation is read off the slots a person or a role is linked to from here on, never offset by
/// a typed figure (see `docs/adr/0018-a-convocation-is-the-slot-you-are-linked-to.md`). Schema
/// version 14 replaces `shooting_slots.startMinute` with the three columns an anchored edge needs,
/// so a slot can be pinned by its end as well as its start, or read its hour off another slot of the
/// same day (ADR 0015, amended a second time). Schema version 15 adds [OcptRoleElementsTable], what
/// a role wears, carries and is made up with. Schema version 17 adds two further schedule tables:
/// who attends a slot without being crew or cast ([OcptShootingSlotGuestsTable]) and what a day does
/// not control, at an absolute hour ([OcptShootingDayEventsTable]) — plus, in the same schema bump,
/// a printed crew note on a block ([OcptShootingDayBlocksTable.crewNote]), a document's validity
/// window on an asset ([OcptAssetsTable.validFrom]/[OcptAssetsTable.validUntil]) and the minimum
/// rest a production says it owes ([OcptProjectInfoTable.minimumRestMinutes]) — and it **drops**
/// `shooting_presences` outright: the grid mixed a computed reading (who is convoked, from the
/// schedule) with a click-through override whose `available`/`unavailable` values only ever
/// restated, from a second source of truth, what `person_unavailabilities` already says in the
/// resources mode. As with every other column and table this app has migrated away from, nothing is
/// reconstructed — an override that said `travelling` does not become anything on the other side of
/// the migration. Schema version 18 is what makes a screenplay row an episode
/// (`docs/adr/0019-one-project-several-episodes.md`): `screenplays` gains `number` (printed) and
/// `sortKey` (what actually orders the episodes), a role stops belonging to any one screenplay and
/// [OcptRoleEpisodesTable] takes over saying which episodes name it, and `shooting_days` stops
/// naming a screenplay at all — a day regularly covers two episodes at one location, which is the
/// whole point of a shared schedule. `OcptProjectsManager` owns the single instance open at a time.
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
    OcptRoleElementsTable,
    OcptRoleEpisodesTable,
    OcptAssetsTable,
    OcptLocalErasuresTable,
    OcptBreakdownTagsTable,
    OcptSceneBreakdownsTable,
    OcptShootingDaysTable,
    OcptShootingSlotsTable,
    OcptShootingSlotCrewTable,
    OcptShootingSlotCastTable,
    OcptShootingDayBlocksTable,
    OcptShootingSlotGuestsTable,
    OcptShootingDayEventsTable,
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
  int get schemaVersion => 18;

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
  /// moment it is created (see [_backfillSetCodes]). From 10 to 11 it creates the five tables of the
  /// schedule mode this build still carries — the shooting days ([OcptShootingDaysTable]), their
  /// convocation windows ([OcptShootingSlotsTable]) and who is convoked, crew
  /// ([OcptShootingSlotCrewTable]) and cast ([OcptShootingSlotCastTable]), and each day's timetable
  /// ([OcptShootingDayBlocksTable]) — a real file reaching version 11 in an older build also gained
  /// a sixth, `shooting_presences`, the presence grid's by-hand override; schema version 17 drops it
  /// again (below), so a file this old is never given it in the first place any more — and, on a
  /// file that already had `shots` (see [_eraseLegacyShootingDays]), blanks every
  /// `shots.shootingDay` value: the schedule's
  /// placement is the only truth from here on, a shooting day is always dated, and a free-text `J3`
  /// carries no date to migrate from, so a blank column is the only honest reading. It needs no
  /// `row_field_versions` stamp — every replica performs the same erasure, deterministically, as
  /// part of the migration itself. From 11 to 12 it fixes up `shooting_day_blocks.slot_id` on a
  /// file that already had the other five schedule tables in their v11 shape (see
  /// [_assignOrphanBlocksToFirstSlot] and [_alterScheduleTablesToV12]) — assigning an orphan one
  /// (null, or naming a slot that isn't live) to its day's first live slot, or dropping the block
  /// outright when its day has no live slot at all — before reshaping the tables schema version 12
  /// changed: `shooting_slots`' `crewCallMinute` renamed `startMinute` and its
  /// `crewWrapMinute`/`castCallMinute`/`castWrapMinute` dropped, `shooting_day_blocks.slotId` made
  /// non-null and gaining the nullable `sceneId` a `hold` names its sequence by, and
  /// `shooting_slot_crew`/`shooting_slot_cast` dropping their own typed minute columns — landing
  /// directly on the shape schema version 13 settles on, since neither table gains the
  /// `groupId`/`leadMinutes` pair version 12 briefly added and version 13 removes again. From 12 to
  /// 13 it drops `shooting_day_groups` outright ([Migrator.deleteTable], harmless whether or not
  /// the file ever held the table) and, on a file that genuinely carried version 12's shape (see
  /// [_alterScheduleTablesToV13]), drops the `groupId`/`leadMinutes` columns
  /// `shooting_slot_crew`/`shooting_slot_cast` briefly gained: a convocation is read off the slots a
  /// person or a role is linked to from here on, never offset by a typed figure (see
  /// `docs/adr/0018-a-convocation-is-the-slot-you-are-linked-to.md`). From 13 to 14 it replaces
  /// `shooting_slots.start_minute` with the three columns an anchored edge needs — `anchor_edge`,
  /// `anchor_minute` and the self-referencing `anchor_slot_id` (see [_alterScheduleTablesToV14]) —
  /// so a slot can be pinned by its **end** as well as its start, or read its hour off another slot
  /// of the same day. From 14 to 15 it creates [OcptRoleElementsTable], what a role wears, carries
  /// and is made up with: it is a plain `createTable` on a file coming from any version, since both
  /// tables it references (`roles` and `elements`) exist by version 6 and are created above for a
  /// file older than that. From 15 to 16 it adds `people.maxDailyPresenceMinutes`, guarded by
  /// `from >= 6` at its call site for the same reason `elements.status` (version 8 to 9) is: a file
  /// coming from below version 6 has just had `people` created fresh above, from the current
  /// declaration, so it already carries the column. It gets no backfill, staying null on every row a
  /// project already had — null is not "no maximum", it is "nobody has recorded one", exactly as
  /// true the moment after the migration as it was the moment before it. From 16 to 17 it creates
  /// [OcptShootingSlotGuestsTable] and [OcptShootingDayEventsTable] — both plain `createTable`s on a
  /// file coming from any version, since every table either one references (`shooting_slots` and
  /// `people` for the first, `shooting_days` for the second) exists by version 11 at the latest, and
  /// is created above for a file older than that — and, in the same step, three more columns: it
  /// adds `project_info.minimumRestMinutes` unconditionally (`project_info` has existed, and been
  /// alterable, since version 1), `assets.validFrom`/`assets.validUntil` guarded by `from >= 6` for
  /// the reason `elements.status` is (a file older than that has just had the table created fresh
  /// above, from the current declaration, so it already carries both columns), and
  /// `shooting_day_blocks.crewNote` guarded by `from >= 12` rather than `from >= 11`: a file below
  /// 11 has the same fresh-table reason, and one from exactly 11 has just been reshaped onto the
  /// current declaration by [_alterScheduleTablesToV12] — `TableMigration`'s picture of a table
  /// mid-migration is always the *current* Dart declaration (see that method's own doc comment), so
  /// both already carry the column by this point. All three are
  /// nullable or defaulted, so none needs a backfill: a project that predates them recorded nothing
  /// for any of the three, which stays as true after the migration as it was before it — exactly the
  /// reading version 16's own column carries. The same step also **drops** `shooting_presences`
  /// outright ([Migrator.deleteTable], harmless whether or not the file ever held the table): the
  /// presence grid's click-through override restated, from a second source of truth, what
  /// `person_unavailabilities` already says in the resources mode, and nothing is reconstructed from
  /// it — an override that said `travelling` does not become anything on the other side of this
  /// migration. From 17 to 18 it lands the whole of `docs/adr/0019-one-project-several-episodes.md`
  /// in one step, in an order that matters: it adds `screenplays.number` and `screenplays.sortKey`
  /// unconditionally (`screenplays` has existed, and been alterable, since version 1), then numbers
  /// every **live** screenplay `1..n` in `id` order and gives each the matching
  /// [ocptFractionalKeySequence] key (see [_numberExistingScreenplays]) — a tombstoned row keeps the
  /// column defaults, [_backfillSetCodes] being the precedent for touching live rows only. A file
  /// reaching this step has, in practice, always held exactly one screenplay, so this is simply
  /// "that screenplay is episode 1"; the general form is only what makes the answer deterministic —
  /// two replicas migrating the same file landing on the same numbering — if it ever holds more than
  /// one. It then creates [OcptRoleEpisodesTable] (both tables it references, `roles` and
  /// `screenplays`, exist by version 6 at the latest, and a file older than that has just had
  /// `roles` created fresh above, so this is never a forward reference) and, guarded by `from >= 6`
  /// for the reason [_deriveRoleEpisodes] states, derives a `role_episodes` row from every **live**
  /// `roles` row's own `screenplayId` — the column the very next step drops — before dropping it: a
  /// role has exactly one episode at this point, so the derivation is lossless, and it is the only
  /// one in this whole migration that materialises nothing and guesses nothing (see that method's
  /// own doc comment for why its link ids aren't fresh UUIDs). Finally it drops `roles.screenplayId`
  /// (guarded `from >= 6`) and `shooting_days.screenplayId` (guarded `from >= 11`) through
  /// [_alterRoleAndShootingDayTablesToV18] — a role belongs to the production now, and a day never
  /// named one episode more truthfully than it names all of them, a shooting day regularly covering
  /// two at once. Every step is additive, as
  /// ADR 0007 requires: every new column carries a default (or is nullable), so the rows a project
  /// already had stay valid without being rewritten — the exceptions being version 12's column
  /// drops and the `NOT NULL` it adds to `shooting_day_blocks.slotId`, version 13's own column
  /// and table drops, version 14's rename, version 17's own table drop, and version 18's own two
  /// column drops, none of which a plain `addColumn` can express, which is why all five reshape
  /// existing tables through [Migrator.alterTable]/[Migrator.deleteTable] instead.
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
        // came from. `shooting_presences` is deliberately not among these any more: a file coming
        // from below version 11 never held it, and creating it here only to drop it again at
        // version 17 below would be work with no reader. That drop still runs unconditionally, for
        // the file that genuinely did hold it — one written by a build that had this table.
        await m.createTable(ocptShootingDaysTable);
        await m.createTable(ocptShootingSlotsTable);
        await m.createTable(ocptShootingSlotCrewTable);
        await m.createTable(ocptShootingSlotCastTable);
        await m.createTable(ocptShootingDayBlocksTable);

        if (from >= 2) {
          await _eraseLegacyShootingDays();
        }
      }

      if (from < 12 && from >= 11) {
        await _assignOrphanBlocksToFirstSlot();
        await _alterScheduleTablesToV12(m);
      }

      if (from < 13) {
        await m.deleteTable('shooting_day_groups');

        if (from >= 12) {
          await _alterScheduleTablesToV13(m);
        }
      }

      if (from < 14 && from >= 12) {
        await _alterScheduleTablesToV14(m);
      }

      if (from < 15) {
        // Both tables it references — `roles` and `elements` — exist by version 6, and a file
        // older than that has just had them created above, so this is never a forward reference.
        await m.createTable(ocptRoleElementsTable);
      }

      if (from < 16 && from >= 6) {
        await m.addColumn(ocptPeopleTable, ocptPeopleTable.maxDailyPresenceMinutes);
      }

      if (from < 17) {
        // Each `createTable` follows every table it references: `shooting_slots` and `people` exist
        // by version 11 (or fresh, for a file older than that), `shooting_days` by version 11 too.
        await m.createTable(ocptShootingSlotGuestsTable);
        await m.createTable(ocptShootingDayEventsTable);

        // `project_info` has existed, and been alterable, since version 1: no guard needed.
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.minimumRestMinutes);

        // Guarded by `from >= 12`, not `from >= 11`: a file from below 11 has just had
        // `shooting_day_blocks` created fresh above, from the current declaration, and one coming
        // from version 11 has just been reshaped straight onto that same current declaration by
        // [_alterScheduleTablesToV12] — `TableMigration`'s picture of a table mid-migration is
        // always the *current* Dart declaration, so both already carry `crew_note` by this point.
        // Only a file that genuinely reached version 12 still lacks the column for this to add.
        if (from >= 12) {
          await m.addColumn(ocptShootingDayBlocksTable, ocptShootingDayBlocksTable.crewNote);
        }

        if (from >= 6) {
          await m.addColumn(ocptAssetsTable, ocptAssetsTable.validFrom);
          await m.addColumn(ocptAssetsTable, ocptAssetsTable.validUntil);
        }

        // `shooting_presences` is dropped outright ([Migrator.deleteTable], harmless whether or
        // not the file ever held the table — the same idiom version 13 already uses for
        // `shooting_day_groups`): the presence grid's click-through override restated, from a
        // second source of truth, what `person_unavailabilities` already says in the resources
        // mode, and nothing here is reconstructed from it — an override that said `travelling`
        // does not become anything on the other side of this migration.
        await m.deleteTable('shooting_presences');
      }

      if (from < 18) {
        // `screenplays` has existed, and been alterable, since version 1: no guard needed, exactly
        // as `project_info.minimumRestMinutes` above needed none.
        await m.addColumn(ocptScreenplaysTable, ocptScreenplaysTable.number);
        await m.addColumn(ocptScreenplaysTable, ocptScreenplaysTable.sortKey);
        await _numberExistingScreenplays();

        // Both tables it references, `roles` and `screenplays`, exist by version 6 at the latest —
        // `screenplays` since version 1, `roles` created fresh just above for a file older than 6 —
        // so this is never a forward reference.
        await m.createTable(ocptRoleEpisodesTable);

        // Must run before the `roles.screenplayId` drop just below: it is the column this derives
        // from. Guarded by `from >= 6` for the reason [_deriveRoleEpisodes] itself states — a file
        // older than that has just had `roles` created fresh, empty and already without the column,
        // so there is nothing to derive.
        if (from >= 6) {
          await _deriveRoleEpisodes();
        }

        await _alterRoleAndShootingDayTablesToV18(m, from: from);
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

  /// Reshapes the four schedule tables whose shape changes in place, on the way to schema version
  /// 12 — guarded by `from >= 11` at its call site
  /// for the same reason [_assignOrphanBlocksToFirstSlot] is: a file from below 11 has just had
  /// these tables created fresh in their current (already v13) shape, so there is nothing left here
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
  /// `shooting_slots.crew_call_minute` is carried across as `anchor_minute`, on a row anchored by
  /// its `start`, through a `TableMigration.columnTransformer` naming the old column by its raw SQL
  /// name (the rename left it with no Dart getter to reference). Schema version 12 spelled that
  /// destination `start_minute`; version 14 has since replaced it with the anchored-edge trio
  /// ([_alterScheduleTablesToV14]), and, exactly as with the crew/cast columns below, a file
  /// reshaped straight from its v11 shape by this method lands on the **current** shape rather than
  /// on the intermediate one — which is why the version 14 step is guarded by `from >= 12` and
  /// therefore skipped for it. `crew_wrap_minute`/`cast_call_minute`/`cast_wrap_minute` are
  /// simply absent from the target shape and therefore dropped with no further action.
  /// `shooting_day_blocks.slot_id` is carried across unchanged — [_assignOrphanBlocksToFirstSlot] has
  /// already made sure every row holds one, which is what lets the freshly `NOT NULL` column accept
  /// it. `shooting_slot_crew`/`shooting_slot_cast` each simply drop their own typed minute columns:
  /// this once left them gaining a nullable `group_id`/`lead_minutes` pair (schema version 12), but
  /// that pair is itself gone from the *current* Dart declaration schema version 13 dropped it from
  /// (`docs/adr/0018-a-convocation-is-the-slot-you-are-linked-to.md`), so a file reshaped straight
  /// from its v11 shape by this method lands directly on the current, group-less columns — nothing
  /// is reconstructed out of the dropped clocks, exactly as nothing was reconstructed when this
  /// method briefly added that pair.
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
        newColumns: [
          ocptShootingSlotsTable.anchorEdge,
          ocptShootingSlotsTable.anchorMinute,
          ocptShootingSlotsTable.anchorSlotId,
        ],
        columnTransformer: {
          // The literal must match `OcptShootingSlotAnchorEdge.start.name`, for the same reason the
          // column's own default has to.
          ocptShootingSlotsTable.anchorEdge: const Constant<String>('start'),
          ocptShootingSlotsTable.anchorMinute: const CustomExpression<int>('crew_call_minute'),
        },
      ),
    );

    await m.alterTable(
      // Same as above: only the destination shape is new. `sceneId` comes out null on every row a
      // file already held, `hold` blocks included: the column is what a hold's sequence is named by
      // from here on, and the free-text `label` those rows carry is not a scene id to read one out
      // of — nothing is guessed, exactly as no lead time is guessed out of the dropped clocks.
      // ignore: experimental_member_use
      TableMigration(ocptShootingDayBlocksTable, newColumns: [ocptShootingDayBlocksTable.sceneId]),
    );

    await m.alterTable(
      // Same as above: only the destination shape is new — no `newColumns` here, since the current
      // declaration adds none over what a v11 row already had, once its typed minute columns are
      // gone.
      // ignore: experimental_member_use
      TableMigration(ocptShootingSlotCrewTable),
    );

    await m.alterTable(
      // Same as above.
      // ignore: experimental_member_use
      TableMigration(ocptShootingSlotCastTable),
    );
  }

  /// Drops `group_id` and `lead_minutes` off `shooting_slot_crew`/`shooting_slot_cast`, on the way
  /// to schema version 13 — guarded by `from >= 12` at its call site: a file from below 12 either
  /// never had those columns at all, or has just been reshaped straight past them by
  /// [_alterScheduleTablesToV12] above, whose own crew/cast steps already target the same
  /// column-less shape this method targets for a file that genuinely reached version 12.
  ///
  /// Each table goes through the same [Migrator.alterTable]/`TableMigration` recipe
  /// [_alterScheduleTablesToV12] uses, and for the same reason — drift's migrator has no plain "drop
  /// column" step. Neither call passes `newColumns`: nothing is being added, only dropped, so the
  /// stock rewrite (create the current shape under a temporary name, copy the columns that still
  /// exist, drop the old table, rename the temporary one) is all either table needs. A convocation's
  /// arrival, readiness band and departure are read off the slots a person or a role is linked to
  /// from here on rather than offset by a typed lead time
  /// (`docs/adr/0018-a-convocation-is-the-slot-you-are-linked-to.md`), and, as with every dropped
  /// column this app has migrated away from, **nothing is reconstructed**: a lead time a file
  /// carried is not turned into a slot nobody asked for.
  Future<void> _alterScheduleTablesToV13(Migrator m) async {
    await m.alterTable(
      // TableMigration is drift's documented, if still @experimental, recipe for a column drop: see
      // the method's own doc comment.
      // ignore: experimental_member_use
      TableMigration(ocptShootingSlotCrewTable),
    );

    await m.alterTable(
      // Same as above.
      // ignore: experimental_member_use
      TableMigration(ocptShootingSlotCastTable),
    );
  }

  /// Replaces `shooting_slots.start_minute` with the anchored-edge trio, on the way to schema
  /// version 14 — guarded by `from >= 12` at its call site: a file from below 11 has just had
  /// `shooting_slots` created fresh in its current (already v14) shape, and one coming from
  /// version 11 has just been reshaped straight onto that same shape by
  /// [_alterScheduleTablesToV12], whose own slots step already carries `crew_call_minute` into
  /// `anchor_minute`. Only a file that genuinely reached version 12 or 13 still holds a
  /// `start_minute` column for this method to rename.
  ///
  /// The same [Migrator.alterTable]/`TableMigration` recipe [_alterScheduleTablesToV12] uses, and
  /// for the same reason — drift's migrator has no plain "rename column" step, and its picture of
  /// the table mid-migration is the *current* Dart declaration, which no longer knows the name
  /// `startMinute` at all.
  ///
  /// Every existing row comes out **anchored by its start, at the very hour it already had**:
  /// `anchor_minute` is carried across from `start_minute` through a `columnTransformer` naming that
  /// column by its raw SQL name, `anchor_edge` is written as the literal `start`, and
  /// `anchor_slot_id` is left null — which is exactly how the app behaved for every project that
  /// reaches this step, so a file opened after the migration draws the day it drew before it.
  /// Nothing is guessed the other way round: no slot is turned into an end-anchored one because its
  /// last block happened to land on a round hour.
  ///
  /// The new `anchor_slot_id` is a **self-referencing** foreign key, which the copy above can never
  /// violate: it comes out null on every row.
  Future<void> _alterScheduleTablesToV14(Migrator m) async {
    await m.alterTable(
      // TableMigration is drift's documented, if still @experimental, recipe for a rename: see the
      // method's own doc comment.
      // ignore: experimental_member_use
      TableMigration(
        ocptShootingSlotsTable,
        newColumns: [
          ocptShootingSlotsTable.anchorEdge,
          ocptShootingSlotsTable.anchorMinute,
          ocptShootingSlotsTable.anchorSlotId,
        ],
        columnTransformer: {
          // The literal must match `OcptShootingSlotAnchorEdge.start.name`, for the same reason the
          // column's own default has to.
          ocptShootingSlotsTable.anchorEdge: const Constant<String>('start'),
          ocptShootingSlotsTable.anchorMinute: const CustomExpression<int>('start_minute'),
        },
      ),
    );
  }

  /// Numbers every **live** `screenplays` row `1..n`, in `id` order, and gives each the matching
  /// [ocptFractionalKeySequence] key, on the way to schema version 18. `id` is the same tie-break
  /// [_assignOrphanBlocksToFirstSlot] gives its own for the same reason: it is deterministic, so two
  /// replicas migrating the same file land on the same numbering rather than two disagreeing ones.
  ///
  /// A tombstoned row is left at the column defaults ([_backfillSetCodes] is the precedent for
  /// touching only live rows): a deleted screenplay was never going to be episode anything.
  ///
  /// A file reaching this step has, in practice, always held exactly one screenplay — every build
  /// before schema version 18 only ever created one — so this is, concretely, "that screenplay is
  /// episode 1". The general `1..n` form exists only to make the answer deterministic should a file
  /// ever hold more than one, which nothing before this version could produce but a restored payload
  /// or a hand-edited file conceivably could.
  ///
  /// Written in raw SQL rather than through the generated API, for the reason [_backfillSortKeys]
  /// gives.
  Future<void> _numberExistingScreenplays() async {
    final rows = await customSelect(
      'SELECT id FROM screenplays WHERE is_deleted = 0 ORDER BY id',
    ).get();

    final keys = ocptFractionalKeySequence(rows.length);
    for (var i = 0; i < rows.length; i++) {
      await customStatement('UPDATE screenplays SET number = ?, sort_key = ? WHERE id = ?', [
        i + 1,
        keys[i],
        rows[i].data['id'],
      ]);
    }
  }

  /// Inserts a `role_episodes` row for every **live** `roles` row, on the way to schema version 18:
  /// `role_id` names the role, `screenplay_id` is that very role's own `screenplayId` — the column
  /// [_alterRoleAndShootingDayTablesToV18] drops right after this runs — and, the one judgement call
  /// this migration makes on its own, **the link's `id` is the role's own id**.
  ///
  /// A role has exactly one episode at this point in the migration: the column about to be dropped
  /// and the table just created both say the same single fact, which is what makes reusing the
  /// role's id safe — it is unique here — and useful — it is deterministic, so two replicas
  /// migrating the same file produce the same `role_episodes` row rather than two a later merge
  /// would have to reconcile. This is the same reasoning [_assignOrphanBlocksToFirstSlot] gives for
  /// its own tie-break, and `docs/adr/0019-one-project-several-episodes.md` gives for this one. It
  /// needs no `row_field_versions` stamp for the same reason [_eraseLegacyShootingDays] needs none:
  /// every replica performs the same deterministic derivation.
  ///
  /// This is the **only lossless step** the whole schema version 18 migration takes: nothing here is
  /// materialised out of nothing (the way `screenplays.number` is) and nothing is discarded (the way
  /// `shooting_days.screenplayId` is) — the fact `roles.screenplayId` already carries is simply
  /// rewritten into the shape `role_episodes` holds it in from here on. A tombstoned role gets no
  /// link: it named no episode worth carrying forward, tombstoned or not.
  ///
  /// Guarded by `from >= 6` at its call site: a file older than that has just had `roles` created
  /// fresh, empty and already without a `screenplayId` column, so there is nothing here to derive
  /// from. **Must run before** the `roles.screenplayId` column is dropped.
  ///
  /// Written in raw SQL rather than through the generated API, for the reason [_backfillSortKeys]
  /// gives.
  Future<void> _deriveRoleEpisodes() async {
    final rows = await customSelect('SELECT id, screenplay_id FROM roles WHERE is_deleted = 0').get();

    for (final row in rows) {
      await customStatement(
        'INSERT INTO role_episodes (id, role_id, screenplay_id) VALUES (?, ?, ?)',
        [row.data['id'], row.data['id'], row.data['screenplay_id']],
      );
    }
  }

  /// Drops `roles.screenplayId` (guarded `from >= 6`) and `shooting_days.screenplayId` (guarded
  /// `from >= 11`), on the way to schema version 18 — the same [Migrator.alterTable]/
  /// `TableMigration` recipe [_alterScheduleTablesToV13] uses, and for the same reason: drift's
  /// migrator has no plain "drop column" step. Neither call passes `newColumns`, since nothing is
  /// being added, only dropped — the stock rewrite (create the current shape under a temporary name,
  /// copy the columns that still exist, drop the old table, rename the temporary one) is all either
  /// table needs.
  ///
  /// Each guard mirrors the table's own creation point in this migration: a file below 6 has just
  /// had `roles` created fresh above, from the current (already column-less) declaration, and one
  /// below 11 has just had `shooting_days` created the same way — only a file that genuinely carried
  /// the column this far still has one for this to drop.
  ///
  /// [_deriveRoleEpisodes] must already have run for `roles` by the time this is called — see the
  /// call site in [migration]. Nothing is reconstructed here: a role simply stops naming a
  /// screenplay of its own (the production names it now, through `role_episodes`), and a day comes
  /// back with everything it held, simply belonging to no episode any more.
  Future<void> _alterRoleAndShootingDayTablesToV18(Migrator m, {required int from}) async {
    if (from >= 6) {
      await m.alterTable(
        // TableMigration is drift's documented, if still @experimental, recipe for a column drop:
        // see the method's own doc comment.
        // ignore: experimental_member_use
        TableMigration(ocptRolesTable),
      );
    }

    if (from >= 11) {
      await m.alterTable(
        // Same as above.
        // ignore: experimental_member_use
        TableMigration(ocptShootingDaysTable),
      );
    }
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
