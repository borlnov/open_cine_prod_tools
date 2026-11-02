// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';

/// The JSON keys `OcptProjectVersionCodec` writes and reads for the payload's own structure (its
/// format number, its lists of rows, its settings and margins objects) and for the columns of the
/// shot list, people and locations tables.
///
/// Every key is part of the stored format: a version sits in a user's `.ocpt` for as long as the
/// version does, so none of these strings may change. The columns of every other table are in
/// [OcptVersionJsonProductionKeys].
abstract final class OcptVersionJsonKeys {
  /// This is the key used to stringify or parse the payload's own format from a JSON object
  static const payloadFormatKey = "payloadFormat";

  /// This is the key used to stringify or parse the `screenplays` rows from a JSON object
  static const screenplaysKey = "screenplays";

  /// This is the key used to stringify or parse the `scenes` rows from a JSON object
  static const scenesKey = "scenes";

  /// This is the key used to stringify or parse the `shots` rows from a JSON object
  static const shotsKey = "shots";

  /// This is the key used to stringify or parse the `shot_characters` rows from a JSON object
  static const shotCharactersKey = "shotCharacters";

  /// This is the key used to stringify or parse the `shot_coverages` rows from a JSON object
  static const shotCoveragesKey = "shotCoverages";

  /// This is the key used to stringify or parse the `people` rows from a JSON object
  static const peopleKey = "people";

  /// This is the key used to stringify or parse the `person_positions` rows from a JSON object
  static const personPositionsKey = "personPositions";

  /// This is the key used to stringify or parse the `person_skills` rows from a JSON object
  static const personSkillsKey = "personSkills";

  /// This is the key used to stringify or parse the `person_unavailabilities` rows from a JSON
  /// object
  static const personUnavailabilitiesKey = "personUnavailabilities";

  /// This is the key used to stringify or parse the `roles` rows from a JSON object
  static const rolesKey = "roles";

  /// This is the key used to stringify or parse the `role_episodes` rows from a JSON object: which
  /// episodes a role is named in, from payload format 13
  /// (`docs/adr/0019-one-project-several-episodes.md`).
  static const roleEpisodesKey = "roleEpisodes";

  /// This is the key used to stringify or parse the `locations` rows from a JSON object
  static const locationsKey = "locations";

  /// This is the key used to stringify or parse the `location_availabilities` rows from a JSON
  /// object
  static const locationAvailabilitiesKey = "locationAvailabilities";

  /// This is the key used to stringify or parse the `sets` rows from a JSON object
  static const setsKey = "sets";

  /// This is the key used to stringify or parse the `scene_sets` rows from a JSON object
  static const sceneSetsKey = "sceneSets";

  /// This is the key used to stringify or parse the `elements` rows from a JSON object
  static const elementsKey = "elements";

  /// This is the key used to stringify or parse the `scene_elements` rows from a JSON object
  static const sceneElementsKey = "sceneElements";

  /// This is the key used to stringify or parse the `role_elements` rows from a JSON object
  static const roleElementsKey = "roleElements";

  /// This is the key used to stringify or parse the `role_candidates` rows from a JSON object: who
  /// was seen for each part, from payload format 16.
  static const roleCandidatesKey = "roleCandidates";

  /// This is the key used to stringify or parse the `assets` rows from a JSON object
  static const assetsKey = "assets";

  /// This is the key used to stringify or parse the `breakdown_tags` rows from a JSON object
  static const breakdownTagsKey = "breakdownTags";

  /// This is the key used to stringify or parse the `scene_breakdowns` rows from a JSON object
  static const sceneBreakdownsKey = "sceneBreakdowns";

  /// This is the key used to stringify or parse the `shooting_days` rows from a JSON object
  static const shootingDaysKey = "shootingDays";

  /// This is the key used to stringify or parse the `shooting_slots` rows from a JSON object
  static const shootingSlotsKey = "shootingSlots";

