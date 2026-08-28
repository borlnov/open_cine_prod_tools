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
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_allowances_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_commitments_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_entries_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_lines_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_mileage_rates_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_postes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_resources_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_revenues_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_budget_shares_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_elements_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_local_erasures_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_location_availabilities_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_positions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_skills_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_person_unavailabilities_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_dictionary_words_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_versions_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_role_candidates_table.dart';
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
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_block_candidates_table.dart';
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
// OcptShootingSlotAnchorEdgeConverter, OcptScreenplayLanguageConverter,
// OcptRoleCandidateStatusConverter, OcptShootingDayKindConverter,
// OcptBudgetCommitmentStatusConverter, OcptBudgetResourceGroupKindConverter,
// OcptBudgetResourceStatusConverter, OcptBudgetRevenueStatusConverter,
// OcptBudgetAllowanceKindConverter), but
// the generated ocpt_project_database.g.dart
// part file below references them directly: since a part file shares its main library's imports
// rather than having its own, they must be imported here too for that generated code to resolve.
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
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
/// whole point of a shared schedule. Schema version 19 adds
/// `project_info.screenplayLanguage`, the language a project's screenplays are written in
/// ([OcptScreenplayLanguage]) — nullable, since "nobody has said" is as true after the migration as
/// it was before it, exactly the reading [OcptProjectInfoTable.minimumRestMinutes] already carries
/// — and, alongside it, [OcptProjectDictionaryWordsTable], the words a writer has taught this
/// project's spell checker. Schema version 20 adds [OcptRoleCandidatesTable], the people seen for a
/// part before `roles.personId` can be filled in — a link between `roles` and `people` carrying the
/// status, the audition date and the notes a casting decision is made on. Schema version 24 is what
/// a day puts in its timetable when it is not shooting: [OcptShootingBlockCandidatesTable], the
/// candidacies an `audition` block sees — the one convocation in this app read off a block rather
/// than off a slot (ADR 0024). It is additive and nothing is backfilled: a project reaching this
/// version has no audition planned anywhere, this app having had no way to plan one. Versions 23
/// and 24 also take back the four columns and the one table intermediate builds of that same,
/// unmerged work briefly carried — `shooting_days.kind`, `shooting_day_blocks.role_candidate_id`,
/// `shooting_day_blocks.role_id` and `shooting_slot_candidates` — see the migration's own
/// comments.
/// Schema version 25 adds the budget mode's foundations: [OcptBudgetPostesTable] and
/// [OcptBudgetLinesTable], the seeded-then-editable CNC nomenclature and its quote lines, plus
/// three nullable [OcptProjectInfoTable] columns the mode reads (`defaultVatRateBasisPoints`,
/// `mealPriceCents`, `snackPriceCents`) — nobody has recorded any of the three until a production
/// says otherwise, the same reading `screenplayLanguage` above already carries.
/// Schema version 26 adds the budget mode's cash journal: [OcptBudgetEntriesTable], the movements
/// that actually left or entered the account, and [OcptBudgetCommitmentsTable], money committed
/// against a poste but not yet paid — plus [OcptAssetsTable.budgetEntryId], naming the entry a
/// receipt asset ([OcptAssetKind.receipt]) stands as the voucher for.
/// Schema version 27 adds the budget mode's financing plan: [OcptBudgetMileageRatesTable], the
/// per-kilometre rates a production names for itself (no scale is seeded — see that table's own
/// doc comment), and [OcptBudgetResourcesTable], the subsidies, cash and in-kind contributions
/// financing the production — plus [OcptBudgetEntriesTable.resourceId], naming which of those a
/// journal movement settles, and [OcptPeopleTable.commuteKmMilli]/`.mileageRateId`, a person's own
/// one-way commute and the rate that applies to them.
/// Schema version 28 adds the budget mode's revenue sharing: [OcptBudgetRevenuesTable], the takings
/// the production expects, and [OcptBudgetSharesTable], the participants splitting what they bring
/// in — plus [OcptBudgetEntriesTable.revenueId]/`.shareId`, naming which taking a journal credit is
/// the actual cash for and which participant a debit actually pays.
/// Schema version 29 adds two nullable columns, both read the way `screenplayLanguage` already is
/// — null means "nobody has said", never a claim about the fact itself:
/// [OcptBudgetResourcesTable.personId], naming the person a financing resource comes from, so
/// several separate contributions from one lender can be added up (a subsidy names nobody, which
/// is why it stays nullable), and [OcptProjectInfoTable.isBudgetSimplified], the budget mode's
/// simplified/detailed toggle, until now held in memory alone and lost on every close.
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
    OcptRoleCandidatesTable,
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
    OcptShootingBlockCandidatesTable,
    OcptShootingDayEventsTable,
    OcptProjectDictionaryWordsTable,
    OcptBudgetPostesTable,
    OcptBudgetLinesTable,
    OcptBudgetEntriesTable,
    OcptBudgetCommitmentsTable,
    OcptBudgetMileageRatesTable,
    OcptBudgetResourcesTable,
    OcptBudgetRevenuesTable,
    OcptBudgetSharesTable,
    OcptBudgetAllowancesTable,
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

  /// The schema version this build of the app writes, readable without a database to hand.
  ///
  /// [schemaVersion] is drift's own instance getter, and the compatibility gate has to know this
  /// number **before** any database exists — its whole point is to read a file's own
  /// `PRAGMA user_version` and compare it to this one while nothing has been opened yet.
  static const currentSchemaVersion = 35;

  /// {@macro drift.GeneratedDatabase.schemaVersion}
  @override
  int get schemaVersion => currentSchemaVersion;

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
  /// two at once. From 18 to 19 it adds `project_info.screenplayLanguage`
  /// **unconditionally** (`project_info` has existed, and been alterable, since version 1, exactly
  /// the reason `project_info.minimumRestMinutes` above needed no guard) and gets no backfill: the
  /// column is nullable by design, and null after this migration is exactly as true a reading —
  /// "nobody has said" — as it was the moment before it, the same reading
  /// `people.maxDailyPresenceMinutes` and `project_info.minimumRestMinutes` itself already carry.
  /// The same step also creates [OcptProjectDictionaryWordsTable], the words a writer has taught
  /// this project's spell checker — a plain `createTable` on a file coming from any version, since
  /// nothing a project already held needs migrating into it. From 19 to 20 it creates
  /// [OcptRoleCandidatesTable], the people seen for a part: another plain `createTable` on a file
  /// coming from any version, both tables it references (`roles` and `people`) existing by version
  /// 6 and being created fresh above for a file older than that — and nothing to backfill either, a
  /// project migrating onto this version having kept its casting somewhere this app has never been
  /// able to read. From 23 to 24 it creates
  /// `shooting_block_candidates`, the candidacies an `audition` block sees — a plain `createTable`
  /// on a file coming from any version, with nothing to backfill, a project reaching this version
  /// having had no way to plan an audition. From 24 to 25 it creates
  /// [OcptBudgetPostesTable] and [OcptBudgetLinesTable] — both plain `createTable`s on a file coming
  /// from any version, since the tables either one references (`budget_postes` itself, created just
  /// above it in this same step, and `elements`, which exists by version 6 at the latest and is
  /// created fresh above for a file older than that) always exist by the time each runs — and adds
  /// `project_info.defaultVatRateBasisPoints`, `project_info.mealPriceCents` and
  /// `project_info.snackPriceCents` **unconditionally** (`project_info` has existed, and been
  /// alterable, since version 1, exactly the reason `project_info.minimumRestMinutes` and
  /// `project_info.screenplayLanguage` above needed no guard). None of the five gets a backfill: the
  /// two tables come out empty, and all three columns are nullable by design, so a project that
  /// predates the budget has no budget and has recorded none of the three figures, which stays as
  /// true after the migration as it was before it. From 25 to 26 it creates
  /// [OcptBudgetEntriesTable] and [OcptBudgetCommitmentsTable] — both plain `createTable`s on a
  /// file coming from any version, since the only table either one references (`budget_postes`)
  /// exists by version 25 at the latest — and adds `assets.budgetEntryId`, guarded `from >= 6` for
  /// the reason `assets.validFrom`/`assets.validUntil` above are. From 26 to 27 it creates
  /// [OcptBudgetMileageRatesTable] and [OcptBudgetResourcesTable] — both plain `createTable`s
  /// referencing nothing, so their own order is free — and adds `budget_entries.resourceId`,
  /// guarded `from >= 26` for the reason `assets.budgetEntryId` above is, and
  /// `people.commuteKmMilli`/`people.mileageRateId`, guarded `from >= 6` for the reason
  /// `people.maxDailyPresenceMinutes` (version 16) is; [OcptBudgetMileageRatesTable] is created
  /// before that `people` column is added, and [OcptBudgetResourcesTable] before
  /// `budget_entries.resourceId` is, since each new column references the table just created. None
  /// of the five gets a backfill: the two tables come out empty, and all three columns are nullable
  /// by design, so a project that predates this step has recorded none of the three, which stays as
  /// true after the migration as it was before it. From 27 to 28 it creates [OcptBudgetRevenuesTable]
  /// and [OcptBudgetSharesTable] — both plain `createTable`s referencing nothing, so their own order
  /// is free — and adds `budget_entries.revenueId`/`budget_entries.shareId`, guarded `from >= 26` for
  /// the reason `assets.budgetEntryId` above is: a file older than 26 has just had `budget_entries`
  /// created fresh above, from the current declaration, so it already carries both columns. Neither
  /// table gets a backfill, coming out empty, and neither column does either, staying null: a project
  /// that predates the sharing view has named no taking and no participant, which stays as true after
  /// the migration as it was before it. Every step is additive, as
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

      if (from < 19) {
        // `project_info` has existed, and been alterable, since version 1: no guard needed,
        // exactly as `project_info.minimumRestMinutes` above needed none.
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.screenplayLanguage);

        // The table a project's learned words live in didn't exist before this version, on any
        // file: a plain `createTable`, exactly as `OcptRoleElementsTable` (version 14 to 15) got
        // one, with nothing to backfill — a project migrating onto this version has taught its
        // spell checker nothing yet.
        await m.createTable(ocptProjectDictionaryWordsTable);
      }

      if (from < 20) {
        // Both tables it references — `roles` and `people` — exist by version 6, and a file older
        // than that has just had them created above, so this is never a forward reference. Nothing
        // to backfill: a project reaching this version kept the people it saw for a part somewhere
        // this app has never been able to read.
        await m.createTable(ocptRoleCandidatesTable);
      }

      if (from < 23) {
        // The two columns a **build that never merged** wrote, and nothing else: `shooting_days
        // .kind` and `shooting_day_blocks.role_candidate_id` were added by intermediate versions of
        // this very branch and taken back out before it landed — a day mixes casting, rehearsal and
        // shooting, and says so through its blocks, so neither column had anything left to say. No
        // released build ever wrote either, so the only files carrying them are the ones this
        // branch was developed against; [_dropColumnIfPresent] is what makes running this against
        // any other file a no-op rather than an error.
        await _dropColumnIfPresent(table: 'shooting_days', column: 'kind');
        await _dropColumnIfPresent(
          table: 'shooting_day_blocks',
          column: 'role_candidate_id',
        );
      }

      if (from < 24) {
        // The same **build that never merged** as the `from < 23` step above, one round later: a
        // candidate was briefly convoked on the whole slot, and an audition block briefly named the
        // single part it saw. Both are gone — somebody is expected at twenty past ten, and a block
        // reading two actors of two different parts could never have named one part. No released
        // build ever wrote either, so these too are dropped defensively rather than migrated, and
        // nothing carries their rows over. Dropped *before* the table below is created, so nothing
        // new ever references a shape still being reshaped.
        await _dropTableIfPresent(table: 'shooting_slot_candidates');
        await _dropColumnIfPresent(table: 'shooting_day_blocks', column: 'role_id');

        // Follows every table it references: `shooting_day_blocks` exists by version 11 (or was
        // created fresh above for a file older than that), and `role_candidates` by version 20 —
        // created by the `from < 20` step above for every file that had not reached it. Nothing to
        // backfill: a project migrating onto this version has convoked no candidate anywhere, this
        // app having had no way to convoke one.
        await m.createTable(ocptShootingBlockCandidatesTable);
      }

      if (from < 25) {
        // `budget_postes` references nothing, and `budget_lines` references `budget_postes`
        // (created just above) and `elements` (which exists by version 6 at the latest, and is
        // created fresh above for a file older than that): neither `createTable` is ever a forward
        // reference.
        await m.createTable(ocptBudgetPostesTable);
        await m.createTable(ocptBudgetLinesTable);

        // `project_info` has existed, and been alterable, since version 1: no guard needed, exactly
        // as `project_info.minimumRestMinutes` and `project_info.screenplayLanguage` above needed
        // none.
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.defaultVatRateBasisPoints);
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.mealPriceCents);
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.snackPriceCents);
      }

      if (from < 26) {
        // `budget_entries` references `budget_postes` (created fresh above for a file older than
        // 25, or already in place otherwise), and `budget_commitments` references `budget_postes`
        // and `budget_entries` (created just above it): neither `createTable` is ever a forward
        // reference.
        await m.createTable(ocptBudgetEntriesTable);
        await m.createTable(ocptBudgetCommitmentsTable);

        // `assets` has existed, and been alterable, since version 6 — a file older than that has
        // just had it created fresh above, from the current declaration, and already carries this
        // column. Guarded `from >= 6` for the same reason `assets.validFrom`/`assets.validUntil`
        // are above.
        if (from >= 6) {
          await m.addColumn(ocptAssetsTable, ocptAssetsTable.budgetEntryId);
        }
      }

      if (from < 27) {
        // Neither table references the other, so their own order is free; what matters is that
        // each is created before the column that references it is added, below: `people` may name
        // a `budget_mileage_rates` row, and `budget_entries` may name a `budget_resources` row.
        await m.createTable(ocptBudgetMileageRatesTable);
        await m.createTable(ocptBudgetResourcesTable);

        // `people` has existed, and been alterable, since version 6 — a file older than that has
        // just had it created fresh above, from the current declaration, so it already carries both
        // columns. Guarded `from >= 6` for the same reason `people.maxDailyPresenceMinutes`
        // (version 16) is.
        if (from >= 6) {
          await m.addColumn(ocptPeopleTable, ocptPeopleTable.commuteKmMilli);
          await m.addColumn(ocptPeopleTable, ocptPeopleTable.mileageRateId);
        }

        // `budget_entries` has existed, and been alterable, since version 26 — a file older than
        // that has just had it created fresh above, from the current declaration, so it already
        // carries the column. Guarded `from >= 26` for the reason `assets.budgetEntryId` above is
        // guarded `from >= 6`.
        if (from >= 26) {
          await m.addColumn(ocptBudgetEntriesTable, ocptBudgetEntriesTable.resourceId);
        }
      }

      if (from < 28) {
        // Neither table references the other, so their own order is free; what matters is that
        // each is created before the column that references it is added, below: `budget_entries`
        // may name a `budget_revenues` row and a `budget_shares` row.
        await m.createTable(ocptBudgetRevenuesTable);
        await m.createTable(ocptBudgetSharesTable);

        // `budget_entries` has existed, and been alterable, since version 26 — a file older than
        // that has just had it created fresh above, from the current declaration, so it already
        // carries both columns. Guarded `from >= 26` for the reason `assets.budgetEntryId` above is
        // guarded `from >= 6`.
        if (from >= 26) {
          await m.addColumn(ocptBudgetEntriesTable, ocptBudgetEntriesTable.revenueId);
          await m.addColumn(ocptBudgetEntriesTable, ocptBudgetEntriesTable.shareId);
        }
      }

      if (from < 29) {
        // `project_info` has existed, and been alterable, since version 1: no guard needed, exactly
        // as `project_info.minimumRestMinutes` and `project_info.screenplayLanguage` above needed
        // none.
        await m.addColumn(ocptProjectInfoTable, ocptProjectInfoTable.isBudgetSimplified);

        // `budget_resources` has existed, and been alterable, since version 27 — a file older than
        // that has just had it created fresh above, from the current declaration, so it already
        // carries the column. Guarded `from >= 27` for the reason `assets.budgetEntryId` above is
        // guarded `from >= 6`.
        if (from >= 27) {
          await m.addColumn(ocptBudgetResourcesTable, ocptBudgetResourcesTable.personId);
        }
      }

      if (from < 30) {
        // The first migration step of this file that **rewrites values rather than the shape** they
        // are stored in: `budget_resources.status` stopped naming a word and started naming a step.
        // A financing resource's status used to be one of four words shared by all three groups
        // (`applied`, `notified`, `secured`, `valued`), which asked a production to call a lent
        // camera "applied for"; it is now one of three steps (`pending`, `agreed`, `confirmed`)
        // whose word is resolved from the group the row sits in, so a subsidy reads `Secured` where
        // a contribution in kind reads `Signed`. `OcptBudgetResourceStatus`'s own doc comment
        // argues it.
        //
        // The mapping keeps every row at the step its old word actually stated, and `valued` — the
        // one word that was already a group's rather than a step's — lands on `agreed`, which is
        // exactly what it said: a figure is on this resource, nothing is signed. **Nothing is
        // invented**: no row changes group, no row moves forward or back a step, and a status the
        // user typed is never replaced by a default.
        //
        // The column is **rebuilt**, not merely updated in place, because the words also live in
        // its own `DEFAULT`, which SQLite gives no way to alter: a file that kept `DEFAULT
        // 'applied'` would write a retired word onto the next resource created in it, and
        // `OcptBudgetResourceStatusConverter` reads the column strictly. Adding the column afresh,
        // filling it, dropping the old one and taking its name is the whole of it — four
        // statements that touch no other table, since nothing references `budget_resources.status`,
        // and that land this file on exactly the declaration `onCreate` writes.
        //
        // Guarded `from >= 27` for the reason every `addColumn` above is: a file older than that
        // has just had the table created fresh, from the current declaration, so its column is
        // already the new one and adding a second would fail.
        if (from >= 27) {
          await customStatement(
            "ALTER TABLE budget_resources ADD COLUMN status_step TEXT NOT NULL DEFAULT 'pending'",
          );
          await customStatement(
            "UPDATE budget_resources SET status_step = CASE status "
            "WHEN 'applied' THEN 'pending' "
            "WHEN 'notified' THEN 'agreed' "
            "WHEN 'secured' THEN 'confirmed' "
            "WHEN 'valued' THEN 'agreed' "
            "ELSE status END",
          );
          await customStatement('ALTER TABLE budget_resources DROP COLUMN status');
          await customStatement(
            'ALTER TABLE budget_resources RENAME COLUMN status_step TO status',
          );
        }
      }

      if (from < 31) {
        // One table, referencing `people` alone — created above for a file older than version 6 —
        // so this is never a forward reference. Nothing else changes: the defrayals replace a
        // *computation* the régie view used to do in memory, never a column.
        await m.createTable(ocptBudgetAllowancesTable);
      }

      if (from < 32) {
        // `budget_lines` has existed, and been alterable, since version 25 — a file older than
        // that has just had it created fresh above, from the current declaration, so it already
        // carries both columns. Guarded `from >= 25` for the reason `assets.budgetEntryId` above
        // is guarded `from >= 6`.
        //
        // Both arrive **null on every existing line**, which is the truthful reading: no line of
        // any project was ever written by the provisioning, since there was none.
        if (from >= 25) {
          await m.addColumn(ocptBudgetLinesTable, ocptBudgetLinesTable.provisionKey);
          await m.addColumn(ocptBudgetLinesTable, ocptBudgetLinesTable.provisionDigest);
        }
      }

      if (from < 33) {
        // `budget_commitments` has existed, and been alterable, since version 26; an older file
        // has just had it created fresh above, from the current declaration, so it already carries
        // the column. Guarded for the reason `assets.budgetEntryId` above is guarded.
        //
        // It arrives **null on every existing commitment**, which is the truthful reading: not one
        // of them was promoted from a quote line, since nothing could be.
        if (from >= 26) {
          await m.addColumn(ocptBudgetCommitmentsTable, ocptBudgetCommitmentsTable.lineId);
        }
      }

      if (from < 34) {
        // `budget_postes` has existed, and been alterable, since version 25 — a file older than
        // that has just had it created fresh above, from the current declaration, so it already
        // carries the column. Guarded for the reason `assets.budgetEntryId` above is guarded.
        //
        // It arrives **null on every existing poste**, which is the truthful reading: nobody has
        // ever judged a poste's estimate to complete, there being no way to before this column
        // existed.
        if (from >= 25) {
          await m.addColumn(ocptBudgetPostesTable, ocptBudgetPostesTable.estimateToCompleteCents);
        }
      }

      if (from < 35) {
        // `budget_entries` has existed, and been alterable, since version 26 — a file older than
        // that has just had it created fresh above, from the current declaration, so it already
        // carries both columns. Guarded for the reason `assets.budgetEntryId` above is guarded.
        if (from >= 26) {
          await m.addColumn(ocptBudgetEntriesTable, ocptBudgetEntriesTable.commitmentId);
          await m.addColumn(ocptBudgetEntriesTable, ocptBudgetEntriesTable.personId);

          // Carried over **before** the column it came from goes: every commitment that named a
          // settling entry (`settled_entry_id`, the only place this fact was ever recorded before
          // this step) writes its own id onto that entry's freshly added `commitment_id` — a
          // payment recorded as one instalment before this step reads as exactly one after it too.
          // Nothing is invented for an entry no commitment ever named, and nothing is lost for a
          // commitment that named no entry at all: both simply keep the null they already read as.
          await customStatement(
            'UPDATE budget_entries SET commitment_id = '
            '(SELECT id FROM budget_commitments WHERE budget_commitments.settled_entry_id = '
            'budget_entries.id) '
            'WHERE EXISTS '
            '(SELECT 1 FROM budget_commitments WHERE budget_commitments.settled_entry_id = '
            'budget_entries.id)',
          );

          // `budget_commitments.settled_entry_id` is retired: settlement is read off
          // `budget_entries.commitment_id` from here on, never a link the commitment itself
          // stores. Dropped through `TableMigration` rather than a plain `ALTER TABLE … DROP
          // COLUMN` (the recipe version 30's own rewrite above uses on `budget_resources.status`):
          // that column carries no foreign key, and this one does — see
          // `_alterRoleAndShootingDayTablesToV18`'s own doc comment for why a column that is also
          // a foreign key needs the full rebuild recipe instead.
          await m.alterTable(
            // TableMigration is drift's documented, if still @experimental, recipe for a column
            // drop: see this block's own comment above.
            // ignore: experimental_member_use
            TableMigration(ocptBudgetCommitmentsTable),
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Drops [column] from [table], if that table actually carries it, and does nothing at all
  /// otherwise.
  ///
  /// The one migration helper in this file that **asks the file what it holds** rather than
  /// deducing it from the version it states, and deliberately: the two columns it is used on were
  /// written by intermediate builds of one unmerged branch, so the version number a file states
  /// says nothing about whether it has them — one project made against that branch does, one made
  /// against the release before it does not, and both state a number below 23.
  ///
  /// Written in raw SQL for the reason [_backfillSortKeys] gives, and because a column that is no
  /// longer declared in Dart cannot be named through the generated API at all.
  Future<void> _dropColumnIfPresent({required String table, required String column}) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final hasColumn = columns.any((row) => row.data['name'] == column);
    if (!hasColumn) {
      return;
    }

    await customStatement('ALTER TABLE "$table" DROP COLUMN "$column"');
  }

  /// Drops [table] entirely, if this file actually carries it, and does nothing at all otherwise.
  ///
  /// [_dropColumnIfPresent]'s sibling, there for exactly the same reason and used on exactly the
  /// same kind of thing: `shooting_slot_candidates` was created by an intermediate build of one
  /// unmerged branch and taken back out before it landed, so the version a file states says nothing
  /// about whether it holds the table. `DROP TABLE IF EXISTS` would do here, but asking
  /// `sqlite_master` keeps this reading the same way its sibling does — and says in one place what
  /// "if present" means.
  Future<void> _dropTableIfPresent({required String table}) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).get();
    if (rows.isEmpty) {
      return;
    }

    await customStatement('DROP TABLE "$table"');
  }

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
        // Same as above: `shooting_days` loses its own `screenplay_id`, every other column being
        // copied straight across.
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
