// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'dart:convert';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

/// The single place that knows the shape of `project_versions.payload`: it turns an
/// [OcptProjectVersionPayload] into the JSON text stored in a version's row, and back.
///
/// Reading the rows out of a project and writing them back into one is
/// `OcptProjectVersionsService`'s job; this class never touches a database. What it owns is the
/// **format**, and the format outlives the app build that wrote it: a payload sits in a user's
/// `.ocpt` for as long as the version does, so [decode] is a migration path rather than only a
/// guard —
///
/// - a payload written in an **older** format is upgraded, in memory, step by step, up to
///   [currentPayloadFormat]; the stored text is never rewritten, so a version stays byte-identical
///   to what was captured;
/// - a payload written in a **newer** format — the file has been opened by a later build of the
///   app — is refused with [OcptProjectVersionPayloadStatus.unsupportedFutureFormat] rather than
///   half-restored.
///
/// The column lists below are a **hand-written mirror of the schema**: a synchronised table gaining
/// a column means this codec, and very probably [currentPayloadFormat], need looking at. When that
/// day comes, add a named upgrade step to [_payloadUpgrades] and keep a fixture of the retired
/// format in the tests — the point of the format field is lost if nothing ever exercises the old
/// branch.
class OcptProjectVersionCodec {
  /// The payload format this build writes, and the highest one it can read.
  ///
  /// Deliberately **independent of the database's schema version**: the two evolve for different
  /// reasons and a payload is read long after the file it lives in has been migrated.
  static const currentPayloadFormat = 25;

  /// This is the key used to stringify or parse the payload's own format from a JSON object
  static const _payloadFormatKey = "payloadFormat";

  /// This is the key used to stringify or parse the `screenplays` rows from a JSON object
  static const _screenplaysKey = "screenplays";

  /// This is the key used to stringify or parse the `scenes` rows from a JSON object
  static const _scenesKey = "scenes";

  /// This is the key used to stringify or parse the `shots` rows from a JSON object
  static const _shotsKey = "shots";

  /// This is the key used to stringify or parse the `shot_characters` rows from a JSON object
  static const _shotCharactersKey = "shotCharacters";

  /// This is the key used to stringify or parse the `shot_coverages` rows from a JSON object
  static const _shotCoveragesKey = "shotCoverages";

  /// This is the key used to stringify or parse the `people` rows from a JSON object
  static const _peopleKey = "people";

  /// This is the key used to stringify or parse the `person_positions` rows from a JSON object
  static const _personPositionsKey = "personPositions";

  /// This is the key used to stringify or parse the `person_skills` rows from a JSON object
  static const _personSkillsKey = "personSkills";

  /// This is the key used to stringify or parse the `person_unavailabilities` rows from a JSON
  /// object
  static const _personUnavailabilitiesKey = "personUnavailabilities";

  /// This is the key used to stringify or parse the `roles` rows from a JSON object
  static const _rolesKey = "roles";

  /// This is the key used to stringify or parse the `role_episodes` rows from a JSON object: which
  /// episodes a role is named in, from payload format 13
  /// (`docs/adr/0019-one-project-several-episodes.md`).
  static const _roleEpisodesKey = "roleEpisodes";

  /// This is the key used to stringify or parse the `locations` rows from a JSON object
  static const _locationsKey = "locations";

  /// This is the key used to stringify or parse the `location_availabilities` rows from a JSON
  /// object
  static const _locationAvailabilitiesKey = "locationAvailabilities";

  /// This is the key used to stringify or parse the `sets` rows from a JSON object
  static const _setsKey = "sets";

  /// This is the key used to stringify or parse the `scene_sets` rows from a JSON object
  static const _sceneSetsKey = "sceneSets";

  /// This is the key used to stringify or parse the `elements` rows from a JSON object
  static const _elementsKey = "elements";

  /// This is the key used to stringify or parse the `scene_elements` rows from a JSON object
  static const _sceneElementsKey = "sceneElements";

  /// This is the key used to stringify or parse the `role_elements` rows from a JSON object
  static const _roleElementsKey = "roleElements";

  /// This is the key used to stringify or parse the `role_candidates` rows from a JSON object: who
  /// was seen for each part, from payload format 16.
  static const _roleCandidatesKey = "roleCandidates";

  /// This is the key used to stringify or parse the `assets` rows from a JSON object
  static const _assetsKey = "assets";

  /// This is the key used to stringify or parse the `breakdown_tags` rows from a JSON object
  static const _breakdownTagsKey = "breakdownTags";

  /// This is the key used to stringify or parse the `scene_breakdowns` rows from a JSON object
  static const _sceneBreakdownsKey = "sceneBreakdowns";

  /// This is the key used to stringify or parse the `shooting_days` rows from a JSON object
  static const _shootingDaysKey = "shootingDays";

  /// The key a payload of format 7 stored the `shooting_day_groups` rows under — read only by
  /// [_upgradeFormat7To8], which drops it: the table itself is gone from format 8 on.
  static const _shootingDayGroupsKey = "shootingDayGroups";

  /// This is the key used to stringify or parse the `shooting_slots` rows from a JSON object
  static const _shootingSlotsKey = "shootingSlots";

  /// This is the key used to stringify or parse the `shooting_slot_crew` rows from a JSON object
  static const _shootingSlotCrewKey = "shootingSlotCrew";

  /// This is the key used to stringify or parse the `shooting_slot_cast` rows from a JSON object
  static const _shootingSlotCastKey = "shootingSlotCast";

  /// This is the key used to stringify or parse the `shooting_day_blocks` rows from a JSON object
  static const _shootingDayBlocksKey = "shootingDayBlocks";

  /// The key a payload of format 11 (or earlier) stored the `shooting_presences` rows under — read
  /// only by [_upgradeFormat11To12], which drops it: the table itself is gone from format 12 on,
  /// exactly as [_shootingDayGroupsKey] is for [_upgradeFormat7To8].
  static const _shootingPresencesKey = "shootingPresences";

  /// This is the key used to stringify or parse the `shooting_slot_guests` rows from a JSON object
  static const _shootingSlotGuestsKey = "shootingSlotGuests";

  /// This is the key used to stringify or parse the `shooting_slot_candidates` rows from a JSON
  /// object: which candidate each slot convoked, from payload format 18. Written by no version any
  /// more, and read only by [_upgradeFormat19To20], which drops it — the table itself is gone from
  /// format 20 on, exactly as [_shootingDayGroupsKey] is for [_upgradeFormat7To8].
  static const _shootingSlotCandidatesKey = "shootingSlotCandidates";

  /// This is the key used to stringify or parse the `shooting_block_candidates` rows from a JSON
  /// object: which candidacies each audition block sees, from payload format 20.
  static const _shootingBlockCandidatesKey = "shootingBlockCandidates";

  /// This is the key used to stringify or parse a `blockId` column
  /// (`shooting_block_candidates.blockId`, always non-null, the audition a candidacy is seen at)
  /// from a JSON object, from payload format 20
  static const _blockIdKey = "blockId";

  /// This is the key used to stringify or parse a `roleCandidateId` column
  /// (`shooting_block_candidates.roleCandidateId`, always non-null, the candidacy an audition block
  /// sees; formerly `shooting_slot_candidates.roleCandidateId` and
  /// `shooting_day_blocks.roleCandidateId`, both gone) from a JSON object, from payload format 18
  static const _roleCandidateIdKey = "roleCandidateId";

  /// This is the key used to stringify or parse the `shooting_day_events` rows from a JSON object
  static const _shootingDayEventsKey = "shootingDayEvents";

  /// This is the key used to stringify or parse the `row_field_versions` rows from a JSON object
  static const _rowFieldVersionsKey = "rowFieldVersions";

  /// This is the key used to stringify or parse the project's own settings from a JSON object
  static const _projectSettingsKey = "projectSettings";

  /// This is the key used to stringify or parse the page margins from a JSON object
  static const _pageMarginsKey = "pageMargins";

  /// This is the key used to stringify or parse a row's `id` column from a JSON object
  static const _idKey = "id";

  /// This is the key used to stringify or parse a row's `isDeleted` column from a JSON object
  static const _isDeletedKey = "isDeleted";

  /// This is the key used to stringify or parse a row's `position` column from a JSON object
  static const _positionKey = "position";

  /// This is the key used to stringify or parse a row's `sortKey` column from a JSON object
  static const _sortKeyKey = "sortKey";

  /// This is the key used to stringify or parse a `screenplayId` column — `scenes.screenplayId`,
  /// `shots.screenplayId` or, from payload format 13, `role_episodes.screenplayId` (the episode a
  /// role is named in) — from a JSON object.
  ///
  /// `roles.screenplayId` and `shooting_days.screenplayId` read and wrote this same key up to
  /// format 12: schema version 18 drops both columns
  /// (`docs/adr/0019-one-project-several-episodes.md`) — a role belongs to the production now, not
  /// to any one screenplay, and a shooting day belongs to no episode at all, a day regularly
  /// covering two of them — so from format 13 on this key serves three tables, not five.
  static const _screenplayIdKey = "screenplayId";

  /// This is the key used to stringify or parse a row's `sceneId` column from a JSON object
  static const _sceneIdKey = "sceneId";

  /// This is the key used to stringify or parse a row's `shotId` column from a JSON object
  static const _shotIdKey = "shotId";

  /// This is the key used to stringify or parse a screenplay's `title` column from a JSON object
  static const _titleKey = "title";

  /// This is the key used to stringify or parse a screenplay's `fountainText` column from a JSON
  /// object
  static const _fountainTextKey = "fountainText";

  /// This is the key used to stringify or parse a screenplay's `updatedAt` column from a JSON
  /// object
  static const _updatedAtKey = "updatedAt";

  /// This is the key used to stringify or parse a screenplay's `number` column from a JSON object:
  /// its printed episode number, from payload format 13
  /// (`docs/adr/0019-one-project-several-episodes.md`).
  static const _numberKey = "number";

  /// This is the key used to stringify or parse a scene's `heading` column from a JSON object
  static const _headingKey = "heading";

  /// This is the key used to stringify or parse a scene's `sceneNumber` column from a JSON object
  static const _sceneNumberKey = "sceneNumber";

  /// This is the key used to stringify or parse a scene's `charStart` column from a JSON object
  static const _charStartKey = "charStart";

  /// This is the key used to stringify or parse a scene's `charEnd` column from a JSON object
  static const _charEndKey = "charEnd";

  /// This is the key used to stringify or parse a shot's `orphanedHeading` column from a JSON
  /// object
  static const _orphanedHeadingKey = "orphanedHeading";

  /// This is the key used to stringify or parse a shot's `shotSize` column from a JSON object
  static const _shotSizeKey = "shotSize";

  /// This is the key used to stringify or parse a shot's `abbreviation` column from a JSON object
  static const _abbreviationKey = "abbreviation";

  /// This is the key used to stringify or parse a shot's `framing` column from a JSON object
  static const _framingKey = "framing";

  /// This is the key used to stringify or parse a shot's `cameraMove` column from a JSON object
  static const _cameraMoveKey = "cameraMove";

  /// This is the key used to stringify or parse a shot's `lens` column from a JSON object
  static const _lensKey = "lens";

  /// This is the key used to stringify or parse a shot's `recordingFormat` column from a JSON
  /// object
  static const _recordingFormatKey = "recordingFormat";

  /// This is the key used to stringify or parse a shot's `estimatedDurationMs` column from a JSON
  /// object
  static const _estimatedDurationMsKey = "estimatedDurationMs";

  /// This is the key used to stringify or parse a shot's `shootingDay` column from a JSON object
  static const _shootingDayKey = "shootingDay";

  /// This is the key used to stringify or parse a shot's `plannedTakes` column from a JSON object
  static const _plannedTakesKey = "plannedTakes";

  /// This is the key used to stringify or parse a shot's `sound` column from a JSON object
  static const _soundKey = "sound";

  /// This is the key used to stringify or parse a `status` column (`shots.status`,
  /// `elements.status`, `scene_breakdowns.status`, `shooting_days.status`, from payload format 16
  /// `role_candidates.status`, from payload format 22 `budget_commitments.status`, or, from payload
  /// format 23, `budget_resources.status`) from a JSON object
  static const _statusKey = "status";

  /// This is the key used to stringify or parse a shot's `difficultySet` column from a JSON object
  static const _difficultySetKey = "difficultySet";

  /// This is the key used to stringify or parse a shot's `difficultyCamera` column from a JSON
  /// object
  static const _difficultyCameraKey = "difficultyCamera";

  /// This is the key used to stringify or parse a shot's `difficultyActing` column from a JSON
  /// object
  static const _difficultyActingKey = "difficultyActing";

  /// This is the key used to stringify or parse a shot's `difficultySound` column from a JSON
  /// object
  static const _difficultySoundKey = "difficultySound";

  /// This is the key used to stringify or parse a free-form `notes` column (`shots.notes`,
  /// `people.notes`, `locations.notes`, `sets.notes`, `elements.notes`, `scene_elements.notes`,
  /// `role_elements.notes`, `role_candidates.notes`, `scene_breakdowns.notes`,
  /// `shooting_days.notes`, `shooting_slots.notes`,
  /// `shooting_slot_crew.notes`, `shooting_slot_cast.notes`, `shooting_slot_guests.notes`,
  /// `shooting_slot_candidates.notes`, `shooting_day_events.notes` or, from payload format 23,
  /// `budget_resources.notes`) from a JSON object
  static const _notesKey = "notes";

  /// This is the key used to stringify or parse a shot's `locationNotes` column from a JSON object
  static const _locationNotesKey = "locationNotes";

  /// This is the key used to stringify or parse a `needsCheck` column (`shots.needsCheck` or
  /// `breakdown_tags.needsCheck`) from a JSON object
  static const _needsCheckKey = "needsCheck";

  /// This is the key used to stringify or parse a shot's `checkReason` column from a JSON object
  static const _checkReasonKey = "checkReason";

  /// This is the key used to stringify or parse a shot character's `characterName` column from a
  /// JSON object
  static const _characterNameKey = "characterName";

  /// This is the key used to stringify or parse a person's `firstName` column from a JSON object
  static const _firstNameKey = "firstName";

  /// This is the key used to stringify or parse a person's `lastName` column from a JSON object
  static const _lastNameKey = "lastName";

  /// This is the key used to stringify or parse a person's `email` column from a JSON object
  static const _emailKey = "email";

  /// This is the key used to stringify or parse a person's `phone` column from a JSON object
  static const _phoneKey = "phone";

  /// This is the key used to stringify or parse a first address line column
  /// (`people.addressLine1` or `locations.addressLine1`) from a JSON object
  static const _addressLine1Key = "addressLine1";

  /// This is the key used to stringify or parse a second address line column
  /// (`people.addressLine2` or `locations.addressLine2`) from a JSON object
  static const _addressLine2Key = "addressLine2";

  /// This is the key used to stringify or parse a postal code column (`people.postalCode` or
  /// `locations.postalCode`) from a JSON object
  static const _postalCodeKey = "postalCode";

  /// This is the key used to stringify or parse a region column (`people.region` or
  /// `locations.region`) from a JSON object
  static const _regionKey = "region";

  /// This is the key used to stringify or parse a country column (`people.country` or
  /// `locations.country`) from a JSON object
  static const _countryKey = "country";

  /// This is the key used to stringify or parse a city column (`people.city` or `locations.city`)
  /// from a JSON object
  static const _cityKey = "city";

  /// This is the key used to stringify or parse a `colorIndex` column (`people` or `locations`)
  /// from a JSON object
  static const _colorIndexKey = "colorIndex";

  /// This is the key used to stringify or parse a `role_candidates` row's `auditionedOn` column
  /// from a JSON object
  static const _auditionedOnKey = "auditionedOn";

  /// This is the key used to stringify or parse a person's `birthDate` column from a JSON object
  static const _birthDateKey = "birthDate";

  /// This is the key used to stringify or parse a person's `minorNotes` column from a JSON object
  static const _minorNotesKey = "minorNotes";

  /// This is the key used to stringify or parse a person's `maxDailyPresenceMinutes` column from a
  /// JSON object
  static const _maxDailyPresenceMinutesKey = "maxDailyPresenceMinutes";

  /// This is the key used to stringify or parse a person's `isTransportAutonomous` column from a
  /// JSON object
  static const _isTransportAutonomousKey = "isTransportAutonomous";

  /// This is the key used to stringify or parse a person's `accommodationNotes` column from a JSON
  /// object
  static const _accommodationNotesKey = "accommodationNotes";

  /// This is the key used to stringify or parse a person's `travelNotes` column from a JSON object
  static const _travelNotesKey = "travelNotes";

  /// This is the key used to stringify or parse a person's `dietaryNotes` column from a JSON object
  static const _dietaryNotesKey = "dietaryNotes";

  /// This is the key used to stringify or parse a person's `allergies` column from a JSON object
  static const _allergiesKey = "allergies";

  /// This is the key used to stringify or parse a person's `measurementHeight` column from a JSON
  /// object
  static const _measurementHeightKey = "measurementHeight";

  /// This is the key used to stringify or parse a person's `measurementChest` column from a JSON
  /// object
  static const _measurementChestKey = "measurementChest";

  /// This is the key used to stringify or parse a person's `measurementWaist` column from a JSON
  /// object
  static const _measurementWaistKey = "measurementWaist";

  /// This is the key used to stringify or parse a person's `measurementHips` column from a JSON
  /// object
  static const _measurementHipsKey = "measurementHips";

  /// This is the key used to stringify or parse a person's `sizeTop` column from a JSON object
  static const _sizeTopKey = "sizeTop";

  /// This is the key used to stringify or parse a person's `sizeBottom` column from a JSON object
  static const _sizeBottomKey = "sizeBottom";

  /// This is the key used to stringify or parse a person's `sizeShoes` column from a JSON object
  static const _sizeShoesKey = "sizeShoes";

  /// This is the key used to stringify or parse a person's `hmcNotes` column from a JSON object
  static const _hmcNotesKey = "hmcNotes";

  /// This is the key used to stringify or parse a person's `imageRightsStatus` column from a JSON
  /// object
  static const _imageRightsStatusKey = "imageRightsStatus";

  /// This is the key used to stringify or parse a person's `imageRightsDate` column from a JSON
  /// object
  static const _imageRightsDateKey = "imageRightsDate";

  /// This is the key used to stringify or parse a person's `imageRightsAssetId` column from a JSON
  /// object
  static const _imageRightsAssetIdKey = "imageRightsAssetId";

  /// This is the key used to stringify or parse a `photoAssetId` column (`people` or `elements`)
  /// from a JSON object
  static const _photoAssetIdKey = "photoAssetId";

  /// This is the key used to stringify or parse a `personId` column (`person_positions`,
  /// `person_skills`, `person_unavailabilities`, `roles.personId`, `locations.contactPersonId`'s
  /// sibling name aside, `elements.ownerPersonId`/`broughtByPersonId`, `assets.personId`,
  /// `shooting_slot_crew.personId`, `shooting_presences.personId`, `role_candidates.personId` —
  /// the person seen for a part, from payload format 16 — or, nullable there,
  /// `shooting_slot_guests.personId`) from a JSON object
  static const _personIdKey = "personId";

  /// This is the key used to stringify or parse a `positionId` column (`person_positions` or
  /// `shooting_slot_crew`) from a JSON object
  static const _positionIdKey = "positionId";

  /// This is the key used to stringify or parse a `customLabel` column (`person_positions` or
  /// `shooting_slot_crew`) from a JSON object
  static const _customLabelKey = "customLabel";

  /// This is the key used to stringify or parse a `label` column (`person_skills.label`,
  /// `assets.label`, `shooting_slots.label`, `shooting_day_blocks.label`,
  /// `shooting_day_events.label`, `budget_postes.label`, `budget_lines.label`, from payload format
  /// 17 `budget_entries.label`/`budget_commitments.label`, or, from payload format 18,
  /// `budget_resources.label`/`budget_mileage_rates.label`) from a JSON object
  static const _labelKey = "label";