  /// This is the key used to stringify or parse the `shooting_slot_crew` rows from a JSON object
  static const shootingSlotCrewKey = "shootingSlotCrew";

  /// This is the key used to stringify or parse the `shooting_slot_cast` rows from a JSON object
  static const shootingSlotCastKey = "shootingSlotCast";

  /// This is the key used to stringify or parse the `shooting_day_blocks` rows from a JSON object
  static const shootingDayBlocksKey = "shootingDayBlocks";

  /// This is the key used to stringify or parse the `shooting_slot_guests` rows from a JSON object
  static const shootingSlotGuestsKey = "shootingSlotGuests";

  /// This is the key used to stringify or parse the `shooting_block_candidates` rows from a JSON
  /// object: which candidacies each audition block sees, from payload format 20.
  static const shootingBlockCandidatesKey = "shootingBlockCandidates";

  /// This is the key used to stringify or parse a `blockId` column
  /// (`shooting_block_candidates.blockId`, always non-null, the audition a candidacy is seen at)
  /// from a JSON object, from payload format 20
  static const blockIdKey = "blockId";

  /// This is the key used to stringify or parse a `roleCandidateId` column
  /// (`shooting_block_candidates.roleCandidateId`, always non-null, the candidacy an audition block
  /// sees; formerly `shooting_slot_candidates.roleCandidateId` and
  /// `shooting_day_blocks.roleCandidateId`, both gone) from a JSON object, from payload format 18
  static const roleCandidateIdKey = "roleCandidateId";

  /// This is the key used to stringify or parse the `shooting_day_events` rows from a JSON object
  static const shootingDayEventsKey = "shootingDayEvents";

  /// This is the key used to stringify or parse the `row_field_versions` rows from a JSON object
  static const rowFieldVersionsKey = "rowFieldVersions";

  /// This is the key used to stringify or parse the project's own settings from a JSON object
  static const projectSettingsKey = "projectSettings";

  /// This is the key used to stringify or parse the page margins from a JSON object
  static const pageMarginsKey = "pageMargins";

  /// This is the key used to stringify or parse a row's `id` column from a JSON object
  static const idKey = "id";

  /// This is the key used to stringify or parse a row's `isDeleted` column from a JSON object
  static const isDeletedKey = "isDeleted";

  /// This is the key used to stringify or parse a row's `position` column from a JSON object
  static const positionKey = "position";

  /// This is the key used to stringify or parse a row's `sortKey` column from a JSON object
  static const sortKeyKey = "sortKey";

  /// This is the key used to stringify or parse a `screenplayId` column — `scenes.screenplayId`,
  /// `shots.screenplayId` or, from payload format 13, `role_episodes.screenplayId` (the episode a
  /// role is named in) — from a JSON object.
  ///
  /// `roles.screenplayId` and `shooting_days.screenplayId` read and wrote this same key up to
  /// format 12: schema version 18 drops both columns
  /// (`docs/adr/0019-one-project-several-episodes.md`) — a role belongs to the production now, not
  /// to any one screenplay, and a shooting day belongs to no episode at all, a day regularly
  /// covering two of them — so from format 13 on this key serves three tables, not five.
  static const screenplayIdKey = "screenplayId";

  /// This is the key used to stringify or parse a row's `sceneId` column from a JSON object
  static const sceneIdKey = "sceneId";

  /// This is the key used to stringify or parse a row's `shotId` column from a JSON object
  static const shotIdKey = "shotId";

  /// This is the key used to stringify or parse a screenplay's `title` column from a JSON object
  static const titleKey = "title";

  /// This is the key used to stringify or parse a screenplay's `fountainText` column from a JSON
  /// object
  static const fountainTextKey = "fountainText";

  /// This is the key used to stringify or parse a screenplay's `updatedAt` column from a JSON
  /// object
  static const updatedAtKey = "updatedAt";

