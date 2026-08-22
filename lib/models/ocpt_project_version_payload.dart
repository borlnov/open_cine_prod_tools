// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// The whole state of a project at the moment a version was created: what
/// `OcptProjectVersionsService` captures, what `OcptProjectVersionCodec` serializes into
/// `project_versions.payload`, and what a restore writes back.
///
/// Every list here holds the table's rows **verbatim, tombstones and primary keys included**:
///
/// - the keys, because a restore must never re-derive the scene index from the restored text.
///   That would mint fresh scene UUIDs and silently break every `shots.sceneId` and
///   `shot_coverages.sceneId` reference carried by this very payload — the single subtlest
///   constraint of the whole feature;
/// - the tombstones, because a payload holding only the live rows would, on restore, resurrect
///   everything the user had deleted since (`docs/adr/0010-sync-ready-data-model-prerequisites.md`
///   makes a deletion a row like any other).
///
/// The `screenplay_snapshots` rows are deliberately **not** part of this: snapshots are a rolling
/// safety net rather than history, and copying thirty full screenplay texts into every version
/// would multiply the project file's size for nothing — stated here so the missing field reads as a
/// decision rather than an oversight.
///
/// `local_erasures` is deliberately **not** part of this either, and for the opposite reason: it
/// must never travel in a payload. It is local, never synchronised, and its whole job is to survive
/// a restore of a version captured before an erasure — carrying it here would let that very restore
/// rewind the fact that the erasure ever happened. See `ocpt_local_erasures_table.dart` and
/// `OcptProjectVersionsService`'s restore path, which reads it straight from the database instead.
class OcptProjectVersionPayload extends Equatable {
  /// The `screenplays` rows of the project.
  final List<OcptScreenplayRow> screenplays;

  /// The `scenes` rows of the project: the scene index as it stood, never recomputed on restore.
  final List<OcptSceneRow> scenes;

  /// The `shots` rows of the project.
  final List<OcptShotRow> shots;

  /// The `shot_characters` rows of the project.
  final List<OcptShotCharacterRow> shotCharacters;

  /// The `shot_coverages` rows of the project.
  final List<OcptShotCoverageRow> shotCoverages;

  /// The `people` rows of the project: the address book, tombstones included.
  final List<OcptPersonRow> people;

  /// The `person_positions` rows of the project.
  final List<OcptPersonPositionRow> personPositions;

  /// The `person_skills` rows of the project.
  final List<OcptPersonSkillRow> personSkills;

  /// The `person_unavailabilities` rows of the project.
  final List<OcptPersonUnavailabilityRow> personUnavailabilities;

  /// The `roles` rows of the project.
  final List<OcptRoleRow> roles;

  /// The `role_episodes` rows of the project: which episodes each role is named in
  /// (`docs/adr/0019-one-project-several-episodes.md`), the link `roles.screenplayId` used to be
  /// until schema version 18 / payload format 13 turned a role into a fact about the production
  /// rather than about any one screenplay.
  final List<OcptRoleEpisodeRow> roleEpisodes;

  /// The `locations` rows of the project.
  final List<OcptLocationRow> locations;

  /// The `location_availabilities` rows of the project.
  final List<OcptLocationAvailabilityRow> locationAvailabilities;

  /// The `sets` rows of the project.
  final List<OcptSetRow> sets;

  /// The `scene_sets` rows of the project.
  final List<OcptSceneSetRow> sceneSets;

  /// The `elements` rows of the project.
  final List<OcptElementRow> elements;

  /// The `scene_elements` rows of the project.
  final List<OcptSceneElementRow> sceneElements;

  /// The `role_elements` rows of the project: what each role wears, carries and is made up with.
  final List<OcptRoleElementRow> roleElements;

  /// The `role_candidates` rows of the project: who was seen for each part, and where the casting
  /// of it stands.
  final List<OcptRoleCandidateRow> roleCandidates;

  /// The `assets` rows of the project: the binary asset references, never the bytes they point at
  /// (`docs/adr/0013-binary-assets-referenced-by-path.md`). Restoring a version restores the
  /// reference, and the file it names may now be dangling — a normal state, not an error.
  final List<OcptAssetRow> assets;

  /// The `breakdown_tags` rows of the project: the passages tagged during the breakdown pass,
  /// anchored to the catalogue row (an element, a role or a set) each one calls for.
  final List<OcptBreakdownTagRow> breakdownTags;