  /// This is the key used to stringify or parse an unavailability's `startDate` column from a
  /// JSON object
  static const _startDateKey = "startDate";

  /// This is the key used to stringify or parse an unavailability's `endDate` column from a JSON
  /// object
  static const _endDateKey = "endDate";

  /// This is the key used to stringify or parse an unavailability's `slot` column from a JSON
  /// object
  static const _slotKey = "slot";

  /// This is the key used to stringify or parse a `startMinute` column (an unavailability's or a
  /// location availability's) from a JSON object.
  ///
  /// Payload formats 7 and 8 also stored `shooting_slots.startMinute` under it, back when a slot
  /// owned one typed start and nothing else; from format 9 on that column is
  /// [_anchorMinuteKey]/[_anchorEdgeKey]/[_anchorSlotIdKey], and this key is read for a slot only
  /// by [_upgradeFormat8To9], which renames it.
  static const _startMinuteKey = "startMinute";

  /// This is the key used to stringify or parse an unavailability's `endMinute` column from a JSON
  /// object
  static const _endMinuteKey = "endMinute";

  /// This is the key used to stringify or parse a `reason` column (an unavailability's or a
  /// `shooting_slot_guests.reason`) from a JSON object
  static const _reasonKey = "reason";

  /// This is the key used to stringify or parse a `shooting_slot_guests.freeName` column from a
  /// JSON object
  static const _freeNameKey = "freeName";

  /// This is the key used to stringify or parse a weekday mask from a JSON object
  static const _weekdaysKey = "weekdays";

  /// This is the key used to stringify or parse a single note from a JSON object
  static const _noteKey = "note";

  /// This is the key used to stringify or parse a `name` column (`roles`, `locations`, `sets` or
  /// `elements`) from a JSON object
  static const _nameKey = "name";

  /// This is the key used to stringify or parse a `kind` column (`roles.kind`, `assets.kind`,
  /// `shooting_day_blocks.kind` or, from payload format 17, `shooting_days.kind`) from a JSON
  /// object
  static const _kindKey = "kind";

  /// This is the key used to stringify or parse a breakdown tag's `targetKind` column from a JSON
  /// object.
  ///
  /// Its own key rather than a reuse of [_kindKey]: that one already serves two columns which are
  /// each a table describing *itself* (what kind of role, what kind of asset), while a tag's
  /// `targetKind` describes which of a **different** row's ids ([_elementIdKey], [_roleIdKey] or
  /// [_setIdKey]) is the one that means something — a distinct enough idea, and overloading
  /// [_kindKey] with it would only make a reader of the stored JSON wonder which sense a given
  /// `"kind"` key holds.
  static const _targetKindKey = "targetKind";

  /// This is the key used to stringify or parse a role's `isFromScreenplay` column from a JSON
  /// object
  static const _isFromScreenplayKey = "isFromScreenplay";

  /// This is the key used to stringify or parse a role's `orphanedName` column from a JSON object
  static const _orphanedNameKey = "orphanedName";

  /// This is the key used to stringify or parse a role's `castingNotes` column from a JSON object
  static const _castingNotesKey = "castingNotes";

  /// This is the key used to stringify or parse a location's `latitude` column from a JSON object
  static const _latitudeKey = "latitude";

  /// This is the key used to stringify or parse a location's `longitude` column from a JSON object
  static const _longitudeKey = "longitude";

  /// This is the key used to stringify or parse a location's `contactPersonId` column from a JSON
  /// object
  static const _contactPersonIdKey = "contactPersonId";

  /// This is the key used to stringify or parse a location's `contactNotes` column from a JSON
  /// object
  static const _contactNotesKey = "contactNotes";

  /// This is the key used to stringify or parse a location's `permitStatus` column from a JSON
  /// object
  static const _permitStatusKey = "permitStatus";

  /// This is the key used to stringify or parse a location's `permitLabel` column from a JSON
  /// object
  static const _permitLabelKey = "permitLabel";

  /// This is the key used to stringify or parse a location's `permitDate` column from a JSON object
  static const _permitDateKey = "permitDate";

  /// This is the key used to stringify or parse a location's `permitAssetId` column from a JSON
  /// object
  static const _permitAssetIdKey = "permitAssetId";

  /// This is the key used to stringify or parse a location's `parkingNotes` column from a JSON
  /// object
  static const _parkingNotesKey = "parkingNotes";

  /// This is the key used to stringify or parse a location's `powerNotes` column from a JSON object
  static const _powerNotesKey = "powerNotes";

  /// This is the key used to stringify or parse a location's `facilitiesNotes` column from a JSON
  /// object
  static const _facilitiesNotesKey = "facilitiesNotes";

  /// This is the key used to stringify or parse a location's `constraintsNotes` column from a JSON
  /// object
  static const _constraintsNotesKey = "constraintsNotes";

  /// This is the key used to stringify or parse a `locationId` column (`sets` or `shooting_slots`)
  /// from a JSON object
  static const _locationIdKey = "locationId";

  /// This is the key used to stringify or parse a `code` column (`sets`, `elements` or, holding the
  /// enum name rather than a minted identifier there, `shooting_presences.code`) from a JSON object
  static const _codeKey = "code";

  /// This is the key used to stringify or parse a `setId` column (`scene_sets.setId`,
  /// `breakdown_tags.setId` or `shooting_slots.setId`) from a JSON object
  static const _setIdKey = "setId";

  /// This is the key used to stringify or parse a `roleId` column
  /// (`breakdown_tags.roleId` — the sibling of [_elementIdKey] and [_setIdKey], non-null only when
  /// the tag's `targetKind` names a role —, `shooting_slot_cast.roleId`, always non-null, the role
  /// a slot convokes, `role_elements.roleId`, the role wearing an element, or, from payload format
  /// 13, `role_episodes.roleId`, the role an episode names, or, from payload format 16,
  /// `role_candidates.roleId`, the part somebody is seen for) from a JSON
  /// object
  static const _roleIdKey = "roleId";

  /// This is the key used to stringify or parse an element's `category` column from a JSON object
  static const _categoryKey = "category";

  /// This is the key used to stringify or parse an element's `subCategory` column from a JSON
  /// object
  static const _subCategoryKey = "subCategory";

  /// This is the key used to stringify or parse a `quantity` column (`elements` or
  /// `scene_elements`) from a JSON object
  static const _quantityKey = "quantity";

  /// This is the key used to stringify or parse an element's `sourceKind` column from a JSON object
  static const _sourceKindKey = "sourceKind";

  /// This is the key used to stringify or parse an element's `ownerPersonId` column from a JSON
  /// object
  static const _ownerPersonIdKey = "ownerPersonId";

  /// This is the key used to stringify or parse an element's `ownerNotes` column from a JSON object
  static const _ownerNotesKey = "ownerNotes";

  /// This is the key used to stringify or parse an element's `broughtByPersonId` column from a
  /// JSON object
  static const _broughtByPersonIdKey = "broughtByPersonId";

  /// This is the key used to stringify or parse an element's `storageNotes` column from a JSON
  /// object
  static const _storageNotesKey = "storageNotes";

  /// This is the key used to stringify or parse an element's `isSecured` column from a JSON object
  static const _isSecuredKey = "isSecured";

  /// This is the key used to stringify or parse an element's `isReadyForShoot` column from a JSON
  /// object
  static const _isReadyForShootKey = "isReadyForShoot";

  /// This is the key used to stringify or parse an element's `isReturned` column from a JSON object
  static const _isReturnedKey = "isReturned";

  /// This is the key used to stringify or parse an element's `cost` column from a JSON object
  static const _costKey = "cost";

  /// This is the key used to stringify or parse an element's `purposeNotes` column from a JSON
  /// object
  static const _purposeNotesKey = "purposeNotes";

  /// This is the key used to stringify or parse an `elementId` column (`scene_elements.elementId`,
  /// `role_elements.elementId` or `breakdown_tags.elementId`) from a JSON object
  static const _elementIdKey = "elementId";

  /// This is the key used to stringify or parse an asset's `path` column from a JSON object
  static const _pathKey = "path";

  /// This is the key used to stringify or parse an asset's `addedAt` column from a JSON object
  static const _addedAtKey = "addedAt";

  /// This is the key used to stringify or parse an asset's `validFrom` column from a JSON object
  static const _validFromKey = "validFrom";

  /// This is the key used to stringify or parse an asset's `validUntil` column from a JSON object
  static const _validUntilKey = "validUntil";

  /// This is the key used to stringify or parse a scene-relative `startOffset` column
  /// (`shot_coverages.startOffset` or `breakdown_tags.startOffset`) from a JSON object
  static const _startOffsetKey = "startOffset";

  /// This is the key used to stringify or parse a scene-relative `endOffset` column
  /// (`shot_coverages.endOffset` or `breakdown_tags.endOffset`) from a JSON object
  static const _endOffsetKey = "endOffset";

  /// This is the key used to stringify or parse a breakdown tag's `taggedText` column from a JSON
  /// object: the tagged passage, verbatim — unlike the neighbouring `shot_coverages`, which stores
  /// only a digest (see `OcptBreakdownTagsTable`'s own doc comment for why).
  static const _taggedTextKey = "taggedText";

  /// This is the key used to stringify or parse a coverage's `coveredTextDigest` column from a JSON
  /// object
  static const _coveredTextDigestKey = "coveredTextDigest";

  /// This is the key used to stringify or parse a `shootingDayId` column (`shooting_slots`,
  /// `shooting_day_blocks`, `shooting_presences` or `shooting_day_events`) from a JSON object
  static const _shootingDayIdKey = "shootingDayId";

  /// This is the key used to stringify or parse a `slotId` column (`shooting_slot_crew`,
  /// `shooting_slot_cast`, `shooting_day_blocks` or `shooting_slot_guests`) from a JSON object —
  /// the foreign key onto a `shooting_slots` row, not to be confused with [_slotKey], the day-part
  /// enum `person_unavailabilities`/`location_availabilities` carry.
  static const _slotIdKey = "slotId";

  /// This is the key used to stringify or parse a `shooting_days.date` column, or, from payload
  /// format 17, a `budget_entries.date` column, from a JSON object
  static const _dateKey = "date";

  /// This is the key used to stringify or parse a `shooting_day_events.minute` column from a JSON
  /// object — the hour it happens at, an offset from the day's own midnight.
  static const _minuteKey = "minute";

  /// This is the key used to stringify or parse a `crewNote` column (`shooting_days.crewNote`, the
  /// note for the whole day, or `shooting_day_blocks.crewNote`, one block narrower) from a JSON
  /// object — both printed, unlike [_notesKey], which never is.
  static const _crewNoteKey = "crewNote";

  /// This is the key used to stringify or parse a shooting day's `weatherNote` column from a JSON
  /// object
  static const _weatherNoteKey = "weatherNote";

  /// This is the key used to stringify or parse `shooting_slots.crewCallMinute`, a format-6-or-
  /// earlier payload's own name for what [_startMinuteKey] reads from here on — the only one of the
  /// six retired minute keys [_upgradeFormat6To7] still has to read; `crewWrapMinute`,
  /// `castCallMinute`, `castWrapMinute` (both `shooting_slots` and `shooting_slot_cast`),
  /// `shooting_slot_crew.callMinute`/`wrapMinute` and `shooting_slot_cast.arrivalMinute` are all
  /// simply dropped columns from here on, computed rather than carried forward (ADR 0017), so
  /// nothing needs their own key named.
  static const _crewCallMinuteKey = "crewCallMinute";

  /// This is the key used to stringify or parse a `shooting_day_blocks.durationMinutes` column from
  /// a JSON object
  static const _durationMinutesKey = "durationMinutes";

  /// This is the key used to stringify or parse an `anchorMinute` column — a
  /// `shooting_day_blocks`', the minute a block is pinned to, or (from payload format 9) a
  /// `shooting_slots`', the hour its own anchored edge is pinned to — from a JSON object
  static const _anchorMinuteKey = "anchorMinute";

  /// The key a `shooting_slot_crew`/`shooting_slot_cast` row of payload format 7 stored its
  /// `groupId` column under: the `shooting_day_groups` row a convocation briefly could belong to.
  /// Read by [_upgradeFormat6To7], which writes it as null, and by [_upgradeFormat7To8], which
  /// drops it again — the column itself is gone from format 8 on.
  static const _groupIdKey = "groupId";

  /// The key a payload-format-7 row (`shooting_slot_crew` or `shooting_slot_cast`) stored its
  /// `leadMinutes` column under. Read by [_upgradeFormat6To7], which writes it as null, and by
  /// [_upgradeFormat7To8], which drops it again — the column itself is gone from format 8 on.
  static const _leadMinutesKey = "leadMinutes";

  /// This is the key used to stringify or parse a `shooting_slots.anchorEdge` column from a JSON
  /// object
  static const _anchorEdgeKey = "anchorEdge";

  /// This is the key used to stringify or parse a `shooting_slots.anchorSlotId` column from a JSON
  /// object — the slot whose opposite edge this one reads its hour off.
  static const _anchorSlotIdKey = "anchorSlotId";

  /// This is the key used to stringify or parse a version stamp's `tableName` column from a JSON
  /// object
  static const _tableNameKey = "tableName";

  /// This is the key used to stringify or parse a version stamp's `rowId` column from a JSON object
  static const _rowIdKey = "rowId";

  /// This is the key used to stringify or parse a version stamp's `columnName` column from a JSON
  /// object
  static const _columnNameKey = "columnName";

  /// This is the key used to stringify or parse a version stamp's `version` column from a JSON
  /// object
  static const _versionKey = "version";

  /// This is the key used to stringify or parse a version stamp's `deviceId` column from a JSON
  /// object
  static const _deviceIdKey = "deviceId";

  /// This is the key used to stringify or parse the project's `pageFormat` from a JSON object
  static const _pageFormatKey = "pageFormat";

  /// This is the key used to stringify or parse the project's `currencyCode` from a JSON object
  static const _currencyCodeKey = "currencyCode";

  /// This is the key used to stringify or parse the project's `settingsJson` from a JSON object
  static const _settingsJsonKey = "settingsJson";

  /// This is the key used to stringify or parse the project's `minimumRestMinutes` from a JSON
  /// object
  static const _minimumRestMinutesKey = "minimumRestMinutes";

  /// This is the key used to stringify or parse the project's `screenplayLanguage` from a JSON
  /// object
  static const _screenplayLanguageKey = "screenplayLanguage";

  /// This is the key used to stringify or parse the `project_dictionary_words` rows from a JSON
  /// object, from payload format 15: the words a writer has taught this project's spell checker.
  static const _projectDictionaryWordsKey = "projectDictionaryWords";

  /// This is the key used to stringify or parse a `project_dictionary_words.word` column from a
  /// JSON object
  static const _wordKey = "word";

  /// This is the key used to stringify or parse the `budget_postes` rows from a JSON object, from
  /// payload format 16: the budget mode's own catalogue.
  static const _budgetPostesKey = "budgetPostes";

  /// This is the key used to stringify or parse the `budget_lines` rows from a JSON object, from
  /// payload format 16: the quote lines inside each poste.
  static const _budgetLinesKey = "budgetLines";

  /// This is the key used to stringify or parse a `budget_postes.simpleLabel` column from a JSON
  /// object
  static const _simpleLabelKey = "simpleLabel";

  /// This is the key used to stringify or parse a `posteId` column (`budget_lines.posteId` or,
  /// from payload format 17, `budget_entries.posteId`/`budget_commitments.posteId`) from a JSON
  /// object
  static const _posteIdKey = "posteId";

  /// This is the key used to stringify or parse a `budget_lines.quantityMilli` column from a JSON
  /// object
  static const _quantityMilliKey = "quantityMilli";

  /// This is the key used to stringify or parse a `budget_lines.unit` column from a JSON object
  static const _unitKey = "unit";

  /// This is the key used to stringify or parse a `budget_lines.unitAmountCents` column from a JSON
  /// object
  static const _unitAmountCentsKey = "unitAmountCents";

  /// This is the key used to stringify or parse an `isTaxInclusive` column (`budget_lines`'s or,
  /// from payload format 17, `budget_entries`'s/`budget_commitments`'s) from a JSON object
  static const _isTaxInclusiveKey = "isTaxInclusive";

  /// This is the key used to stringify or parse a `vatRateBasisPoints` column (`budget_lines`'s or,
  /// from payload format 17, `budget_entries`'s/`budget_commitments`'s) from a JSON object
  static const _vatRateBasisPointsKey = "vatRateBasisPoints";

  /// This is the key used to stringify or parse the project's `defaultVatRateBasisPoints` from a
  /// JSON object, from payload format 16
  static const _defaultVatRateBasisPointsKey = "defaultVatRateBasisPoints";

  /// This is the key used to stringify or parse the project's `mealPriceCents` from a JSON object,
  /// from payload format 16
  static const _mealPriceCentsKey = "mealPriceCents";

  /// This is the key used to stringify or parse the project's `snackPriceCents` from a JSON object,
  /// from payload format 16
  static const _snackPriceCentsKey = "snackPriceCents";

  /// This is the key used to stringify or parse the `budget_entries` rows from a JSON object, from
  /// payload format 17: the cash journal's own movements.
  static const _budgetEntriesKey = "budgetEntries";

  /// This is the key used to stringify or parse the `budget_commitments` rows from a JSON object,
  /// from payload format 17: money committed against a poste but not yet paid.
  static const _budgetCommitmentsKey = "budgetCommitments";

  /// This is the key used to stringify or parse a `budget_entries.debitCents` column from a JSON
  /// object
  static const _debitCentsKey = "debitCents";

  /// This is the key used to stringify or parse a `budget_entries.creditCents` column from a JSON
  /// object
  static const _creditCentsKey = "creditCents";

  /// This is the key used to stringify or parse a `budget_entries.voucherNumber` column from a JSON
  /// object
  static const _voucherNumberKey = "voucherNumber";

  /// This is the key used to stringify or parse a `budget_commitments.dueDate` column from a JSON
  /// object
  static const _dueDateKey = "dueDate";

  /// This is the key used to stringify or parse a `budget_commitments.amountCents` column, or, from
  /// payload format 18, a `budget_resources.amountCents` column, from a JSON object
  static const _amountCentsKey = "amountCents";

  /// This is the key used to stringify or parse a `budget_commitments.settledEntryId` column from a
  /// JSON object
  static const _settledEntryIdKey = "settledEntryId";

  /// This is the key used to stringify or parse an `assets.budgetEntryId` column from a JSON object,
  /// from payload format 17: the journal entry a receipt asset is the voucher for.
  static const _budgetEntryIdKey = "budgetEntryId";

  /// This is the key used to stringify or parse the `budget_resources` rows from a JSON object,
  /// from payload format 18: the production's financing plan — subsidies, cash and in-kind
  /// contributions.
  static const _budgetResourcesKey = "budgetResources";

  /// This is the key used to stringify or parse the `budget_mileage_rates` rows from a JSON object,
  /// from payload format 18: the per-kilometre rates a production names for itself.
  static const _budgetMileageRatesKey = "budgetMileageRates";

  /// This is the key used to stringify or parse a `budget_resources.groupKind` column from a JSON
  /// object
  static const _groupKindKey = "groupKind";

  /// This is the key used to stringify or parse a `budget_resources.isReimbursable` column from a
  /// JSON object
  static const _isReimbursableKey = "isReimbursable";

  /// This is the key used to stringify or parse a `budget_mileage_rates.ratePerKmMilliCents`
  /// column from a JSON object
  static const _ratePerKmMilliCentsKey = "ratePerKmMilliCents";

