// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// How `OcptProjectVersionsService` writes a payload into a database: a restore over the working
/// copy ([applyPayload]) and the hydration of an in-memory preview ([hydratePreview]).
///
/// The two sit in one file on purpose: every synchronised table has to reach both, and a table
/// added to one and forgotten in the other is a silent bug, so a reader changing one sees the
/// other.
///
/// Stateless, so a call takes the database it writes to and the services it needs.
abstract final class OcptProjectVersionsRestoreOps {
  /// Write [payload] over the project in [database], from inside
  /// `OcptProjectVersionsService.restoreVersion`'s transaction.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectVersionsService.restoreIsAnEdit}
  ///
  /// The tables are walked in dependency order — a screenplay before its scenes, a scene before the
  /// shots pointing at it — and `scenes` is the one that carries no stamp at all: ADR 0010 keeps it
  /// out of the merge entirely, since it is derived from the screenplay text and recomputed
  /// locally. Its rows still go back **verbatim, ids included**, which is what stops the restored
  /// `shots.sceneId` and `shot_coverages.sceneId` references from dangling; and a scene the payload
  /// doesn't carry is tombstoned rather than deleted, for the reason `OcptScenesTable.isDeleted`
  /// gives — the tombstoned shots and coverages still left over from the working copy reference it,
  /// and `PRAGMA foreign_keys` is on.
  ///
  /// `budget_mileage_rates` is restored **before** the twelve resources tables below, for the one
  /// reason it has to be: `people.mileageRateId` may name one of its rows, and a row the payload
  /// doesn't hold there would otherwise be a genuine forward reference this ordering could avoid
  /// paying for — unlike the asset trio further down, which cannot avoid it.
  ///
  /// The twelve resources tables follow, in the same dependency order the schema's own migration
  /// creates them in: `people` (and its `person_positions`/`person_skills`/
  /// `person_unavailabilities` siblings, each pointing at it) before `roles` (which may cast one),
  /// before `locations` (whose contact may be one) before the `sets` inside them, before
  /// `scene_sets` linking a scene to one, before `elements` (whose owner and bringer may be a
  /// person) before `scene_elements` linking a scene to one and `role_elements` linking a role to
  /// one, then `role_candidates` — the other link a role carries, onto the people seen for it —
  /// which names `roles` and `people` alike and so follows both, and `assets` last, since a person,
  /// a location or an element may name one as its photo or document before that row itself exists.
  /// `role_episodes` — which episode each role is named in
  /// (`docs/adr/0019-one-project-several-episodes.md`) — is restored right after `roles`, the table
  /// it names alongside `screenplays`: both are already restored by this point (`screenplays` at
  /// the very top, `roles` immediately above), so this is not a forward reference, and — unlike the
  /// asset trio below — it closes no foreign-key cycle of its own: nothing restored after
  /// `role_episodes` ever references it back. That last point is also where the ordering stops
  /// being fully satisfiable: `people`, `locations` and `elements` each reference `assets` (a
  /// photo, a permit, a document) while `assets` references all three back (whose photo or document
  /// it is) — a genuine foreign-key cycle, the same one `OcptAssetsTable`'s own doc comment
  /// describes for `CREATE TABLE`. No statement-by-statement ordering can satisfy every reference
  /// in a cycle, which is exactly why `OcptProjectVersionsService.restoreVersion` runs this under
  /// `PRAGMA defer_foreign_keys = ON`: every constraint is only checked at the transaction's
  /// commit, by which point every table above has been written in full.
  ///
  /// `breakdown_tags` and `scene_breakdowns` follow the resources tables, since a tag may point at
  /// an element, a role or a set, and both tables reference `scenes`: every one of those exists by
  /// this point, so — unlike `assets` — neither closes a foreign-key cycle of its own; the deferred
  /// pragma above is what the asset trio needs, not these two.
  ///
  /// The schedule tables follow last, in the same dependency order the schema's own v11 migration
  /// creates the five of them it still carries in, `shooting_slot_guests` and `shooting_day_events`
  /// (schema v17) slotted in beside the sibling each one follows: `shooting_days` (which may
  /// reference a screenplay already restored above) before `shooting_slots` (which may name a
  /// location or a set), before `shooting_slot_crew`/`shooting_slot_cast`/`shooting_slot_guests`
  /// (which each point at a slot, and at a person, a role or — nullable — a person respectively)
  /// and `shooting_day_blocks` (which points at a slot and, for a shot block, at a shot), then
  /// `shooting_block_candidates` (which points at a block, so it has to follow them, and at a
  /// candidacy restored back among the resources tables long before this group runs), and
  /// `shooting_day_events` last, referencing only a day. Every table it could possibly reference is
  /// restored by this point, so this is not a forward reference and closes no cycle of its own —
  /// the deferred pragma above is still what the asset trio further up needs, not this group.
  ///
  /// `project_dictionary_words` is restored next, and could just as well go anywhere else: it
  /// references nothing, and nothing else in the schema references it back, so there is no
  /// dependency order for it to respect.
  ///
  /// `budget_postes` and `budget_lines` are restored next: `budget_postes` references nothing, and
  /// `budget_lines` references `budget_postes` (restored immediately above it) and, optionally,
  /// `elements` (restored well above, inside the asset trio's own deferred-foreign-key cycle) — so
  /// neither is a forward reference, and this pair closes no cycle of its own either.
  ///
  /// `budget_resources` is restored next: it references nothing, and `budget_entries`, restored
  /// right after it, may name one of its rows through `resourceId` — the same reason
  /// `budget_mileage_rates` above is restored before `people`.
  ///
  /// `budget_revenues` and `budget_shares` follow, for the same reason again: `budget_revenues`
  /// references nothing, `budget_shares` only optionally references `people` (restored well above,
  /// inside the asset trio's own deferred-foreign-key cycle), and `budget_entries`, restored right
  /// after both, may name either of their rows through `revenueId`/`shareId`.
  ///
  /// `budget_commitments` and `budget_entries` are restored last, in that order:
  /// `budget_commitments` references only `budget_postes` (restored well above) and, optionally,
  /// `budget_lines` (restored well above too), so it closes no cycle of its own. `budget_entries`
  /// follows it — reversed from the order these two used to restore in, back when a commitment
  /// named its own settling entry rather than the other way round — since it may now name a
  /// commitment through `commitmentId`, beside `budget_postes`, `budget_resources`,
  /// `budget_revenues`, `budget_shares` (all restored above it already) and `people` (through
  /// `personId`, restored well above, inside the asset trio's own deferred-foreign-key cycle). None
  /// of these is a forward reference either. `assets.budgetEntryId`, restored well above this pair,
  /// names a `budget_entries` row that only exists once this method reaches here: a genuine forward
  /// reference, closed the same way the asset trio's own cycle is, by this whole restore running
  /// under `PRAGMA defer_foreign_keys = ON` (see `OcptProjectVersionsService.restoreVersion`).
  ///
  /// The five storyboard and floor plan tables are restored last, in their own dependency order:
  /// `floor_plan_sets` (references only `scenes`, restored at the very top, and optionally
  /// `assets`) before `storyboard_panels` (references `shots` and optionally `assets`, both
  /// restored well above) before `storyboard_annotations` (references the panel it marks, restored
  /// immediately above) before `floor_plan_symbols` (references `floor_plan_sets` and optionally
  /// `shots`, both restored above) before `floor_plan_arrows` last (references `floor_plan_sets`,
  /// `shots` and the two `floor_plan_symbols` rows it connects, all restored above it). None of the
  /// five closes a cycle of its own.
  ///
  /// [payload] arrives already scrubbed of every erased person:
  /// `OcptProjectVersionsService.loadPayload` is what does it, once, for every reader of a payload
  /// alike — see `OcptProjectVersionsPayloadOps.scrubErasedPeople`. None of the schedule tables
  /// holds a person's own data (a phone number, an address, an allergy) — only ids pointing at
  /// `people` and `roles`, `shooting_slot_guests.freeName` naming somebody the address book has
  /// never heard of — so there is nothing in them for that scrub to touch; `role_candidates`, above
  /// them, is the one link table that does hold some, and that scrub has already emptied it.
  static Future<void> applyPayload({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
    required OcptScreenplayService screenplayService,
    required String deviceId,
  }) async {
    final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
    stamps.raiseFloor(payload.rowFieldVersions);

    await snapshotScreenplaysAboutToChange(
      database: database,
      payload: payload,
      screenplayService: screenplayService,
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptScreenplaysTable,
      payloadRows: payload.screenplays,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptScenesTable,
      payloadRows: payload.scenes,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: null,
    );

    await restoreTable(
      database: database,
      table: database.ocptShotsTable,
      payloadRows: payload.shots,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShotCharactersTable,
      payloadRows: payload.shotCharacters,
      rowIdOf: (row) => ocptCompositeRowStampKey([row.shotId, row.roleId]),
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShotCoveragesTable,
      payloadRows: payload.shotCoverages,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `budget_mileage_rates` references nothing, and `people`, restored right after it, may name
    // one of its rows through `mileageRateId`.
    await restoreTable(
      database: database,
      table: database.ocptBudgetMileageRatesTable,
      payloadRows: payload.budgetMileageRates,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptPeopleTable,
      payloadRows: payload.people,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptPersonPositionsTable,
      payloadRows: payload.personPositions,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptPersonSkillsTable,
      payloadRows: payload.personSkills,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptPersonUnavailabilitiesTable,
      payloadRows: payload.personUnavailabilities,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptRolesTable,
      payloadRows: payload.roles,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptRoleEpisodesTable,
      payloadRows: payload.roleEpisodes,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptLocationsTable,
      payloadRows: payload.locations,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptLocationAvailabilitiesTable,
      payloadRows: payload.locationAvailabilities,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptSetsTable,
      payloadRows: payload.sets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptSceneSetsTable,
      payloadRows: payload.sceneSets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptElementsTable,
      payloadRows: payload.elements,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptSceneElementsTable,
      payloadRows: payload.sceneElements,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptRoleElementsTable,
      payloadRows: payload.roleElements,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptRoleCandidatesTable,
      payloadRows: payload.roleCandidates,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptAssetsTable,
      payloadRows: payload.assets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptBreakdownTagsTable,
      payloadRows: payload.breakdownTags,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptSceneBreakdownsTable,
      payloadRows: payload.sceneBreakdowns,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingDaysTable,
      payloadRows: payload.shootingDays,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingSlotsTable,
      payloadRows: payload.shootingSlots,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingSlotCrewTable,
      payloadRows: payload.shootingSlotCrew,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingSlotCastTable,
      payloadRows: payload.shootingSlotCast,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingSlotGuestsTable,
      payloadRows: payload.shootingSlotGuests,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingDayBlocksTable,
      payloadRows: payload.shootingDayBlocks,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // After the blocks it hangs off, unlike every slot-level link above: a candidacy is named on an
    // audition **block** (ADR 0024), so restoring it first would point at a row this very method
    // has not written yet.
    await restoreTable(
      database: database,
      table: database.ocptShootingBlockCandidatesTable,
      payloadRows: payload.shootingBlockCandidates,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptShootingDayEventsTable,
      payloadRows: payload.shootingDayEvents,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `project_dictionary_words` references nothing, and nothing references it back, so it needs
    // no particular place in this dependency order: last is as good as any.
    await restoreTable(
      database: database,
      table: database.ocptProjectDictionaryWordsTable,
      payloadRows: payload.projectDictionaryWords,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `budget_postes` references nothing, and `budget_lines` references `budget_postes` (restored
    // just above) and, optionally, `elements` (restored well above, inside the asset trio's own
    // deferred-foreign-key cycle) — neither is a forward reference.
    await restoreTable(
      database: database,
      table: database.ocptBudgetAccountsTable,
      payloadRows: payload.budgetAccounts,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptBudgetLinesTable,
      payloadRows: payload.budgetLines,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `budget_resources` references nothing, and `budget_entries`, restored right after it, may
    // name one of its rows through `resourceId`.
    await restoreTable(
      database: database,
      table: database.ocptBudgetResourcesTable,
      payloadRows: payload.budgetResources,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `budget_revenues` references nothing, and `budget_shares` only optionally references
    // `people` (restored well above): `budget_entries`, restored right after both, may name either
    // of their rows through `revenueId`/`shareId`.
    await restoreTable(
      database: database,
      table: database.ocptBudgetRevenuesTable,
      payloadRows: payload.budgetRevenues,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptBudgetSharesTable,
      payloadRows: payload.budgetShares,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptBudgetAllowancesTable,
      payloadRows: payload.budgetAllowances,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptBudgetCommitmentsTable,
      payloadRows: payload.budgetCommitments,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await restoreTable(
      database: database,
      table: database.ocptBudgetEntriesTable,
      payloadRows: payload.budgetEntries,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `floor_plan_sets` references only `scenes` (restored at the very top) and, optionally,
    // `assets` (restored well above, inside the asset trio's own deferred-foreign-key cycle) — not
    // a forward reference either way.
    await restoreTable(
      database: database,
      table: database.ocptFloorPlanSetsTable,
      payloadRows: payload.floorPlanSets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `storyboard_panels` references `shots` and, optionally, `assets` — both restored well above —
    // so it follows both.
    await restoreTable(
      database: database,
      table: database.ocptStoryboardPanelsTable,
      payloadRows: payload.storyboardPanels,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `storyboard_annotations` references the panel it marks, restored immediately above.
    await restoreTable(
      database: database,
      table: database.ocptStoryboardAnnotationsTable,
      payloadRows: payload.storyboardAnnotations,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `floor_plan_symbols` references `floor_plan_sets` (restored above) and, optionally, `shots`
    // (restored well above) — not a forward reference either way.
    await restoreTable(
      database: database,
      table: database.ocptFloorPlanSymbolsTable,
      payloadRows: payload.floorPlanSymbols,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    // `floor_plan_arrows` references `floor_plan_sets`, `shots` and the two `floor_plan_symbols`
    // rows it connects — the last of them restored immediately above, so it comes last.
    await restoreTable(
      database: database,
      table: database.ocptFloorPlanArrowsTable,
      payloadRows: payload.floorPlanArrows,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await stamps.flush(database);
  }

  /// Write [payload] into [database], an empty [OcptProjectDatabase.memory] opened for a preview,
  /// so the modes find the version's state exactly where they usually find the working copy's.
  ///
  /// [projectInfo] is the working copy's own header: the preview keeps the project's name, its
  /// creation date and the app version that created it, and takes only what the payload owns — the
  /// page format, the currency and the free-form settings. Its `currentVersionId` is deliberately
  /// left null, since the preview database holds no `project_versions` row for it to point at.
  ///
  /// The rows go in verbatim, tombstones and primary keys included, in dependency order and within
  /// a single transaction: a half-hydrated preview must never be shown. The page **margins** the
  /// payload carries are not written here — they are an app-wide preference, and a preview never
  /// touches the user's preferences (they travel on `OcptOpenProjectModel.previewedPageSetup`
  /// instead).
  static Future<void> hydratePreview({
    required OcptProjectDatabase database,
    required OcptProjectInfoRow projectInfo,
    required OcptProjectVersionPayload payload,
  }) => database.transaction(() async {
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: projectInfo.name,
            createdAt: projectInfo.createdAt,
            appVersionAtCreation: projectInfo.appVersionAtCreation,
            pageFormat: payload.pageSetup.format,
            settingsJson: Value(payload.settingsJson),
            // A payload predating currencies (format 2 or earlier) carries no currency of its own
            // to preview: the schema's own default reads as truthfully as anything else can for a
            // moment currencies didn't exist yet.
            currencyCode: Value(payload.currencyCode ?? ocptDefaultCurrencyCode),
            // Unlike the currency, a null here is never "this payload predates the column" — it is
            // exactly as truthful on a live capture as on an old one — so it previews verbatim,
            // null included.
            minimumRestMinutes: Value(payload.minimumRestMinutes),
            // The same `minimumRestMinutes` reading, not the currency's: see
            // `OcptProjectVersionPayload.screenplayLanguage`.
            screenplayLanguage: Value(payload.screenplayLanguage),
            // Same reading again: `OcptProjectVersionPayload.defaultVatRateBasisPoints`,
            // `.mealPriceCents` and `.snackPriceCents`.
            defaultVatRateBasisPoints: Value(payload.defaultVatRateBasisPoints),
            mealPriceCents: Value(payload.mealPriceCents),
            snackPriceCents: Value(payload.snackPriceCents),
          ),
        );

    await database.batch((batch) {
      batch
        ..insertAll(database.ocptScreenplaysTable, payload.screenplays)
        ..insertAll(database.ocptScenesTable, payload.scenes)
        ..insertAll(database.ocptShotsTable, payload.shots)
        ..insertAll(database.ocptShotCoveragesTable, payload.shotCoverages)
        // `budget_mileage_rates` references nothing, and must be inserted before `people`, which
        // may name one through `mileageRateId` — the same reason `budget_resources` is inserted
        // before `budget_entries`, further below.
        ..insertAll(database.ocptBudgetMileageRatesTable, payload.budgetMileageRates)
        ..insertAll(database.ocptPeopleTable, payload.people)
        ..insertAll(database.ocptPersonPositionsTable, payload.personPositions)
        ..insertAll(database.ocptPersonSkillsTable, payload.personSkills)
        ..insertAll(database.ocptPersonUnavailabilitiesTable, payload.personUnavailabilities)
        ..insertAll(database.ocptRolesTable, payload.roles)
        ..insertAll(database.ocptRoleEpisodesTable, payload.roleEpisodes)
        // `shot_characters.roleId` references `roles` (ADR 0030): inserted only now that the roles
        // it names exist, rather than beside `shots` above.
        ..insertAll(database.ocptShotCharactersTable, payload.shotCharacters)
        ..insertAll(database.ocptLocationsTable, payload.locations)
        ..insertAll(database.ocptLocationAvailabilitiesTable, payload.locationAvailabilities)
        ..insertAll(database.ocptSetsTable, payload.sets)
        ..insertAll(database.ocptSceneSetsTable, payload.sceneSets)
        ..insertAll(database.ocptElementsTable, payload.elements)
        ..insertAll(database.ocptSceneElementsTable, payload.sceneElements)
        ..insertAll(database.ocptRoleElementsTable, payload.roleElements)
        ..insertAll(database.ocptRoleCandidatesTable, payload.roleCandidates)
        ..insertAll(database.ocptAssetsTable, payload.assets)
        // Both breakdown tables follow every table they may reference (scenes, roles, sets and
        // elements are all written above), so this is not a forward reference — unlike the
        // asset-referencing trio above it, `breakdown_tags` closes no foreign-key cycle of its own.
        ..insertAll(database.ocptBreakdownTagsTable, payload.breakdownTags)
        ..insertAll(database.ocptSceneBreakdownsTable, payload.sceneBreakdowns)
        // The schedule tables follow every table they may reference too — screenplays, shots,
        // people, roles, locations and sets are all written above — so none of these is a forward
        // reference either: shootingDays before shootingSlots (which may name a location or a set),
        // before shootingSlotCrew/shootingSlotCast/shootingSlotGuests (which each point at a slot,
        // and a guest at a person too) and
        // shootingDayBlocks (which points at a slot, and a block may also point at a shot), and
        // shootingDayEvents last, referencing only a day.
        ..insertAll(database.ocptShootingDaysTable, payload.shootingDays)
        ..insertAll(database.ocptShootingSlotsTable, payload.shootingSlots)
        ..insertAll(database.ocptShootingSlotCrewTable, payload.shootingSlotCrew)
        ..insertAll(database.ocptShootingSlotCastTable, payload.shootingSlotCast)
        ..insertAll(database.ocptShootingSlotGuestsTable, payload.shootingSlotGuests)
        ..insertAll(database.ocptShootingDayBlocksTable, payload.shootingDayBlocks)
        ..insertAll(database.ocptShootingDayEventsTable, payload.shootingDayEvents)
        ..insertAll(database.ocptProjectDictionaryWordsTable, payload.projectDictionaryWords)
        // `budget_postes` references nothing, and `budget_lines` references `budget_postes` (just
        // above) and, optionally, `elements` (already inserted above): neither is a forward
        // reference. `budget_commitments` references `budget_postes` too, and, optionally,
        // `budget_lines` (just above it) — and `assets.budgetEntryId`, inserted well above this,
        // names a `budget_entries` row inserted only further below: a genuine forward reference,
        // but `insertAll` defers foreign-key checking to the end of this batch's own transaction,
        // exactly what already lets the person/location/element trio point at an `assets` row
        // inserted after them.
        ..insertAll(database.ocptBudgetAccountsTable, payload.budgetAccounts)
        ..insertAll(database.ocptBudgetLinesTable, payload.budgetLines)
        // `budget_resources` references nothing, and must be inserted before `budget_entries`,
        // which may name one through `resourceId`. `budget_revenues` references nothing either,
        // and `budget_shares` only optionally names a `people` row already inserted well above —
        // both must still land before `budget_entries`, which may name either through `revenueId`/
        // `shareId`.
        ..insertAll(database.ocptBudgetResourcesTable, payload.budgetResources)
        ..insertAll(database.ocptBudgetRevenuesTable, payload.budgetRevenues)
        ..insertAll(database.ocptBudgetSharesTable, payload.budgetShares)
        // `budget_allowances` only optionally names a `people` row already inserted well above,
        // and nothing references it, so it may land anywhere after `people`.
        ..insertAll(database.ocptBudgetAllowancesTable, payload.budgetAllowances)
        // `budget_commitments`, inserted just above, before `budget_entries`, which may now name
        // one through `commitmentId` — reversed from the order these two used to insert in, back
        // when a commitment named its own settling entry rather than the other way round.
        ..insertAll(database.ocptBudgetCommitmentsTable, payload.budgetCommitments)
        ..insertAll(database.ocptBudgetEntriesTable, payload.budgetEntries)
        // The storyboard and floor plan tables, in the same dependency order [applyPayload]
        // restores them in: `floor_plan_sets` references only `sets` (its own id) and, optionally,
        // `assets` (both inserted above); `storyboard_panels` references `shots` and, optionally,
        // `assets` (both inserted above); `storyboard_annotations` references the panel it marks,
        // just inserted; `floor_plan_symbols` references `floor_plan_sets` and, optionally,
        // `scenes`/`shots` (all inserted above) and, optionally, another live `floor_plan_symbols`
        // row of its own (`overridesSymbolId`) — a self-reference `insertAll`'s deferred
        // foreign-key checking handles the same way as the genuine forward reference noted above,
        // whichever order the two rows land in; `floor_plan_arrows` references `floor_plan_sets`,
        // `shots` and the two `floor_plan_symbols` rows it connects, so it comes last.
        ..insertAll(database.ocptFloorPlanSetsTable, payload.floorPlanSets)
        ..insertAll(database.ocptStoryboardPanelsTable, payload.storyboardPanels)
        ..insertAll(database.ocptStoryboardAnnotationsTable, payload.storyboardAnnotations)
        ..insertAll(database.ocptFloorPlanSymbolsTable, payload.floorPlanSymbols)
        ..insertAll(database.ocptFloorPlanArrowsTable, payload.floorPlanArrows)
        ..insertAll(database.ocptRowFieldVersionsTable, payload.rowFieldVersions);
    });
  });

  /// Snapshot the text of every screenplay [payload] is about to overwrite in [database].
  ///
  /// This is what a restore owes the merge rather than the user (see [OcptSnapshotReason.restore]),
  /// and it has to happen before a single character of `screenplays.fountainText` changes. Only the
  /// screenplays whose text actually differs are snapshotted: a restore that changes nothing must
  /// not push thirty real snapshots out of the rolling window for nothing.
  ///
  /// [stamps] is [applyPayload]'s own instance, already seeded and floor-raised: passed straight
  /// through to `OcptScreenplayService.snapshotBeforeRestore`, which stamps the snapshot it takes
  /// into it rather than seeding one of its own.
  static Future<void> snapshotScreenplaysAboutToChange({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
    required OcptScreenplayService screenplayService,
    required OcptRowStampService stamps,
  }) async {
    final currentRows = {
      for (final row in await database.select(database.ocptScreenplaysTable).get()) row.id: row,
    };

    for (final screenplay in payload.screenplays) {
      final current = currentRows[screenplay.id];

      // A screenplay the working copy doesn't hold live has no text to protect: either it is about
      // to be inserted, or it is a tombstone the restore only reinstates as one.
      if (current == null || current.isDeleted || current.fountainText == screenplay.fountainText) {
        continue;
      }

      await screenplayService.snapshotBeforeRestore(
        database: database,
        screenplayId: screenplay.id,
        stamps: stamps,
      );
    }
  }

  /// Restore one table of a payload: [payloadRows] are written over whatever [table] currently
  /// holds in [database], and whatever it holds beyond them is tombstoned.
  ///
  /// The three cases, each stamped through [stamps] unless the table is one no merge ever sees (see
  /// [applyPayload]):
  ///
  /// - a row the payload holds and the working copy doesn't is **inserted**, and every one of its
  ///   columns stamped;
  /// - a row both hold is **updated**, and only the columns whose value actually changes are
  ///   stamped. A column that already matches the payload is left alone: that is what keeps a
  ///   restore from stomping an unrelated concurrent edit that happened to agree with it;
  /// - a row the working copy holds and the payload doesn't is **tombstoned**, never deleted, and
  ///   its tombstone column stamped. One already tombstoned is left untouched, stamp included.
  ///
  /// [rowIdOf] names a row both in the map matching the two sides up and in
  /// `row_field_versions.rowId`, so a composite primary key goes through
  /// [ocptCompositeRowStampKey]. [tombstonedOf] returns the row as its own tombstone — returning it
  /// unchanged is how a table with no tombstone column would opt out.
  ///
  /// The per-row write and stamp itself — insert, update or tombstone-in-place alike — is
  /// [OcptRowStampService.writeAndStamp]: the machinery shared with whatever, later, writes an
  /// ordinary domain-service edit into `row_field_versions` the same way.
  static Future<void> restoreTable<D extends DataClass>({
    required OcptProjectDatabase database,
    required TableInfo<Table, D> table,
    required List<D> payloadRows,
    required String Function(D row) rowIdOf,
    required D Function(D row) tombstonedOf,
    required OcptRowStampService? stamps,
  }) async {
    final leftovers = {for (final row in await database.select(table).get()) rowIdOf(row): row};

    for (final row in payloadRows) {
      final rowId = rowIdOf(row);
      final current = leftovers.remove(rowId);

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: table,
        rowId: rowId,
        current: current,
        next: row,
        stamps: stamps,
      );
    }

    for (final leftover in leftovers.entries) {
      final tombstone = tombstonedOf(leftover.value);
      if (tombstone == leftover.value) {
        continue;
      }

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: table,
        rowId: leftover.key,
        current: leftover.value,
        next: tombstone,
        stamps: stamps,
      );
    }
  }
}