  /// This is the key used to stringify or parse a screenplay's `number` column from a JSON object:
  /// its printed episode number, from payload format 13
  /// (`docs/adr/0019-one-project-several-episodes.md`).
  static const numberKey = "number";

  /// This is the key used to stringify or parse a scene's `heading` column from a JSON object
  static const headingKey = "heading";

  /// This is the key used to stringify or parse a scene's `sceneNumber` column from a JSON object
  static const sceneNumberKey = "sceneNumber";

  /// This is the key used to stringify or parse a scene's `charStart` column from a JSON object
  static const charStartKey = "charStart";

  /// This is the key used to stringify or parse a scene's `charEnd` column from a JSON object
  static const charEndKey = "charEnd";

  /// This is the key used to stringify or parse a shot's `orphanedHeading` column from a JSON
  /// object
  static const orphanedHeadingKey = "orphanedHeading";

  /// This is the key used to stringify or parse a shot's `shotSize` column from a JSON object
  static const shotSizeKey = "shotSize";

  /// This is the key used to stringify or parse a shot's `abbreviation` column from a JSON object
  static const abbreviationKey = "abbreviation";

  /// This is the key used to stringify or parse a shot's `framing` column from a JSON object
  static const framingKey = "framing";

  /// This is the key used to stringify or parse a shot's `cameraMove` column from a JSON object
  static const cameraMoveKey = "cameraMove";

  /// This is the key used to stringify or parse a shot's `lens` column from a JSON object
  static const lensKey = "lens";

  /// This is the key used to stringify or parse a shot's `recordingFormat` column from a JSON
  /// object
  static const recordingFormatKey = "recordingFormat";

  /// This is the key used to stringify or parse a shot's `estimatedDurationMs` column from a JSON
  /// object
  static const estimatedDurationMsKey = "estimatedDurationMs";

  /// This is the key used to stringify or parse a shot's `shootingDay` column from a JSON object
  static const shootingDayKey = "shootingDay";

  /// This is the key used to stringify or parse a shot's `plannedTakes` column from a JSON object
  static const plannedTakesKey = "plannedTakes";

  /// This is the key used to stringify or parse a shot's `sound` column from a JSON object
  static const soundKey = "sound";

  /// This is the key used to stringify or parse a `status` column (`shots.status`,
  /// `elements.status`, `scene_breakdowns.status`, `shooting_days.status`, from payload format 16
  /// `role_candidates.status`, from payload format 22 `budget_commitments.status`, or, from payload
  /// format 23, `budget_resources.status`) from a JSON object
  static const statusKey = "status";

  /// This is the key used to stringify or parse a shot's `difficultySet` column from a JSON object
  static const difficultySetKey = "difficultySet";

  /// This is the key used to stringify or parse a shot's `difficultyCamera` column from a JSON
  /// object
  static const difficultyCameraKey = "difficultyCamera";

  /// This is the key used to stringify or parse a shot's `difficultyActing` column from a JSON
  /// object
  static const difficultyActingKey = "difficultyActing";

  /// This is the key used to stringify or parse a shot's `difficultySound` column from a JSON
  /// object
  static const difficultySoundKey = "difficultySound";

  /// This is the key used to stringify or parse a free-form `notes` column (`shots.notes`,
  /// `people.notes`, `locations.notes`, `sets.notes`, `elements.notes`, `scene_elements.notes`,
  /// `role_elements.notes`, `role_candidates.notes`, `scene_breakdowns.notes`,
  /// `shooting_days.notes`, `shooting_slots.notes`,
  /// `shooting_slot_crew.notes`, `shooting_slot_cast.notes`, `shooting_slot_guests.notes`,
  /// `shooting_slot_candidates.notes`, `shooting_day_events.notes` or, from payload format 23,
  /// `budget_resources.notes`) from a JSON object
  static const notesKey = "notes";

  /// This is the key used to stringify or parse a shot's `locationNotes` column from a JSON object
  static const locationNotesKey = "locationNotes";