  /// This is the key used to stringify or parse a `budget_entries.resourceId` column from a JSON
  /// object, from payload format 18: which financing resource a movement settles.
  static const _resourceIdKey = "resourceId";

  /// This is the key used to stringify or parse a person's `commuteKmMilli` column from a JSON
  /// object, from payload format 18: their own one-way commute to set.
  static const _commuteKmMilliKey = "commuteKmMilli";

  /// This is the key used to stringify or parse a person's `mileageRateId` column from a JSON
  /// object, from payload format 18: which of the project's own rates applies to them.
  static const _mileageRateIdKey = "mileageRateId";

  /// This is the key used to stringify or parse the `budget_revenues` rows from a JSON object,
  /// from payload format 19: the takings the production expects.
  static const _budgetRevenuesKey = "budgetRevenues";

  /// This is the key used to stringify or parse the `budget_shares` rows from a JSON object, from
  /// payload format 19: the participants splitting what the takings bring in.
  static const _budgetSharesKey = "budgetShares";

  /// This is the key used to stringify or parse a `budget_shares.sharePermille` column from a JSON
  /// object
  static const _sharePermilleKey = "sharePermille";

  /// This is the key used to stringify or parse the project's `isBudgetSimplified` from a JSON
  /// object, from payload format 25: the budget mode's simplified/detailed header toggle.
  static const _isBudgetSimplifiedKey = "isBudgetSimplified";

  /// This is the key used to stringify or parse a `budget_shares.reinvestPermille` column from a
  /// JSON object
  static const _reinvestPermilleKey = "reinvestPermille";

  /// This is the key used to stringify or parse a `budget_entries.revenueId` column from a JSON
  /// object, from payload format 19: which taking a credit is the actual cash for.
  static const _revenueIdKey = "revenueId";

  /// This is the key used to stringify or parse a `budget_entries.shareId` column from a JSON
  /// object, from payload format 19: which participant a debit actually pays.
  static const _shareIdKey = "shareId";

  /// This is the key used to stringify or parse the left page margin from a JSON object
  static const _marginLeftKey = "leftInches";

  /// This is the key used to stringify or parse the right page margin from a JSON object
  static const _marginRightKey = "rightInches";

  /// This is the key used to stringify or parse the top page margin from a JSON object
  static const _marginTopKey = "topInches";

  /// This is the key used to stringify or parse the bottom page margin from a JSON object
  static const _marginBottomKey = "bottomInches";

  /// The upgrade steps [decode] replays, keyed by the format each one upgrades **from**: the entry
  /// at `n` turns a format `n` JSON object into a format `n + 1` one.
  ///
  /// The map has to cover every format from the oldest readable one up to
  /// `currentPayloadFormat - 1`, without a hole, or [decode] refuses the payload rather than
  /// guessing.
  static const _payloadUpgrades = <int, Map<String, dynamic> Function(Map<String, dynamic> json)>{
    1: _upgradeFormat1To2,
    2: _upgradeFormat2To3,
    3: _upgradeFormat3To4,
    4: _upgradeFormat4To5,
    5: _upgradeFormat5To6,
    6: _upgradeFormat6To7,
    7: _upgradeFormat7To8,
    8: _upgradeFormat8To9,
    9: _upgradeFormat9To10,
    10: _upgradeFormat10To11,
    11: _upgradeFormat11To12,
    12: _upgradeFormat12To13,
    13: _upgradeFormat13To14,
    14: _upgradeFormat14To15,
    15: _upgradeFormat15To16,
    16: _upgradeFormat16To17,
    17: _upgradeFormat17To18,
    18: _upgradeFormat18To19,
    19: _upgradeFormat19To20,
    20: _upgradeFormat20To21,
    21: _upgradeFormat21To22,
    22: _upgradeFormat22To23,
    23: _upgradeFormat23To24,
    24: _upgradeFormat24To25,
  };

  /// Turns a format-**1** JSON object into a format-**2** one: the resources mode's eleven tables
  /// (`people` down to `assets`) simply didn't exist yet, so this materialises them as **empty
  /// lists** rather than special-casing their absence anywhere else.
  ///
  /// A version written in format 1 predates the resources mode entirely, so a payload with no
  /// resources keys at all is a *truthful* statement about that moment: the project had no people,
  /// no locations, no elements. Once this step has run, [_payloadFromJson] sees the same eleven
  /// empty lists it would see for a project that genuinely never had any resources, and
  /// `OcptProjectVersionsService._restoreTable` already tombstones, on restore, every row the
  /// payload doesn't hold — so a restore of a format-1 version correctly wipes whatever resources
  /// the working copy had accumulated since, with no special case written for it.
  static Map<String, dynamic> _upgradeFormat1To2(Map<String, dynamic> json) => {
    ...json,
    _peopleKey: const <dynamic>[],
    _personPositionsKey: const <dynamic>[],
    _personSkillsKey: const <dynamic>[],
    _personUnavailabilitiesKey: const <dynamic>[],
    _rolesKey: const <dynamic>[],
    _locationsKey: const <dynamic>[],
    _setsKey: const <dynamic>[],
    _sceneSetsKey: const <dynamic>[],
    _elementsKey: const <dynamic>[],
    _sceneElementsKey: const <dynamic>[],
    _assetsKey: const <dynamic>[],
  };

  /// Turns a format-**2** JSON object into a format-**3** one: `location_availabilities` did not
  /// exist yet, so this materialises it as an **empty list**, exactly as [_upgradeFormat1To2] does
  /// for the tables that predate it.
  ///
  /// That empty list is truthful: a version written in format 2 was captured when no location could
  /// carry a window at all. `OcptProjectVersionsService._restoreTable` tombstones, on restore, every
  /// row the payload doesn't hold, so restoring one correctly drops the windows entered since.
  static Map<String, dynamic> _upgradeFormat2To3(Map<String, dynamic> json) => {
    ...json,
    _locationAvailabilitiesKey: const <dynamic>[],
  };

  /// Turns a format-**3** JSON object into a format-**4** one: `project_info.currencyCode` didn't
  /// exist yet, so [_projectSettingsKey] gains a **null** [_currencyCodeKey] rather than a guessed
  /// one.
  ///
  /// Null is the truthful reading here, unlike the empty lists [_upgradeFormat1To2] and
  /// [_upgradeFormat2To3] materialise: those tables genuinely held nothing yet, whereas a project
  /// captured in format 3 or earlier *did* have a currency — the column has never been nullable —
  /// this payload simply never recorded which one. `OcptProjectVersionsService.restoreVersion`
  /// reads that null as "leave the project's currency untouched" rather than as "there was none",
  /// which is the whole reason [OcptProjectVersionPayload.currencyCode] is nullable at all.
  static Map<String, dynamic> _upgradeFormat3To4(Map<String, dynamic> json) {
    final projectSettings = Map<String, dynamic>.from(
      json[_projectSettingsKey] as Map<String, dynamic>? ?? const {},
    );
    projectSettings[_currencyCodeKey] = null;

    return {...json, _projectSettingsKey: projectSettings};
  }

  /// Turns a format-**4** JSON object into a format-**5** one: two things, done together because
  /// the same moment in the schema's history left both undone — the breakdown pass's two tables and
  /// the `elements.status` column it leans on all arrived in schema v9, so a payload written before
  /// that carries none of the three.
  ///
  /// - [_breakdownTagsKey]/[_sceneBreakdownsKey] materialise as **empty lists**, exactly as
  ///   [_upgradeFormat1To2] and [_upgradeFormat2To3] do for the tables that predate them: a payload
  ///   that never reached format 5 predates the breakdown pass entirely, so "no tags, no scene
  ///   statuses" is a truthful statement about that moment, and
  ///   `OcptProjectVersionsService._restoreTable` tombstones, on restore, every row the payload
  ///   doesn't hold — so restoring one correctly drops whatever breakdown work has happened since,
  ///   with no special case written for it;
  /// - every `elements` row gains a [_statusKey] of [OcptElementStatus.toFind] — **unlike**
  ///   [_upgradeFormat3To4]'s currency, which upgrades to *null* and means "leave the project's own
  ///   value alone": a version that never reached format 5 was captured before `elements.status`
  ///   existed at all, so there is no live value anywhere to leave alone — the column's own default
  ///   is the honest reading of "nobody has ever recorded a status for this element", not a guess.
  ///   This is also what lets [_elementFromJson] read [_statusKey] strictly rather than defaulting
  ///   it itself: by the time a JSON object reaches that method it has already been upgraded to
  ///   [currentPayloadFormat], where the column is never absent.
  static Map<String, dynamic> _upgradeFormat4To5(Map<String, dynamic> json) => {
    ...json,
    _elementsKey: [
      for (final element in _rows(json, _elementsKey))
        {...element, _statusKey: OcptElementStatus.toFind.name},
    ],
    _breakdownTagsKey: const <dynamic>[],
    _sceneBreakdownsKey: const <dynamic>[],
  };

  /// Turns a format-**5** JSON object into a format-**6** one: the six tables of the schedule mode
  /// (`shootingDays` down to `shootingPresences`) didn't exist yet, so this materialises all six as
  /// **empty lists**, exactly as [_upgradeFormat1To2] and [_upgradeFormat2To3] do for the tables
  /// that predate them.
  ///
  /// This is the **empty-list** kind of upgrade, not the *null* kind [_upgradeFormat3To4] uses for
  /// the currency — and deliberately so. The currency upgrades to null because a project captured
  /// in format 3 or earlier *did* have one (the column has never been nullable): the payload simply
  /// never recorded which, so overwriting the working copy's own value on restore would be a guess,
  /// and leaving it untouched is the fail-safe reading. A shooting day carries no equivalent
  /// "unknown, but it existed" state to fall back on: `shooting_days.date` is **never null** (§6 of
  /// the plan this ships under is the same reasoning applied to the schema's own migration, which
  /// erases `shots.shootingDay`'s legacy free text rather than guess a date for it), so there is no
  /// value to leave alone — a payload that never reached format 6 is a truthful statement that the
  /// project it was captured from had not been scheduled yet: no days, no slots, no convocations, no
  /// blocks, no presence overrides. `OcptProjectVersionsService._restoreTable` tombstones, on
  /// restore, every row the payload doesn't hold, so restoring a version this old correctly drops
  /// whatever schedule has been planned since, with no special case written for it anywhere.
  static Map<String, dynamic> _upgradeFormat5To6(Map<String, dynamic> json) => {
    ...json,
    _shootingDaysKey: const <dynamic>[],
    _shootingSlotsKey: const <dynamic>[],
    _shootingSlotCrewKey: const <dynamic>[],
    _shootingSlotCastKey: const <dynamic>[],
    _shootingDayBlocksKey: const <dynamic>[],
    _shootingPresencesKey: const <dynamic>[],
  };

