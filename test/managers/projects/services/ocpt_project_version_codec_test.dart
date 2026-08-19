// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

void main() {
  // The codec logs through appLogger(), which requires a global manager instance to be set; merely
  // accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec();

  /// A payload covering everything the format has to survive: a live row and a tombstoned one in
  /// every table, both nullable and non-null columns, both enum columns, the fractional sort keys,
  /// and the version stamps of the rows it carries.
  ///
  /// The second row of each table leaves every nullable column at its null default — a scene with
  /// no number, an orphaned shot with no scene, no duration, no shooting day, no planned takes and
  /// no check reason — so the round trip is exercised on null values as well as on set ones.
  OcptProjectVersionPayload buildRichPayload() => OcptProjectVersionPayload(
    screenplays: [
      OcptScreenplayRow(
        id: "screenplay-1",
        title: "My Movie",
        fountainText: "INT. HOUSE - DAY\n\nCLARA enters.",
        updatedAt: DateTime.utc(2026, 3, 4, 15, 42, 12, 345),
        number: 1,
        sortKey: "V",
        isDeleted: false,
      ),
      OcptScreenplayRow(
        id: "screenplay-2",
        title: "Abandoned draft",
        fountainText: "",
        updatedAt: DateTime.utc(2026, 2, 2),
        number: 2,
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    scenes: const [
      OcptSceneRow(
        id: "scene-1",
        screenplayId: "screenplay-1",
        position: 0,
        heading: "INT. HOUSE - DAY",
        sceneNumber: "4A",
        charStart: 0,
        charEnd: 18,
        isDeleted: false,
      ),
      OcptSceneRow(
        id: "scene-2",
        screenplayId: "screenplay-1",
        position: 1,
        heading: "EXT. STREET - NIGHT",
        charStart: 18,
        charEnd: 40,
        isDeleted: true,
      ),
    ],
    shots: const [
      OcptShotRow(
        id: "shot-1",
        screenplayId: "screenplay-1",
        sceneId: "scene-1",
        position: 0,
        sortKey: "V",
        shotSize: "Wide",
        abbreviation: "WS",
        framing: "Low angle",
        cameraMove: "Dolly in",
        lens: "35mm",
        recordingFormat: "4K · 25 fps",
        estimatedDurationMs: 12500,
        shootingDay: "Day 3",
        plannedTakes: 4,
        sound: "Direct",
        status: OcptShotStatus.shot,
        difficultySet: 2,
        difficultyCamera: 4,
        difficultyActing: 1,
        difficultySound: 3,
        notes: "Hold on CLARA's hands.",
        locationNotes: "Kitchen, north window",
        needsCheck: true,
        checkReason: OcptShotCheckReason.coveredTextChanged,
        isDeleted: false,
      ),
      OcptShotRow(
        id: "shot-2",
        screenplayId: "screenplay-1",
        orphanedHeading: "EXT. STREET - NIGHT",
        position: 1,
        sortKey: "k",
        shotSize: "",
        abbreviation: "",
        framing: "",
        cameraMove: "",
        lens: "",
        recordingFormat: "",
        sound: "",
        status: OcptShotStatus.toShoot,
        difficultySet: 1,
        difficultyCamera: 1,
        difficultyActing: 1,
        difficultySound: 1,
        notes: "",
        locationNotes: "",
        needsCheck: false,
        isDeleted: true,
      ),
    ],
    shotCharacters: const [
      OcptShotCharacterRow(
        shotId: "shot-1",
        characterName: "CLARA",
        position: 0,
        sortKey: "V",
        isDeleted: false,
      ),
      OcptShotCharacterRow(
        shotId: "shot-1",
        characterName: "THÉO",
        position: 1,
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    shotCoverages: const [
      OcptShotCoverageRow(
        id: "coverage-1",
        shotId: "shot-1",
        sceneId: "scene-1",
        startOffset: 0,
        endOffset: 12,
        coveredTextDigest: "digest-1",
        isDeleted: false,
      ),
      OcptShotCoverageRow(
        id: "coverage-2",
        shotId: "shot-1",
        sceneId: "scene-2",
        startOffset: 3,
        endOffset: 9,
        coveredTextDigest: "digest-2",
        isDeleted: true,
      ),
    ],
    people: [
      const OcptPersonRow(
        id: "person-1",
        sortKey: "V",
        isDeleted: false,
        firstName: "Clara",
        lastName: "Martin",
        email: "clara@example.com",
        phone: "0102030405",
        addressLine1: "12 rue des Lilas",
        addressLine2: "Bâtiment B",
        postalCode: "75011",
        city: "Paris",
        region: "Île-de-France",
        country: "France",
        colorIndex: 2,
        minorNotes: "",
        maxDailyPresenceMinutes: 480,
        isTransportAutonomous: true,
        accommodationNotes: "Chez Camille",
        travelNotes: "Carte jeune SNCF",
        dietaryNotes: "Vegetarian",
        allergies: "Peanuts",
        measurementHeight: "168",
        measurementChest: "88",
        measurementWaist: "68",
        measurementHips: "94",
        sizeTop: "38",
        sizeBottom: "M",
        sizeShoes: "39",
        hmcNotes: "Redhead wig",
        imageRightsStatus: OcptImageRightsStatus.signed,
        imageRightsAssetId: "asset-1",
        photoAssetId: "asset-2",
        notes: "Lead actress",
      ),
      OcptPersonRow(
        id: "person-2",
        sortKey: "k",
        isDeleted: true,
        firstName: "",
        lastName: "",
        email: "",
        phone: "",
        addressLine1: "",
        addressLine2: "",
        postalCode: "",
        city: "",
        region: "",
        country: "",
        colorIndex: 0,
        birthDate: DateTime.utc(1990, 5, 12),
        minorNotes: "",
        accommodationNotes: "",
        travelNotes: "",
        dietaryNotes: "",
        allergies: "",
        measurementHeight: "",
        measurementChest: "",
        measurementWaist: "",
        measurementHips: "",
        sizeTop: "",
        sizeBottom: "",
        sizeShoes: "",
        hmcNotes: "",
        imageRightsStatus: OcptImageRightsStatus.notApplicable,
        imageRightsDate: DateTime.utc(2026, 1, 10),
        notes: "",
      ),
    ],
    personPositions: const [
      OcptPersonPositionRow(
        id: "position-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptPersonPositionRow(
        id: "position-2",
        personId: "person-1",
        positionId: "",
        customLabel: "Régie",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    personSkills: const [
      OcptPersonSkillRow(
        id: "skill-1",
        personId: "person-1",
        label: "Permis B",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptPersonSkillRow(id: "skill-2", personId: "person-1", label: "", sortKey: "k", isDeleted: true),
    ],
    personUnavailabilities: [
      OcptPersonUnavailabilityRow(
        id: "unavailability-1",
        personId: "person-1",
        startDate: DateTime.utc(2026, 3),
        endDate: DateTime.utc(2026, 3, 5),
        slot: OcptDayPartSlot.custom,
        startMinute: 14 * 60,
        endMinute: 17 * 60 + 30,
        reason: "Wedding",
        isDeleted: false,
      ),
      OcptPersonUnavailabilityRow(
        id: "unavailability-2",
        personId: "person-1",
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 2),
        slot: OcptDayPartSlot.fullDay,
        reason: "",
        isDeleted: true,
      ),
    ],
    roles: const [
      OcptRoleRow(
        id: "role-1",
        name: "CLARA",
        sortKey: "V",
        isDeleted: false,
        personId: "person-1",
        kind: OcptRoleKind.speaking,
        isFromScreenplay: true,
        castingNotes: "Confirmed",
      ),
      OcptRoleRow(
        id: "role-2",
        name: "EXTRA",
        sortKey: "k",
        isDeleted: true,
        kind: OcptRoleKind.extra,
        isFromScreenplay: false,
        orphanedName: "GHOST",
        castingNotes: "",
      ),
    ],
    roleEpisodes: const [
      OcptRoleEpisodeRow(
        id: "role-episode-1",
        roleId: "role-1",
        screenplayId: "screenplay-1",
        isDeleted: false,
      ),
      OcptRoleEpisodeRow(
        id: "role-episode-2",
        roleId: "role-2",
        screenplayId: "screenplay-1",
        isDeleted: true,
      ),
    ],
    locations: [
      const OcptLocationRow(
        id: "location-1",
        name: "Maison des Pains",
        colorIndex: 1,
        addressLine1: "3 rue Victor Hugo",
        addressLine2: "",
        postalCode: "69002",
        city: "Lyon",
        region: "Auvergne-Rhône-Alpes",
        country: "France",
        latitude: 45.75,
        longitude: 4.85,
        contactPersonId: "person-1",
        contactNotes: "Call after 6pm",
        permitStatus: OcptPermitStatus.granted,
        permitLabel: "AUT-2026-01",
        permitAssetId: "asset-1",
        parkingNotes: "Street parking",
        powerNotes: "16A available",
        facilitiesNotes: "Toilet inside",
        constraintsNotes: "No noise after 10pm",
        notes: "Owner lives nearby",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptLocationRow(
        id: "location-2",
        name: "",
        colorIndex: 0,
        addressLine1: "",
        addressLine2: "",
        postalCode: "",
        city: "",
        region: "",
        country: "",
        contactNotes: "",
        permitStatus: OcptPermitStatus.toRequest,
        permitLabel: "",
        permitDate: DateTime.utc(2026, 2),
        parkingNotes: "",
        powerNotes: "",
        facilitiesNotes: "",
        constraintsNotes: "",
        notes: "",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    locationAvailabilities: [
      OcptLocationAvailabilityRow(
        id: "availability-1",
        locationId: "location-1",
        startDate: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 20),
        weekdays: 0x03,
        slot: OcptDayPartSlot.custom,
        startMinute: 8 * 60,
        endMinute: 19 * 60,
        kind: OcptLocationAvailabilityKind.conditional,
        note: "No noise after 22:00",
        isDeleted: false,
      ),
      OcptLocationAvailabilityRow(
        id: "availability-2",
        locationId: "location-2",
        startDate: DateTime.utc(2026, 4, 5),
        endDate: DateTime.utc(2026, 4, 5),
        weekdays: ocptEveryWeekdayMask,
        slot: OcptDayPartSlot.fullDay,
        kind: OcptLocationAvailabilityKind.available,
        note: "",
        isDeleted: true,
      ),
    ],
    sets: const [
      OcptSetRow(
        id: "set-1",
        locationId: "location-1",
        code: "A",
        name: "Cuisine",
        notes: "Bright morning light",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptSetRow(
        id: "set-2",
        locationId: "location-1",
        code: "",
        name: "Escalier",
        notes: "",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    sceneSets: const [
      OcptSceneSetRow(id: "scene-set-1", sceneId: "scene-1", setId: "set-1", isDeleted: false),
      OcptSceneSetRow(id: "scene-set-2", sceneId: "scene-2", setId: "set-1", isDeleted: true),
    ],
    elements: const [
      OcptElementRow(
        id: "element-1",
        sortKey: "V",
        isDeleted: false,
        category: OcptElementCategory.prop,
        subCategory: "Kitchenware",
        name: "Ceramic mug",
        code: "MUG1",
        quantity: "×2",
        sourceKind: OcptElementSourceKind.owned,
        ownerPersonId: "person-1",
        ownerNotes: "M. et Mme Schmit",
        broughtByPersonId: "person-1",
        storageNotes: "Sous l'abri",
        status: OcptElementStatus.confirmed,
        isSecured: true,
        isReadyForShoot: true,
        isReturned: false,
        cost: 1200,
        purposeNotes: "Breakfast scene",
        notes: "Handle with care",
        photoAssetId: "asset-1",
      ),
      OcptElementRow(
        id: "element-2",
        sortKey: "k",
        isDeleted: true,
        category: OcptElementCategory.other,
        subCategory: "",
        name: "",
        code: "",
        quantity: "",
        sourceKind: OcptElementSourceKind.toBuy,
        ownerNotes: "",
        storageNotes: "",
        status: OcptElementStatus.toFind,
        isSecured: false,
        isReadyForShoot: false,
        isReturned: false,
        purposeNotes: "",
        notes: "",
      ),
    ],
    sceneElements: const [
      OcptSceneElementRow(
        id: "scene-element-1",
        sceneId: "scene-1",
        elementId: "element-1",
        quantity: "1",
        notes: "On the table",
        isDeleted: false,
      ),
      OcptSceneElementRow(
        id: "scene-element-2",
        sceneId: "scene-2",
        elementId: "element-1",
        quantity: "",
        notes: "",
        isDeleted: true,
      ),
    ],
    roleElements: const [
      OcptRoleElementRow(
        id: "role-element-1",
        roleId: "role-1",
        elementId: "element-1",
        notes: "Torn from scene 12 on",
        isDeleted: false,
      ),
      OcptRoleElementRow(
        id: "role-element-2",
        roleId: "role-1",
        elementId: "element-1",
        notes: "",
        isDeleted: true,
      ),
    ],
    assets: [
      OcptAssetRow(
        id: "asset-1",
        kind: OcptAssetKind.document,
        path: "/home/user/Documents/release-clara.pdf",
        label: "Signed release",
        addedAt: DateTime.utc(2026, 1, 10, 9),
        sortKey: "V",
        isDeleted: false,
        personId: "person-1",
        validFrom: DateTime.utc(2026, 1, 10),
        validUntil: DateTime.utc(2027, 1, 10),
      ),
      OcptAssetRow(
        id: "asset-2",
        kind: OcptAssetKind.personPhoto,
        path: "",
        label: "",
        addedAt: DateTime.utc(2026),
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    breakdownTags: const [
      OcptBreakdownTagRow(
        id: "breakdown-tag-1",
        sceneId: "scene-1",
        targetKind: OcptBreakdownTargetKind.element,
        elementId: "element-1",
        startOffset: 0,
        endOffset: 4,
        taggedText: "desk",
        needsCheck: false,
        isDeleted: false,
      ),
      OcptBreakdownTagRow(
        id: "breakdown-tag-2",
        sceneId: "scene-1",
        targetKind: OcptBreakdownTargetKind.role,
        roleId: "role-1",
        startOffset: 10,
        endOffset: 13,
        taggedText: "LÉA",
        needsCheck: true,
        isDeleted: false,
      ),
      OcptBreakdownTagRow(
        id: "breakdown-tag-3",
        sceneId: "scene-2",
        targetKind: OcptBreakdownTargetKind.set,
        setId: "set-1",
        startOffset: 2,
        endOffset: 9,
        taggedText: "kitchen",
        needsCheck: false,
        isDeleted: true,
      ),
    ],
    sceneBreakdowns: const [
      OcptSceneBreakdownRow(
        id: "scene-breakdown-1",
        sceneId: "scene-1",
        status: OcptBreakdownSceneStatus.inProgress,
        notes: "Check the lamp cable colour",
        isDeleted: false,
      ),
      OcptSceneBreakdownRow(
        id: "scene-breakdown-2",
        sceneId: "scene-2",
        status: OcptBreakdownSceneStatus.done,
        notes: "",
        isDeleted: true,
      ),
    ],
    shootingDays: [
      OcptShootingDayRow(
        id: "day-1",
        date: DateTime.utc(2026, 3, 10),
        sortKey: "V",
        status: OcptShootingDayStatus.planned,
        crewNote: "Arrive at the north gate",
        weatherNote: "Sunny, light wind",
        notes: "Backup interior booked in case of rain",
        isDeleted: false,
      ),
      OcptShootingDayRow(
        id: "day-2",
        date: DateTime.utc(2026, 3, 11),
        sortKey: "k",
        status: OcptShootingDayStatus.cancelled,
        crewNote: "",
        weatherNote: "",
        notes: "",
        isDeleted: true,
      ),
    ],
    shootingSlots: const [
      OcptShootingSlotRow(
        id: "slot-1",
        shootingDayId: "day-1",
        sortKey: "V",
        label: "Matin",
        locationId: "location-1",
        setId: "set-1",
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorMinute: 420,
        notes: "Check the generator before crew call",
        isDeleted: false,
      ),
      OcptShootingSlotRow(
        id: "slot-2",
        // A night slot running past midnight: its anchor minute exceeds 1440, never taken modulo
        // anything — see ocpt_shooting_slots_table.dart. It is pinned by its **end** and reads
        // nothing off another slot, the other half of the discriminator being exercised by
        // "slot-3" below.
        shootingDayId: "day-1",
        sortKey: "k",
        label: "",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 1620,
        notes: "",
        isDeleted: true,
      ),
      OcptShootingSlotRow(
        id: "slot-3",
        // The linked half of the anchor discriminator: no typed minute at all, its start read off
        // slot-1's own end.
        shootingDayId: "day-1",
        sortKey: "p",
        label: "Soir",
        anchorEdge: OcptShootingSlotAnchorEdge.start,
        anchorSlotId: "slot-1",
        notes: "",
        isDeleted: false,
      ),
    ],
    shootingSlotCrew: const [
      OcptShootingSlotCrewRow(
        id: "crew-1",
        slotId: "slot-1",
        sortKey: "V",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        notes: "Called ahead of the rest of the crew",
        isDeleted: false,
      ),
      OcptShootingSlotCrewRow(
        id: "crew-2",
        slotId: "slot-1",
        sortKey: "k",
        personId: "person-1",
        positionId: "",
        customLabel: "Régie",
        notes: "",
        isDeleted: true,
      ),
    ],
    shootingSlotCast: const [
      OcptShootingSlotCastRow(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        sortKey: "V",
        notes: "Hair and make-up before PAT",
        isDeleted: false,
      ),
      OcptShootingSlotCastRow(
        id: "cast-2",
        slotId: "slot-1",
        roleId: "role-2",
        sortKey: "k",
        notes: "",
        isDeleted: true,
      ),
    ],
    shootingDayBlocks: const [
      OcptShootingDayBlockRow(
        id: "block-1",
        shootingDayId: "day-1",
        sortKey: "V",
        slotId: "slot-1",
        kind: OcptShootingBlockKind.shot,
        shotId: "shot-1",
        label: "",
        notes: "First shot of the day",
        crewNote: "Silence, take in progress",
        isDeleted: false,
      ),
      OcptShootingDayBlockRow(
        id: "block-2",
        shootingDayId: "day-1",
        sortKey: "k",
        slotId: "slot-2",
        kind: OcptShootingBlockKind.hold,
        sceneId: "scene-1",
        label: "Seq. 6 not shot-listed yet",
        durationMinutes: 30,
        anchorMinute: 600,
        notes: "",
        crewNote: "",
        isDeleted: true,
      ),
    ],
    shootingSlotGuests: const [
      OcptShootingSlotGuestRow(
        id: "guest-1",
        slotId: "slot-1",
        personId: "person-1",
        freeName: "",
        reason: "Maire, prête la place",
        notes: "",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptShootingSlotGuestRow(
        id: "guest-2",
        slotId: "slot-1",
        freeName: "Le maire",
        reason: "",
        notes: "",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    shootingDayEvents: const [
      OcptShootingDayEventRow(
        id: "event-1",
        shootingDayId: "day-1",
        minute: 1020,
        label: "Feu d'artifice du village",
        notes: "",
        sortKey: "V",
        isDeleted: false,
      ),
      OcptShootingDayEventRow(
        id: "event-2",
        shootingDayId: "day-1",
        minute: 300,
        label: "",
        notes: "",
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    rowFieldVersions: const [
      OcptRowFieldVersionRow(
        targetTableName: "shots",
        rowId: "shot-1",
        columnName: "framing",
        version: 7,
        deviceId: "device-1",
      ),
      OcptRowFieldVersionRow(
        targetTableName: "shot_characters",
        rowId: "shot-1/THÉO",
        columnName: "isDeleted",
        version: 2,
        deviceId: "device-2",
      ),
    ],
    pageSetup: const OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 0.75,
        bottomInches: 1.25,
      ),
    ),
    settingsJson: '{"someSetting":true}',
    currencyCode: "GBP",
    minimumRestMinutes: 660,
    screenplayLanguage: OcptScreenplayLanguage.fr,
  );

  /// [buildRichPayload] serialized and read back.
  OcptProjectVersionPayload roundTrip(OcptProjectVersionPayload payload) {
    final result = codec.decode(codec.encode(payload));

    expect(result.status, OcptProjectVersionPayloadStatus.ok);
    return result.value!;
  }

  /// [encoded] — the current (format 13) encoding of a payload — put back into the shape a format
  /// **12** payload actually had: `roles.screenplayId` and `shooting_days.screenplayId` restored
  /// (read off [roleEpisodes]'s own links for a role, and hard-coded to the one screenplay every
  /// shooting day of [buildRichPayload] belongs to, since format 12 carried nothing else to read
  /// one off), `screenplays.number`/`sortKey` and `roleEpisodes` itself taken back out.
  ///
  /// Every fixture below format 13 in this file is [encoded] wound back further still, so each one
  /// starts from this shape rather than from the current one directly — otherwise
  /// [_upgradeFormat12To13] would run against a `roles` row that already lacks the very
  /// `screenplayId` it means to derive `role_episodes` from, which no real payload of any format
  /// below 13 was ever missing.
  Map<String, dynamic> asFormat12Shape(Map<String, dynamic> encoded) {
    final screenplayIdByRoleId = {
      for (final row in encoded["roleEpisodes"] as List)
        (row as Map<String, dynamic>)["roleId"] as String: row["screenplayId"],
    };

    final downgraded = {...encoded}..remove("roleEpisodes");

    downgraded["screenplays"] = [
      for (final screenplay in downgraded["screenplays"] as List)
        ({...screenplay as Map<String, dynamic>}
          ..remove("number")
          ..remove("sortKey")),
    ];
    downgraded["roles"] = [
      for (final role in downgraded["roles"] as List)
        {
          ...role as Map<String, dynamic>,
          "screenplayId": screenplayIdByRoleId[role["id"]] ?? "screenplay-1",
        },
    ];
    downgraded["shootingDays"] = [
      for (final day in downgraded["shootingDays"] as List)
        {...day as Map<String, dynamic>, "screenplayId": "screenplay-1"},
    ];

    return downgraded;
  }

  group('OcptProjectVersionCodec round trip', () {
    test('decode(encode(payload)) returns an equal payload', () {
      final payload = buildRichPayload();

      expect(roundTrip(payload), payload);
    });

    test('tombstones, sort keys and version stamps all survive', () {
      final roundTripped = roundTrip(buildRichPayload());

      // Tombstones are rows: a payload that dropped them would resurrect, on restore, everything
      // the user had deleted since.
      expect(roundTripped.screenplays.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.scenes.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shots.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shotCharacters.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shotCoverages.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.people.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.personPositions.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.personSkills.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.personUnavailabilities.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.roles.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.roleEpisodes.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.locations.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sceneSets.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.elements.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.sceneElements.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.assets.map((row) => row.isDeleted), [false, true]);

      // sortKey, not position, is what orders a group after ADR 0010.
      expect(roundTripped.shots.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.shotCharacters.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.people.map((row) => row.sortKey), ["V", "k"]);

      // The per-column stamps travel with the rows they describe: this is the assertion that
      // catches a codec silently dropping the sidecar.
      expect(roundTripped.rowFieldVersions, hasLength(2));
      expect(roundTripped.rowFieldVersions.first.targetTableName, "shots");
      expect(roundTripped.rowFieldVersions.first.version, 7);
      expect(roundTripped.rowFieldVersions.last.rowId, "shot-1/THÉO");
      expect(roundTripped.rowFieldVersions.last.deviceId, "device-2");
    });

    test('every column of the eleven resource tables round trips, enums and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final person = roundTripped.people.first;
      expect(person.firstName, "Clara");
      // The six address columns travel one by one: a payload that kept only the street would lose
      // the postcode a call sheet prints and the country an export gives a column of its own.
      expect(person.addressLine1, "12 rue des Lilas");
      expect(person.addressLine2, "Bâtiment B");
      expect(person.postalCode, "75011");
      expect(person.city, "Paris");
      expect(person.region, "Île-de-France");
      expect(person.country, "France");
      expect(person.colorIndex, 2);
      expect(person.birthDate, isNull);
      expect(person.maxDailyPresenceMinutes, 480);
      expect(person.isTransportAutonomous, isTrue);
      expect(person.imageRightsStatus, OcptImageRightsStatus.signed);
      expect(person.imageRightsAssetId, "asset-1");
      final erasedPerson = roundTripped.people.last;
      expect(erasedPerson.birthDate, DateTime.utc(1990, 5, 12));
      expect(erasedPerson.maxDailyPresenceMinutes, isNull);
      expect(erasedPerson.isTransportAutonomous, isNull);
      expect(erasedPerson.imageRightsStatus, OcptImageRightsStatus.notApplicable);

      final position = roundTripped.personPositions.first;
      expect(position.personId, "person-1");
      expect(position.positionId, "director");

      final skill = roundTripped.personSkills.first;
      expect(skill.label, "Permis B");

      final unavailability = roundTripped.personUnavailabilities.first;
      expect(unavailability.startDate, DateTime.utc(2026, 3));
      expect(unavailability.endDate, DateTime.utc(2026, 3, 5));
      expect(unavailability.slot, OcptDayPartSlot.custom);
      expect(unavailability.startMinute, 14 * 60);
      expect(unavailability.endMinute, 17 * 60 + 30);
      // The window of the second row is null, not zero: only a custom slot carries one.
      expect(roundTripped.personUnavailabilities.last.startMinute, isNull);
      expect(unavailability.reason, "Wedding");

      final role = roundTripped.roles.first;
      expect(role.personId, "person-1");
      expect(role.kind, OcptRoleKind.speaking);
      expect(role.isFromScreenplay, isTrue);
      expect(role.orphanedName, isNull);
      final orphanedRole = roundTripped.roles.last;
      expect(orphanedRole.personId, isNull);
      expect(orphanedRole.kind, OcptRoleKind.extra);
      expect(orphanedRole.orphanedName, "GHOST");

      final screenplay = roundTripped.screenplays.first;
      expect(screenplay.number, 1);
      expect(screenplay.sortKey, "V");
      final tombstonedScreenplay = roundTripped.screenplays.last;
      expect(tombstonedScreenplay.number, 2);
      expect(tombstonedScreenplay.sortKey, "k");

      final roleEpisode = roundTripped.roleEpisodes.first;
      expect(roleEpisode.roleId, "role-1");
      expect(roleEpisode.screenplayId, "screenplay-1");
      expect(roleEpisode.isDeleted, isFalse);
      final tombstonedRoleEpisode = roundTripped.roleEpisodes.last;
      expect(tombstonedRoleEpisode.roleId, "role-2");
      expect(tombstonedRoleEpisode.isDeleted, isTrue);

      final location = roundTripped.locations.first;
      expect(location.addressLine1, "3 rue Victor Hugo");
      expect(location.postalCode, "69002");
      expect(location.region, "Auvergne-Rhône-Alpes");
      expect(location.country, "France");
      expect(location.latitude, 45.75);
      expect(location.longitude, 4.85);
      expect(location.contactPersonId, "person-1");
      expect(location.permitStatus, OcptPermitStatus.granted);
      final unpinnedLocation = roundTripped.locations.last;
      expect(unpinnedLocation.latitude, isNull);
      expect(unpinnedLocation.longitude, isNull);
      expect(unpinnedLocation.permitDate, DateTime.utc(2026, 2));

      final set = roundTripped.sets.first;
      expect(set.locationId, "location-1");
      expect(set.code, "A");

      final sceneSet = roundTripped.sceneSets.first;
      expect(sceneSet.sceneId, "scene-1");
      expect(sceneSet.setId, "set-1");

      final element = roundTripped.elements.first;
      expect(element.category, OcptElementCategory.prop);
      expect(element.sourceKind, OcptElementSourceKind.owned);
      expect(element.ownerPersonId, "person-1");
      expect(element.broughtByPersonId, "person-1");
      expect(element.isSecured, isTrue);
      expect(element.cost, 1200);
      expect(element.status, OcptElementStatus.confirmed);
      final freeElement = roundTripped.elements.last;
      expect(freeElement.ownerPersonId, isNull);
      expect(freeElement.cost, isNull);
      expect(freeElement.status, OcptElementStatus.toFind);

      final sceneElement = roundTripped.sceneElements.first;
      expect(sceneElement.elementId, "element-1");
      expect(sceneElement.quantity, "1");

      final asset = roundTripped.assets.first;
      expect(asset.kind, OcptAssetKind.document);
      expect(asset.path, "/home/user/Documents/release-clara.pdf");
      expect(asset.addedAt, DateTime.utc(2026, 1, 10, 9));
      expect(asset.personId, "person-1");
    });

    test('every column of the two breakdown tables round trips, enums and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      // The three targetKind values, each pointing at exactly one of elementId/roleId/setId and
      // leaving the other two null — a codec that forgot one of the three columns would silently
      // lose the tags of that whole kind on a restore.
      final elementTag = roundTripped.breakdownTags.firstWhere((tag) => tag.id == "breakdown-tag-1");
      expect(elementTag.targetKind, OcptBreakdownTargetKind.element);
      expect(elementTag.elementId, "element-1");
      expect(elementTag.roleId, isNull);
      expect(elementTag.setId, isNull);
      expect(elementTag.taggedText, "desk");
      expect(elementTag.startOffset, 0);
      expect(elementTag.endOffset, 4);
      expect(elementTag.needsCheck, isFalse);
      expect(elementTag.isDeleted, isFalse);

      final roleTag = roundTripped.breakdownTags.firstWhere((tag) => tag.id == "breakdown-tag-2");
      expect(roleTag.targetKind, OcptBreakdownTargetKind.role);
      expect(roleTag.elementId, isNull);
      expect(roleTag.roleId, "role-1");
      expect(roleTag.setId, isNull);
      expect(roleTag.needsCheck, isTrue);

      final setTag = roundTripped.breakdownTags.firstWhere((tag) => tag.id == "breakdown-tag-3");
      expect(setTag.targetKind, OcptBreakdownTargetKind.set);
      expect(setTag.elementId, isNull);
      expect(setTag.roleId, isNull);
      expect(setTag.setId, "set-1");
      // The tombstone is a row like any other: a payload holding only live tags would resurrect,
      // on restore, every tag the user had removed since.
      expect(setTag.isDeleted, isTrue);

      final inProgressScene = roundTripped.sceneBreakdowns.firstWhere(
        (row) => row.id == "scene-breakdown-1",
      );
      expect(inProgressScene.status, OcptBreakdownSceneStatus.inProgress);
      expect(inProgressScene.notes, "Check the lamp cable colour");
      expect(inProgressScene.isDeleted, isFalse);

      final doneScene = roundTripped.sceneBreakdowns.firstWhere(
        (row) => row.id == "scene-breakdown-2",
      );
      expect(doneScene.status, OcptBreakdownSceneStatus.done);
      expect(doneScene.notes, "");
      expect(doneScene.isDeleted, isTrue);
    });

    test('every column of the schedule tables round trips, enums and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final day = roundTripped.shootingDays.firstWhere((row) => row.id == "day-1");
      expect(day.date, DateTime.utc(2026, 3, 10));
      expect(day.sortKey, "V");
      expect(day.status, OcptShootingDayStatus.planned);
      expect(day.crewNote, "Arrive at the north gate");
      expect(day.weatherNote, "Sunny, light wind");
      expect(day.notes, "Backup interior booked in case of rain");
      expect(day.isDeleted, isFalse);
      final cancelledDay = roundTripped.shootingDays.firstWhere((row) => row.id == "day-2");
      expect(cancelledDay.status, OcptShootingDayStatus.cancelled);
      expect(cancelledDay.isDeleted, isTrue);

      final slot = roundTripped.shootingSlots.firstWhere((row) => row.id == "slot-1");
      expect(slot.shootingDayId, "day-1");
      expect(slot.label, "Matin");
      expect(slot.locationId, "location-1");
      expect(slot.setId, "set-1");
      expect(slot.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slot.anchorMinute, 420);
      expect(slot.anchorSlotId, isNull);
      // A night slot's anchored minute exceeds 1440 and comes back exactly as stored, never taken
      // modulo anything — see ocpt_shooting_slots_table.dart.
      final nightSlot = roundTripped.shootingSlots.firstWhere((row) => row.id == "slot-2");
      expect(nightSlot.anchorEdge, OcptShootingSlotAnchorEdge.end);
      expect(nightSlot.anchorMinute, 1620);
      expect(nightSlot.locationId, isNull);
      expect(nightSlot.setId, isNull);
      expect(nightSlot.isDeleted, isTrue);

      // The other half of the anchor discriminator: a linked edge comes back with no minute and
      // the slot it reads.
      final linkedSlot = roundTripped.shootingSlots.firstWhere((row) => row.id == "slot-3");
      expect(linkedSlot.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(linkedSlot.anchorMinute, isNull);
      expect(linkedSlot.anchorSlotId, "slot-1");

      final crew = roundTripped.shootingSlotCrew.firstWhere((row) => row.id == "crew-1");
      expect(crew.slotId, "slot-1");
      expect(crew.personId, "person-1");
      expect(crew.positionId, "director");
      expect(crew.customLabel, "");
      final customCrew = roundTripped.shootingSlotCrew.firstWhere((row) => row.id == "crew-2");
      expect(customCrew.positionId, "");
      expect(customCrew.customLabel, "Régie");
      expect(customCrew.isDeleted, isTrue);

      final cast = roundTripped.shootingSlotCast.firstWhere((row) => row.id == "cast-1");
      expect(cast.slotId, "slot-1");
      expect(cast.roleId, "role-1");
      final unsetCast = roundTripped.shootingSlotCast.firstWhere((row) => row.id == "cast-2");
      expect(unsetCast.isDeleted, isTrue);

      final shotBlock = roundTripped.shootingDayBlocks.firstWhere((row) => row.id == "block-1");
      expect(shotBlock.shootingDayId, "day-1");
      expect(shotBlock.slotId, "slot-1");
      expect(shotBlock.kind, OcptShootingBlockKind.shot);
      expect(shotBlock.shotId, "shot-1");
      expect(shotBlock.durationMinutes, isNull);
      expect(shotBlock.anchorMinute, isNull);
      expect(shotBlock.sceneId, isNull);
      final holdBlock = roundTripped.shootingDayBlocks.firstWhere((row) => row.id == "block-2");
      expect(holdBlock.slotId, "slot-2");
      expect(holdBlock.kind, OcptShootingBlockKind.hold);
      expect(holdBlock.shotId, isNull);
      expect(holdBlock.sceneId, "scene-1");
      expect(holdBlock.label, "Seq. 6 not shot-listed yet");
      expect(holdBlock.durationMinutes, 30);
      expect(holdBlock.anchorMinute, 600);
      expect(holdBlock.isDeleted, isTrue);

      final guest = roundTripped.shootingSlotGuests.firstWhere((row) => row.id == "guest-1");
      expect(guest.slotId, "slot-1");
      expect(guest.personId, "person-1");
      expect(guest.freeName, "");
      expect(guest.reason, "Maire, prête la place");
      expect(guest.isDeleted, isFalse);
      final freeNamedGuest = roundTripped.shootingSlotGuests.firstWhere(
        (row) => row.id == "guest-2",
      );
      expect(freeNamedGuest.personId, isNull);
      expect(freeNamedGuest.freeName, "Le maire");
      expect(freeNamedGuest.isDeleted, isTrue);

      final event = roundTripped.shootingDayEvents.firstWhere((row) => row.id == "event-1");
      expect(event.shootingDayId, "day-1");
      // Past 1440, exactly as a night slot's own anchored minute is — see
      // ocpt_shooting_day_events_table.dart.
      expect(event.minute, 1020);
      expect(event.label, "Feu d'artifice du village");
      expect(event.isDeleted, isFalse);
      final tombstonedEvent = roundTripped.shootingDayEvents.firstWhere(
        (row) => row.id == "event-2",
      );
      expect(tombstonedEvent.isDeleted, isTrue);
    });

    test("a shot's abbreviation survives, so a restore keeps the coverage bar labels", () {
      final roundTripped = roundTrip(buildRichPayload());

      // The codec is a hand-written mirror of the schema, so every column it forgets is a column
      // a restore silently blanks. This one degrades the scenario coverage export's bar labels
      // from «WS1/1» back to «1/1», which nothing else would catch.
      expect(roundTripped.shots.map((row) => row.abbreviation), ["WS", ""]);
    });

    test('scene ids come back identical, and every reference to them still resolves', () {
      final roundTripped = roundTrip(buildRichPayload());

      // Re-deriving the scene index on restore would mint fresh UUIDs and break every reference
      // carried by the very same payload.
      expect(roundTripped.scenes.map((row) => row.id), ["scene-1", "scene-2"]);

      final sceneIds = {for (final scene in roundTripped.scenes) scene.id};
      for (final shot in roundTripped.shots) {
        expect(shot.sceneId == null || sceneIds.contains(shot.sceneId), isTrue);
      }
      for (final coverage in roundTripped.shotCoverages) {
        expect(sceneIds, contains(coverage.sceneId));
      }
    });

    test('the whole page setup comes back, margins included', () {
      final roundTripped = roundTrip(buildRichPayload());

      expect(roundTripped.pageSetup.format, OcptPageFormat.a4);
      expect(roundTripped.pageSetup.margins.leftInches, 1.5);
      expect(roundTripped.pageSetup.margins.rightInches, 1);
      expect(roundTripped.pageSetup.margins.topInches, 0.75);
      expect(roundTripped.pageSetup.margins.bottomInches, 1.25);
      expect(roundTripped.settingsJson, '{"someSetting":true}');
    });

    test('the currency comes back', () {
      expect(roundTrip(buildRichPayload()).currencyCode, "GBP");
    });

    test('the minimum rest comes back', () {
      expect(roundTrip(buildRichPayload()).minimumRestMinutes, 660);
    });

    test('the screenplay language comes back', () {
      expect(roundTrip(buildRichPayload()).screenplayLanguage, OcptScreenplayLanguage.fr);
    });

    test("a block's crew note comes back", () {
      final block = roundTrip(
        buildRichPayload(),
      ).shootingDayBlocks.firstWhere((row) => row.id == "block-1");
      expect(block.crewNote, "Silence, take in progress");
    });

    test("an asset's validity window comes back", () {
      final asset = roundTrip(buildRichPayload()).assets.firstWhere((row) => row.id == "asset-1");
      expect(asset.validFrom, DateTime.utc(2026, 1, 10));
      expect(asset.validUntil, DateTime.utc(2027, 1, 10));
    });

    test('a project with no shot list at all round trips as an empty one', () {
      const payload = OcptProjectVersionPayload(
        screenplays: [],
        scenes: [],
        shots: [],
        shotCharacters: [],
        shotCoverages: [],
        people: [],
        personPositions: [],
        personSkills: [],
        personUnavailabilities: [],
        roles: [],
        roleEpisodes: [],
        locations: [],
        locationAvailabilities: [],
        sets: [],
        sceneSets: [],
        elements: [],
        sceneElements: [],
        roleElements: [],
        assets: [],
        breakdownTags: [],
        sceneBreakdowns: [],
        shootingDays: [],
        shootingSlots: [],
        shootingSlotCrew: [],
        shootingSlotCast: [],
        shootingDayBlocks: [],
        shootingSlotGuests: [],
        shootingDayEvents: [],
        rowFieldVersions: [],
        pageSetup: OcptPageSetup.standard(),
        settingsJson: null,
        currencyCode: null,
        minimumRestMinutes: null,
        screenplayLanguage: null,
      );

      expect(roundTrip(payload), payload);
    });

    test('the encoded text declares the format it was written in', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;

      expect(encoded["payloadFormat"], OcptProjectVersionCodec.currentPayloadFormat);
    });
  });

  group('OcptProjectVersionCodec contentDigest', () {
    test('is stable across two captures of the same unchanged state', () {
      expect(codec.contentDigest(buildRichPayload()), codec.contentDigest(buildRichPayload()));
    });

    test('is insensitive to the order SQLite happened to return rows in', () {
      final payload = buildRichPayload();
      final reordered = OcptProjectVersionPayload(
        screenplays: payload.screenplays.reversed.toList(),
        scenes: payload.scenes.reversed.toList(),
        shots: payload.shots.reversed.toList(),
        shotCharacters: payload.shotCharacters.reversed.toList(),
        shotCoverages: payload.shotCoverages.reversed.toList(),
        people: payload.people.reversed.toList(),
        personPositions: payload.personPositions.reversed.toList(),
        personSkills: payload.personSkills.reversed.toList(),
        personUnavailabilities: payload.personUnavailabilities.reversed.toList(),
        roles: payload.roles.reversed.toList(),
        roleEpisodes: payload.roleEpisodes.reversed.toList(),
        locations: payload.locations.reversed.toList(),
        locationAvailabilities: payload.locationAvailabilities.reversed.toList(),
        sets: payload.sets.reversed.toList(),
        sceneSets: payload.sceneSets.reversed.toList(),
        elements: payload.elements.reversed.toList(),
        sceneElements: payload.sceneElements.reversed.toList(),
        roleElements: payload.roleElements.reversed.toList(),
        assets: payload.assets.reversed.toList(),
        breakdownTags: payload.breakdownTags.reversed.toList(),
        sceneBreakdowns: payload.sceneBreakdowns.reversed.toList(),
        shootingDays: payload.shootingDays.reversed.toList(),
        shootingSlots: payload.shootingSlots.reversed.toList(),
        shootingSlotCrew: payload.shootingSlotCrew.reversed.toList(),
        shootingSlotCast: payload.shootingSlotCast.reversed.toList(),
        shootingDayBlocks: payload.shootingDayBlocks.reversed.toList(),
        shootingSlotGuests: payload.shootingSlotGuests.reversed.toList(),
        shootingDayEvents: payload.shootingDayEvents.reversed.toList(),
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), codec.contentDigest(reordered));
    });

    test('ignores rowFieldVersions: the per-column stamps play no part in the content', () {
      final payload = buildRichPayload();
      final withDifferentStamps = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: const [
          OcptRowFieldVersionRow(
            targetTableName: "shots",
            rowId: "shot-1",
            columnName: "framing",
            version: 99,
            deviceId: "device-9",
          ),
        ],
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), codec.contentDigest(withDifferentStamps));
    });

    test('ignores the page margins: only the page format is project content', () {
      final payload = buildRichPayload();
      final withDifferentMargins = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: OcptPageSetup(
          format: payload.pageSetup.format,
          margins: const FountainPageMargins(
            leftInches: 2,
            rightInches: 2,
            topInches: 2,
            bottomInches: 2,
          ),
        ),
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), codec.contentDigest(withDifferentMargins));
    });

    test('changes when a screenplay is edited', () {
      final payload = buildRichPayload();
      final edited = OcptProjectVersionPayload(
        screenplays: [
          payload.screenplays.first.copyWith(fountainText: "INT. HOUSE - DAY\n\nCLARA leaves."),
          payload.screenplays.last,
        ],
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(edited)));
    });

    test('changes when a row is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: [payload.shots.first.copyWith(isDeleted: true), payload.shots.last],
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when a resources row is edited', () {
      final payload = buildRichPayload();
      final edited = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: [payload.people.first.copyWith(phone: "0699999999"), payload.people.last],
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      // Without the resources tables in the digest, an afternoon of typing people, locations and
      // elements in would leave the working-copy card claiming no drift from its base.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(edited)));
    });

    test('changes when a resources row is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: [payload.people.first.copyWith(isDeleted: true), payload.people.last],
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when a role_episodes row is added', () {
      final payload = buildRichPayload();
      final withNewLink = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: [
          ...payload.roleEpisodes,
          const OcptRoleEpisodeRow(
            id: "role-episode-3",
            roleId: "role-2",
            screenplayId: "screenplay-2",
            isDeleted: false,
          ),
        ],
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      // Two states differing only in which episodes name a role are not the same project: a
      // digest that left `role_episodes` out would let the working-copy card claim no drift after
      // an afternoon spent saying, episode by episode, who speaks where.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewLink)));
    });

    test('changes when a role_episodes row is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: [
          payload.roleEpisodes.first.copyWith(isDeleted: true),
          payload.roleEpisodes.last,
        ],
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when a role_episodes row is repointed to a different episode', () {
      final payload = buildRichPayload();
      final repointed = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: [
          payload.roleEpisodes.first.copyWith(screenplayId: "screenplay-2"),
          payload.roleEpisodes.last,
        ],
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      // A role recast onto a different episode changes the project even though every row's own id
      // stays put — the same reason a tombstone must move the digest and not only an insertion.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(repointed)));
    });

    test('changes when a breakdown tag is added', () {
      final payload = buildRichPayload();
      final withNewTag = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: [
          ...payload.breakdownTags,
          const OcptBreakdownTagRow(
            id: "breakdown-tag-4",
            sceneId: "scene-1",
            targetKind: OcptBreakdownTargetKind.element,
            elementId: "element-1",
            startOffset: 20,
            endOffset: 24,
            taggedText: "mug!",
            needsCheck: false,
            isDeleted: false,
          ),
        ],
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      // Without the breakdown tables in the digest, an afternoon of tagging the script would leave
      // the working-copy card claiming no drift from its base.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewTag)));
    });

    test("changes when a breakdown tag's text or offsets change", () {
      final payload = buildRichPayload();
      final reanchored = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: [
          payload.breakdownTags.first.copyWith(
            startOffset: 5,
            endOffset: 9,
            taggedText: "lamp",
          ),
          ...payload.breakdownTags.skip(1),
        ],
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(reanchored)));
    });

    test('changes when a breakdown tag is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: [
          payload.breakdownTags.first.copyWith(isDeleted: true),
          ...payload.breakdownTags.skip(1),
        ],
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test("changes when a scene breakdown's status changes", () {
      final payload = buildRichPayload();
      final marked = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: [
          payload.sceneBreakdowns.first.copyWith(status: OcptBreakdownSceneStatus.done),
          ...payload.sceneBreakdowns.skip(1),
        ],
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(marked)));
    });

    test("changes when an element's status changes", () {
      final payload = buildRichPayload();
      final restatused = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: [
          payload.elements.first.copyWith(status: OcptElementStatus.reserved),
          ...payload.elements.skip(1),
        ],
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      // elements.status is new too, and it lives inside the digest exactly like every other
      // column: a status changed only on this field must not read as an unmodified working copy.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(restatused)));
    });

    test('changes when a shooting day is added', () {
      final payload = buildRichPayload();
      final withNewDay = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: [
          ...payload.shootingDays,
          OcptShootingDayRow(
            id: "day-3",
            date: DateTime.utc(2026, 3, 12),
            sortKey: "m",
            status: OcptShootingDayStatus.planned,
            crewNote: "",
            weatherNote: "",
            notes: "",
            isDeleted: false,
          ),
        ],
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      // Without the seven schedule tables in the digest, planning a whole shooting day would leave
      // the working-copy card claiming no drift from its base.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewDay)));
    });

    test("changes when a slot's anchored hour changes", () {
      final payload = buildRichPayload();
      final recalled = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: [
          payload.shootingSlots.first.copyWith(anchorMinute: const drift.Value(360)),
          ...payload.shootingSlots.skip(1),
        ],
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(recalled)));
    });

    test('changes when a shooting day block is tombstoned', () {
      final payload = buildRichPayload();
      final tombstoned = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: [
          payload.shootingDayBlocks.first.copyWith(isDeleted: true),
          ...payload.shootingDayBlocks.skip(1),
        ],
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when a guest is added', () {
      final payload = buildRichPayload();
      final withNewGuest = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: [
          ...payload.shootingSlotGuests,
          const OcptShootingSlotGuestRow(
            id: "guest-3",
            slotId: "slot-1",
            freeName: "Une journaliste",
            reason: "Ouest-France",
            notes: "",
            sortKey: "p",
            isDeleted: false,
          ),
        ],
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewGuest)));
    });

    test('changes when the page format changes', () {
      final payload = buildRichPayload();
      final reformatted = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: OcptPageSetup(
          format: OcptPageFormat.usLetter,
          margins: payload.pageSetup.margins,
        ),
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(reformatted)));
    });

    test('changes when the currency changes', () {
      final payload = buildRichPayload();
      final recurrencied = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: "USD",
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(recurrencied)));
    });

    test('changes when the minimum rest changes', () {
      final payload = buildRichPayload();
      final rerested = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: 720,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(rerested)));
    });

    test('changes when the screenplay language changes', () {
      final payload = buildRichPayload();
      final relanguaged = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: payload.shootingDayBlocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: OcptScreenplayLanguage.enGb,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(relanguaged)));
    });

    test("changes when a block's crew note is typed", () {
      final payload = buildRichPayload();
      final blocks = [
        for (final row in payload.shootingDayBlocks)
          row.id == "block-1" ? row.copyWith(crewNote: "Generator arrives now") : row,
      ];
      final renoted = OcptProjectVersionPayload(
        screenplays: payload.screenplays,
        scenes: payload.scenes,
        shots: payload.shots,
        shotCharacters: payload.shotCharacters,
        shotCoverages: payload.shotCoverages,
        people: payload.people,
        personPositions: payload.personPositions,
        personSkills: payload.personSkills,
        personUnavailabilities: payload.personUnavailabilities,
        roles: payload.roles,
        roleEpisodes: payload.roleEpisodes,
        locations: payload.locations,
        locationAvailabilities: payload.locationAvailabilities,
        sets: payload.sets,
        sceneSets: payload.sceneSets,
        elements: payload.elements,
        sceneElements: payload.sceneElements,
        roleElements: payload.roleElements,
        assets: payload.assets,
        breakdownTags: payload.breakdownTags,
        sceneBreakdowns: payload.sceneBreakdowns,
        shootingDays: payload.shootingDays,
        shootingSlots: payload.shootingSlots,
        shootingSlotCrew: payload.shootingSlotCrew,
        shootingSlotCast: payload.shootingSlotCast,
        shootingDayBlocks: blocks,
        shootingSlotGuests: payload.shootingSlotGuests,
        shootingDayEvents: payload.shootingDayEvents,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(renoted)));
    });
  });

  group('OcptProjectVersionCodec format handling', () {
    /// The encoded rich payload, with its declared format replaced by [payloadFormat].
    String encodedWithFormat(int payloadFormat) {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      encoded["payloadFormat"] = payloadFormat;

      return jsonEncode(encoded);
    }

    test('a payload written by a later build of the app is refused, not half-read', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat + 1),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.unsupportedFutureFormat);
      expect(result.value, isNull);
    });

    test('a payload written in the current format needs no upgrade step', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value, buildRichPayload());
    });

    test('a format with no upgrade step at all is refused rather than guessed', () {
      // Format 0 has never existed and no step of _payloadUpgrades claims to read it: the replay
      // loop must refuse the payload instead of reading it as if it were current.
      final result = codec.decode(encodedWithFormat(0));

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
      expect(result.value, isNull);
    });

    test('a stored format-1 payload decodes cleanly with the eleven resources tables empty', () {
      // A literal fixture of what a real version written before the resources mode existed looks
      // like on disk: none of the eleven resources keys are present at all, since payload format 1
      // predates them entirely.
      const format1Payload = r'''
{
  "payloadFormat": 1,
  "screenplays": [
    {
      "id": "screenplay-1",
      "title": "My Movie",
      "fountainText": "INT. HOUSE - DAY\n\nCLARA enters.",
      "updatedAt": "2026-03-04T15:42:12.345Z",
      "isDeleted": false
    }
  ],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

      final result = codec.decode(format1Payload);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      final payload = result.value!;
      expect(payload.screenplays, hasLength(1));
      expect(payload.screenplays.single.id, "screenplay-1");
      // A version captured before the resources mode existed is a truthful statement that the
      // project had none: this is what OcptProjectVersionsService._restoreTable then tombstones
      // the working copy's resources against, with no special case of its own.
      expect(payload.people, isEmpty);
      expect(payload.personPositions, isEmpty);
      expect(payload.personSkills, isEmpty);
      expect(payload.personUnavailabilities, isEmpty);
      expect(payload.roles, isEmpty);
      expect(payload.locations, isEmpty);
      expect(payload.sets, isEmpty);
      expect(payload.sceneSets, isEmpty);
      expect(payload.elements, isEmpty);
      expect(payload.sceneElements, isEmpty);
      expect(payload.assets, isEmpty);
      expect(payload.locationAvailabilities, isEmpty);
      // A version written before schema v9 predates the breakdown pass by even more, so it goes
      // through every upgrade step in a row: still no tags, no scene statuses, and — vacuously here,
      // since there are no elements at all — every one of them still to find.
      expect(payload.breakdownTags, isEmpty);
      expect(payload.sceneBreakdowns, isEmpty);
      expect(payload.elements.every((row) => row.status == OcptElementStatus.toFind), isTrue);
    });

    test('a stored format-2 payload decodes with no availability window', () {
      // The retired format the resources mode first shipped in: every resources key is there, and
      // `locationAvailabilities` is the one that isn't — a location could not carry a window yet.
      const format2Payload = '''
{
  "payloadFormat": 2,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [
    {
      "id": "location-1",
      "name": "Maison des Pains",
      "colorIndex": 1,
      "addressLine1": "",
      "addressLine2": "",
      "postalCode": "",
      "city": "Lyon",
      "region": "",
      "country": "",
      "latitude": null,
      "longitude": null,
      "contactPersonId": null,
      "contactNotes": "",
      "permitStatus": "granted",
      "permitLabel": "",
      "permitDate": null,
      "permitAssetId": null,
      "parkingNotes": "",
      "powerNotes": "",
      "facilitiesNotes": "",
      "constraintsNotes": "",
      "notes": "",
      "sortKey": "V",
      "isDeleted": false
    }
  ],
  "sets": [],
  "sceneSets": [],
  "elements": [],
  "sceneElements": [],
  "assets": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

      final result = codec.decode(format2Payload);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      final payload = result.value!;
      expect(payload.locations, hasLength(1));
      // Truthful rather than unknown: the project had no window to capture, so restoring this
      // version drops whatever windows the working copy has gathered since.
      expect(payload.locationAvailabilities, isEmpty);
      expect(payload.breakdownTags, isEmpty);
      expect(payload.sceneBreakdowns, isEmpty);
      expect(payload.elements.every((row) => row.status == OcptElementStatus.toFind), isTrue);
    });

    test('a stored format-3 payload decodes to a null currency', () {
      // The retired format that shipped with `location_availabilities` but before
      // `project_info.currencyCode` existed: `projectSettings` carries no `currencyCode` key at
      // all.
      const format3Payload = '''
{
  "payloadFormat": 3,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [],
  "locationAvailabilities": [],
  "sets": [],
  "sceneSets": [],
  "elements": [],
  "sceneElements": [],
  "assets": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

      final result = codec.decode(format3Payload);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      // Null reads as "this version doesn't know", never as "there was no currency" — the column
      // has never been nullable — which is why `OcptProjectVersionsService.restoreVersion` leaves
      // the project's own currency untouched rather than overwriting it with this null.
      expect(result.value!.currencyCode, isNull);
      expect(result.value!.breakdownTags, isEmpty);
      expect(result.value!.sceneBreakdowns, isEmpty);
      expect(result.value!.elements.every((row) => row.status == OcptElementStatus.toFind), isTrue);
    });

    test('a stored format-4 payload decodes with no breakdown and every element still to find', () {
      // The retired format that shipped `elements.status` on the table but never bumped the payload
      // format for it (`9a42495`): a real format-4 payload written before that column existed
      // carries no `status` key on its element rows at all, and no breakdown keys whatsoever.
      const format4Payload = '''
{
  "payloadFormat": 4,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [],
  "locationAvailabilities": [],
  "sets": [],
  "sceneSets": [],
  "elements": [
    {
      "id": "element-1",
      "sortKey": "V",
      "isDeleted": false,
      "category": "prop",
      "subCategory": "",
      "name": "Old lamp",
      "code": "LAMP1",
      "quantity": "",
      "sourceKind": "owned",
      "ownerPersonId": null,
      "ownerNotes": "",
      "broughtByPersonId": null,
      "storageNotes": "",
      "isSecured": false,
      "isReadyForShoot": false,
      "isReturned": false,
      "cost": null,
      "purposeNotes": "",
      "notes": "",
      "photoAssetId": null
    }
  ],
  "sceneElements": [],
  "assets": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null, "currencyCode": "EUR" },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

      final result = codec.decode(format4Payload);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      final payload = result.value!;
      expect(payload.breakdownTags, isEmpty);
      expect(payload.sceneBreakdowns, isEmpty);
      // The column's own default is the honest reading here, not a guess: this element was
      // captured before `status` existed at all, so there is no real value to have preserved.
      expect(payload.elements.single.status, OcptElementStatus.toFind);
    });

    test('a stored format-5 payload decodes with the five schedule tables empty', () {
      // The retired format the breakdown pass shipped in: every table up to and including
      // `sceneBreakdowns` is there, and none of the five schedule tables — `shootingDays` down to
      // `shootingDayBlocks` — are present at all, since payload format 5 predates the schedule mode
      // entirely.
      const format5Payload = '''
{
  "payloadFormat": 5,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [],
  "locationAvailabilities": [],
  "sets": [],
  "sceneSets": [],
  "elements": [],
  "sceneElements": [],
  "assets": [],
  "breakdownTags": [],
  "sceneBreakdowns": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null, "currencyCode": "EUR" },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

      final result = codec.decode(format5Payload);

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      final payload = result.value!;
      // A version captured before milestone M1 is a truthful statement that the project had not
      // been scheduled yet: this is what OcptProjectVersionsService._restoreTable then tombstones
      // the working copy's own schedule against, with no special case of its own.
      expect(payload.shootingDays, isEmpty);
      expect(payload.shootingSlots, isEmpty);
      expect(payload.shootingSlotCrew, isEmpty);
      expect(payload.shootingSlotCast, isEmpty);
      expect(payload.shootingDayBlocks, isEmpty);
    });

    test(
      "a stored format-6 payload upgrades the slot rework: startMinute, dropped clocks, "
      "and orphan blocks reassigned to their day's first slot",
      () {
        // The shape milestone M1 shipped: the six schedule tables, `shooting_slots` still typing
        // its own crewCallMinute/crewWrapMinute/castCallMinute/castWrapMinute, `shooting_slot_crew`
        // its own callMinute/wrapMinute, `shooting_slot_cast` its own
        // arrivalMinute/castCallMinute/castWrapMinute, `shooting_day_blocks.slotId` still nullable,
        // and no `shootingDayGroups` at all — that table doesn't exist before format 7.
        const format6Payload = '''
{
  "payloadFormat": 6,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [],
  "locationAvailabilities": [],
  "sets": [],
  "sceneSets": [],
  "elements": [],
  "sceneElements": [],
  "assets": [],
  "breakdownTags": [],
  "sceneBreakdowns": [],
  "shootingDays": [
    {
      "id": "day-1",
      "screenplayId": "screenplay-1",
      "date": "2026-03-10T00:00:00.000Z",
      "sortKey": "V",
      "status": "planned",
      "crewNote": "",
      "weatherNote": "",
      "notes": "",
      "isDeleted": false
    },
    {
      "id": "day-2",
      "screenplayId": "screenplay-1",
      "date": "2026-03-11T00:00:00.000Z",
      "sortKey": "k",
      "status": "planned",
      "crewNote": "",
      "weatherNote": "",
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlots": [
    {
      "id": "slot-second",
      "shootingDayId": "day-1",
      "sortKey": "b",
      "label": "",
      "locationId": null,
      "setId": null,
      "crewCallMinute": 600,
      "crewWrapMinute": 1140,
      "castCallMinute": null,
      "castWrapMinute": null,
      "notes": "",
      "isDeleted": false
    },
    {
      "id": "slot-first",
      "shootingDayId": "day-1",
      "sortKey": "a",
      "label": "Matin",
      "locationId": null,
      "setId": null,
      "crewCallMinute": 480,
      "crewWrapMinute": 1080,
      "castCallMinute": 500,
      "castWrapMinute": 1000,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlotCrew": [
    {
      "id": "crew-1",
      "slotId": "slot-first",
      "sortKey": "V",
      "personId": "person-1",
      "positionId": "director",
      "customLabel": "",
      "callMinute": 450,
      "wrapMinute": 1100,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlotCast": [
    {
      "id": "cast-1",
      "slotId": "slot-first",
      "roleId": "role-1",
      "sortKey": "V",
      "arrivalMinute": 420,
      "castCallMinute": 480,
      "castWrapMinute": 1000,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingDayBlocks": [
    {
      "id": "block-kept",
      "shootingDayId": "day-1",
      "sortKey": "a",
      "slotId": "slot-second",
      "kind": "wrap",
      "shotId": null,
      "label": "",
      "durationMinutes": null,
      "anchorMinute": null,
      "notes": "",
      "isDeleted": false
    },
    {
      "id": "block-orphan",
      "shootingDayId": "day-1",
      "sortKey": "b",
      "slotId": null,
      "kind": "wrap",
      "shotId": null,
      "label": "",
      "durationMinutes": null,
      "anchorMinute": null,
      "notes": "",
      "isDeleted": false
    },
    {
      "id": "block-orphan-no-slot-day",
      "shootingDayId": "day-2",
      "sortKey": "a",
      "slotId": null,
      "kind": "wrap",
      "shotId": null,
      "label": "",
      "durationMinutes": null,
      "anchorMinute": null,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingPresences": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null, "currencyCode": "EUR" },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

        final result = codec.decode(format6Payload);

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        final payload = result.value!;

        // (a) every slot gains its start from its old crewCallMinute; the three dropped columns
        // simply aren't read any more (there is no field left on the row to read them through).
        // Decoding always upgrades to the current format, so what that start lands in is the
        // format-9 anchor trio: pinned by the start edge, at the hour the payload carried.
        final firstSlot = payload.shootingSlots.firstWhere((row) => row.id == "slot-first");
        expect(firstSlot.anchorEdge, OcptShootingSlotAnchorEdge.start);
        expect(firstSlot.anchorMinute, 480);
        expect(firstSlot.anchorSlotId, isNull);
        final secondSlot = payload.shootingSlots.firstWhere((row) => row.id == "slot-second");
        expect(secondSlot.anchorMinute, 600);

        // (b) the crew and cast rows survived their old clock overrides being dropped, and — this
        // payload also being carried straight through the format-7-to-8 step, since decoding always
        // upgrades to the current format — carry no group or lead time column at all any more.
        expect(payload.shootingSlotCrew.single.personId, "person-1");
        expect(payload.shootingSlotCast.single.roleId, "role-1");

        // (c) the block already pointing at a live slot keeps it; the orphan on day-1 lands on
        // that day's first slot in this same payload — "slot-first" (sortKey "a", ahead of
        // "slot-second"'s "b") — despite being declared second in the JSON; the orphan whose day
        // (day-2) carries no slot at all is dropped from the list entirely.
        final blockIds = payload.shootingDayBlocks.map((row) => row.id).toSet();
        expect(blockIds, {"block-kept", "block-orphan"});
        final keptBlock = payload.shootingDayBlocks.firstWhere((row) => row.id == "block-kept");
        expect(keptBlock.slotId, "slot-second");
        final orphanBlock = payload.shootingDayBlocks.firstWhere(
          (row) => row.id == "block-orphan",
        );
        expect(orphanBlock.slotId, "slot-first");

        // (d) no block names a scene: the column is new, and the free text a format-6 hold carries
        // is not a scene id to read one out of.
        expect(payload.shootingDayBlocks.every((row) => row.sceneId == null), isTrue);
      },
    );

    test(
      'a stored format-7 payload decodes with the groups and lead times gone',
      () {
        // The shape milestone M1' shipped: shooting_day_groups exists and carries a row, and
        // shooting_slot_crew/shooting_slot_cast each carry a groupId and a leadMinutes value —
        // all of it dropped by ADR 0018's own half of the codec, [_upgradeFormat7To8].
        const format7Payload = '''
{
  "payloadFormat": 7,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [],
  "locationAvailabilities": [],
  "sets": [],
  "sceneSets": [],
  "elements": [],
  "sceneElements": [],
  "assets": [],
  "breakdownTags": [],
  "sceneBreakdowns": [],
  "shootingDays": [
    {
      "id": "day-1",
      "screenplayId": "screenplay-1",
      "date": "2026-03-10T00:00:00.000Z",
      "sortKey": "V",
      "status": "planned",
      "crewNote": "",
      "weatherNote": "",
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingDayGroups": [
    {
      "id": "group-1",
      "shootingDayId": "day-1",
      "sortKey": "V",
      "label": "Équipe image",
      "leadMinutes": 20,
      "isDeleted": false
    }
  ],
  "shootingSlots": [
    {
      "id": "slot-1",
      "shootingDayId": "day-1",
      "sortKey": "V",
      "label": "",
      "locationId": null,
      "setId": null,
      "startMinute": 480,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlotCrew": [
    {
      "id": "crew-1",
      "slotId": "slot-1",
      "sortKey": "V",
      "personId": "person-1",
      "positionId": "director",
      "customLabel": "",
      "groupId": "group-1",
      "leadMinutes": null,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlotCast": [
    {
      "id": "cast-1",
      "slotId": "slot-1",
      "roleId": "role-1",
      "sortKey": "V",
      "groupId": null,
      "leadMinutes": 45,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingDayBlocks": [],
  "shootingPresences": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null, "currencyCode": "EUR" },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

        final result = codec.decode(format7Payload);

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        final payload = result.value!;

        // The group and the lead times it and the two convocations carried are all gone — not
        // reconstructed into anything, exactly as a format-6 payload's typed clocks are not
        // reconstructed into a lead time.
        final crew = payload.shootingSlotCrew.single;
        expect(crew.personId, "person-1");
        expect(crew.positionId, "director");
        final cast = payload.shootingSlotCast.single;
        expect(cast.roleId, "role-1");
      },
    );

    test(
      'a stored format-8 payload decodes with every slot anchored by the start it had',
      () {
        // The shape ADR 0018 left behind: a slot owning a single typed `startMinute`, which M1
        // replaces with the anchored-edge trio. [_upgradeFormat8To9] is a **rename**, so the hour
        // itself must come back untouched, on the start edge, reading no other slot.
        const format8Payload = '''
{
  "payloadFormat": 8,
  "screenplays": [],
  "scenes": [],
  "shots": [],
  "shotCharacters": [],
  "shotCoverages": [],
  "people": [],
  "personPositions": [],
  "personSkills": [],
  "personUnavailabilities": [],
  "roles": [],
  "locations": [],
  "locationAvailabilities": [],
  "sets": [],
  "sceneSets": [],
  "elements": [],
  "sceneElements": [],
  "assets": [],
  "breakdownTags": [],
  "sceneBreakdowns": [],
  "shootingDays": [
    {
      "id": "day-1",
      "screenplayId": "screenplay-1",
      "date": "2026-03-10T00:00:00.000Z",
      "sortKey": "V",
      "status": "planned",
      "crewNote": "",
      "weatherNote": "",
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlots": [
    {
      "id": "slot-1",
      "shootingDayId": "day-1",
      "sortKey": "V",
      "label": "Matin",
      "locationId": null,
      "setId": null,
      "startMinute": 480,
      "notes": "",
      "isDeleted": false
    },
    {
      "id": "slot-2",
      "shootingDayId": "day-1",
      "sortKey": "k",
      "label": "Nuit",
      "locationId": null,
      "setId": null,
      "startMinute": 1140,
      "notes": "",
      "isDeleted": false
    }
  ],
  "shootingSlotCrew": [],
  "shootingSlotCast": [],
  "shootingDayBlocks": [],
  "shootingPresences": [],
  "rowFieldVersions": [],
  "projectSettings": { "pageFormat": "a4", "settingsJson": null, "currencyCode": "EUR" },
  "pageMargins": {
    "leftInches": 1.5,
    "rightInches": 1,
    "topInches": 0.75,
    "bottomInches": 1.25
  }
}
''';

        final result = codec.decode(format8Payload);

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        final payload = result.value!;

        final slotsById = {for (final row in payload.shootingSlots) row.id: row};
        expect(slotsById['slot-1']!.anchorEdge, OcptShootingSlotAnchorEdge.start);
        expect(slotsById['slot-1']!.anchorMinute, 480);
        expect(slotsById['slot-1']!.anchorSlotId, isNull);
        // A night slot's own hour exceeds 1440 and is carried across untouched, never taken modulo
        // anything.
        expect(slotsById['slot-2']!.anchorEdge, OcptShootingSlotAnchorEdge.start);
        expect(slotsById['slot-2']!.anchorMinute, 1140);
        expect(slotsById['slot-2']!.anchorSlotId, isNull);
      },
    );

    test('a stored format-9 payload decodes with no role linked to any element', () {
      // Format 9 predates `role_elements` entirely, so [_upgradeFormat9To10] materialises it as an
      // **empty list** — the plain kind, not the currency's "leave the live value alone" null. The
      // fixture is the current encoding with the key taken back out and the format wound back,
      // rather than a second hand-written literal: what matters is the missing section, and every
      // other section is exercised by the round-trip tests already.
      final encoded = asFormat12Shape(
        jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>,
      )..remove("roleElements");
      encoded["payloadFormat"] = 9;

      final result = codec.decode(jsonEncode(encoded));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value!.roleElements, isEmpty);
      // And nothing else was disturbed on the way through: the rest of the project came back.
      expect(result.value!.elements, buildRichPayload().elements);
      expect(result.value!.roles, buildRichPayload().roles);
    });

    test(
      "a stored format-10 payload decodes with nobody's maximum daily presence recorded",
      () {
        // Format 10 predates `people.maxDailyPresenceMinutes` entirely, so [_upgradeFormat10To11]
        // materialises it as **null** on every person — the same kind of null
        // [_upgradeFormat6To7] writes for a crew or cast row's dropped `groupId`/`leadMinutes`,
        // never the currency's "leave the live value alone" one, since the column is nullable by
        // design and null is its own truthful state. The fixture is the current encoding with the
        // key taken back out of every person row and the format wound back, rather than a second
        // hand-written literal.
        final encoded = asFormat12Shape(
          jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>,
        );
        for (final person in encoded["people"] as List) {
          (person as Map<String, dynamic>).remove("maxDailyPresenceMinutes");
        }
        encoded["payloadFormat"] = 10;

        final result = codec.decode(jsonEncode(encoded));

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        expect(
          result.value!.people.map((row) => row.maxDailyPresenceMinutes),
          everyElement(isNull),
        );
        // And nothing else was disturbed on the way through: the rest of the project came back,
        // the first person's own name included — only the one column was ever missing.
        expect(
          result.value!.people.map((row) => row.firstName),
          buildRichPayload().people.map((row) => row.firstName),
        );
      },
    );

    test(
      'a stored format-11 payload decodes with no guest, no event, an empty crew note on '
      'every block, no validity or rest recorded, and its presence overrides dropped',
      () {
        // Format 11 predates `shooting_slot_guests`, `shooting_day_events`,
        // `shooting_day_blocks.crewNote`, `assets.validFrom`/`validUntil` and
        // `project_info.minimumRestMinutes` entirely. [_upgradeFormat11To12] materialises the first
        // two as **empty lists** (the plain kind), and the crew note, the validity dates and the
        // rest minimum as an **empty string**/**null**s — the same kind [_upgradeFormat10To11]
        // writes for `maxDailyPresenceMinutes`, not the currency's "leave the live value alone"
        // null. The fixture is the current encoding with every one of those keys taken back out and
        // the format wound back, rather than a second hand-written literal.
        final encoded = asFormat12Shape(
          jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>,
        )
          ..remove("shootingSlotGuests")
          ..remove("shootingDayEvents");

        for (final block in encoded["shootingDayBlocks"] as List) {
          (block as Map<String, dynamic>).remove("crewNote");
        }
        for (final asset in encoded["assets"] as List) {
          (asset as Map<String, dynamic>)
            ..remove("validFrom")
            ..remove("validUntil");
        }
        (encoded["projectSettings"] as Map<String, dynamic>).remove("minimumRestMinutes");

        // `shooting_presences` genuinely existed at format 11, since format 6 first shipped it
        // alongside the rest of the schedule mode — this is a real row, typed by a user, not merely
        // an absent key: [_upgradeFormat11To12]'s third kind of change must drop it rather than
        // leave it materialised as an empty list, the way a table that never existed at format 11
        // would be.
        encoded["shootingPresences"] = [
          {
            "id": "presence-1",
            "shootingDayId": "day-1",
            "personId": "person-1",
            "code": "travelling",
            "isDeleted": false,
          },
        ];
        encoded["payloadFormat"] = 11;

        final result = codec.decode(jsonEncode(encoded));

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        expect(result.value!.shootingSlotGuests, isEmpty);
        expect(result.value!.shootingDayEvents, isEmpty);
        expect(result.value!.shootingDayBlocks.map((row) => row.crewNote), everyElement(""));
        expect(result.value!.assets.map((row) => row.validFrom), everyElement(isNull));
        expect(result.value!.assets.map((row) => row.validUntil), everyElement(isNull));
        expect(result.value!.minimumRestMinutes, isNull);
        // And nothing else was disturbed on the way through: the rest of the schedule came back.
        expect(result.value!.shootingSlots, buildRichPayload().shootingSlots);
        expect(result.value!.shootingDays, buildRichPayload().shootingDays);

        // The dropped override is gone for good, not merely unread: re-encoding what came out of
        // the decode never mentions it again, exactly as a format-7 payload's dropped lead times
        // never resurface either.
        final reEncoded = jsonDecode(codec.encode(result.value!)) as Map<String, dynamic>;
        expect(reEncoded.containsKey("shootingPresences"), isFalse);
      },
    );

    test(
      'a stored format-12 payload decodes with its single live screenplay numbered 1, every '
      'live role linked to the episode it named and keeping its casting, no link for a '
      'tombstoned role, and a shooting day carrying everything it held',
      () {
        // Format 12 predates `screenplays.number`/`sortKey` and `role_episodes` entirely, and
        // still carries `roles.screenplayId`/`shooting_days.screenplayId` — the shape schema
        // version 18 and payload format 13 both retire together
        // (`docs/adr/0019-one-project-several-episodes.md`). The fixture is the current encoding
        // wound back to that shape ([asFormat12Shape]) rather than a second hand-written literal:
        // what matters here is the shape of the upgrade, and every column [_upgradeFormat12To13]
        // doesn't touch is already exercised by the other round-trip tests.
        final encoded = asFormat12Shape(
          jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>,
        );
        encoded["payloadFormat"] = 12;

        final result = codec.decode(jsonEncode(encoded));

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        final payload = result.value!;

        // "This project had one episode, and it was the first" is the truthful reading of a
        // format-12 capture — format 5's kind of materialisation, not a null left for a live
        // value: the live screenplay is numbered 1 and keyed exactly as
        // `_numberExistingScreenplays` keys a lone live row (`ocptFractionalKeySequence(1)`
        // yields "V", the same key every other lone-row fixture in this file already uses). The
        // tombstoned screenplay was never going to be episode anything, so it is left at the
        // column's own defaults, exactly as `_numberExistingScreenplays` leaves a tombstoned row.
        final liveScreenplay = payload.screenplays.firstWhere((row) => row.id == "screenplay-1");
        expect(liveScreenplay.number, 1);
        expect(liveScreenplay.sortKey, "V");
        final tombstonedScreenplay = payload.screenplays.firstWhere(
          (row) => row.id == "screenplay-2",
        );
        expect(tombstonedScreenplay.number, 1);
        expect(tombstonedScreenplay.sortKey, "");

        // `role_episodes` is derived from the very `roles.screenplayId` this step drops: the only
        // lossless step in the codec. The link's id is the role's own — unique here, since a role
        // named exactly one screenplay at format 12, and deterministic, the same reasoning
        // `_deriveRoleEpisodes` gives for its own schema-migration twin.
        final liveRole = payload.roles.firstWhere((row) => row.id == "role-1");
        expect(liveRole.isDeleted, isFalse);
        final linksOfLiveRole = payload.roleEpisodes.where((row) => row.roleId == "role-1");
        expect(linksOfLiveRole, hasLength(1));
        expect(linksOfLiveRole.single.id, "role-1");
        expect(linksOfLiveRole.single.screenplayId, "screenplay-1");
        expect(linksOfLiveRole.single.isDeleted, isFalse);
        // No role loses its casting on the way through: a role is no longer a script's, but it
        // is still the very same casting decision.
        expect(liveRole.personId, "person-1");
        expect(liveRole.castingNotes, "Confirmed");
        expect(liveRole.orphanedName, isNull);

        // A tombstoned role named no episode worth carrying forward, tombstoned or not — mirroring
        // `_deriveRoleEpisodes`, which reads only live `roles` rows.
        final tombstonedRole = payload.roles.firstWhere((row) => row.id == "role-2");
        expect(tombstonedRole.isDeleted, isTrue);
        expect(payload.roleEpisodes.where((row) => row.roleId == "role-2"), isEmpty);
        // Its own casting fields survive the upgrade untouched too, whatever `role_episodes` ends
        // up saying about it.
        expect(tombstonedRole.orphanedName, "GHOST");

        // `roles.screenplayId` and `shooting_days.screenplayId` are dropped outright — format 8's
        // and format 12's own kind, not a reconstruction: a day comes back with everything else it
        // held, simply belonging to no episode any more.
        final day = payload.shootingDays.firstWhere((row) => row.id == "day-1");
        expect(day.crewNote, "Arrive at the north gate");
        expect(day.weatherNote, "Sunny, light wind");
        expect(day.status, OcptShootingDayStatus.planned);
        expect(day.isDeleted, isFalse);

        // A round trip through encode/decode at the current format is lossless, `role_episodes`
        // included.
        final reEncoded = codec.decode(codec.encode(payload)).value!;
        expect(reEncoded, payload);
      },
    );

    test(
      'a stored format-13 payload decodes with no screenplay language recorded',
      () {
        // Format 13 predates `project_info.screenplayLanguage` entirely, so
        // [_upgradeFormat13To14] materialises it as **null** — [_upgradeFormat11To12]'s kind, not
        // the currency's "leave the live value alone" one, since the column is nullable by design
        // and null is its own truthful state. The fixture is the current encoding with the key
        // taken back out of `projectSettings` and the format wound back, rather than a second
        // hand-written literal.
        final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
        (encoded["projectSettings"] as Map<String, dynamic>).remove("screenplayLanguage");
        encoded["payloadFormat"] = 13;

        final result = codec.decode(jsonEncode(encoded));

        expect(result.status, OcptProjectVersionPayloadStatus.ok);
        expect(result.value!.screenplayLanguage, isNull);
        // And nothing else was disturbed on the way through: the rest of the project came back.
        expect(result.value!.currencyCode, buildRichPayload().currencyCode);
        expect(result.value!.minimumRestMinutes, buildRichPayload().minimumRestMinutes);
      },
    );
  });

  group('OcptProjectVersionCodec malformed payloads', () {
    test("text that isn't JSON at all is refused", () {
      final result = codec.decode("not json");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test("a JSON value that isn't an object is refused", () {
      final result = codec.decode("[1, 2, 3]");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test('a payload with no format at all is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>
        ..remove("payloadFormat");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a payload missing one of its row sections is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>
        ..remove("rowFieldVersions");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a row missing one of its columns is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>).remove("sortKey");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a column holding the wrong type is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["scenes"] as List).first as Map<String, dynamic>)["charStart"] = "zero";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('an enum column holding an unknown value is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>)["status"] = "teleported";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a format-5 element row missing its status is refused, not defaulted', () {
      // At the current format, elements.status is read strictly ([_upgradeFormat4To5] is the only
      // place that ever defaults it, and only for a payload that never reached format 5): a format-5
      // payload with the column simply missing is malformed, not a project that predates it.
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["elements"] as List).first as Map<String, dynamic>).remove("status");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });
  });
}