  /// The `scene_breakdowns` rows of the project: how far the breakdown pass has got, scene by
  /// scene, held by hand rather than deduced.
  final List<OcptSceneBreakdownRow> sceneBreakdowns;

  /// The `shooting_days` rows of the project: one row per day of shooting, dated, ordered and
  /// tombstoned exactly like every other synchronised table.
  final List<OcptShootingDayRow> shootingDays;

  /// The `shooting_slots` rows of the project: the convocation windows (*créneaux*) inside each
  /// day.
  final List<OcptShootingSlotRow> shootingSlots;

  /// The `shooting_slot_crew` rows of the project: who holds which position during a slot.
  final List<OcptShootingSlotCrewRow> shootingSlotCrew;

  /// The `shooting_slot_cast` rows of the project: which role is convoked during a slot.
  final List<OcptShootingSlotCastRow> shootingSlotCast;

  /// The `shooting_day_blocks` rows of the project: a day's timetable, in order — the heart of the
  /// schedule mode.
  final List<OcptShootingDayBlockRow> shootingDayBlocks;

  /// The `shooting_block_candidates` rows of the project: which candidacies each audition block
  /// sees — the one convocation read off a block rather than off a slot, and what a casting day is
  /// planned with.
  final List<OcptShootingBlockCandidateRow> shootingBlockCandidates;

  /// The `shooting_slot_guests` rows of the project: who attends a slot without being crew or cast.
  final List<OcptShootingSlotGuestRow> shootingSlotGuests;

  /// The `shooting_day_events` rows of the project: what a day does not control, at an absolute
  /// hour.
  final List<OcptShootingDayEventRow> shootingDayEvents;

  /// The `project_dictionary_words` rows of the project: the words a writer has taught this
  /// project's spell checker, tombstones included — a word removed since this version was captured
  /// must come back un-learned on restore, exactly as any other deleted row does.
  final List<OcptProjectDictionaryWordRow> projectDictionaryWords;

  /// The `budget_postes` rows of the project: the budget mode's own catalogue, tombstones included.
  final List<OcptBudgetPosteRow> budgetPostes;

  /// The `budget_lines` rows of the project: the quote lines inside each poste.
  final List<OcptBudgetLineRow> budgetLines;

  /// The `budget_entries` rows of the project: the cash journal's own movements, tombstones
  /// included.
  final List<OcptBudgetEntryRow> budgetEntries;

  /// The `budget_commitments` rows of the project: money committed against a poste but not yet
  /// paid.
  final List<OcptBudgetCommitmentRow> budgetCommitments;

  /// The `budget_resources` rows of the project: the financing plan — subsidies, cash and in-kind
  /// contributions — tombstones included.
  final List<OcptBudgetResourceRow> budgetResources;

  /// The `budget_mileage_rates` rows of the project: the per-kilometre rates the production names
  /// for itself, tombstones included.
  final List<OcptBudgetMileageRateRow> budgetMileageRates;

  /// The `budget_revenues` rows of the project: the takings the production expects, tombstones
  /// included.
  final List<OcptBudgetRevenueRow> budgetRevenues;

  /// The `budget_shares` rows of the project: the participants splitting what the takings bring
  /// in, tombstones included.
  final List<OcptBudgetShareRow> budgetShares;

  /// The `row_field_versions` stamps of the rows this payload carries.
  ///
  /// A restore rewinds the data, so it has to rewind the per-column stamps a merge resolves
  /// conflicts with along with it: left at their working-copy values, they would let the next merge
  /// treat the restored columns as older than the very edits the restore was meant to supersede.
  final List<OcptRowFieldVersionRow> rowFieldVersions;

  /// The page setup the project was typeset with when this version was captured.
  ///
  /// This pairs two values of different natures on purpose: the page format is project data
  /// (`project_info.pageFormat`), while the margins are an app-wide preference
  /// (`OcptPropertiesManager.pageMargins`). Carrying both is what keeps the page count shown on a
  /// version's card true — the layout it was counted against travels with it. A *preview* only ever
  /// renders with this setup; only a restore writes the margins back, and only once its database
  /// transaction has committed.
  final OcptPageSetup pageSetup;

  /// The `project_info.settingsJson` of the project, or null if it had none.
  final String? settingsJson;