  /// This is the key used to stringify or parse a `needsCheck` column (`shots.needsCheck` or
  /// `breakdown_tags.needsCheck`) from a JSON object
  static const needsCheckKey = "needsCheck";

  /// This is the key used to stringify or parse a shot's `checkReason` column from a JSON object
  static const checkReasonKey = "checkReason";

  /// This is the key used to stringify or parse a person's `firstName` column from a JSON object
  static const firstNameKey = "firstName";

  /// This is the key used to stringify or parse a person's `lastName` column from a JSON object
  static const lastNameKey = "lastName";

  /// This is the key used to stringify or parse a person's `email` column from a JSON object
  static const emailKey = "email";

  /// This is the key used to stringify or parse a person's `phone` column from a JSON object
  static const phoneKey = "phone";

  /// This is the key used to stringify or parse a first address line column
  /// (`people.addressLine1` or `locations.addressLine1`) from a JSON object
  static const addressLine1Key = "addressLine1";

  /// This is the key used to stringify or parse a second address line column
  /// (`people.addressLine2` or `locations.addressLine2`) from a JSON object
  static const addressLine2Key = "addressLine2";

  /// This is the key used to stringify or parse a postal code column (`people.postalCode` or
  /// `locations.postalCode`) from a JSON object
  static const postalCodeKey = "postalCode";

  /// This is the key used to stringify or parse a region column (`people.region` or
  /// `locations.region`) from a JSON object
  static const regionKey = "region";

  /// This is the key used to stringify or parse a country column (`people.country` or
  /// `locations.country`) from a JSON object
  static const countryKey = "country";

  /// This is the key used to stringify or parse a city column (`people.city` or `locations.city`)
  /// from a JSON object
  static const cityKey = "city";

  /// This is the key used to stringify or parse a `colorIndex` column (`people` or `locations`)
  /// from a JSON object
  static const colorIndexKey = "colorIndex";

  /// This is the key used to stringify or parse a `role_candidates` row's `auditionedOn` column
  /// from a JSON object
  static const auditionedOnKey = "auditionedOn";

  /// This is the key used to stringify or parse a person's `birthDate` column from a JSON object
  static const birthDateKey = "birthDate";

  /// This is the key used to stringify or parse a person's `minorNotes` column from a JSON object
  static const minorNotesKey = "minorNotes";

  /// This is the key used to stringify or parse a person's `maxDailyPresenceMinutes` column from a
  /// JSON object
  static const maxDailyPresenceMinutesKey = "maxDailyPresenceMinutes";

  /// This is the key used to stringify or parse a person's `isTransportAutonomous` column from a
  /// JSON object
  static const isTransportAutonomousKey = "isTransportAutonomous";

  /// This is the key used to stringify or parse a person's `accommodationNotes` column from a JSON
  /// object
  static const accommodationNotesKey = "accommodationNotes";

  /// This is the key used to stringify or parse a person's `travelNotes` column from a JSON object
  static const travelNotesKey = "travelNotes";

  /// This is the key used to stringify or parse a person's `dietaryNotes` column from a JSON object
  static const dietaryNotesKey = "dietaryNotes";

  /// This is the key used to stringify or parse a person's `allergies` column from a JSON object
  static const allergiesKey = "allergies";

  /// This is the key used to stringify or parse a person's `measurementHeight` column from a JSON
  /// object
  static const measurementHeightKey = "measurementHeight";

  /// This is the key used to stringify or parse a person's `measurementChest` column from a JSON
  /// object
  static const measurementChestKey = "measurementChest";

  /// This is the key used to stringify or parse a person's `measurementWaist` column from a JSON
  /// object
  static const measurementWaistKey = "measurementWaist";

  /// This is the key used to stringify or parse a person's `measurementHips` column from a JSON
  /// object
  static const measurementHipsKey = "measurementHips";

