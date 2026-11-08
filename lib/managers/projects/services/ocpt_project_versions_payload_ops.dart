// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';

/// How `OcptProjectVersionsService` reads a project into a payload, and what it does to a payload
/// it has loaded: the list of tables a payload carries, the capture of their rows and stamps, and
/// the scrub of every erased person.
///
/// Stateless, so a call takes the database it reads from.
abstract final class OcptProjectVersionsPayloadOps {
  /// The tables a payload carries every row of, as `row_field_versions.table_name` spells them.
  ///
  /// The stamps of those tables — and of no others — travel with a version (see
  /// [captureRowFieldVersions]).
  static const payloadTableNames = [
    'screenplays',
    'scenes',
    'shots',
    'shot_characters',
    'shot_coverages',
    'people',
    'person_positions',
    'person_skills',
    'person_unavailabilities',
    'roles',
    'role_episodes',
    'locations',
    'location_availabilities',
    'sets',
    'scene_sets',
    'elements',
    'scene_elements',
    'role_elements',
    'role_candidates',
    'assets',
    'breakdown_tags',
    'scene_breakdowns',
    'shooting_days',
    'shooting_slots',
    'shooting_slot_crew',
    'shooting_slot_cast',
    'shooting_day_blocks',
    'shooting_slot_guests',
    'shooting_block_candidates',
    'shooting_day_events',
    'project_dictionary_words',
    'budget_postes',
    'budget_lines',
    'budget_entries',
    'budget_commitments',
    'budget_resources',
    'budget_mileage_rates',
    'budget_revenues',
    'budget_shares',
    'budget_allowances',
    'storyboard_panels',
    'storyboard_annotations',
    'floor_plan_sets',
    'floor_plan_symbols',
    'floor_plan_arrows',
  ];

  /// Read the whole state of the project in [database] into a payload, at [pageMargins].
  ///
  /// One query per table, none of them filtering tombstones: a version that carried only the live
  /// rows would, on restore, resurrect everything the user had deleted since.
  static Future<OcptProjectVersionPayload> capturePayload({
    required OcptProjectDatabase database,
    required FountainPageMargins pageMargins,
  }) async {
    final info = await database.select(database.ocptProjectInfoTable).getSingle();

    return OcptProjectVersionPayload(
      screenplays: await database.select(database.ocptScreenplaysTable).get(),
      scenes: await database.select(database.ocptScenesTable).get(),
      shots: await database.select(database.ocptShotsTable).get(),
      shotCharacters: await database.select(database.ocptShotCharactersTable).get(),
      shotCoverages: await database.select(database.ocptShotCoveragesTable).get(),
      people: await database.select(database.ocptPeopleTable).get(),
      personPositions: await database.select(database.ocptPersonPositionsTable).get(),
      personSkills: await database.select(database.ocptPersonSkillsTable).get(),
      personUnavailabilities: await database.select(database.ocptPersonUnavailabilitiesTable).get(),
      roles: await database.select(database.ocptRolesTable).get(),
      roleEpisodes: await database.select(database.ocptRoleEpisodesTable).get(),
      locations: await database.select(database.ocptLocationsTable).get(),
      locationAvailabilities: await database.select(database.ocptLocationAvailabilitiesTable).get(),
      sets: await database.select(database.ocptSetsTable).get(),
      sceneSets: await database.select(database.ocptSceneSetsTable).get(),
      elements: await database.select(database.ocptElementsTable).get(),
      sceneElements: await database.select(database.ocptSceneElementsTable).get(),
      roleElements: await database.select(database.ocptRoleElementsTable).get(),
      roleCandidates: await database.select(database.ocptRoleCandidatesTable).get(),
      assets: await database.select(database.ocptAssetsTable).get(),
      breakdownTags: await database.select(database.ocptBreakdownTagsTable).get(),
      sceneBreakdowns: await database.select(database.ocptSceneBreakdownsTable).get(),
      shootingDays: await database.select(database.ocptShootingDaysTable).get(),
      shootingSlots: await database.select(database.ocptShootingSlotsTable).get(),
      shootingSlotCrew: await database.select(database.ocptShootingSlotCrewTable).get(),
      shootingSlotCast: await database.select(database.ocptShootingSlotCastTable).get(),
      shootingDayBlocks: await database.select(database.ocptShootingDayBlocksTable).get(),
      shootingSlotGuests: await database.select(database.ocptShootingSlotGuestsTable).get(),
      shootingBlockCandidates: await database
          .select(database.ocptShootingBlockCandidatesTable)
          .get(),
      shootingDayEvents: await database.select(database.ocptShootingDayEventsTable).get(),
      projectDictionaryWords: await database.select(database.ocptProjectDictionaryWordsTable).get(),
      budgetAccounts: await database.select(database.ocptBudgetAccountsTable).get(),
      budgetLines: await database.select(database.ocptBudgetLinesTable).get(),
      budgetEntries: await database.select(database.ocptBudgetEntriesTable).get(),
      budgetCommitments: await database.select(database.ocptBudgetCommitmentsTable).get(),
      budgetResources: await database.select(database.ocptBudgetResourcesTable).get(),
      budgetMileageRates: await database.select(database.ocptBudgetMileageRatesTable).get(),
      budgetRevenues: await database.select(database.ocptBudgetRevenuesTable).get(),
      budgetShares: await database.select(database.ocptBudgetSharesTable).get(),
      budgetAllowances: await database.select(database.ocptBudgetAllowancesTable).get(),
      storyboardPanels: await database.select(database.ocptStoryboardPanelsTable).get(),
      storyboardAnnotations: await database.select(database.ocptStoryboardAnnotationsTable).get(),
      floorPlanSets: await database.select(database.ocptFloorPlanSetsTable).get(),
      floorPlanSymbols: await database.select(database.ocptFloorPlanSymbolsTable).get(),
      floorPlanArrows: await database.select(database.ocptFloorPlanArrowsTable).get(),
      rowFieldVersions: await captureRowFieldVersions(database: database),
      pageSetup: OcptPageSetup(format: info.pageFormat, margins: pageMargins),
      settingsJson: info.settingsJson,
      currencyCode: info.currencyCode,
      minimumRestMinutes: info.minimumRestMinutes,
      screenplayLanguage: info.screenplayLanguage,
      defaultVatRateBasisPoints: info.defaultVatRateBasisPoints,
      mealPriceCents: info.mealPriceCents,
      snackPriceCents: info.snackPriceCents,
      isBudgetSimplified: info.isBudgetSimplified,
    );
  }