  /// The `project_info.currencyCode` of the project, or null when this payload predates
  /// currencies (captured in payload format 3 or earlier).
  ///
  /// Unlike every other field of this class, a null here is not "this project had none" — the
  /// column itself is never null — it is "this version doesn't know". That distinction is what
  /// `OcptProjectVersionsService.restoreVersion` reads it for: a restore **leaves the project's
  /// currency untouched** when this is null, rather than overwriting it with a guess, which is the
  /// fail-safe direction (the opposite choice the resources tables make, since their absence is a
  /// truthful "there were none").
  final String? currencyCode;

  /// The `project_info.minimumRestMinutes` of the project, or null.
  ///
  /// **Unlike [currencyCode], a null here is a truthful "this project had none recorded"** — the
  /// column is nullable by design, not something every payload from a certain format on always
  /// carries a real value for, so there is no format boundary to read the null against.
  /// `OcptProjectVersionsService.restoreVersion` writes it back onto the working copy like any
  /// other changed column, including when it is null, rather than leaving the live value alone —
  /// the reading `people.maxDailyPresenceMinutes` gets on restore, not the currency's.
  final int? minimumRestMinutes;

  /// The `project_info.screenplayLanguage` of the project, or null.
  ///
  /// **Unlike [currencyCode], and like [minimumRestMinutes], a null here is a truthful "this
  /// version recorded none"** — the column is nullable by design, not something every payload from
  /// a certain format on always carries a real value for, so there is no format boundary to read
  /// the null against. `OcptProjectVersionsService.restoreVersion` writes it back onto the working
  /// copy like any other changed column, including when it is null, rather than leaving the live
  /// value alone — the reading [minimumRestMinutes] gets on restore, not the currency's.
  final OcptScreenplayLanguage? screenplayLanguage;

  /// The `project_info.defaultVatRateBasisPoints` of the project, or null.
  ///
  /// **Unlike [currencyCode], and like [minimumRestMinutes], a null here is a truthful "this
  /// version recorded none"** — the column is nullable by design, not something every payload from
  /// a certain format on always carries a real value for, so there is no format boundary to read
  /// the null against. `OcptProjectVersionsService.restoreVersion` writes it back onto the working
  /// copy like any other changed column, including when it is null, rather than leaving the live
  /// value alone — the reading [minimumRestMinutes] gets on restore, not the currency's.
  final int? defaultVatRateBasisPoints;

  /// The `project_info.mealPriceCents` of the project, or null — [defaultVatRateBasisPoints]'s
  /// sibling, read the same way and for the same reason.
  final int? mealPriceCents;

  /// The `project_info.snackPriceCents` of the project, or null — [mealPriceCents]'s sibling.
  final int? snackPriceCents;

  /// The `project_info.isBudgetSimplified` of the project, or null.
  ///
  /// **Unlike [currencyCode], and like [minimumRestMinutes], a null here is a truthful "nobody has
  /// chosen"** — the column is nullable by design, not something every payload from a certain
  /// format on always carries a real value for, so there is no format boundary to read the null
  /// against, and the mode opens detailed for it exactly as it does for a project that has never
  /// been opened at all. `OcptProjectVersionsService.restoreVersion` writes it back onto the
  /// working copy like any other changed column, including when it is null, rather than leaving the
  /// live value alone — the reading [minimumRestMinutes] gets on restore, not the currency's.
  final bool? isBudgetSimplified;