  /// Turns a format-**6** JSON object into a format-**7** one: per-slot timetables and computed
  /// convocations reshaped four of the six schedule tables and added a seventh, so this is the
  /// payload's own half of the schema's v11-to-v12 migration, and for the same reasons.
  ///
  /// - [_shootingDayGroupsKey] materialises as an **empty list** — the plain kind of upgrade, like
  ///   [_upgradeFormat5To6], not the *null* kind [_upgradeFormat3To4] uses for the currency: a
  ///   payload that never reached format 7 predates groups entirely, so "no groups" is a truthful
  ///   statement about that moment.
  /// - Each `shootingSlots` row gains [_startMinuteKey] read from its old [_crewCallMinuteKey];
  ///   `crewWrapMinute`/`castCallMinute`/`castWrapMinute` are simply no longer read.
  /// - Each `shootingSlotCrew`/`shootingSlotCast` row gains a **null** [_groupIdKey] and a **null**
  ///   [_leadMinutesKey] — their old minute columns are simply no longer read. Nothing reconstructs
  ///   a lead time out of the dropped clocks, for the same reason the schema migration doesn't: a
  ///   figure guessed from a timetable that has since moved would be worse than the zero every row
  ///   starts at.
  /// - Each `shootingDayBlocks` row gains a **null** [_sceneIdKey]: a `hold` names the sequence it
  ///   holds through that column from here on, and the free-text `label` a format-6 payload carries
  ///   is not a scene id — so nothing is resolved out of it, and such a block names no role until
  ///   somebody says which sequence it is for.
  /// - Each `shootingDayBlocks` row that is an **orphan** — its [_slotIdKey] null, *or* naming a
  ///   slot that isn't live in this same payload — gains the [_slotIdKey] of its day's first live
  ///   slot (lowest `sortKey`, ties broken by `id`), the same reading the schema's own
  ///   `_assignOrphanBlocksToFirstSlot` takes; a block whose day carries no live slot at all is
  ///   **dropped from the list**, the payload's own half of the migration's rule, and for the same
  ///   reason: the column is non-null from here on.
  static Map<String, dynamic> _upgradeFormat6To7(Map<String, dynamic> json) {
    final slots = [
      for (final slot in _rows(json, _shootingSlotsKey))
        {...slot, _startMinuteKey: slot[_crewCallMinuteKey]},
    ];

    final crew = [
      for (final row in _rows(json, _shootingSlotCrewKey))
        {...row, _groupIdKey: null, _leadMinutesKey: null},
    ];

    final cast = [
      for (final row in _rows(json, _shootingSlotCastKey))
        {...row, _groupIdKey: null, _leadMinutesKey: null},
    ];

    final liveSlotIds = <String>{};
    final firstSlotIdByDay = <String, String>{};
    final liveSlotsByDay = <String, List<Map<String, dynamic>>>{};
    for (final slot in slots) {
      if (slot[_isDeletedKey] == true) {
        continue;
      }
      liveSlotIds.add(slot[_idKey] as String);
      liveSlotsByDay.putIfAbsent(slot[_shootingDayIdKey] as String, () => []).add(slot);
    }
    for (final entry in liveSlotsByDay.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) {
          final sortKeyComparison = (a[_sortKeyKey] as String).compareTo(b[_sortKeyKey] as String);
          return sortKeyComparison != 0
              ? sortKeyComparison
              : (a[_idKey] as String).compareTo(b[_idKey] as String);
        });
      firstSlotIdByDay[entry.key] = ordered.first[_idKey] as String;
    }

    final blocks = <Map<String, dynamic>>[];
    for (final block in _rows(json, _shootingDayBlocksKey)) {
      final withScene = {...block, _sceneIdKey: null};
      final slotId = block[_slotIdKey] as String?;
      if (slotId != null && liveSlotIds.contains(slotId)) {
        blocks.add(withScene);
        continue;
      }

      final firstSlotId = firstSlotIdByDay[block[_shootingDayIdKey]];
      if (firstSlotId == null) {
        continue;
      }

      blocks.add({...withScene, _slotIdKey: firstSlotId});
    }

    return {
      ...json,
      _shootingDayGroupsKey: const <dynamic>[],
      _shootingSlotsKey: slots,
      _shootingSlotCrewKey: crew,
      _shootingSlotCastKey: cast,
      _shootingDayBlocksKey: blocks,
    };
  }

  /// Turns a format-**8** JSON object into a format-**9** one: `shooting_slots.startMinute` becomes
  /// the anchored-edge trio, the payload's own half of the schema's v13-to-v14 migration.
  ///
  /// This is a **rename**, the kind [_upgradeFormat6To7] already shows for `crewCallMinute`, and
  /// neither of the other two kinds: nothing materialises (the column existed and held a real
  /// value), and nothing is removed (that value is exactly what the new columns say). Every slot
  /// comes back anchored **by its start, at the hour it already had** — [_anchorEdgeKey] the
  /// literal `start`, [_anchorMinuteKey] the old [_startMinuteKey], [_anchorSlotIdKey] null —
  /// which is what every slot of a format-8 payload meant, so restoring one draws the day it drew
  /// when it was captured. Nothing is guessed the other way round: no slot becomes end-anchored
  /// because its last block happened to land on a round hour, and no link is invented between two
  /// slots that merely met.
  ///
  /// The retired [_startMinuteKey] is left on the row rather than removed, exactly as
  /// [_upgradeFormat6To7] leaves `crewCallMinute` on one: [_shootingSlotFromJson] reads the keys it
  /// knows and ignores the rest, and an upgrade step that also tidied would be doing two things.
  static Map<String, dynamic> _upgradeFormat8To9(Map<String, dynamic> json) => {
    ...json,
    _shootingSlotsKey: [
      for (final slot in _rows(json, _shootingSlotsKey))
        {
          ...slot,
          _anchorEdgeKey: OcptShootingSlotAnchorEdge.start.name,
          _anchorMinuteKey: slot[_startMinuteKey],
          _anchorSlotIdKey: null,
        },
    ],
  };

  /// Turns a format-**9** JSON object into a format-**10** one: `role_elements` — what a role
  /// wears, carries and is made up with — did not exist yet, so this materialises it as an **empty
  /// list**.
  ///
  /// Back to the plainest of the three kinds, [_upgradeFormat5To6]'s: a version written in format 9
  /// was captured when nothing in the app could say a role wore a coat, so "this role had no
  /// things" is a truthful statement about that moment — unlike [_upgradeFormat3To4]'s null, which
  /// means "leave the live value alone", and unlike [_upgradeFormat7To8]'s removal, which makes no
  /// claim about the capture at all. `OcptProjectVersionsService._restoreTable` tombstones, on
  /// restore, every row the payload doesn't hold, so restoring one correctly drops every link made
  /// since, exactly as restoring a pre-schedule version drops the days planned since.
  static Map<String, dynamic> _upgradeFormat9To10(Map<String, dynamic> json) => {
    ...json,
    _roleElementsKey: const <dynamic>[],
  };

  /// Turns a format-**10** JSON object into a format-**11** one: `people.maxDailyPresenceMinutes`
  /// didn't exist yet, so every `people` row gains a **null** value for it.
  ///
  /// This null is the same kind [_upgradeFormat6To7] writes for a crew or cast row's `groupId`/
  /// `leadMinutes`, not [_upgradeFormat3To4]'s currency: the currency's null means "leave the
  /// working copy's own value alone" because the column has never itself been nullable — a project
  /// captured before format 4 *did* have a currency, the payload simply never recorded which. Here
  /// the column is nullable by design (see `OcptPeopleTable.maxDailyPresenceMinutes`'s own doc
  /// comment) and null is its own truthful state: a payload that never reached format 11 was
  /// captured when nobody could record a maximum for anybody, so "nobody has said" is exactly what
  /// every row of it means, restored or not. `OcptProjectVersionsService.restoreVersion` therefore
  /// writes this null onto the working copy like any other changed column, rather than skipping it
  /// the way it skips the currency's — and, as with every materialised value this codec writes,
  /// **nothing is guessed**: no figure is invented from a legal maximum this build happens to know
  /// about, which is the whole reason the column exists rather than a hard-coded one.
  static Map<String, dynamic> _upgradeFormat10To11(Map<String, dynamic> json) => {
    ...json,
    _peopleKey: [
      for (final person in _rows(json, _peopleKey))
        {...person, _maxDailyPresenceMinutesKey: null},
    ],
  };

  /// Turns a format-**11** JSON object into a format-**12** one, doing all three kinds of change at
  /// once:
  ///
  /// - `shooting_slot_guests` and `shooting_day_events` didn't exist yet, so this materialises both
  ///   as **empty lists** — the plainest of the three kinds, [_upgradeFormat5To6]'s and
  ///   [_upgradeFormat9To10]'s: a version written in format 11 was captured when nothing in the app
  ///   could say a day had a guest or an event of its own — a slot convoked crew and cast alone, and
  ///   a day's timetable was the only thing it could say happened on it — so "this day had neither"
  ///   is a truthful statement about that moment. `OcptProjectVersionsService._restoreTable`
  ///   tombstones, on restore, every row the payload doesn't hold, so restoring a format-11 version
  ///   correctly drops every guest and every event recorded since — the reading, not a bug, exactly
  ///   as restoring a pre-schedule version drops the days planned since.
  /// - Each `shootingDayBlocks` row gains an **empty string** [_crewNoteKey], and each `assets` row
  ///   a **null** [_validFromKey]/[_validUntilKey], and [_projectSettingsKey] a **null**
  ///   [_minimumRestMinutesKey] — [_upgradeFormat10To11]'s kind, not [_upgradeFormat3To4]'s: every
  ///   one of the three columns is nullable or defaulted by design, so a version captured in format
  ///   11 truthfully recorded nothing for any of them, and that nothing is written back onto the
  ///   working copy on restore like any other changed column, rather than being skipped the way the
  ///   currency's null is.
  /// - [_shootingPresencesKey] is **dropped**, [_upgradeFormat7To8]'s kind — the second entry in
  ///   this codec that removes rather than materialises. Read that step's own doc comment first: a
  ///   format-11 version genuinely *did* carry presence overrides, typed by a user who is owed an
  ///   honest account of what became of them, so this is not the empty-list bullet above wearing a
  ///   different name. The project being restored into has no concept for them any more — schema
  ///   version 17 drops `shooting_presences` outright — so they come back as nothing at all, and, as
  ///   everywhere else, **nothing is reconstructed**: an override that said `travelling` does not
  ///   become a slot nobody asked for, exactly as a format-7 payload's dropped lead times do not
  ///   become one either.
  static Map<String, dynamic> _upgradeFormat11To12(Map<String, dynamic> json) {
    final blocks = [
      for (final row in _rows(json, _shootingDayBlocksKey)) {...row, _crewNoteKey: ""},
    ];

    final assets = [
      for (final row in _rows(json, _assetsKey))
        {...row, _validFromKey: null, _validUntilKey: null},
    ];

    final projectSettings = {
      ..._object(json, _projectSettingsKey),
      _minimumRestMinutesKey: null,
    };

    final upgraded = {...json}..remove(_shootingPresencesKey);

    return {
      ...upgraded,
      _shootingDayBlocksKey: blocks,
      _assetsKey: assets,
      _projectSettingsKey: projectSettings,
      _shootingSlotGuestsKey: const <dynamic>[],
      _shootingDayEventsKey: const <dynamic>[],
    };
  }

  /// Turns a format-**12** JSON object into a format-**13** one: the payload's own half of schema
  /// version 18, which makes a `screenplays` row an episode
  /// (`docs/adr/0019-one-project-several-episodes.md`, §3.2 of the plan this ships under). It does
  /// **four** kinds of thing, one of which is new to this codec — read the third bullet below in
  /// full before ever adding a fifth.
  ///
  /// - Every `screenplays` row gains [_numberKey] and [_sortKeyKey]. This is [_upgradeFormat4To5]'s
  ///   kind (`elements.status` filled with [OcptElementStatus.toFind]), **not**
  ///   [_upgradeFormat3To4]'s currency null: a payload captured in format 12 held exactly one
  ///   screenplay, so "this project had one episode, and it was the first" is the truthful reading
  ///   of that moment — there is no live value anywhere to leave alone, unlike the currency, which
  ///   the column has never itself been nullable for. Every **live** row is numbered `1..n` in
  ///   `id` order and keyed with [ocptFractionalKeySequence] — the same rule, for the same
  ///   determinism reason (two replicas restoring the same version must land on the same
  ///   numbering), that `OcptProjectDatabase._numberExistingScreenplays` follows for the schema's
  ///   own migration; the two **must** agree, since a payload restored into a freshly migrated file
  ///   has to describe the same episode the file itself already settled on. A tombstoned row is left
  ///   at the columns' own defaults (`1` and `""`), mirroring that same method: a deleted screenplay
  ///   was never going to be episode anything.
  /// - [_roleEpisodesKey] is derived from the very `roles.screenplayId` the next bullet drops. This
  ///   is a **fourth kind of change, and the only lossless one in the whole codec**: every other
  ///   upgrade step in this file either materialises a value that was never recorded (the bullet
  ///   above) or discards one the app has no concept for any more (the bullet below) — this one
  ///   instead rewrites a fact the payload already carries in full, into the shape the new table
  ///   holds it in from here on, exactly as `OcptProjectDatabase._deriveRoleEpisodes` does for the
  ///   schema's own migration and for the same reason. **This is the only entry that may do this —
  ///   read it again before adding a fifth kind of upgrade step to this codec.** The link's `id` is
  ///   **the role's own id**: a role has exactly one episode at format 12, which is what makes reuse
  ///   safe (the id is unique here) and useful (it is deterministic, so two replicas restoring the
  ///   same version produce the same `role_episodes` row rather than two a later merge would have
  ///   to reconcile) — `_deriveRoleEpisodes`'s own doc comment, and
  ///   `docs/adr/0019-one-project-several-episodes.md`, give the same reasoning for the same choice.
  ///   Derived from **live** `roles` rows only, matching that same migration: a tombstoned role
  ///   named no episode worth carrying forward, tombstoned or not.
  /// - `roles.screenplayId` and `shooting_days.screenplayId` are **dropped** from every row, whether
  ///   or not it is a tombstone. This is [_upgradeFormat7To8]'s and [_upgradeFormat11To12]'s kind:
  ///   unlike the first bullet's empty-then-filled column it makes no claim about the moment of
  ///   capture, and unlike the currency's null it leaves no live value alone — there is nothing
  ///   truthful left to say through either column once the project being restored into has dropped
  ///   the very idea each one named. A shooting day comes back with everything else it held, simply
  ///   belonging to no episode any more: nothing here is reconstructed, exactly as a format-7
  ///   payload's dropped lead times are not turned into a slot nobody asked for.
  ///
  /// The consequence, stated in the plan and in the ADR and worth restating here where a future
  /// reader of this step will actually be looking: restoring a format-12 version into a
  /// multi-episode project **tombstones every episode but the first**, along with its scenes, its
  /// shots and its breakdown — the truthful reading of "this project had one episode when this
  /// version was sealed", an edit like any other restore, undoable through the restore's own safety
  /// version. **No role loses its casting** on the way through, since a role is no longer a
  /// script's: only the link the second bullet derives says where it used to speak.
  static Map<String, dynamic> _upgradeFormat12To13(Map<String, dynamic> json) {
    final liveScreenplayIds = [
      for (final screenplay in _rows(json, _screenplaysKey))
        if (screenplay[_isDeletedKey] != true) screenplay[_idKey] as String,
    ]..sort();
    final freshKeys = ocptFractionalKeySequence(liveScreenplayIds.length);
    final numberById = <String, int>{
      for (var i = 0; i < liveScreenplayIds.length; i++) liveScreenplayIds[i]: i + 1,
    };
    final sortKeyById = <String, String>{
      for (var i = 0; i < liveScreenplayIds.length; i++) liveScreenplayIds[i]: freshKeys[i],
    };

    final screenplays = [
      for (final screenplay in _rows(json, _screenplaysKey))
        {
          ...screenplay,
          _numberKey: numberById[screenplay[_idKey]] ?? 1,
          _sortKeyKey: sortKeyById[screenplay[_idKey]] ?? "",
        },
    ];

    final roleEpisodes = [
      for (final role in _rows(json, _rolesKey))
        if (role[_isDeletedKey] != true)
          {
            _idKey: role[_idKey],
            _roleIdKey: role[_idKey],
            _screenplayIdKey: role[_screenplayIdKey],
            _isDeletedKey: false,
          },
    ];

    final roles = [
      for (final role in _rows(json, _rolesKey)) ({...role}..remove(_screenplayIdKey)),
    ];

    final shootingDays = [
      for (final day in _rows(json, _shootingDaysKey)) ({...day}..remove(_screenplayIdKey)),
    ];

    return {
      ...json,
      _screenplaysKey: screenplays,
      _rolesKey: roles,
      _roleEpisodesKey: roleEpisodes,
      _shootingDaysKey: shootingDays,
    };
  }

  /// Turns a format-**13** JSON object into a format-**14** one: `project_info.screenplayLanguage`
  /// didn't exist yet, so [_projectSettingsKey] gains a **null** [_screenplayLanguageKey].
  ///
  /// [_upgradeFormat11To12]'s kind, not [_upgradeFormat3To4]'s currency: the column is nullable by
  /// design, so a version captured in format 13 or earlier truthfully recorded nothing for it, and
  /// that nothing is written back onto the working copy on restore like any other changed column —
  /// see [OcptProjectVersionPayload.screenplayLanguage].
  static Map<String, dynamic> _upgradeFormat13To14(Map<String, dynamic> json) {
    final projectSettings = {
      ..._object(json, _projectSettingsKey),
      _screenplayLanguageKey: null,
    };

    return {...json, _projectSettingsKey: projectSettings};
  }

  /// Turns a format-**14** JSON object into a format-**15** one: `project_dictionary_words` didn't
  /// exist yet, so this materialises it as an **empty list** — [_upgradeFormat1To2]'s kind, not
  /// [_upgradeFormat13To14]'s null: a version captured this early truthfully taught the spell
  /// checker nothing at all, which is exactly what an empty list says, and
  /// `OcptProjectVersionsService._restoreTable` already tombstones, on restore, every row the
  /// payload doesn't hold — so a restore of a format-14 version correctly un-learns whatever the
  /// working copy had been taught since, with no special case written for it.
  static Map<String, dynamic> _upgradeFormat14To15(Map<String, dynamic> json) => {
    ...json,
    _projectDictionaryWordsKey: const <dynamic>[],
  };

  /// Turns a format-**15** JSON object into a format-**16** one: `role_candidates` — who was seen
  /// for a part — didn't exist yet, so this materialises it as an **empty list**.
  ///
  /// [_upgradeFormat14To15]'s kind, and [_upgradeFormat9To10]'s before it: a version captured this
  /// early genuinely held nobody seen for any part, which is exactly what an empty list says, and
  /// `OcptProjectVersionsService._restoreTable` already tombstones, on restore, every row the
  /// payload doesn't hold — so restoring a format-15 version correctly takes back the candidates
  /// entered since, with no special case written for it. The `roles.personId` such a restore writes
  /// back is the payload's own, which is the honest answer: it is the cast the project actually had
  /// at the moment the version was captured.
  static Map<String, dynamic> _upgradeFormat15To16(Map<String, dynamic> json) => {
    ...json,
    _roleCandidatesKey: const <dynamic>[],
  };

  /// Turns a format-**16** JSON object into a format-**17** one: each `shootingDays` row gains a
  /// [_kindKey] of `"shoot"`.
  ///
  /// [_upgradeFormat11To12]'s kind, not [_upgradeFormat1To2]'s empty lists nor
  /// [_upgradeFormat3To4]'s null: the column is defaulted by design, and a version captured before
  /// this app could say a day did anything but shoot recorded a schedule every day of which shot —
  /// so `"shoot"` is not a stand-in for a missing value, it is the value. It is written back onto
  /// the working copy on restore like any other column, and, as everywhere else in this codec,
  /// **nothing is reconstructed**: a day whose timetable happens to hold nothing but a `hold` block
  /// does not become a rehearsal nobody declared.
  static Map<String, dynamic> _upgradeFormat16To17(Map<String, dynamic> json) => {
    ...json,
    _shootingDaysKey: [
      // The literal must match `OcptShootingDayKind.shoot.name`, for the same reason the column's
      // own default has to.
      for (final row in _rows(json, _shootingDaysKey)) {...row, _kindKey: "shoot"},
    ],
  };

  /// Turns a format-**17** JSON object into a format-**18** one: `shooting_slot_candidates` — which
  /// candidate each slot convokes — didn't exist yet, so this materialises it as an **empty list**,
  /// and each `shootingDayBlocks` row gains a **null** [_roleIdKey] and a **null**
  /// [_roleCandidateIdKey].
  ///
  /// Both halves of [_upgradeFormat15To16]'s and [_upgradeFormat3To4]'s kinds at once, and neither
  /// is a stand-in: a version captured before this app could plan an audition genuinely convoked no
  /// candidate anywhere and held no block naming one, which is exactly what an empty list and two
  /// nulls say. Nothing is reconstructed either, as everywhere else in this codec — a block whose
  /// label happens to read *"Camille, 14h"* does not become an audition nobody declared.
  static Map<String, dynamic> _upgradeFormat17To18(Map<String, dynamic> json) => {
    ...json,
    _shootingSlotCandidatesKey: const <dynamic>[],
    _shootingDayBlocksKey: [
      for (final row in _rows(json, _shootingDayBlocksKey))
        {...row, _roleIdKey: null, _roleCandidateIdKey: null},
    ],
  };

  /// Turns a format-**18** JSON object into a format-**19** one: `shootingDays` rows lose their
  /// [_kindKey] and `shootingDayBlocks` rows their [_roleCandidateIdKey].
  ///
  /// [_upgradeFormat7To8]'s kind — a step that **removes** — and for a close cousin of its reason. A
  /// day was briefly given a kind (shoot, casting, rehearsal) and an audition block was briefly
  /// given the candidacy it saw; both were dropped, because a real day mixes those activities and
  /// says so through its **blocks**: a production auditions in the morning and rehearses in the
  /// afternoon, and rehearses on the morning of a day it shoots. What a day is for is read off what
  /// it holds, so neither column has anything left to say.
  ///
  /// Both keys are stripped rather than left to be ignored: [contentDigest] hashes what this codec
  /// writes, and a key nothing writes any more must not linger in one payload and not the next.
  static Map<String, dynamic> _upgradeFormat18To19(Map<String, dynamic> json) => {
    ...json,
    _shootingDaysKey: [
      for (final row in _rows(json, _shootingDaysKey)) {...row}..remove(_kindKey),
    ],
    _shootingDayBlocksKey: [
      for (final row in _rows(json, _shootingDayBlocksKey)) {...row}..remove(_roleCandidateIdKey),
    ],
  };

  /// Turns a format-**19** JSON object into a format-**20** one: `shootingSlotCandidates` and every
  /// `shootingDayBlocks` row's [_roleIdKey] are dropped, and `shootingBlockCandidates` — which
  /// candidacies each audition block sees — is materialised as an **empty list**.
  ///
  /// [_upgradeFormat7To8]'s kind and [_upgradeFormat5To6]'s at once, and neither is a stand-in. What
  /// goes was written only by intermediate builds of one unmerged branch: a candidate convoked on
  /// the whole slot, and an audition block naming the single part it saw. Both were taken back out
  /// because a candidate is expected at twenty past ten rather than "on the unit today", and a block
  /// reading two actors of two different parts could never have named one part (ADR 0024). What
  /// arrives is genuinely empty: a version captured before this app could name a candidacy on a
  /// block named none anywhere. **Nothing is carried over** — a slot-wide convocation names no hour,
  /// so there is no block for this step to attach it to, and inventing one would put somebody in a
  /// running order nobody planned.
  ///
  /// Both retired keys are stripped rather than left to be ignored: [contentDigest] hashes what this
  /// codec writes, and a key nothing writes any more must not linger in one payload and not the
  /// next.
  static Map<String, dynamic> _upgradeFormat19To20(Map<String, dynamic> json) =>
      {
        ...json,
        _shootingBlockCandidatesKey: const <dynamic>[],
        _shootingDayBlocksKey: [
          for (final row in _rows(json, _shootingDayBlocksKey)) {...row}..remove(_roleIdKey),
        ],
      }..remove(_shootingSlotCandidatesKey);
  /// Turns a format-**20** JSON object into a format-**21** one: the budget mode's foundations,
  /// doing both of the two kinds `docs/architecture/foundations.md` documents at once.
  ///
  /// - [_budgetPostesKey] and [_budgetLinesKey] materialise as **empty lists**
  ///   ([_upgradeFormat1To2]'s kind, the first of the codec's two kinds a table can arrive by): a
  ///   version written in format 20 predates the budget mode entirely, so "this project had no
  ///   postes, no lines" is a truthful statement about that moment, and
  ///   `OcptProjectVersionsService._restoreTable` tombstones, on restore, every row the payload
  ///   doesn't hold — so restoring a format-20 version correctly drops whatever budget has been
  ///   typed since, with no special case written for it;
  /// - [_projectSettingsKey] gains a **null** [_defaultVatRateBasisPointsKey],
  ///   [_mealPriceCentsKey] and [_snackPriceCentsKey] — [_upgradeFormat13To14]'s kind (the second of
  ///   the two, not the currency's "leave the live value alone" one): all three columns are
  ///   nullable by design, so a version captured in format 20 or earlier truthfully recorded
  ///   nothing for any of them, and that nothing is written back onto the working copy on restore
  ///   like any other changed column.
  static Map<String, dynamic> _upgradeFormat20To21(Map<String, dynamic> json) {
    final projectSettings = {
      ..._object(json, _projectSettingsKey),
      _defaultVatRateBasisPointsKey: null,
      _mealPriceCentsKey: null,
      _snackPriceCentsKey: null,
    };

    return {
      ...json,
      _budgetPostesKey: const <dynamic>[],
      _budgetLinesKey: const <dynamic>[],
      _projectSettingsKey: projectSettings,
    };
  }

  /// Turns a format-**21** JSON object into a format-**22** one: the cash journal didn't exist yet,
  /// so [_budgetEntriesKey] and [_budgetCommitmentsKey] materialise as **empty lists**
  /// ([_upgradeFormat1To2]'s kind): a version written in format 21 predates the journal entirely, so
  /// "this project had no entries, no commitments" is a truthful statement about that moment, and
  /// `OcptProjectVersionsService._restoreTable` tombstones, on restore, every row the payload
  /// doesn't hold — so restoring a format-21 version correctly drops whatever cash movement has been
  /// typed since, with no special case written for it.
  ///
  /// Every `assets` row also gains a **null** [_budgetEntryIdKey]: no asset could name a journal
  /// entry that didn't exist yet, so null is the only truthful reading — [_upgradeFormat3To4]'s
  /// kind, not the empty-list one, since `assets` rows themselves are not new here.
  static Map<String, dynamic> _upgradeFormat21To22(Map<String, dynamic> json) {
    final assets = [
      for (final row in _rows(json, _assetsKey)) {...row, _budgetEntryIdKey: null},
    ];

    return {
      ...json,
      _budgetEntriesKey: const <dynamic>[],
      _budgetCommitmentsKey: const <dynamic>[],
      _assetsKey: assets,
    };
  }

  /// Turns a format-**22** JSON object into a format-**23** one: the financing plan didn't exist
  /// yet, so [_budgetResourcesKey] and [_budgetMileageRatesKey] materialise as **empty lists**
  /// ([_upgradeFormat1To2]'s kind): a version written in format 22 predates the financing plan
  /// entirely, so "this project named no resource, no rate" is a truthful statement about that
  /// moment, and `OcptProjectVersionsService._restoreTable` tombstones, on restore, every row the
  /// payload doesn't hold — so restoring a format-22 version correctly drops whatever financing has
  /// been typed since, with no special case written for it.
  ///
  /// Every `budget_entries` row also gains a **null** [_resourceIdKey], and every `people` row a
  /// **null** [_commuteKmMilliKey]/[_mileageRateIdKey] — [_upgradeFormat3To4]'s kind, not the
  /// empty-list one, since neither table is new here: no entry could yet name a resource that
  /// didn't exist, and no person could yet claim a distance or a rate this project had nowhere to
  /// record.
  static Map<String, dynamic> _upgradeFormat22To23(Map<String, dynamic> json) {
    final entries = [
      for (final row in _rows(json, _budgetEntriesKey)) {...row, _resourceIdKey: null},
    ];

    final people = [
      for (final row in _rows(json, _peopleKey))
        {...row, _commuteKmMilliKey: null, _mileageRateIdKey: null},
    ];

    return {
      ...json,
      _budgetResourcesKey: const <dynamic>[],
      _budgetMileageRatesKey: const <dynamic>[],
      _budgetEntriesKey: entries,
      _peopleKey: people,
    };
  }

  /// Turns a format-**23** JSON object into a format-**24** one: the revenue sharing didn't exist
  /// yet, so [_budgetRevenuesKey] and [_budgetSharesKey] materialise as **empty lists**
  /// ([_upgradeFormat1To2]'s kind): a version written in format 23 predates the sharing view
  /// entirely, so "this project named no taking, no participant" is a truthful statement about that
  /// moment, and `OcptProjectVersionsService._restoreTable` tombstones, on restore, every row the
  /// payload doesn't hold — so restoring a format-23 version correctly drops whatever sharing has
  /// been typed since, with no special case written for it.
  ///
  /// Every `budget_entries` row also gains a **null** [_revenueIdKey]/[_shareIdKey] —
  /// [_upgradeFormat3To4]'s kind, not the empty-list one, since the table itself is not new here: no
  /// entry could yet name a taking or a participant this project had nowhere to record.
  static Map<String, dynamic> _upgradeFormat23To24(Map<String, dynamic> json) {
    final entries = [
      for (final row in _rows(json, _budgetEntriesKey))
        {...row, _revenueIdKey: null, _shareIdKey: null},
    ];

    return {
      ...json,
      _budgetRevenuesKey: const <dynamic>[],
      _budgetSharesKey: const <dynamic>[],
      _budgetEntriesKey: entries,
    };
  }

  /// Turns a format-**24** JSON object into a format-**25** one: `budget_resources.personId` and
  /// `project_info.isBudgetSimplified` didn't exist yet, so every `budgetResources` row gains a
  /// **null** [_personIdKey] and [_projectSettingsKey] gains a **null** [_isBudgetSimplifiedKey] —
  /// [_upgradeFormat3To4]'s kind twice over, not the empty-list one: neither `budget_resources` nor
  /// `project_info` is new here, so no resource could yet name the person it comes from, and
  /// nobody has ever chosen between the simplified and the detailed header on a project captured
  /// this early — the mode opens detailed for it today for exactly that reason.
  static Map<String, dynamic> _upgradeFormat24To25(Map<String, dynamic> json) {
    final resources = [
      for (final row in _rows(json, _budgetResourcesKey)) {...row, _personIdKey: null},
    ];

    final projectSettings = {
      ..._object(json, _projectSettingsKey),
      _isBudgetSimplifiedKey: null,
    };

    return {
      ...json,
      _budgetResourcesKey: resources,
      _projectSettingsKey: projectSettings,
    };
  }

  /// Turns a format-**7** JSON object into a format-**8** one: `shooting_day_groups` and the
  /// `groupId`/`leadMinutes` pair `shooting_slot_crew`/`shooting_slot_cast` briefly carried are
  /// dropped, the payload's own half of ADR 0018 — a convocation is read off the slots a person or
  /// a role is linked to from here on, never offset by a typed lead time.
  ///
  /// This is the first upgrade step that **removes rather than materialises**, and it is a third
  /// kind of change alongside the two the earlier steps already show: [_upgradeFormat5To6]
  /// materialises an **empty list** for a table that genuinely held nothing at the moment it was
  /// captured, and [_upgradeFormat3To4] writes a **null** for a value that did exist but was never
  /// recorded, to be left untouched on restore. Here there is no working-copy value to leave
  /// untouched and no truthful "there were none" to state about the moment of capture — a version
  /// captured in format 7 genuinely *did* carry groups and lead times, typed by a user who is owed
  /// an honest account of what became of them. **Nothing is reconstructed**: a lead time is not
  /// turned into a slot nobody asked for, exactly as the v11-to-v12 schema migration reconstructed
  /// nothing out of the typed clocks it dropped. A version restored from a format-7 payload
  /// therefore comes back with every crew and cast row it held, simply carrying no lead time and no
  /// group any more, because the project being restored into no longer has a concept for either to
  /// mean anything.
  static Map<String, dynamic> _upgradeFormat7To8(Map<String, dynamic> json) {
    final crew = [
      for (final row in _rows(json, _shootingSlotCrewKey))
        ({...row}..remove(_groupIdKey)..remove(_leadMinutesKey)),
    ];

    final cast = [
      for (final row in _rows(json, _shootingSlotCastKey))
        ({...row}..remove(_groupIdKey)..remove(_leadMinutesKey)),
    ];

    final upgraded = {...json}..remove(_shootingDayGroupsKey);

    return {...upgraded, _shootingSlotCrewKey: crew, _shootingSlotCastKey: cast};
  }

  /// Class constructor
  const OcptProjectVersionCodec();

  /// Serializes [payload] into the JSON text stored in `project_versions.payload`, stamped with
  /// [currentPayloadFormat].
  String encode(OcptProjectVersionPayload payload) => jsonEncode({
    _payloadFormatKey: currentPayloadFormat,
    _screenplaysKey: [for (final row in payload.screenplays) _screenplayToJson(row)],
    _scenesKey: [for (final row in payload.scenes) _sceneToJson(row)],
    _shotsKey: [for (final row in payload.shots) _shotToJson(row)],
    _shotCharactersKey: [for (final row in payload.shotCharacters) _shotCharacterToJson(row)],
    _shotCoveragesKey: [for (final row in payload.shotCoverages) _shotCoverageToJson(row)],
    _peopleKey: [for (final row in payload.people) _personToJson(row)],
    _personPositionsKey: [for (final row in payload.personPositions) _personPositionToJson(row)],
    _personSkillsKey: [for (final row in payload.personSkills) _personSkillToJson(row)],
    _personUnavailabilitiesKey: [
      for (final row in payload.personUnavailabilities) _personUnavailabilityToJson(row),
    ],
    _rolesKey: [for (final row in payload.roles) _roleToJson(row)],
    _roleEpisodesKey: [for (final row in payload.roleEpisodes) _roleEpisodeToJson(row)],
    _locationsKey: [for (final row in payload.locations) _locationToJson(row)],
    _locationAvailabilitiesKey: [
      for (final row in payload.locationAvailabilities) _locationAvailabilityToJson(row),
    ],
    _setsKey: [for (final row in payload.sets) _setToJson(row)],
    _sceneSetsKey: [for (final row in payload.sceneSets) _sceneSetToJson(row)],
    _elementsKey: [for (final row in payload.elements) _elementToJson(row)],
    _sceneElementsKey: [for (final row in payload.sceneElements) _sceneElementToJson(row)],
    _roleElementsKey: [for (final row in payload.roleElements) _roleElementToJson(row)],
    _roleCandidatesKey: [for (final row in payload.roleCandidates) _roleCandidateToJson(row)],
    _assetsKey: [for (final row in payload.assets) _assetToJson(row)],
    _breakdownTagsKey: [for (final row in payload.breakdownTags) _breakdownTagToJson(row)],
    _sceneBreakdownsKey: [for (final row in payload.sceneBreakdowns) _sceneBreakdownToJson(row)],
    _shootingDaysKey: [for (final row in payload.shootingDays) _shootingDayToJson(row)],
    _shootingSlotsKey: [for (final row in payload.shootingSlots) _shootingSlotToJson(row)],
    _shootingSlotCrewKey: [
      for (final row in payload.shootingSlotCrew) _shootingSlotCrewToJson(row),
    ],
    _shootingSlotCastKey: [
      for (final row in payload.shootingSlotCast) _shootingSlotCastToJson(row),
    ],
    _shootingDayBlocksKey: [
      for (final row in payload.shootingDayBlocks) _shootingDayBlockToJson(row),
    ],
    _shootingSlotGuestsKey: [
      for (final row in payload.shootingSlotGuests) _shootingSlotGuestToJson(row),
    ],
    _shootingBlockCandidatesKey: [
      for (final row in payload.shootingBlockCandidates) _shootingBlockCandidateToJson(row),
    ],
    _shootingDayEventsKey: [
      for (final row in payload.shootingDayEvents) _shootingDayEventToJson(row),
    ],
    _budgetPostesKey: [for (final row in payload.budgetPostes) _budgetPosteToJson(row)],
    _budgetLinesKey: [for (final row in payload.budgetLines) _budgetLineToJson(row)],
    _budgetEntriesKey: [for (final row in payload.budgetEntries) _budgetEntryToJson(row)],
    _budgetCommitmentsKey: [
      for (final row in payload.budgetCommitments) _budgetCommitmentToJson(row),
    ],
    _budgetResourcesKey: [for (final row in payload.budgetResources) _budgetResourceToJson(row)],
    _budgetMileageRatesKey: [
      for (final row in payload.budgetMileageRates) _budgetMileageRateToJson(row),
    ],
    _budgetRevenuesKey: [for (final row in payload.budgetRevenues) _budgetRevenueToJson(row)],
    _budgetSharesKey: [for (final row in payload.budgetShares) _budgetShareToJson(row)],
    _projectDictionaryWordsKey: [
      for (final row in payload.projectDictionaryWords) _projectDictionaryWordToJson(row),
    ],
    _rowFieldVersionsKey: [for (final row in payload.rowFieldVersions) _rowFieldVersionToJson(row)],
    _projectSettingsKey: {
      _pageFormatKey: payload.pageSetup.format.name,
      _settingsJsonKey: payload.settingsJson,
      _currencyCodeKey: payload.currencyCode,
      _minimumRestMinutesKey: payload.minimumRestMinutes,
      _screenplayLanguageKey: payload.screenplayLanguage?.name,
      _defaultVatRateBasisPointsKey: payload.defaultVatRateBasisPoints,
      _mealPriceCentsKey: payload.mealPriceCents,
      _snackPriceCentsKey: payload.snackPriceCents,
      _isBudgetSimplifiedKey: payload.isBudgetSimplified,
    },
    _pageMarginsKey: {
      _marginLeftKey: payload.pageSetup.margins.leftInches,
      _marginRightKey: payload.pageSetup.margins.rightInches,
      _marginTopKey: payload.pageSetup.margins.topInches,
      _marginBottomKey: payload.pageSetup.margins.bottomInches,
    },
  });

  /// Parses [payloadJson], the text stored in `project_versions.payload`, upgrading it from an
  /// older format when needed.
  ///
  /// Never throws: every failure comes back as an [OcptProjectVersionPayloadStatus], because the
  /// caller of a decode is always about to tell the user why a version can't be opened.
  ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload> decode(
    String payloadJson,
  ) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, dynamic>) {
        throw const _OcptPayloadFormatError("the payload isn't a JSON object");
      }

      final payloadFormat = _int(decoded, _payloadFormatKey);
      if (payloadFormat > currentPayloadFormat) {
        appLogger().w(
          "The project version payload is written in the format $payloadFormat, while "
          "this build of the app only knows up to $currentPayloadFormat: it was created by a "
          "later version of Open Cine Prod Tools",
        );
        return const ResultWithStatus(
          status: OcptProjectVersionPayloadStatus.unsupportedFutureFormat,
        );
      }

      return ResultWithStatus(
        status: OcptProjectVersionPayloadStatus.ok,
        value: _payloadFromJson(_upgraded(decoded, payloadFormat)),
      );
    } on _OcptPayloadFormatError catch (error) {
      appLogger().e("The project version payload can't be read: ${error.reason}");
      return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
    } on FormatException catch (error) {
      appLogger().e("The project version payload isn't valid JSON: $error");
      return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
    }
  }

  /// The SHA-256 hex digest of [payload]'s canonical *content* — the primitive
  /// `OcptProjectVersionsService` builds both "is the working copy the same as this version?" and
  /// a restore's deduplicated safety version on top of. Stored on the row as
  /// `project_versions.contentDigest`, never inside [payload] itself: it describes the payload
  /// rather than being part of it, so keeping a second copy of it in the JSON would only be one
  /// more place for the two to drift apart.
  ///
  /// What goes in and what is left out, and why — matching `OcptProjectVersionsTable.contentDigest`
  /// exactly:
  ///
  /// - **in**: `screenplays`, `scenes`, `shots`, `shotCharacters`, `shotCoverages`, `people`,
  ///   `personPositions`, `personSkills`, `personUnavailabilities`, `roles`, `roleEpisodes`,
  ///   `locations`, `sets`,
  ///   `sceneSets`, `elements`, `sceneElements`, `roleElements`, `roleCandidates`, `assets`,
  ///   `breakdownTags`,
  ///   `sceneBreakdowns`,
  ///   `shootingDays`, `shootingSlots`, `shootingSlotCrew`, `shootingSlotCast`,
  ///   `shootingDayBlocks`, `shootingSlotGuests`, `shootingBlockCandidates`, `shootingDayEvents`,
  ///   `projectDictionaryWords`, `budgetPostes`, `budgetLines`, `budgetEntries`,
  ///   `budgetCommitments`, `budgetResources`, `budgetMileageRates`, `budgetRevenues`,
  ///   `budgetShares` — every
  ///   column of each — plus `pageSetup.format`,
  ///   `settingsJson` and `currencyCode`. This is
  ///   "the project", as a user would describe it, and the resources tables are not optional here:
  ///   leave them out and two states differing only in their people, locations or elements would
  ///   hash identically — the working-copy card would claim no drift after an afternoon of typing
  ///   resources in, and a restore would skip the safety version it promised to keep. `roleEpisodes`
  ///   is the same case in miniature, from payload format 13 on: two states differing only in which
  ///   episodes name a role are not the same project — a character cut from episode 2 but kept in
  ///   episode 3 is a real edit — and leaving the link table out would let the working-copy card
  ///   claim no drift after an afternoon spent saying, episode by episode, who speaks where. The
  ///   breakdown
  ///   tables are exactly the same case, one step later in the project's life: leave them out and an
  ///   afternoon spent tagging the script, or marking scenes done, would hash identically to a
  ///   screenplay nobody has ever broken down. The six schedule tables are the same case again, one
  ///   milestone later: leave them out and planning a whole shoot — a day added, a slot crewed, a
  ///   shot placed onto a block — would hash identically to a project nobody has ever scheduled, so
  ///   the working-copy card would claim no drift and a restore over that afternoon's work would skip
  ///   the safety version it owes. `shootingSlotGuests` and `shootingDayEvents` are the same case a
  ///   step later still: leave them out and entering the mayor lending a square, or the fireworks
  ///   nobody controls, would hash identically to a day carrying neither. `projectDictionaryWords`
  ///   is the same case once more, from payload format 15 on: leave it out and a word learned, or
  ///   un-learned, since the version was captured would hash identically to a project whose lexicon
  ///   never changed — the working-copy card would claim no drift, and a restore that is about to
  ///   silently un-teach a word would skip the safety version it owes for it. `roleCandidates` is
  ///   the same case again, from payload format 16 on, and a costly one to get wrong: a whole week
  ///   of casting — twelve people seen, noted and ranked for one part — moves no other table at all
  ///   until somebody is retained, so leaving it out would let the working-copy card claim no drift
  ///   after exactly the work this table exists to hold. `currencyCode` is only
  ///   ever
  ///   null on a payload decoded
  ///   from a format predating it (never on one freshly captured from a live database, which always
  ///   reads a real value), so this never makes an old and a current capture of the very same
  ///   project disagree; `minimumRestMinutes` is different — it is null exactly as often on a live
  ///   capture as on an old one, since the column is nullable by design — but it stays **in**, not
  ///   out alongside the margins: two projects agreeing on every shooting day but disagreeing on the
  ///   rest they owe between them are not the same project, and leaving it out would hide that;
  ///   `screenplayLanguage` is the same case again, for the same reason: two projects agreeing on
  ///   everything else but disagreeing on the language their screenplays are written in are not the
  ///   same project — one of them would be spell-checked and the other would not — so it stays in,
  ///   null exactly as legitimately as `minimumRestMinutes`. `budgetPostes` and `budgetLines` are
  ///   the same case once more, from payload format 16 on: leave them out and a whole quote typed in
  ///   would hash identically to a project with no budget at all — the working-copy card would
  ///   claim no drift, and a restore over that afternoon's work would skip the safety version it
  ///   owes. `defaultVatRateBasisPoints`, `mealPriceCents` and `snackPriceCents` are
  ///   `minimumRestMinutes`'s own case again: nullable by design, in rather than out alongside the
  ///   margins, since two projects agreeing on every quote line but disagreeing on the rate or the
  ///   catering prices they read against are not the same project. `budgetEntries` and
  ///   `budgetCommitments` are the quote's own case yet again, from payload format 17 on: leave them
  ///   out and a whole afternoon spent recording the cash journal, or the commitments still owed,
  ///   would hash identically to a project with no movement in its account at all. `budgetResources`
  ///   and `budgetMileageRates` are the very same case once more, from payload format 18 on: leave
  ///   them out and a whole financing plan typed in — a subsidy applied for, a rate named for the
  ///   crew's own car — would hash identically to a project with no financing plan at all, the
  ///   working-copy card claiming no drift and a restore over that afternoon's work skipping the
  ///   safety version it owes. `budgetRevenues` and `budgetShares` are the same case once more
  ///   again, from payload format 19 on: leave them out and a whole sharing plan typed in — a
  ///   taking recorded, a participant's share agreed — would hash identically to a project with no
  ///   sharing plan at all, the working-copy card claiming no drift and a restore over that
  ///   afternoon's work skipping the safety version it owes. `isBudgetSimplified` is
  ///   `minimumRestMinutes`'s own case once more, from payload format 25 on: nullable by design, in
  ///   rather than out alongside the margins, since two projects agreeing on every figure but
  ///   disagreeing on which of the header's two views they were last left on are not the same
  ///   project. `budget_resources.personId` needs no entry of its own here: it is a column of
  ///   `budgetResources`, already in above;
  /// - **out**: `rowFieldVersions`, whose per-column stamps change on every restore without the
  ///   content changing, and `pageSetup.margins`, an app-wide rendering preference rather than
  ///   project state.
  ///
  /// **Canonical.** `OcptProjectVersionsService._capturePayload` issues its `select`s with no
  /// `orderBy`, so SQLite's row order is never something either side of a comparison may rely on —
  /// and sorting happens here, rather than in that capture, precisely so the bytes actually stored
  /// in `project_versions.payload` stay untouched. Each table's rows are sorted by primary key (a
  /// composite one, `shotCharacters`', joined the same way [ocptCompositeRowStampKey] joins a
  /// version stamp's `rowId`), and each row's own JSON map has its keys sorted too, so two
  /// captures of the same state always hash the same regardless of the order SQLite happened to
  /// return rows in.
  String contentDigest(OcptProjectVersionPayload payload) {
    final canonical = <String, Object?>{
      _screenplaysKey: _canonicalRows(
        payload.screenplays,
        primaryKeyOf: (row) => row.id,
        toJson: _screenplayToJson,
      ),
      _scenesKey: _canonicalRows(
        payload.scenes,
        primaryKeyOf: (row) => row.id,
        toJson: _sceneToJson,
      ),
      _shotsKey: _canonicalRows(payload.shots, primaryKeyOf: (row) => row.id, toJson: _shotToJson),
      _shotCharactersKey: _canonicalRows(
        payload.shotCharacters,
        primaryKeyOf: (row) => ocptCompositeRowStampKey([row.shotId, row.characterName]),
        toJson: _shotCharacterToJson,
      ),
      _shotCoveragesKey: _canonicalRows(
        payload.shotCoverages,
        primaryKeyOf: (row) => row.id,
        toJson: _shotCoverageToJson,
      ),
      _peopleKey: _canonicalRows(
        payload.people,
        primaryKeyOf: (row) => row.id,
        toJson: _personToJson,
      ),
      _personPositionsKey: _canonicalRows(
        payload.personPositions,
        primaryKeyOf: (row) => row.id,
        toJson: _personPositionToJson,
      ),
      _personSkillsKey: _canonicalRows(
        payload.personSkills,
        primaryKeyOf: (row) => row.id,
        toJson: _personSkillToJson,
      ),
      _personUnavailabilitiesKey: _canonicalRows(
        payload.personUnavailabilities,
        primaryKeyOf: (row) => row.id,
        toJson: _personUnavailabilityToJson,
      ),
      _rolesKey: _canonicalRows(payload.roles, primaryKeyOf: (row) => row.id, toJson: _roleToJson),
      _roleEpisodesKey: _canonicalRows(
        payload.roleEpisodes,
        primaryKeyOf: (row) => row.id,
        toJson: _roleEpisodeToJson,
      ),
      _locationsKey: _canonicalRows(
        payload.locations,
        primaryKeyOf: (row) => row.id,
        toJson: _locationToJson,
      ),
      _locationAvailabilitiesKey: _canonicalRows(
        payload.locationAvailabilities,
        primaryKeyOf: (row) => row.id,
        toJson: _locationAvailabilityToJson,
      ),
      _setsKey: _canonicalRows(payload.sets, primaryKeyOf: (row) => row.id, toJson: _setToJson),
      _sceneSetsKey: _canonicalRows(
        payload.sceneSets,
        primaryKeyOf: (row) => row.id,
        toJson: _sceneSetToJson,
      ),
      _elementsKey: _canonicalRows(
        payload.elements,
        primaryKeyOf: (row) => row.id,
        toJson: _elementToJson,
      ),
      _sceneElementsKey: _canonicalRows(
        payload.sceneElements,
        primaryKeyOf: (row) => row.id,
        toJson: _sceneElementToJson,
      ),
      _roleElementsKey: _canonicalRows(
        payload.roleElements,
        primaryKeyOf: (row) => row.id,
        toJson: _roleElementToJson,
      ),
      _roleCandidatesKey: _canonicalRows(
        payload.roleCandidates,
        primaryKeyOf: (row) => row.id,
        toJson: _roleCandidateToJson,
      ),
      _assetsKey: _canonicalRows(
        payload.assets,
        primaryKeyOf: (row) => row.id,
        toJson: _assetToJson,
      ),
      _breakdownTagsKey: _canonicalRows(
        payload.breakdownTags,
        primaryKeyOf: (row) => row.id,
        toJson: _breakdownTagToJson,
      ),
      _sceneBreakdownsKey: _canonicalRows(
        payload.sceneBreakdowns,
        primaryKeyOf: (row) => row.id,
        toJson: _sceneBreakdownToJson,
      ),
      _shootingDaysKey: _canonicalRows(
        payload.shootingDays,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingDayToJson,
      ),
      _shootingSlotsKey: _canonicalRows(
        payload.shootingSlots,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingSlotToJson,
      ),
      _shootingSlotCrewKey: _canonicalRows(
        payload.shootingSlotCrew,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingSlotCrewToJson,
      ),
      _shootingSlotCastKey: _canonicalRows(
        payload.shootingSlotCast,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingSlotCastToJson,
      ),
      _shootingDayBlocksKey: _canonicalRows(
        payload.shootingDayBlocks,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingDayBlockToJson,
      ),
      _shootingSlotGuestsKey: _canonicalRows(
        payload.shootingSlotGuests,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingSlotGuestToJson,
      ),
      _shootingBlockCandidatesKey: _canonicalRows(
        payload.shootingBlockCandidates,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingBlockCandidateToJson,
      ),
      _shootingDayEventsKey: _canonicalRows(
        payload.shootingDayEvents,
        primaryKeyOf: (row) => row.id,
        toJson: _shootingDayEventToJson,
      ),
      _projectDictionaryWordsKey: _canonicalRows(
        payload.projectDictionaryWords,
        primaryKeyOf: (row) => row.id,
        toJson: _projectDictionaryWordToJson,
      ),
      _budgetPostesKey: _canonicalRows(
        payload.budgetPostes,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetPosteToJson,
      ),
      _budgetLinesKey: _canonicalRows(
        payload.budgetLines,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetLineToJson,
      ),
      _budgetEntriesKey: _canonicalRows(
        payload.budgetEntries,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetEntryToJson,
      ),
      _budgetCommitmentsKey: _canonicalRows(
        payload.budgetCommitments,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetCommitmentToJson,
      ),
      _budgetResourcesKey: _canonicalRows(
        payload.budgetResources,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetResourceToJson,
      ),
      _budgetMileageRatesKey: _canonicalRows(
        payload.budgetMileageRates,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetMileageRateToJson,
      ),
      _budgetRevenuesKey: _canonicalRows(
        payload.budgetRevenues,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetRevenueToJson,
      ),
      _budgetSharesKey: _canonicalRows(
        payload.budgetShares,
        primaryKeyOf: (row) => row.id,
        toJson: _budgetShareToJson,
      ),
      _pageFormatKey: payload.pageSetup.format.name,
      _settingsJsonKey: payload.settingsJson,
      _currencyCodeKey: payload.currencyCode,
      _minimumRestMinutesKey: payload.minimumRestMinutes,
      _screenplayLanguageKey: payload.screenplayLanguage?.name,
      _defaultVatRateBasisPointsKey: payload.defaultVatRateBasisPoints,
      _mealPriceCentsKey: payload.mealPriceCents,
      _snackPriceCentsKey: payload.snackPriceCents,
      _isBudgetSimplifiedKey: payload.isBudgetSimplified,
    };

    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  /// [rows], sorted by [primaryKeyOf] and each turned into a JSON map (through the same
  /// `_screenplayToJson`-shaped serializer [encode] itself uses, so an enum column comes out as
  /// the plain string `jsonEncode` can write rather than the `TypeConverter`'s own Dart value)
  /// whose keys are themselves sorted — the two orderings [contentDigest] needs to be canonical.
  static List<Map<String, dynamic>> _canonicalRows<D>(
    List<D> rows, {
    required String Function(D row) primaryKeyOf,
    required Map<String, dynamic> Function(D row) toJson,
  }) {
    final sortedRows = [...rows]..sort((a, b) => primaryKeyOf(a).compareTo(primaryKeyOf(b)));

    return [for (final row in sortedRows) SplayTreeMap<String, dynamic>.of(toJson(row))];
  }

  /// Replays the [_payloadUpgrades] steps that take [json], written in [payloadFormat], up to
  /// [currentPayloadFormat].
  ///
  /// Returns [json] itself when it is already current, which is the only case that exists so far.
  static Map<String, dynamic> _upgraded(Map<String, dynamic> json, int payloadFormat) {
    var upgraded = json;

    for (var format = payloadFormat; format < currentPayloadFormat; format++) {
      final upgrade = _payloadUpgrades[format];
      if (upgrade == null) {
        throw _OcptPayloadFormatError("no upgrade step knows how to read the format $format");
      }

      upgraded = upgrade(upgraded);
    }

    return upgraded;
  }

  /// Builds the payload described by [json], already upgraded to [currentPayloadFormat].
  static OcptProjectVersionPayload _payloadFromJson(Map<String, dynamic> json) {
    final projectSettings = _object(json, _projectSettingsKey);
    final pageMargins = _object(json, _pageMarginsKey);

    return OcptProjectVersionPayload(
      screenplays: [for (final row in _rows(json, _screenplaysKey)) _screenplayFromJson(row)],
      scenes: [for (final row in _rows(json, _scenesKey)) _sceneFromJson(row)],
      shots: [for (final row in _rows(json, _shotsKey)) _shotFromJson(row)],
      shotCharacters: [
        for (final row in _rows(json, _shotCharactersKey)) _shotCharacterFromJson(row),
      ],
      shotCoverages: [for (final row in _rows(json, _shotCoveragesKey)) _shotCoverageFromJson(row)],
      people: [for (final row in _rows(json, _peopleKey)) _personFromJson(row)],
      personPositions: [
        for (final row in _rows(json, _personPositionsKey)) _personPositionFromJson(row),
      ],
      personSkills: [for (final row in _rows(json, _personSkillsKey)) _personSkillFromJson(row)],
      personUnavailabilities: [
        for (final row in _rows(json, _personUnavailabilitiesKey))
          _personUnavailabilityFromJson(row),
      ],
      roles: [for (final row in _rows(json, _rolesKey)) _roleFromJson(row)],
      roleEpisodes: [
        for (final row in _rows(json, _roleEpisodesKey)) _roleEpisodeFromJson(row),
      ],
      locations: [for (final row in _rows(json, _locationsKey)) _locationFromJson(row)],
      locationAvailabilities: [
        for (final row in _rows(json, _locationAvailabilitiesKey))
          _locationAvailabilityFromJson(row),
      ],
      sets: [for (final row in _rows(json, _setsKey)) _setFromJson(row)],
      sceneSets: [for (final row in _rows(json, _sceneSetsKey)) _sceneSetFromJson(row)],
      elements: [for (final row in _rows(json, _elementsKey)) _elementFromJson(row)],
      sceneElements: [for (final row in _rows(json, _sceneElementsKey)) _sceneElementFromJson(row)],
      roleElements: [for (final row in _rows(json, _roleElementsKey)) _roleElementFromJson(row)],
      roleCandidates: [
        for (final row in _rows(json, _roleCandidatesKey)) _roleCandidateFromJson(row),
      ],
      assets: [for (final row in _rows(json, _assetsKey)) _assetFromJson(row)],
      breakdownTags: [for (final row in _rows(json, _breakdownTagsKey)) _breakdownTagFromJson(row)],
      sceneBreakdowns: [
        for (final row in _rows(json, _sceneBreakdownsKey)) _sceneBreakdownFromJson(row),
      ],
      shootingDays: [for (final row in _rows(json, _shootingDaysKey)) _shootingDayFromJson(row)],
      shootingSlots: [for (final row in _rows(json, _shootingSlotsKey)) _shootingSlotFromJson(row)],
      shootingSlotCrew: [
        for (final row in _rows(json, _shootingSlotCrewKey)) _shootingSlotCrewFromJson(row),
      ],
      shootingSlotCast: [
        for (final row in _rows(json, _shootingSlotCastKey)) _shootingSlotCastFromJson(row),
      ],
      shootingDayBlocks: [
        for (final row in _rows(json, _shootingDayBlocksKey)) _shootingDayBlockFromJson(row),
      ],
      shootingSlotGuests: [
        for (final row in _rows(json, _shootingSlotGuestsKey)) _shootingSlotGuestFromJson(row),
      ],
      shootingBlockCandidates: [
        for (final row in _rows(json, _shootingBlockCandidatesKey))
          _shootingBlockCandidateFromJson(row),
      ],
      shootingDayEvents: [
        for (final row in _rows(json, _shootingDayEventsKey)) _shootingDayEventFromJson(row),
      ],
      projectDictionaryWords: [
        for (final row in _rows(json, _projectDictionaryWordsKey))
          _projectDictionaryWordFromJson(row),
      ],
      budgetPostes: [for (final row in _rows(json, _budgetPostesKey)) _budgetPosteFromJson(row)],
      budgetLines: [for (final row in _rows(json, _budgetLinesKey)) _budgetLineFromJson(row)],
      budgetEntries: [
        for (final row in _rows(json, _budgetEntriesKey)) _budgetEntryFromJson(row),
      ],
      budgetCommitments: [
        for (final row in _rows(json, _budgetCommitmentsKey)) _budgetCommitmentFromJson(row),
      ],
      budgetResources: [
        for (final row in _rows(json, _budgetResourcesKey)) _budgetResourceFromJson(row),
      ],
      budgetMileageRates: [
        for (final row in _rows(json, _budgetMileageRatesKey)) _budgetMileageRateFromJson(row),
      ],
      budgetRevenues: [
        for (final row in _rows(json, _budgetRevenuesKey)) _budgetRevenueFromJson(row),
      ],
      budgetShares: [for (final row in _rows(json, _budgetSharesKey)) _budgetShareFromJson(row)],
      rowFieldVersions: [
        for (final row in _rows(json, _rowFieldVersionsKey)) _rowFieldVersionFromJson(row),
      ],
      pageSetup: OcptPageSetup(
        format: _enum(projectSettings, _pageFormatKey, OcptPageFormat.values.asNameMap()),
        margins: FountainPageMargins(
          leftInches: _double(pageMargins, _marginLeftKey),
          rightInches: _double(pageMargins, _marginRightKey),
          topInches: _double(pageMargins, _marginTopKey),
          bottomInches: _double(pageMargins, _marginBottomKey),
        ),
      ),
      settingsJson: _nullableString(projectSettings, _settingsJsonKey),
      currencyCode: _nullableString(projectSettings, _currencyCodeKey),
      minimumRestMinutes: _nullableInt(projectSettings, _minimumRestMinutesKey),
      screenplayLanguage: _nullableEnum(
        projectSettings,
        _screenplayLanguageKey,
        OcptScreenplayLanguage.values.asNameMap(),
      ),
      defaultVatRateBasisPoints: _nullableInt(projectSettings, _defaultVatRateBasisPointsKey),
      mealPriceCents: _nullableInt(projectSettings, _mealPriceCentsKey),
      snackPriceCents: _nullableInt(projectSettings, _snackPriceCentsKey),
      isBudgetSimplified: _nullableBool(projectSettings, _isBudgetSimplifiedKey),
    );
  }

  /// Serializes one `screenplays` row.
  static Map<String, dynamic> _screenplayToJson(OcptScreenplayRow row) => {
    _idKey: row.id,
    _titleKey: row.title,
    _fountainTextKey: row.fountainText,
    _updatedAtKey: row.updatedAt.toIso8601String(),
    _numberKey: row.number,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `screenplays` row.
  static OcptScreenplayRow _screenplayFromJson(Map<String, dynamic> json) => OcptScreenplayRow(
    id: _string(json, _idKey),
    title: _string(json, _titleKey),
    fountainText: _string(json, _fountainTextKey),
    updatedAt: _dateTime(json, _updatedAtKey),
    number: _int(json, _numberKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `scenes` row.
  static Map<String, dynamic> _sceneToJson(OcptSceneRow row) => {
    _idKey: row.id,
    _screenplayIdKey: row.screenplayId,
    _positionKey: row.position,
    _headingKey: row.heading,
    _sceneNumberKey: row.sceneNumber,
    _charStartKey: row.charStart,
    _charEndKey: row.charEnd,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `scenes` row.
  static OcptSceneRow _sceneFromJson(Map<String, dynamic> json) => OcptSceneRow(
    id: _string(json, _idKey),
    screenplayId: _string(json, _screenplayIdKey),
    position: _int(json, _positionKey),
    heading: _string(json, _headingKey),
    sceneNumber: _nullableString(json, _sceneNumberKey),
    charStart: _int(json, _charStartKey),
    charEnd: _int(json, _charEndKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `shots` row.
  static Map<String, dynamic> _shotToJson(OcptShotRow row) => {
    _idKey: row.id,
    _screenplayIdKey: row.screenplayId,
    _sceneIdKey: row.sceneId,
    _orphanedHeadingKey: row.orphanedHeading,
    _positionKey: row.position,
    _sortKeyKey: row.sortKey,
    _shotSizeKey: row.shotSize,
    _abbreviationKey: row.abbreviation,
    _framingKey: row.framing,
    _cameraMoveKey: row.cameraMove,
    _lensKey: row.lens,
    _recordingFormatKey: row.recordingFormat,
    _estimatedDurationMsKey: row.estimatedDurationMs,
    _shootingDayKey: row.shootingDay,
    _plannedTakesKey: row.plannedTakes,
    _soundKey: row.sound,
    _statusKey: row.status.name,
    _difficultySetKey: row.difficultySet,
    _difficultyCameraKey: row.difficultyCamera,
    _difficultyActingKey: row.difficultyActing,
    _difficultySoundKey: row.difficultySound,
    _notesKey: row.notes,
    _locationNotesKey: row.locationNotes,
    _needsCheckKey: row.needsCheck,
    _checkReasonKey: row.checkReason?.name,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shots` row.
  static OcptShotRow _shotFromJson(Map<String, dynamic> json) => OcptShotRow(
    id: _string(json, _idKey),
    screenplayId: _string(json, _screenplayIdKey),
    sceneId: _nullableString(json, _sceneIdKey),
    orphanedHeading: _nullableString(json, _orphanedHeadingKey),
    position: _int(json, _positionKey),
    sortKey: _string(json, _sortKeyKey),
    shotSize: _string(json, _shotSizeKey),
    abbreviation: _string(json, _abbreviationKey),
    framing: _string(json, _framingKey),
    cameraMove: _string(json, _cameraMoveKey),
    lens: _string(json, _lensKey),
    recordingFormat: _string(json, _recordingFormatKey),
    estimatedDurationMs: _nullableInt(json, _estimatedDurationMsKey),
    shootingDay: _nullableString(json, _shootingDayKey),
    plannedTakes: _nullableInt(json, _plannedTakesKey),
    sound: _string(json, _soundKey),
    status: _enum(json, _statusKey, OcptShotStatus.values.asNameMap()),
    difficultySet: _int(json, _difficultySetKey),
    difficultyCamera: _int(json, _difficultyCameraKey),
    difficultyActing: _int(json, _difficultyActingKey),
    difficultySound: _int(json, _difficultySoundKey),
    notes: _string(json, _notesKey),
    locationNotes: _string(json, _locationNotesKey),
    needsCheck: _bool(json, _needsCheckKey),
    checkReason: _nullableEnum(json, _checkReasonKey, OcptShotCheckReason.values.asNameMap()),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `shot_characters` row.
  static Map<String, dynamic> _shotCharacterToJson(OcptShotCharacterRow row) => {
    _shotIdKey: row.shotId,
    _characterNameKey: row.characterName,
    _positionKey: row.position,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shot_characters` row.
  static OcptShotCharacterRow _shotCharacterFromJson(Map<String, dynamic> json) =>
      OcptShotCharacterRow(
        shotId: _string(json, _shotIdKey),
        characterName: _string(json, _characterNameKey),
        position: _int(json, _positionKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shot_coverages` row.
  static Map<String, dynamic> _shotCoverageToJson(OcptShotCoverageRow row) => {
    _idKey: row.id,
    _shotIdKey: row.shotId,
    _sceneIdKey: row.sceneId,
    _startOffsetKey: row.startOffset,
    _endOffsetKey: row.endOffset,
    _coveredTextDigestKey: row.coveredTextDigest,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shot_coverages` row.
  static OcptShotCoverageRow _shotCoverageFromJson(Map<String, dynamic> json) =>
      OcptShotCoverageRow(
        id: _string(json, _idKey),
        shotId: _string(json, _shotIdKey),
        sceneId: _string(json, _sceneIdKey),
        startOffset: _int(json, _startOffsetKey),
        endOffset: _int(json, _endOffsetKey),
        coveredTextDigest: _string(json, _coveredTextDigestKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `people` row.
  static Map<String, dynamic> _personToJson(OcptPersonRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _firstNameKey: row.firstName,
    _lastNameKey: row.lastName,
    _emailKey: row.email,
    _phoneKey: row.phone,
    _addressLine1Key: row.addressLine1,
    _addressLine2Key: row.addressLine2,
    _postalCodeKey: row.postalCode,
    _cityKey: row.city,
    _regionKey: row.region,
    _countryKey: row.country,
    _colorIndexKey: row.colorIndex,
    _birthDateKey: row.birthDate?.toIso8601String(),
    _minorNotesKey: row.minorNotes,
    _maxDailyPresenceMinutesKey: row.maxDailyPresenceMinutes,
    _isTransportAutonomousKey: row.isTransportAutonomous,
    _accommodationNotesKey: row.accommodationNotes,
    _travelNotesKey: row.travelNotes,
    _dietaryNotesKey: row.dietaryNotes,
    _allergiesKey: row.allergies,
    _measurementHeightKey: row.measurementHeight,
    _measurementChestKey: row.measurementChest,
    _measurementWaistKey: row.measurementWaist,
    _measurementHipsKey: row.measurementHips,
    _sizeTopKey: row.sizeTop,
    _sizeBottomKey: row.sizeBottom,
    _sizeShoesKey: row.sizeShoes,
    _hmcNotesKey: row.hmcNotes,
    _imageRightsStatusKey: row.imageRightsStatus.name,
    _imageRightsDateKey: row.imageRightsDate?.toIso8601String(),
    _imageRightsAssetIdKey: row.imageRightsAssetId,
    _photoAssetIdKey: row.photoAssetId,
    _notesKey: row.notes,
    _commuteKmMilliKey: row.commuteKmMilli,
    _mileageRateIdKey: row.mileageRateId,
  };

  /// Parses one `people` row.
  static OcptPersonRow _personFromJson(Map<String, dynamic> json) => OcptPersonRow(
    id: _string(json, _idKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    firstName: _string(json, _firstNameKey),
    lastName: _string(json, _lastNameKey),
    email: _string(json, _emailKey),
    phone: _string(json, _phoneKey),
    addressLine1: _string(json, _addressLine1Key),
    addressLine2: _string(json, _addressLine2Key),
    postalCode: _string(json, _postalCodeKey),
    city: _string(json, _cityKey),
    region: _string(json, _regionKey),
    country: _string(json, _countryKey),
    colorIndex: _int(json, _colorIndexKey),
    birthDate: _nullableDateTime(json, _birthDateKey),
    minorNotes: _string(json, _minorNotesKey),
    maxDailyPresenceMinutes: _nullableInt(json, _maxDailyPresenceMinutesKey),
    isTransportAutonomous: _nullableBool(json, _isTransportAutonomousKey),
    accommodationNotes: _string(json, _accommodationNotesKey),
    travelNotes: _string(json, _travelNotesKey),
    dietaryNotes: _string(json, _dietaryNotesKey),
    allergies: _string(json, _allergiesKey),
    measurementHeight: _string(json, _measurementHeightKey),
    measurementChest: _string(json, _measurementChestKey),
    measurementWaist: _string(json, _measurementWaistKey),
    measurementHips: _string(json, _measurementHipsKey),
    sizeTop: _string(json, _sizeTopKey),
    sizeBottom: _string(json, _sizeBottomKey),
    sizeShoes: _string(json, _sizeShoesKey),
    hmcNotes: _string(json, _hmcNotesKey),
    imageRightsStatus: _enum(json, _imageRightsStatusKey, OcptImageRightsStatus.values.asNameMap()),
    imageRightsDate: _nullableDateTime(json, _imageRightsDateKey),
    imageRightsAssetId: _nullableString(json, _imageRightsAssetIdKey),
    photoAssetId: _nullableString(json, _photoAssetIdKey),
    notes: _string(json, _notesKey),
    commuteKmMilli: _nullableInt(json, _commuteKmMilliKey),
    mileageRateId: _nullableString(json, _mileageRateIdKey),
  );

  /// Serializes one `person_positions` row.
  static Map<String, dynamic> _personPositionToJson(OcptPersonPositionRow row) => {
    _idKey: row.id,
    _personIdKey: row.personId,
    _positionIdKey: row.positionId,
    _customLabelKey: row.customLabel,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `person_positions` row.
  static OcptPersonPositionRow _personPositionFromJson(Map<String, dynamic> json) =>
      OcptPersonPositionRow(
        id: _string(json, _idKey),
        personId: _string(json, _personIdKey),
        positionId: _string(json, _positionIdKey),
        customLabel: _string(json, _customLabelKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `person_skills` row.
  static Map<String, dynamic> _personSkillToJson(OcptPersonSkillRow row) => {
    _idKey: row.id,
    _personIdKey: row.personId,
    _labelKey: row.label,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `person_skills` row.
  static OcptPersonSkillRow _personSkillFromJson(Map<String, dynamic> json) => OcptPersonSkillRow(
    id: _string(json, _idKey),
    personId: _string(json, _personIdKey),
    label: _string(json, _labelKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `person_unavailabilities` row.
  static Map<String, dynamic> _personUnavailabilityToJson(OcptPersonUnavailabilityRow row) => {
    _idKey: row.id,
    _personIdKey: row.personId,
    _startDateKey: row.startDate.toIso8601String(),
    _endDateKey: row.endDate.toIso8601String(),
    _slotKey: row.slot.name,
    _startMinuteKey: row.startMinute,
    _endMinuteKey: row.endMinute,
    _reasonKey: row.reason,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `person_unavailabilities` row.
  static OcptPersonUnavailabilityRow _personUnavailabilityFromJson(Map<String, dynamic> json) =>
      OcptPersonUnavailabilityRow(
        id: _string(json, _idKey),
        personId: _string(json, _personIdKey),
        startDate: _dateTime(json, _startDateKey),
        endDate: _dateTime(json, _endDateKey),
        slot: _enum(json, _slotKey, OcptDayPartSlot.values.asNameMap()),
        startMinute: _nullableInt(json, _startMinuteKey),
        endMinute: _nullableInt(json, _endMinuteKey),
        reason: _string(json, _reasonKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `roles` row.
  static Map<String, dynamic> _roleToJson(OcptRoleRow row) => {
    _idKey: row.id,
    _nameKey: row.name,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _personIdKey: row.personId,
    _kindKey: row.kind.name,
    _isFromScreenplayKey: row.isFromScreenplay,
    _orphanedNameKey: row.orphanedName,
    _castingNotesKey: row.castingNotes,
  };

  /// Parses one `roles` row.
  static OcptRoleRow _roleFromJson(Map<String, dynamic> json) => OcptRoleRow(
    id: _string(json, _idKey),
    name: _string(json, _nameKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    personId: _nullableString(json, _personIdKey),
    kind: _enum(json, _kindKey, OcptRoleKind.values.asNameMap()),
    isFromScreenplay: _bool(json, _isFromScreenplayKey),
    orphanedName: _nullableString(json, _orphanedNameKey),
    castingNotes: _string(json, _castingNotesKey),
  );

  /// Serializes one `role_episodes` row: the same shape of link row `scene_sets` is
  /// ([_sceneSetToJson]) — id, two foreign keys, tombstone, no `sortKey`, since which episodes name
  /// a role is an unordered set of answers rather than a list the user reorders
  /// (`OcptRoleEpisodesTable`'s own doc comment).
  static Map<String, dynamic> _roleEpisodeToJson(OcptRoleEpisodeRow row) => {
    _idKey: row.id,
    _roleIdKey: row.roleId,
    _screenplayIdKey: row.screenplayId,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `role_episodes` row.
  static OcptRoleEpisodeRow _roleEpisodeFromJson(Map<String, dynamic> json) => OcptRoleEpisodeRow(
    id: _string(json, _idKey),
    roleId: _string(json, _roleIdKey),
    screenplayId: _string(json, _screenplayIdKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `project_dictionary_words` row: id, the word as it was typed, tombstone — no
  /// `sortKey`, for the reason `OcptProjectDictionaryWordsTable`'s own doc comment gives (an
  /// unordered set a writer builds up, not a list they arrange).
  static Map<String, dynamic> _projectDictionaryWordToJson(OcptProjectDictionaryWordRow row) => {
    _idKey: row.id,
    _wordKey: row.word,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `project_dictionary_words` row.
  static OcptProjectDictionaryWordRow _projectDictionaryWordFromJson(Map<String, dynamic> json) =>
      OcptProjectDictionaryWordRow(
        id: _string(json, _idKey),
        word: _string(json, _wordKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `budget_postes` row.
  static Map<String, dynamic> _budgetPosteToJson(OcptBudgetPosteRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _codeKey: row.code,
    _labelKey: row.label,
    _simpleLabelKey: row.simpleLabel,
  };

  /// Parses one `budget_postes` row.
  static OcptBudgetPosteRow _budgetPosteFromJson(Map<String, dynamic> json) => OcptBudgetPosteRow(
    id: _string(json, _idKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    code: _string(json, _codeKey),
    label: _string(json, _labelKey),
    simpleLabel: _nullableString(json, _simpleLabelKey),
  );

  /// Serializes one `budget_lines` row.
  static Map<String, dynamic> _budgetLineToJson(OcptBudgetLineRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _posteIdKey: row.posteId,
    _labelKey: row.label,
    _quantityMilliKey: row.quantityMilli,
    _unitKey: row.unit,
    _unitAmountCentsKey: row.unitAmountCents,
    _isTaxInclusiveKey: row.isTaxInclusive,
    _vatRateBasisPointsKey: row.vatRateBasisPoints,
    _elementIdKey: row.elementId,
    _notesKey: row.notes,
  };

  /// Parses one `budget_lines` row.
  static OcptBudgetLineRow _budgetLineFromJson(Map<String, dynamic> json) => OcptBudgetLineRow(
    id: _string(json, _idKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    posteId: _string(json, _posteIdKey),
    label: _string(json, _labelKey),
    quantityMilli: _int(json, _quantityMilliKey),
    unit: _string(json, _unitKey),
    unitAmountCents: _int(json, _unitAmountCentsKey),
    isTaxInclusive: _bool(json, _isTaxInclusiveKey),
    vatRateBasisPoints: _nullableInt(json, _vatRateBasisPointsKey),
    elementId: _nullableString(json, _elementIdKey),
    notes: _string(json, _notesKey),
  );

  /// Serializes one `budget_entries` row.
  static Map<String, dynamic> _budgetEntryToJson(OcptBudgetEntryRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _dateKey: row.date.toIso8601String(),
    _labelKey: row.label,
    _posteIdKey: row.posteId,
    _debitCentsKey: row.debitCents,
    _creditCentsKey: row.creditCents,
    _isTaxInclusiveKey: row.isTaxInclusive,
    _vatRateBasisPointsKey: row.vatRateBasisPoints,
    _voucherNumberKey: row.voucherNumber,
    _resourceIdKey: row.resourceId,
    _revenueIdKey: row.revenueId,
    _shareIdKey: row.shareId,
  };

  /// Parses one `budget_entries` row.
  static OcptBudgetEntryRow _budgetEntryFromJson(Map<String, dynamic> json) => OcptBudgetEntryRow(
    id: _string(json, _idKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    date: _dateTime(json, _dateKey),
    label: _string(json, _labelKey),
    posteId: _nullableString(json, _posteIdKey),
    debitCents: _int(json, _debitCentsKey),
    creditCents: _int(json, _creditCentsKey),
    isTaxInclusive: _bool(json, _isTaxInclusiveKey),
    vatRateBasisPoints: _nullableInt(json, _vatRateBasisPointsKey),
    voucherNumber: _string(json, _voucherNumberKey),
    resourceId: _nullableString(json, _resourceIdKey),
    revenueId: _nullableString(json, _revenueIdKey),
    shareId: _nullableString(json, _shareIdKey),
  );

  /// Serializes one `budget_commitments` row.
  static Map<String, dynamic> _budgetCommitmentToJson(OcptBudgetCommitmentRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _dueDateKey: row.dueDate?.toIso8601String(),
    _labelKey: row.label,
    _posteIdKey: row.posteId,
    _amountCentsKey: row.amountCents,
    _isTaxInclusiveKey: row.isTaxInclusive,
    _vatRateBasisPointsKey: row.vatRateBasisPoints,
    _statusKey: row.status.name,
    _settledEntryIdKey: row.settledEntryId,
  };

  /// Parses one `budget_commitments` row.
  static OcptBudgetCommitmentRow _budgetCommitmentFromJson(Map<String, dynamic> json) =>
      OcptBudgetCommitmentRow(
        id: _string(json, _idKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
        dueDate: _nullableDateTime(json, _dueDateKey),
        label: _string(json, _labelKey),
        posteId: _string(json, _posteIdKey),
        amountCents: _int(json, _amountCentsKey),
        isTaxInclusive: _bool(json, _isTaxInclusiveKey),
        vatRateBasisPoints: _nullableInt(json, _vatRateBasisPointsKey),
        status: _enum(json, _statusKey, OcptBudgetCommitmentStatus.values.asNameMap()),
        settledEntryId: _nullableString(json, _settledEntryIdKey),
      );

  /// Serializes one `budget_resources` row.
  static Map<String, dynamic> _budgetResourceToJson(OcptBudgetResourceRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _groupKindKey: row.groupKind.name,
    _personIdKey: row.personId,
    _labelKey: row.label,
    _amountCentsKey: row.amountCents,
    _statusKey: row.status.name,
    _isReimbursableKey: row.isReimbursable,
    _notesKey: row.notes,
  };

  /// Parses one `budget_resources` row.
  static OcptBudgetResourceRow _budgetResourceFromJson(Map<String, dynamic> json) =>
      OcptBudgetResourceRow(
        id: _string(json, _idKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
        groupKind: _enum(json, _groupKindKey, OcptBudgetResourceGroupKind.values.asNameMap()),
        personId: _nullableString(json, _personIdKey),
        label: _string(json, _labelKey),
        amountCents: _int(json, _amountCentsKey),
        status: _enum(json, _statusKey, OcptBudgetResourceStatus.values.asNameMap()),
        isReimbursable: _bool(json, _isReimbursableKey),
        notes: _string(json, _notesKey),
      );

  /// Serializes one `budget_mileage_rates` row.
  static Map<String, dynamic> _budgetMileageRateToJson(OcptBudgetMileageRateRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _labelKey: row.label,
    _ratePerKmMilliCentsKey: row.ratePerKmMilliCents,
  };

  /// Parses one `budget_mileage_rates` row.
  static OcptBudgetMileageRateRow _budgetMileageRateFromJson(Map<String, dynamic> json) =>
      OcptBudgetMileageRateRow(
        id: _string(json, _idKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
        label: _string(json, _labelKey),
        ratePerKmMilliCents: _int(json, _ratePerKmMilliCentsKey),
      );

  /// Serializes one `budget_revenues` row.
  static Map<String, dynamic> _budgetRevenueToJson(OcptBudgetRevenueRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _dateKey: row.date.toIso8601String(),
    _labelKey: row.label,
    _amountCentsKey: row.amountCents,
    _statusKey: row.status.name,
    _notesKey: row.notes,
  };

  /// Parses one `budget_revenues` row.
  static OcptBudgetRevenueRow _budgetRevenueFromJson(Map<String, dynamic> json) =>
      OcptBudgetRevenueRow(
        id: _string(json, _idKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
        date: _dateTime(json, _dateKey),
        label: _string(json, _labelKey),
        amountCents: _int(json, _amountCentsKey),
        status: _enum(json, _statusKey, OcptBudgetRevenueStatus.values.asNameMap()),
        notes: _string(json, _notesKey),
      );

  /// Serializes one `budget_shares` row.
  static Map<String, dynamic> _budgetShareToJson(OcptBudgetShareRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _personIdKey: row.personId,
    _labelKey: row.label,
    _sharePermilleKey: row.sharePermille,
    _reinvestPermilleKey: row.reinvestPermille,
    _notesKey: row.notes,
  };

  /// Parses one `budget_shares` row.
  static OcptBudgetShareRow _budgetShareFromJson(Map<String, dynamic> json) => OcptBudgetShareRow(
    id: _string(json, _idKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    personId: _nullableString(json, _personIdKey),
    label: _string(json, _labelKey),
    sharePermille: _int(json, _sharePermilleKey),
    reinvestPermille: _int(json, _reinvestPermilleKey),
    notes: _string(json, _notesKey),
  );

  /// Serializes one `locations` row.
  static Map<String, dynamic> _locationToJson(OcptLocationRow row) => {
    _idKey: row.id,
    _nameKey: row.name,
    _colorIndexKey: row.colorIndex,
    _addressLine1Key: row.addressLine1,
    _addressLine2Key: row.addressLine2,
    _postalCodeKey: row.postalCode,
    _cityKey: row.city,
    _regionKey: row.region,
    _countryKey: row.country,
    _latitudeKey: row.latitude,
    _longitudeKey: row.longitude,
    _contactPersonIdKey: row.contactPersonId,
    _contactNotesKey: row.contactNotes,
    _permitStatusKey: row.permitStatus.name,
    _permitLabelKey: row.permitLabel,
    _permitDateKey: row.permitDate?.toIso8601String(),
    _permitAssetIdKey: row.permitAssetId,
    _parkingNotesKey: row.parkingNotes,
    _powerNotesKey: row.powerNotes,
    _facilitiesNotesKey: row.facilitiesNotes,
    _constraintsNotesKey: row.constraintsNotes,
    _notesKey: row.notes,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `locations` row.
  static OcptLocationRow _locationFromJson(Map<String, dynamic> json) => OcptLocationRow(
    id: _string(json, _idKey),
    name: _string(json, _nameKey),
    colorIndex: _int(json, _colorIndexKey),
    addressLine1: _string(json, _addressLine1Key),
    addressLine2: _string(json, _addressLine2Key),
    postalCode: _string(json, _postalCodeKey),
    city: _string(json, _cityKey),
    region: _string(json, _regionKey),
    country: _string(json, _countryKey),
    latitude: _nullableDouble(json, _latitudeKey),
    longitude: _nullableDouble(json, _longitudeKey),
    contactPersonId: _nullableString(json, _contactPersonIdKey),
    contactNotes: _string(json, _contactNotesKey),
    permitStatus: _enum(json, _permitStatusKey, OcptPermitStatus.values.asNameMap()),
    permitLabel: _string(json, _permitLabelKey),
    permitDate: _nullableDateTime(json, _permitDateKey),
    permitAssetId: _nullableString(json, _permitAssetIdKey),
    parkingNotes: _string(json, _parkingNotesKey),
    powerNotes: _string(json, _powerNotesKey),
    facilitiesNotes: _string(json, _facilitiesNotesKey),
    constraintsNotes: _string(json, _constraintsNotesKey),
    notes: _string(json, _notesKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `location_availabilities` row.
  static Map<String, dynamic> _locationAvailabilityToJson(OcptLocationAvailabilityRow row) => {
    _idKey: row.id,
    _locationIdKey: row.locationId,
    _startDateKey: row.startDate.toIso8601String(),
    _endDateKey: row.endDate.toIso8601String(),
    _weekdaysKey: row.weekdays,
    _slotKey: row.slot.name,
    _startMinuteKey: row.startMinute,
    _endMinuteKey: row.endMinute,
    _kindKey: row.kind.name,
    _noteKey: row.note,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `location_availabilities` row.
  static OcptLocationAvailabilityRow _locationAvailabilityFromJson(Map<String, dynamic> json) =>
      OcptLocationAvailabilityRow(
        id: _string(json, _idKey),
        locationId: _string(json, _locationIdKey),
        startDate: _dateTime(json, _startDateKey),
        endDate: _dateTime(json, _endDateKey),
        weekdays: _int(json, _weekdaysKey),
        slot: _enum(json, _slotKey, OcptDayPartSlot.values.asNameMap()),
        startMinute: _nullableInt(json, _startMinuteKey),
        endMinute: _nullableInt(json, _endMinuteKey),
        kind: _enum(json, _kindKey, OcptLocationAvailabilityKind.values.asNameMap()),
        note: _string(json, _noteKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `sets` row.
  static Map<String, dynamic> _setToJson(OcptSetRow row) => {
    _idKey: row.id,
    _locationIdKey: row.locationId,
    _codeKey: row.code,
    _nameKey: row.name,
    _notesKey: row.notes,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `sets` row.
  static OcptSetRow _setFromJson(Map<String, dynamic> json) => OcptSetRow(
    id: _string(json, _idKey),
    locationId: _string(json, _locationIdKey),
    code: _string(json, _codeKey),
    name: _string(json, _nameKey),
    notes: _string(json, _notesKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `scene_sets` row.
  static Map<String, dynamic> _sceneSetToJson(OcptSceneSetRow row) => {
    _idKey: row.id,
    _sceneIdKey: row.sceneId,
    _setIdKey: row.setId,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `scene_sets` row.
  static OcptSceneSetRow _sceneSetFromJson(Map<String, dynamic> json) => OcptSceneSetRow(
    id: _string(json, _idKey),
    sceneId: _string(json, _sceneIdKey),
    setId: _string(json, _setIdKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `elements` row.
  static Map<String, dynamic> _elementToJson(OcptElementRow row) => {
    _idKey: row.id,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _categoryKey: row.category.name,
    _subCategoryKey: row.subCategory,
    _nameKey: row.name,
    _codeKey: row.code,
    _quantityKey: row.quantity,
    _sourceKindKey: row.sourceKind.name,
    _ownerPersonIdKey: row.ownerPersonId,
    _ownerNotesKey: row.ownerNotes,
    _broughtByPersonIdKey: row.broughtByPersonId,
    _storageNotesKey: row.storageNotes,
    _statusKey: row.status.name,
    _isSecuredKey: row.isSecured,
    _isReadyForShootKey: row.isReadyForShoot,
    _isReturnedKey: row.isReturned,
    _costKey: row.cost,
    _purposeNotesKey: row.purposeNotes,
    _notesKey: row.notes,
    _photoAssetIdKey: row.photoAssetId,
  };

  /// Parses one `elements` row.
  static OcptElementRow _elementFromJson(Map<String, dynamic> json) => OcptElementRow(
    id: _string(json, _idKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    category: _enum(json, _categoryKey, OcptElementCategory.values.asNameMap()),
    subCategory: _string(json, _subCategoryKey),
    name: _string(json, _nameKey),
    code: _string(json, _codeKey),
    quantity: _string(json, _quantityKey),
    sourceKind: _enum(json, _sourceKindKey, OcptElementSourceKind.values.asNameMap()),
    ownerPersonId: _nullableString(json, _ownerPersonIdKey),
    ownerNotes: _string(json, _ownerNotesKey),
    broughtByPersonId: _nullableString(json, _broughtByPersonIdKey),
    storageNotes: _string(json, _storageNotesKey),
    status: _enum(json, _statusKey, OcptElementStatus.values.asNameMap()),
    isSecured: _bool(json, _isSecuredKey),
    isReadyForShoot: _bool(json, _isReadyForShootKey),
    isReturned: _bool(json, _isReturnedKey),
    cost: _nullableInt(json, _costKey),
    purposeNotes: _string(json, _purposeNotesKey),
    notes: _string(json, _notesKey),
    photoAssetId: _nullableString(json, _photoAssetIdKey),
  );

  /// Serializes one `scene_elements` row.
  static Map<String, dynamic> _sceneElementToJson(OcptSceneElementRow row) => {
    _idKey: row.id,
    _sceneIdKey: row.sceneId,
    _elementIdKey: row.elementId,
    _quantityKey: row.quantity,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `scene_elements` row.
  static OcptSceneElementRow _sceneElementFromJson(Map<String, dynamic> json) =>
      OcptSceneElementRow(
        id: _string(json, _idKey),
        sceneId: _string(json, _sceneIdKey),
        elementId: _string(json, _elementIdKey),
        quantity: _string(json, _quantityKey),
        notes: _string(json, _notesKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `role_elements` row.
  static Map<String, dynamic> _roleElementToJson(OcptRoleElementRow row) => {
    _idKey: row.id,
    _roleIdKey: row.roleId,
    _elementIdKey: row.elementId,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `role_elements` row.
  static OcptRoleElementRow _roleElementFromJson(Map<String, dynamic> json) => OcptRoleElementRow(
    id: _string(json, _idKey),
    roleId: _string(json, _roleIdKey),
    elementId: _string(json, _elementIdKey),
    notes: _string(json, _notesKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `role_candidates` row.
  static Map<String, dynamic> _roleCandidateToJson(OcptRoleCandidateRow row) => {
    _idKey: row.id,
    _roleIdKey: row.roleId,
    _personIdKey: row.personId,
    _statusKey: row.status.name,
    _auditionedOnKey: row.auditionedOn?.toIso8601String(),
    _notesKey: row.notes,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `role_candidates` row.
  static OcptRoleCandidateRow _roleCandidateFromJson(Map<String, dynamic> json) =>
      OcptRoleCandidateRow(
        id: _string(json, _idKey),
        roleId: _string(json, _roleIdKey),
        personId: _string(json, _personIdKey),
        status: _enum(json, _statusKey, OcptRoleCandidateStatus.values.asNameMap()),
        auditionedOn: _nullableDateTime(json, _auditionedOnKey),
        notes: _string(json, _notesKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `assets` row.
  static Map<String, dynamic> _assetToJson(OcptAssetRow row) => {
    _idKey: row.id,
    _kindKey: row.kind.name,
    _pathKey: row.path,
    _labelKey: row.label,
    _addedAtKey: row.addedAt.toIso8601String(),
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
    _personIdKey: row.personId,
    _locationIdKey: row.locationId,
    _elementIdKey: row.elementId,
    _budgetEntryIdKey: row.budgetEntryId,
    _validFromKey: row.validFrom?.toIso8601String(),
    _validUntilKey: row.validUntil?.toIso8601String(),
  };

  /// Parses one `assets` row.
  static OcptAssetRow _assetFromJson(Map<String, dynamic> json) => OcptAssetRow(
    id: _string(json, _idKey),
    kind: _enum(json, _kindKey, OcptAssetKind.values.asNameMap()),
    path: _string(json, _pathKey),
    label: _string(json, _labelKey),
    addedAt: _dateTime(json, _addedAtKey),
    sortKey: _string(json, _sortKeyKey),
    isDeleted: _bool(json, _isDeletedKey),
    personId: _nullableString(json, _personIdKey),
    locationId: _nullableString(json, _locationIdKey),
    elementId: _nullableString(json, _elementIdKey),
    budgetEntryId: _nullableString(json, _budgetEntryIdKey),
    validFrom: _nullableDateTime(json, _validFromKey),
    validUntil: _nullableDateTime(json, _validUntilKey),
  );

  /// Serializes one `breakdown_tags` row.
  static Map<String, dynamic> _breakdownTagToJson(OcptBreakdownTagRow row) => {
    _idKey: row.id,
    _sceneIdKey: row.sceneId,
    _targetKindKey: row.targetKind.name,
    _elementIdKey: row.elementId,
    _roleIdKey: row.roleId,
    _setIdKey: row.setId,
    _startOffsetKey: row.startOffset,
    _endOffsetKey: row.endOffset,
    _taggedTextKey: row.taggedText,
    _needsCheckKey: row.needsCheck,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `breakdown_tags` row.
  static OcptBreakdownTagRow _breakdownTagFromJson(Map<String, dynamic> json) =>
      OcptBreakdownTagRow(
        id: _string(json, _idKey),
        sceneId: _string(json, _sceneIdKey),
        targetKind: _enum(json, _targetKindKey, OcptBreakdownTargetKind.values.asNameMap()),
        elementId: _nullableString(json, _elementIdKey),
        roleId: _nullableString(json, _roleIdKey),
        setId: _nullableString(json, _setIdKey),
        startOffset: _int(json, _startOffsetKey),
        endOffset: _int(json, _endOffsetKey),
        taggedText: _string(json, _taggedTextKey),
        needsCheck: _bool(json, _needsCheckKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `scene_breakdowns` row.
  static Map<String, dynamic> _sceneBreakdownToJson(OcptSceneBreakdownRow row) => {
    _idKey: row.id,
    _sceneIdKey: row.sceneId,
    _statusKey: row.status.name,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `scene_breakdowns` row.
  static OcptSceneBreakdownRow _sceneBreakdownFromJson(Map<String, dynamic> json) =>
      OcptSceneBreakdownRow(
        id: _string(json, _idKey),
        sceneId: _string(json, _sceneIdKey),
        status: _enum(json, _statusKey, OcptBreakdownSceneStatus.values.asNameMap()),
        notes: _string(json, _notesKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shooting_days` row.
  static Map<String, dynamic> _shootingDayToJson(OcptShootingDayRow row) => {
    _idKey: row.id,
    _dateKey: row.date.toIso8601String(),
    _sortKeyKey: row.sortKey,
    _statusKey: row.status.name,
    _crewNoteKey: row.crewNote,
    _weatherNoteKey: row.weatherNote,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_days` row.
  static OcptShootingDayRow _shootingDayFromJson(Map<String, dynamic> json) => OcptShootingDayRow(
    id: _string(json, _idKey),
    date: _dateTime(json, _dateKey),
    sortKey: _string(json, _sortKeyKey),
    status: _enum(json, _statusKey, OcptShootingDayStatus.values.asNameMap()),
    crewNote: _string(json, _crewNoteKey),
    weatherNote: _string(json, _weatherNoteKey),
    notes: _string(json, _notesKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `shooting_slots` row.
  static Map<String, dynamic> _shootingSlotToJson(OcptShootingSlotRow row) => {
    _idKey: row.id,
    _shootingDayIdKey: row.shootingDayId,
    _sortKeyKey: row.sortKey,
    _labelKey: row.label,
    _locationIdKey: row.locationId,
    _setIdKey: row.setId,
    _anchorEdgeKey: row.anchorEdge.name,
    _anchorMinuteKey: row.anchorMinute,
    _anchorSlotIdKey: row.anchorSlotId,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_slots` row.
  static OcptShootingSlotRow _shootingSlotFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotRow(
        id: _string(json, _idKey),
        shootingDayId: _string(json, _shootingDayIdKey),
        sortKey: _string(json, _sortKeyKey),
        label: _string(json, _labelKey),
        locationId: _nullableString(json, _locationIdKey),
        setId: _nullableString(json, _setIdKey),
        anchorEdge: OcptShootingSlotAnchorEdge.values.byName(_string(json, _anchorEdgeKey)),
        anchorMinute: _nullableInt(json, _anchorMinuteKey),
        anchorSlotId: _nullableString(json, _anchorSlotIdKey),
        notes: _string(json, _notesKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shooting_slot_crew` row.
  static Map<String, dynamic> _shootingSlotCrewToJson(OcptShootingSlotCrewRow row) => {
    _idKey: row.id,
    _slotIdKey: row.slotId,
    _sortKeyKey: row.sortKey,
    _personIdKey: row.personId,
    _positionIdKey: row.positionId,
    _customLabelKey: row.customLabel,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_slot_crew` row.
  static OcptShootingSlotCrewRow _shootingSlotCrewFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotCrewRow(
        id: _string(json, _idKey),
        slotId: _string(json, _slotIdKey),
        sortKey: _string(json, _sortKeyKey),
        personId: _string(json, _personIdKey),
        positionId: _string(json, _positionIdKey),
        customLabel: _string(json, _customLabelKey),
        notes: _string(json, _notesKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shooting_slot_cast` row.
  static Map<String, dynamic> _shootingSlotCastToJson(OcptShootingSlotCastRow row) => {
    _idKey: row.id,
    _slotIdKey: row.slotId,
    _roleIdKey: row.roleId,
    _sortKeyKey: row.sortKey,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_slot_cast` row.
  static OcptShootingSlotCastRow _shootingSlotCastFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotCastRow(
        id: _string(json, _idKey),
        slotId: _string(json, _slotIdKey),
        roleId: _string(json, _roleIdKey),
        sortKey: _string(json, _sortKeyKey),
        notes: _string(json, _notesKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shooting_day_blocks` row.
  static Map<String, dynamic> _shootingDayBlockToJson(OcptShootingDayBlockRow row) => {
    _idKey: row.id,
    _shootingDayIdKey: row.shootingDayId,
    _sortKeyKey: row.sortKey,
    _slotIdKey: row.slotId,
    _kindKey: row.kind.name,
    _shotIdKey: row.shotId,
    _sceneIdKey: row.sceneId,
    _labelKey: row.label,
    _durationMinutesKey: row.durationMinutes,
    _anchorMinuteKey: row.anchorMinute,
    _notesKey: row.notes,
    _crewNoteKey: row.crewNote,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_day_blocks` row.
  static OcptShootingDayBlockRow _shootingDayBlockFromJson(Map<String, dynamic> json) =>
      OcptShootingDayBlockRow(
        id: _string(json, _idKey),
        shootingDayId: _string(json, _shootingDayIdKey),
        sortKey: _string(json, _sortKeyKey),
        slotId: _string(json, _slotIdKey),
        kind: _enum(json, _kindKey, OcptShootingBlockKind.values.asNameMap()),
        shotId: _nullableString(json, _shotIdKey),
        sceneId: _nullableString(json, _sceneIdKey),
        label: _string(json, _labelKey),
        durationMinutes: _nullableInt(json, _durationMinutesKey),
        anchorMinute: _nullableInt(json, _anchorMinuteKey),
        notes: _string(json, _notesKey),
        crewNote: _string(json, _crewNoteKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shooting_block_candidates` row.
  static Map<String, dynamic> _shootingBlockCandidateToJson(OcptShootingBlockCandidateRow row) => {
    _idKey: row.id,
    _blockIdKey: row.blockId,
    _roleCandidateIdKey: row.roleCandidateId,
    _sortKeyKey: row.sortKey,
    _notesKey: row.notes,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_block_candidates` row.
  static OcptShootingBlockCandidateRow _shootingBlockCandidateFromJson(
    Map<String, dynamic> json,
  ) => OcptShootingBlockCandidateRow(
    id: _string(json, _idKey),
    blockId: _string(json, _blockIdKey),
    roleCandidateId: _string(json, _roleCandidateIdKey),
    sortKey: _string(json, _sortKeyKey),
    notes: _string(json, _notesKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `shooting_slot_guests` row.
  static Map<String, dynamic> _shootingSlotGuestToJson(OcptShootingSlotGuestRow row) => {
    _idKey: row.id,
    _slotIdKey: row.slotId,
    _personIdKey: row.personId,
    _freeNameKey: row.freeName,
    _reasonKey: row.reason,
    _notesKey: row.notes,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_slot_guests` row.
  static OcptShootingSlotGuestRow _shootingSlotGuestFromJson(Map<String, dynamic> json) =>
      OcptShootingSlotGuestRow(
        id: _string(json, _idKey),
        slotId: _string(json, _slotIdKey),
        personId: _nullableString(json, _personIdKey),
        freeName: _string(json, _freeNameKey),
        reason: _string(json, _reasonKey),
        notes: _string(json, _notesKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shooting_day_events` row.
  static Map<String, dynamic> _shootingDayEventToJson(OcptShootingDayEventRow row) => {
    _idKey: row.id,
    _shootingDayIdKey: row.shootingDayId,
    _minuteKey: row.minute,
    _labelKey: row.label,
    _notesKey: row.notes,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shooting_day_events` row.
  static OcptShootingDayEventRow _shootingDayEventFromJson(Map<String, dynamic> json) =>
      OcptShootingDayEventRow(
        id: _string(json, _idKey),
        shootingDayId: _string(json, _shootingDayIdKey),
        minute: _int(json, _minuteKey),
        label: _string(json, _labelKey),
        notes: _string(json, _notesKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `row_field_versions` row.
  static Map<String, dynamic> _rowFieldVersionToJson(OcptRowFieldVersionRow row) => {
    _tableNameKey: row.targetTableName,
    _rowIdKey: row.rowId,
    _columnNameKey: row.columnName,
    _versionKey: row.version,
    _deviceIdKey: row.deviceId,
  };

  /// Parses one `row_field_versions` row.
  static OcptRowFieldVersionRow _rowFieldVersionFromJson(Map<String, dynamic> json) =>
      OcptRowFieldVersionRow(
        targetTableName: _string(json, _tableNameKey),
        rowId: _string(json, _rowIdKey),
        columnName: _string(json, _columnNameKey),
        version: _int(json, _versionKey),
        deviceId: _string(json, _deviceIdKey),
      );

  /// The list of JSON objects stored at [key] in [json].
  static List<Map<String, dynamic>> _rows(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw _OcptPayloadFormatError("'$key' isn't a list");
    }

    return [
      for (final element in value)
        if (element is Map<String, dynamic>)
          element
        else
          throw _OcptPayloadFormatError("an element of '$key' isn't a JSON object"),
    ];
  }

  /// The JSON object stored at [key] in [json].
  static Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw _OcptPayloadFormatError("'$key' isn't a JSON object");
    }

    return value;
  }

  /// The non-null string stored at [key] in [json].
  static String _string(Map<String, dynamic> json, String key) =>
      _nullableString(json, key) ?? (throw _OcptPayloadFormatError("'$key' is missing"));

  /// The string stored at [key] in [json], or null when the column it mirrors was null.
  static String? _nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw _OcptPayloadFormatError("'$key' isn't a string");
    }

    return value;
  }

  /// The non-null integer stored at [key] in [json].
  static int _int(Map<String, dynamic> json, String key) =>
      _nullableInt(json, key) ?? (throw _OcptPayloadFormatError("'$key' is missing"));

  /// The integer stored at [key] in [json], or null when the column it mirrors was null.
  static int? _nullableInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! int) {
      throw _OcptPayloadFormatError("'$key' isn't an integer");
    }

    return value;
  }

  /// The non-null boolean stored at [key] in [json].
  static bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw _OcptPayloadFormatError("'$key' isn't a boolean");
    }

    return value;
  }

  /// The boolean stored at [key] in [json], or null when the column it mirrors was null — the
  /// tri-state `people.isTransportAutonomous` is the one column of the schema that needs this.
  static bool? _nullableBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! bool) {
      throw _OcptPayloadFormatError("'$key' isn't a boolean");
    }

    return value;
  }

  /// The non-null number stored at [key] in [json], as a double.
  ///
  /// A whole margin written as `1` by an older build (or by a hand-edited file) reads back as an
  /// `int`, so this accepts any [num] rather than only what `jsonEncode` writes for a double.
  static double _double(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw _OcptPayloadFormatError("'$key' isn't a number");
    }

    return value.toDouble();
  }

  /// The number stored at [key] in [json], as a double, or null when the column it mirrors was
  /// null — `locations.latitude`/`longitude` before a location has been pinned on a map.
  static double? _nullableDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! num) {
      throw _OcptPayloadFormatError("'$key' isn't a number");
    }

    return value.toDouble();
  }

  /// The non-null date and time stored at [key] in [json], as an ISO 8601 string.
  static DateTime _dateTime(Map<String, dynamic> json, String key) =>
      DateTime.tryParse(_string(json, key)) ??
      (throw _OcptPayloadFormatError("'$key' isn't an ISO 8601 date"));

  /// The date and time stored at [key] in [json], as an ISO 8601 string, or null when the column
  /// it mirrors was null.
  static DateTime? _nullableDateTime(Map<String, dynamic> json, String key) {
    final value = _nullableString(json, key);
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value) ??
        (throw _OcptPayloadFormatError("'$key' isn't an ISO 8601 date"));
  }

  /// The non-null enum value stored at [key] in [json], looked up by name in [valuesByName].
  static T _enum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    Map<String, T> valuesByName,
  ) =>
      _nullableEnum(json, key, valuesByName) ??
      (throw _OcptPayloadFormatError("'$key' is missing"));

  /// The enum value stored at [key] in [json], or null when the column it mirrors was null.
  static T? _nullableEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    Map<String, T> valuesByName,
  ) {
    final name = _nullableString(json, key);
    if (name == null) {
      return null;
    }

    return valuesByName[name] ??
        (throw _OcptPayloadFormatError(
          "'$key' holds the unknown value "
          "'$name'",
        ));
  }
}

/// Thrown, and caught, inside [OcptProjectVersionCodec] alone: a payload field is missing or holds
/// something other than what the format says it holds.
///
/// This never escapes [OcptProjectVersionCodec.decode], which turns it into
/// [OcptProjectVersionPayloadStatus.malformedPayload]: it exists only so the dozens of field reads
/// building a payload can stay expressions instead of each checking a result.
class _OcptPayloadFormatError implements Exception {
  /// What was wrong with the payload, for the log.
  final String reason;

  /// Class constructor
  const _OcptPayloadFormatError(this.reason);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "_OcptPayloadFormatError($reason)";
}