  /// This is the key used to stringify or parse a person's `sizeTop` column from a JSON object
  static const sizeTopKey = "sizeTop";

  /// This is the key used to stringify or parse a person's `sizeBottom` column from a JSON object
  static const sizeBottomKey = "sizeBottom";

  /// This is the key used to stringify or parse a person's `sizeShoes` column from a JSON object
  static const sizeShoesKey = "sizeShoes";

  /// This is the key used to stringify or parse a person's `hmcNotes` column from a JSON object
  static const hmcNotesKey = "hmcNotes";

  /// This is the key used to stringify or parse a person's `imageRightsStatus` column from a JSON
  /// object
  static const imageRightsStatusKey = "imageRightsStatus";

  /// This is the key used to stringify or parse a person's `imageRightsDate` column from a JSON
  /// object
  static const imageRightsDateKey = "imageRightsDate";

  /// This is the key used to stringify or parse a person's `imageRightsAssetId` column from a JSON
  /// object
  static const imageRightsAssetIdKey = "imageRightsAssetId";

  /// This is the key used to stringify or parse a `photoAssetId` column (`people` or `elements`)
  /// from a JSON object
  static const photoAssetIdKey = "photoAssetId";

  /// This is the key used to stringify or parse a `personId` column (`person_positions`,
  /// `person_skills`, `person_unavailabilities`, `roles.personId`, `locations.contactPersonId`'s
  /// sibling name aside, `elements.ownerPersonId`/`broughtByPersonId`, `assets.personId`,
  /// `shooting_slot_crew.personId`, `shooting_presences.personId`, `role_candidates.personId` —
  /// the person seen for a part, from payload format 16 — or, nullable there,
  /// `shooting_slot_guests.personId`) from a JSON object
  static const personIdKey = "personId";

  /// This is the key used to stringify or parse a `positionId` column (`person_positions` or
  /// `shooting_slot_crew`) from a JSON object
  static const positionIdKey = "positionId";

  /// This is the key used to stringify or parse a `customLabel` column (`person_positions` or
  /// `shooting_slot_crew`) from a JSON object
  static const customLabelKey = "customLabel";

  /// This is the key used to stringify or parse a `label` column (`person_skills.label`,
  /// `assets.label`, `shooting_slots.label`, `shooting_day_blocks.label`,
  /// `shooting_day_events.label`, `budget_postes.label`, `budget_lines.label`, from payload format
  /// 17 `budget_entries.label`/`budget_commitments.label`, or, from payload format 18,
  /// `budget_resources.label`/`budget_mileage_rates.label`) from a JSON object
  static const labelKey = "label";

  /// This is the key used to stringify or parse an unavailability's `startDate` column from a
  /// JSON object
  static const startDateKey = "startDate";

  /// This is the key used to stringify or parse an unavailability's `endDate` column from a JSON
  /// object
  static const endDateKey = "endDate";

  /// This is the key used to stringify or parse an unavailability's `slot` column from a JSON
  /// object
  static const slotKey = "slot";

  /// This is the key used to stringify or parse a `startMinute` column (an unavailability's or a
  /// location availability's) from a JSON object. A `shooting_slots` row reads its own start off
  /// [OcptVersionJsonProductionKeys.anchorMinuteKey],
  /// [OcptVersionJsonProductionKeys.anchorEdgeKey] and
  /// [OcptVersionJsonProductionKeys.anchorSlotIdKey] instead.
  static const startMinuteKey = "startMinute";

  /// This is the key used to stringify or parse an unavailability's `endMinute` column from a JSON
  /// object
  static const endMinuteKey = "endMinute";

  /// This is the key used to stringify or parse a `reason` column (an unavailability's or a
  /// `shooting_slot_guests.reason`) from a JSON object
  static const reasonKey = "reason";

  /// This is the key used to stringify or parse a `shooting_slot_guests.freeName` column from a
  /// JSON object
  static const freeNameKey = "freeName";