  /// Class constructor
  const OcptProjectVersionPayload({
    required this.screenplays,
    required this.scenes,
    required this.shots,
    required this.shotCharacters,
    required this.shotCoverages,
    required this.people,
    required this.personPositions,
    required this.personSkills,
    required this.personUnavailabilities,
    required this.roles,
    required this.roleEpisodes,
    required this.locations,
    required this.locationAvailabilities,
    required this.sets,
    required this.sceneSets,
    required this.elements,
    required this.sceneElements,
    required this.roleElements,
    required this.roleCandidates,
    required this.assets,
    required this.breakdownTags,
    required this.sceneBreakdowns,
    required this.shootingDays,
    required this.shootingSlots,
    required this.shootingSlotCrew,
    required this.shootingSlotCast,
    required this.shootingDayBlocks,
    required this.shootingBlockCandidates,
    required this.shootingSlotGuests,
    required this.shootingDayEvents,
    required this.projectDictionaryWords,
    required this.budgetPostes,
    required this.budgetLines,
    required this.budgetEntries,
    required this.budgetCommitments,
    required this.budgetResources,
    required this.budgetMileageRates,
    required this.budgetRevenues,
    required this.budgetShares,
    required this.rowFieldVersions,
    required this.pageSetup,
    required this.settingsJson,
    required this.currencyCode,
    required this.minimumRestMinutes,
    required this.screenplayLanguage,
    required this.defaultVatRateBasisPoints,
    required this.mealPriceCents,
    required this.snackPriceCents,
    required this.isBudgetSimplified,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectVersionPayload(screenplays: ${screenplays.length}, scenes: ${scenes.length}, "
      "shots: ${shots.length}, shotCharacters: ${shotCharacters.length}, "
      "shotCoverages: ${shotCoverages.length}, people: ${people.length}, "
      "personPositions: ${personPositions.length}, personSkills: ${personSkills.length}, "
      "personUnavailabilities: ${personUnavailabilities.length}, roles: ${roles.length}, "
      "roleEpisodes: ${roleEpisodes.length}, "
      "locations: ${locations.length}, sets: ${sets.length}, sceneSets: ${sceneSets.length}, "
      "elements: ${elements.length}, sceneElements: ${sceneElements.length}, "
      "roleElements: ${roleElements.length}, "
      "roleCandidates: ${roleCandidates.length}, "
      "assets: ${assets.length}, breakdownTags: ${breakdownTags.length}, "
      "sceneBreakdowns: ${sceneBreakdowns.length}, shootingDays: ${shootingDays.length}, "
      "shootingSlots: ${shootingSlots.length}, shootingSlotCrew: ${shootingSlotCrew.length}, "
      "shootingSlotCast: ${shootingSlotCast.length}, "
      "shootingDayBlocks: ${shootingDayBlocks.length}, "
      "shootingBlockCandidates: ${shootingBlockCandidates.length}, "
      "shootingSlotGuests: ${shootingSlotGuests.length}, "
      "shootingDayEvents: ${shootingDayEvents.length}, "
      "projectDictionaryWords: ${projectDictionaryWords.length}, "
      "budgetPostes: ${budgetPostes.length}, budgetLines: ${budgetLines.length}, "
      "budgetEntries: ${budgetEntries.length}, budgetCommitments: ${budgetCommitments.length}, "
      "budgetResources: ${budgetResources.length}, "
      "budgetMileageRates: ${budgetMileageRates.length}, "
      "budgetRevenues: ${budgetRevenues.length}, budgetShares: ${budgetShares.length}, "
      "rowFieldVersions: ${rowFieldVersions.length}, "
      "pageSetup: $pageSetup, currencyCode: $currencyCode, "
      "minimumRestMinutes: $minimumRestMinutes, screenplayLanguage: $screenplayLanguage, "
      "defaultVatRateBasisPoints: $defaultVatRateBasisPoints, "
      "mealPriceCents: $mealPriceCents, snackPriceCents: $snackPriceCents, "
      "isBudgetSimplified: $isBudgetSimplified)";

  /// Object properties
  @override
  List<Object?> get props => [
    screenplays,
    scenes,
    shots,
    shotCharacters,
    shotCoverages,
    people,
    personPositions,
    personSkills,
    personUnavailabilities,
    roles,
    roleEpisodes,
    locations,
    locationAvailabilities,
    sets,
    sceneSets,
    elements,
    sceneElements,
    roleElements,
    roleCandidates,
    assets,
    breakdownTags,
    sceneBreakdowns,
    shootingDays,
    shootingSlots,
    shootingSlotCrew,
    shootingSlotCast,
    shootingDayBlocks,
    shootingBlockCandidates,
    shootingSlotGuests,
    shootingDayEvents,
    projectDictionaryWords,
    budgetPostes,
    budgetLines,
    budgetEntries,
    budgetCommitments,
    budgetResources,
    budgetMileageRates,
    budgetRevenues,
    budgetShares,
    rowFieldVersions,
    pageSetup,
    settingsJson,
    currencyCode,
    minimumRestMinutes,
    screenplayLanguage,
    defaultVatRateBasisPoints,
    mealPriceCents,
    snackPriceCents,
    isBudgetSimplified,
  ];
}