  /// Read the version stamps of the rows the payload carries.
  ///
  /// Scoped by table rather than row by row, which comes to the same thing: a capture takes every
  /// row of [payloadTableNames], so every stamp of those tables describes a row the payload holds
  /// — and it saves matching each stamp's [OcptRowFieldVersionRow.rowId] against a composite key
  /// rebuilt through [ocptCompositeRowStampKey].
  static Future<List<OcptRowFieldVersionRow>> captureRowFieldVersions({
    required OcptProjectDatabase database,
  }) => (database.select(
    database.ocptRowFieldVersionsTable,
  )..where((table) => table.targetTableName.isIn(payloadTableNames))).get();

  /// Rewrite [payload]'s `people` rows — and the `person_positions`/`person_skills`/
  /// `person_unavailabilities`/`assets` rows hanging off them — for every person `local_erasures`
  /// names in [database], so no reader of a payload ever sees an erased person again: neither
  /// `OcptProjectVersionsRestoreOps.applyPayload` writing one back into the working copy, nor
  /// `OcptProjectVersionsRestoreOps.hydratePreview` putting one on screen.
  /// `OcptProjectVersionsService.loadPayload` is the single door both come through, which is why
  /// the scrub lives there.
  ///
  /// A version is captured before knowing about an erasure made later, so its stored payload still
  /// holds that person's personal data verbatim, forever: a version is never rewritten once
  /// captured (`OcptProjectVersionCodec`'s own doc comment). `local_erasures` is what lets this
  /// replica remember the erasure happened without the payload that predates it ever having to
  /// become untruthful about the moment it captured — decode-time scrubbing, not a rewrite on disk
  /// (see `docs/architecture/foundations.md`). It is read fresh from [database] rather than from
  /// [payload] on purpose: that is what lets a restore of an *old* version still honour an erasure
  /// recorded strictly after that version was taken, and `local_erasures` itself is never part of a
  /// payload — carrying it there would let this very restore rewind the fact that the erasure ever
  /// happened.
  ///
  /// Every erased person's row is put back through exactly the blanking-and-tombstoning
  /// [erasedPersonRow] performs — chosen over dropping the row outright, since nothing in this
  /// schema is ever hard-deleted, and other rows this same payload may carry
  /// (`elements.ownerPersonId`/`broughtByPersonId`, `assets.personId`, `locations.contactPersonId`)
  /// can still reference the id (`roles.personId` is the exception: it is cleared): the row they
  /// point at must keep existing, merely empty, or the restore's own
  /// `PRAGMA defer_foreign_keys` commit would have nothing to resolve them against.
  /// **This must be kept in step with `OcptPeopleService.deletePerson` by hand** — the two
  /// implement the very same erasure from two different starting points (a live row there, a
  /// captured one here), and a column blanked by one but not the other reopens exactly the leak
  /// this method exists to close.
  static Future<OcptProjectVersionPayload> scrubErasedPeople({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
  }) async {
    final erasedPersonIds = {
      for (final row in await database.select(database.ocptLocalErasuresTable).get()) row.personId,
    };

    if (erasedPersonIds.isEmpty) {
      return payload;
    }

    return OcptProjectVersionPayload(
      screenplays: payload.screenplays,
      scenes: payload.scenes,
      shots: payload.shots,
      shotCharacters: payload.shotCharacters,
      shotCoverages: payload.shotCoverages,
      people: [
        for (final row in payload.people)
          erasedPersonIds.contains(row.id) ? erasedPersonRow(row) : row,
      ],
      personPositions: [
        for (final row in payload.personPositions)
          erasedPersonIds.contains(row.personId) ? row.copyWith(isDeleted: true) : row,
      ],
      // person_skills.label and person_unavailabilities.reason are blanked along with the
      // tombstone, exactly as OcptPeopleService.deletePerson blanks them: both routinely hold
      // something personal about the person (a driving licence, a language, why they were away on
      // a date), and an erasure is about what the file stops holding, not only what a screen stops
      // showing.
      personSkills: [
        for (final row in payload.personSkills)
          erasedPersonIds.contains(row.personId) ? row.copyWith(isDeleted: true, label: '') : row,
      ],
      personUnavailabilities: [
        for (final row in payload.personUnavailabilities)
          erasedPersonIds.contains(row.personId) ? row.copyWith(isDeleted: true, reason: '') : row,
      ],
      // A role cast with an erased person is uncast, exactly as `OcptPeopleService.deletePerson`
      // does it live.
      roles: [
        for (final row in payload.roles)
          row.personId != null && erasedPersonIds.contains(row.personId)
              ? row.copyWith(personId: const Value(null))
              : row,
      ],
      // A role_episodes row names a role and a screenplay, never a person: an actor is reached
      // through `roles.personId`, which the `roles` list above already answers for. Nothing here
      // to scrub.
      roleEpisodes: payload.roleEpisodes,
      locations: payload.locations,
      locationAvailabilities: payload.locationAvailabilities,
      sets: payload.sets,
      sceneSets: payload.sceneSets,
      elements: payload.elements,
      sceneElements: payload.sceneElements,
      // A `role_elements` row names a role and an element, never a person: an actor is reached
      // through `roles.personId`, which the `roles` list above already answers for. Nothing here
      // to scrub.
      roleElements: payload.roleElements,
      // A `role_candidates` row is the one link table that *is* about a person: it names them, and
      // its `notes` hold what somebody wrote about them at an audition. So a candidacy of an erased
      // person is tombstoned **and blanked**, exactly as `OcptPeopleService.deletePerson` does it
      // live — the mirror this method's own doc comment warns must be kept in step.
      roleCandidates: [
        for (final row in payload.roleCandidates)
          erasedPersonIds.contains(row.personId) ? row.copyWith(isDeleted: true, notes: '') : row,
      ],
      // An asset's `path` is personal data in its own right: an absolute path routinely names the
      // person (`…/cession-droits-Jean-Dupont.pdf`) and always says where a photograph of them
      // sits on this machine. So a row belonging to an erased person is tombstoned **and blanked**,
      // exactly as `OcptAssetsService.erasePersonAssets` does it live — the mirror this comment's
      // method doc warns must be kept in step. A row belonging to a location or an element is
      // nobody's personal data and travels through untouched.
      assets: [
        for (final row in payload.assets)
          row.personId != null && erasedPersonIds.contains(row.personId)
              ? row.copyWith(isDeleted: true, path: '', label: '')
              : row,
      ],
      // A breakdown tag never names a person — only an element, a role or a set — and a scene
      // breakdown carries nothing about anyone either, so neither list has anything for this method
      // to scrub: both travel through unchanged.
      breakdownTags: payload.breakdownTags,
      sceneBreakdowns: payload.sceneBreakdowns,
      // None of the schedule tables holds a person's own data either — only ids pointing at
      // `people` or `roles`, which stay valid (an erased person's row is blanked and tombstoned,
      // never dropped, so a `shooting_slot_crew.personId` or a `shooting_slot_guests.personId`
      // referencing it still resolves) — so all of them travel through unchanged too.
      // `shooting_slot_guests.freeName` names somebody who was never a `people` row in the first
      // place, so there is nothing there for this scrub to reach either,
      // `shooting_block_candidates` names a **candidacy** rather than a person (the blanked
      // `role_candidates` row above is what holds their name and what somebody wrote about them),
      // and `shooting_day_events` carries nobody's data at all.
      shootingDays: payload.shootingDays,
      shootingSlots: payload.shootingSlots,
      shootingSlotCrew: payload.shootingSlotCrew,
      shootingSlotCast: payload.shootingSlotCast,
      shootingDayBlocks: payload.shootingDayBlocks,
      shootingSlotGuests: payload.shootingSlotGuests,
      shootingBlockCandidates: payload.shootingBlockCandidates,
      shootingDayEvents: payload.shootingDayEvents,
      // A dictionary word names no person — only the word itself and its tombstone — so there is
      // nothing here for this scrub to reach either.
      projectDictionaryWords: payload.projectDictionaryWords,
      // Neither a budget account nor a budget line names a person: a line points at an account and,
      // optionally, an element, never at the address book. Both travel through unchanged.
      budgetAccounts: payload.budgetAccounts,
      budgetLines: payload.budgetLines,
      // Nor does a journal entry or a commitment: an entry points at an account and, at most, a
      // resource, and a commitment at an account and, at most, at the entry that settled it — never
      // at the address book. Both travel through unchanged too.
      budgetEntries: payload.budgetEntries,
      budgetCommitments: payload.budgetCommitments,
      // A mileage rate names no person at all: a label and a rate. A financing resource may,
      // through `personId`, exactly the way `roles.personId`/`budget_shares.personId` do above and
      // below: the row it points at is blanked, not dropped, so the link itself still resolves and
      // there is nothing here for this scrub to rewrite. Both travel through unchanged.
      budgetResources: payload.budgetResources,
      budgetMileageRates: payload.budgetMileageRates,
      // Nor does a revenue name a person at all. A share may, through `personId`, exactly the way
      // `roles.personId` does above: the row it points at is blanked, not dropped, so the link
      // itself still resolves and there is nothing here for this scrub to rewrite.
      budgetRevenues: payload.budgetRevenues,
      budgetShares: payload.budgetShares,
      // A defrayal may name a person, through `personId`, exactly as a share does just above:
      // the row it points at is blanked, not dropped, so the link still resolves and there is
      // nothing here for this scrub to rewrite.
      budgetAllowances: payload.budgetAllowances,
      // None of the five storyboard/floor plan tables holds anything about a person — a floor
      // plan character symbol carries a free label, never a `personId` — so all five travel
      // through unchanged.
      storyboardPanels: payload.storyboardPanels,
      storyboardAnnotations: payload.storyboardAnnotations,
      floorPlanSets: payload.floorPlanSets,
      floorPlanSymbols: payload.floorPlanSymbols,
      floorPlanArrows: payload.floorPlanArrows,
      rowFieldVersions: payload.rowFieldVersions,
      pageSetup: payload.pageSetup,
      settingsJson: payload.settingsJson,
      currencyCode: payload.currencyCode,
      minimumRestMinutes: payload.minimumRestMinutes,
      screenplayLanguage: payload.screenplayLanguage,
      defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
      mealPriceCents: payload.mealPriceCents,
      snackPriceCents: payload.snackPriceCents,
      isBudgetSimplified: payload.isBudgetSimplified,
    );
  }