  /// This is the key used to stringify or parse a weekday mask from a JSON object
  static const weekdaysKey = "weekdays";

  /// This is the key used to stringify or parse a single note from a JSON object
  static const noteKey = "note";

  /// This is the key used to stringify or parse a `name` column (`roles`, `locations`, `sets` or
  /// `elements`) from a JSON object
  static const nameKey = "name";

  /// This is the key used to stringify or parse a `kind` column (`roles.kind`, `assets.kind`,
  /// `shooting_day_blocks.kind` or, from payload format 17, `shooting_days.kind`) from a JSON
  /// object
  static const kindKey = "kind";

  /// This is the key used to stringify or parse a breakdown tag's `targetKind` column from a JSON
  /// object.
  ///
  /// Its own key rather than a reuse of [kindKey]: that one already serves two columns which are
  /// each a table describing *itself* (what kind of role, what kind of asset), while a tag's
  /// `targetKind` describes which of a **different** row's ids
  /// ([OcptVersionJsonProductionKeys.elementIdKey], [OcptVersionJsonProductionKeys.roleIdKey] or
  /// [OcptVersionJsonProductionKeys.setIdKey]) is the one that means something — a distinct enough
  /// idea, and overloading [kindKey] with it would only make a reader of the stored JSON wonder
  /// which sense a given `"kind"` key holds.
  static const targetKindKey = "targetKind";

  /// This is the key used to stringify or parse a role's `isFromScreenplay` column from a JSON
  /// object
  static const isFromScreenplayKey = "isFromScreenplay";

  /// This is the key used to stringify or parse a role's `orphanedName` column from a JSON object
  static const orphanedNameKey = "orphanedName";

  /// This is the key used to stringify or parse a role's `castingNotes` column from a JSON object
  static const castingNotesKey = "castingNotes";

  /// This is the key used to stringify or parse a location's `latitude` column from a JSON object
  static const latitudeKey = "latitude";

  /// This is the key used to stringify or parse a location's `longitude` column from a JSON object
  static const longitudeKey = "longitude";

  /// This is the key used to stringify or parse a location's `contactPersonId` column from a JSON
  /// object
  static const contactPersonIdKey = "contactPersonId";

  /// This is the key used to stringify or parse a location's `contactNotes` column from a JSON
  /// object
  static const contactNotesKey = "contactNotes";

  /// This is the key used to stringify or parse a location's `permitStatus` column from a JSON
  /// object
  static const permitStatusKey = "permitStatus";

  /// This is the key used to stringify or parse a location's `permitLabel` column from a JSON
  /// object
  static const permitLabelKey = "permitLabel";

  /// This is the key used to stringify or parse a location's `permitDate` column from a JSON object
  static const permitDateKey = "permitDate";

  /// This is the key used to stringify or parse a location's `permitAssetId` column from a JSON
  /// object
  static const permitAssetIdKey = "permitAssetId";

  /// This is the key used to stringify or parse a location's `parkingNotes` column from a JSON
  /// object
  static const parkingNotesKey = "parkingNotes";

  /// This is the key used to stringify or parse a location's `powerNotes` column from a JSON object
  static const powerNotesKey = "powerNotes";

  /// This is the key used to stringify or parse a location's `facilitiesNotes` column from a JSON
  /// object
  static const facilitiesNotesKey = "facilitiesNotes";

  /// This is the key used to stringify or parse a location's `constraintsNotes` column from a JSON
  /// object
  static const constraintsNotesKey = "constraintsNotes";

  /// This is the key used to stringify or parse a `locationId` column (`sets` or `shooting_slots`)
  /// from a JSON object
  static const locationIdKey = "locationId";

  /// This is the key used to stringify or parse a `code` column (`sets`, `elements` or, holding the
  /// enum name rather than a minted identifier there, `shooting_presences.code`) from a JSON object
  static const codeKey = "code";
}
