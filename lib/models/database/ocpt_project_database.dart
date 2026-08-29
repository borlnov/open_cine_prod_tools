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
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

part 'ocpt_project_database.g.dart';

/// The per-project SQLite database backing a single `.ocpt` project file.
///
/// Every Open Cine Prod Tools project is one such database. It holds: the project metadata
/// ([OcptProjectInfoTable], including the app version that last created or migrated the file);
/// its screenplay(s) ([OcptScreenplaysTable]) and safety copies of their
/// text ([OcptScreenplaySnapshotsTable]); the reconciled scene index ([OcptScenesTable]) and the
/// shot list built on top of it ([OcptShotsTable], [OcptShotCharactersTable],
/// [OcptShotCoveragesTable]); the resources mode's catalogue — the address book
/// ([OcptPeopleTable] and its [OcptPersonPositionsTable]/[OcptPersonSkillsTable]/
/// [OcptPersonUnavailabilitiesTable] siblings), the cast ([OcptRolesTable],
/// [OcptRoleEpisodesTable], [OcptRoleCandidatesTable], [OcptRoleElementsTable]), locations and
/// their sets ([OcptLocationsTable], [OcptLocationAvailabilitiesTable], [OcptSetsTable],
/// [OcptSceneSetsTable]), the physical elements catalogue ([OcptElementsTable],
/// [OcptSceneElementsTable]), the binary asset references ([OcptAssetsTable]) and the local,
/// never-synchronised record of erased people ([OcptLocalErasuresTable]); the breakdown pass's own
/// tables — the tags anchoring a passage of a scene to a catalogue row ([OcptBreakdownTagsTable])
/// and each scene's breakdown status ([OcptSceneBreakdownsTable]); the schedule mode's own tables —
/// the shooting days ([OcptShootingDaysTable]), the convocation windows inside them
/// ([OcptShootingSlotsTable]), who is convoked during one — crew ([OcptShootingSlotCrewTable]),
/// cast ([OcptShootingSlotCastTable]) and guests ([OcptShootingSlotGuestsTable]) — each day's
/// timetable ([OcptShootingDayBlocksTable]) and its candidacies
/// ([OcptShootingBlockCandidatesTable]), and what a day does not control, at an absolute hour
/// ([OcptShootingDayEventsTable]); the budget mode — the seeded-then-editable CNC nomenclature and
/// its quote lines ([OcptBudgetPostesTable], [OcptBudgetLinesTable]), the cash journal
/// ([OcptBudgetEntriesTable], [OcptBudgetCommitmentsTable]), the financing plan
/// ([OcptBudgetMileageRatesTable], [OcptBudgetResourcesTable]), the revenue sharing
/// ([OcptBudgetRevenuesTable], [OcptBudgetSharesTable]) and the per-diem allowances
/// ([OcptBudgetAllowancesTable]); the writer's own project dictionary
/// ([OcptProjectDictionaryWordsTable]); the user's named project versions
/// ([OcptProjectVersionsTable]); and the per-column version stamps a merge resolves conflicts with
/// ([OcptRowFieldVersionsTable]).
///
/// All of it is created by `onCreate` at schema version 1: per
/// `docs/adr/0029-schema-versions-frozen-at-stable-releases.md`, no stable release has shipped yet,
/// so this build carries no pre-stable migration history. A future stable release cycle adds the
/// first real `onUpgrade` step, once the schema it wrote is a promise to a user's file rather than
/// workshop churn between developer machines.
///
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
  ///
  /// [currentSchemaVersion] and [lastStableSchemaVersion] together drive whether the next schema
  /// change overwrites the top migration file or creates a new one
  /// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`): when
  /// `currentSchemaVersion == lastStableSchemaVersion`, the top file is frozen — a stable release
  /// already shipped it — so a change **creates** a new
  /// `lib/models/database/migrations/ocpt_migration_v<n>.dart` and bumps [currentSchemaVersion];
  /// when `currentSchemaVersion == lastStableSchemaVersion + 1`, a development cycle is already
  /// open, so a change **overwrites** that top file in place instead. [currentSchemaVersion] is
  /// always one of those two values. Freezing a stable release is the one line
  /// `lastStableSchemaVersion = currentSchemaVersion`, done at release prep (see
  /// `docs/RELEASING.md`).
  static const currentSchemaVersion = 1;

  /// The highest schema version a stable release has frozen.
  ///
  /// See [currentSchemaVersion]'s own doc comment for the overwrite-vs-create rule these two
  /// constants drive together.
  static const lastStableSchemaVersion = 1;

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

  /// How an existing `.ocpt` file is brought up to the current [schemaVersion].
  ///
  /// Per `docs/adr/0029-schema-versions-frozen-at-stable-releases.md`, no stable release has ever
  /// shipped, so the schema carries no pre-stable migration history: `onCreate` creates the whole
  /// schema at once, at version 1, and `onUpgrade` has nothing to do — real `.ocpt` files are never
  /// found below this schema version. The first real `onUpgrade` step is written when a schema
  /// change is needed after a stable release has frozen [lastStableSchemaVersion], following the
  /// additive-only guidance `docs/adr/0007-schema-migration-policy.md` still gives for how a single
  /// step is written.
  ///
  /// `beforeOpen` turns SQLite's `foreign_keys` pragma on: `NativeDatabase` leaves it at SQLite's
  /// own default, which is off, so the `references()` declared on the tables above would otherwise
  /// never actually be enforced.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // No real `.ocpt` file is ever found below schema version 1 (ADR 0029: no stable
      // release has shipped, so there is no pre-stable migration history to carry), so this
      // has nothing to do yet.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