  /// Build [row], blanked exactly as `OcptPeopleService.deletePerson`'s own erasure blanks a live
  /// row:
  /// every column held something about the person except `id`, `sortKey`, `isDeleted` (set to true
  /// here rather than left alone) and `colorIndex`. `maxDailyPresenceMinutes` is blanked with the
  /// rest, being personal data of the same nature as `minorNotes`, and `commuteKmMilli`/
  /// `mileageRateId` are blanked for the same reason: a one-way commute distance says roughly where
  /// somebody lives. See [scrubErasedPeople] for why the two must stay in step by hand.
  static OcptPersonRow erasedPersonRow(OcptPersonRow row) => row.copyWith(
    isDeleted: true,
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    addressLine1: '',
    addressLine2: '',
    postalCode: '',
    city: '',
    region: '',
    country: '',
    birthDate: const Value(null),
    minorNotes: '',
    maxDailyPresenceMinutes: const Value(null),
    isTransportAutonomous: const Value(null),
    accommodationNotes: '',
    travelNotes: '',
    dietaryNotes: '',
    allergies: '',
    measurementHeight: '',
    measurementChest: '',
    measurementWaist: '',
    measurementHips: '',
    sizeTop: '',
    sizeBottom: '',
    sizeShoes: '',
    hmcNotes: '',
    imageRightsStatus: OcptImageRightsStatus.notApplicable,
    imageRightsDate: const Value(null),
    imageRightsAssetId: const Value(null),
    photoAssetId: const Value(null),
    notes: '',
    commuteKmMilli: const Value(null),
    mileageRateId: const Value(null),
  );
}
