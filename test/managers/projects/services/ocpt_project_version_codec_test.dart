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
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
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
        commuteKmMilli: 1484000,
        mileageRateId: "rate-1",
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
    roleCandidates: [
      OcptRoleCandidateRow(
        id: "role-candidate-1",
        roleId: "role-1",
        personId: "person-1",
        status: OcptRoleCandidateStatus.retained,
        auditionedOn: DateTime.utc(2026, 2, 12, 14, 30),
        notes: "Very sure of the last scene",
        sortKey: "V",
        isDeleted: false,
      ),
      const OcptRoleCandidateRow(
        id: "role-candidate-2",
        roleId: "role-1",
        personId: "person-2",
        status: OcptRoleCandidateStatus.declined,
        notes: "",
        sortKey: "k",
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
      OcptAssetRow(
        id: "asset-3",
        kind: OcptAssetKind.receipt,
        path: "/home/user/Documents/facture-camion.pdf",
        label: "Facture location camion",
        addedAt: DateTime.utc(2026, 3, 10, 9),
        sortKey: "m",
        isDeleted: false,
        budgetEntryId: "entry-1",
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
      OcptShootingDayBlockRow(
        id: "block-3",
        shootingDayId: "day-2",
        sortKey: "t",
        slotId: "slot-3",
        kind: OcptShootingBlockKind.audition,
        label: "",
        durationMinutes: 20,
        notes: "",
        crewNote: "",
        isDeleted: false,
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
    projectDictionaryWords: const [
      OcptProjectDictionaryWordRow(id: "word-1", word: "Séquence", isDeleted: false),
      OcptProjectDictionaryWordRow(id: "word-2", word: "Marc", isDeleted: true),
    ],
    budgetPostes: const [
      OcptBudgetPosteRow(
        id: "poste-1",
        sortKey: "V",
        isDeleted: false,
        code: "2",
        label: "Personnel",
        simpleLabel: "Crew",
        estimateToCompleteCents: 42000,
      ),
      OcptBudgetPosteRow(
        id: "poste-2",
        sortKey: "k",
        isDeleted: true,
        code: "",
        label: "Abandoned poste",
      ),
    ],
    budgetLines: const [
      OcptBudgetLineRow(
        id: "line-1",
        sortKey: "V",
        isDeleted: false,
        posteId: "poste-1",
        label: "First assistant camera",
        quantityMilli: 1500,
        unit: "day",
        unitAmountCents: 20000,
        isTaxInclusive: true,
        vatRateBasisPoints: 550,
        elementId: "element-1",
        notes: "Confirmed",
      ),
      OcptBudgetLineRow(
        id: "line-2",
        sortKey: "k",
        isDeleted: true,
        posteId: "poste-1",
        label: "",
        quantityMilli: 1000,
        unit: "",
        unitAmountCents: 0,
        isTaxInclusive: true,
        notes: "",
      ),
    ],
    budgetEntries: [
      OcptBudgetEntryRow(
        id: "entry-1",
        sortKey: "V",
        isDeleted: false,
        date: DateTime.utc(2026, 3, 10),
        label: "Location camion",
        posteId: "poste-1",
        debitCents: 15000,
        creditCents: 0,
        isTaxInclusive: true,
        vatRateBasisPoints: 550,
        voucherNumber: "J-001",
        resourceId: "resource-1",
        revenueId: "revenue-1",
        shareId: "share-1",
        commitmentId: "commitment-1",
        personId: "person-1",
      ),
      OcptBudgetEntryRow(
        id: "entry-2",
        sortKey: "k",
        isDeleted: true,
        date: DateTime.utc(2026, 3, 11),
        label: "",
        debitCents: 0,
        creditCents: 0,
        isTaxInclusive: true,
        voucherNumber: "",
      ),
    ],
    budgetCommitments: [
      OcptBudgetCommitmentRow(
        id: "commitment-1",
        sortKey: "V",
        isDeleted: false,
        dueDate: DateTime.utc(2026, 4, 15),
        label: "Assurance tournage",
        posteId: "poste-1",
        amountCents: 45000,
        isTaxInclusive: false,
        vatRateBasisPoints: 2000,
        status: OcptBudgetCommitmentStatus.contractSigned,
      ),
      const OcptBudgetCommitmentRow(
        id: "commitment-2",
        sortKey: "k",
        isDeleted: true,
        label: "",
        posteId: "poste-1",
        amountCents: 0,
        isTaxInclusive: true,
        status: OcptBudgetCommitmentStatus.quoteAccepted,
      ),
    ],
    budgetResources: const [
      OcptBudgetResourceRow(
        id: "resource-1",
        sortKey: "V",
        isDeleted: false,
        groupKind: OcptBudgetResourceGroupKind.inKind,
        personId: "person-1",
        label: "Caméra prêtée",
        amountCents: 150000,
        status: OcptBudgetResourceStatus.confirmed,
        isReimbursable: true,
        notes: "Prêt du loueur",
      ),
      OcptBudgetResourceRow(
        id: "resource-2",
        sortKey: "k",
        isDeleted: true,
        groupKind: OcptBudgetResourceGroupKind.subsidy,
        label: "",
        amountCents: 0,
        status: OcptBudgetResourceStatus.pending,
        isReimbursable: false,
        notes: "",
      ),
    ],
    budgetMileageRates: const [
      OcptBudgetMileageRateRow(
        id: "rate-1",
        sortKey: "V",
        isDeleted: false,
        label: "Voiture personnelle",
        ratePerKmMilliCents: 52900,
      ),
      OcptBudgetMileageRateRow(
        id: "rate-2",
        sortKey: "k",
        isDeleted: true,
        label: "",
        ratePerKmMilliCents: 0,
      ),
    ],
    budgetRevenues: [
      OcptBudgetRevenueRow(
        id: "revenue-1",
        sortKey: "V",
        isDeleted: false,
        date: DateTime.utc(2026, 5, 15),
        label: "Vente VOD",
        amountCents: 80000,
        status: OcptBudgetRevenueStatus.confirmed,
        notes: "Contrat signé",
      ),
      OcptBudgetRevenueRow(
        id: "revenue-2",
        sortKey: "k",
        isDeleted: true,
        date: DateTime.utc(2026, 5, 2),
        label: "",
        amountCents: 0,
        status: OcptBudgetRevenueStatus.expected,
        notes: "",
      ),
    ],
    budgetShares: const [
      OcptBudgetShareRow(
        id: "share-1",
        sortKey: "V",
        isDeleted: false,
        personId: "person-1",
        label: "Réalisatrice",
        sharePermille: 300,
        reinvestPermille: 100,
        notes: "",
      ),
      OcptBudgetShareRow(
        id: "share-2",
        sortKey: "k",
        isDeleted: true,
        label: "",
        sharePermille: 0,
        reinvestPermille: 0,
        notes: "",
      ),
    ],
    budgetAllowances: [
      // A journey, which is the case the mileage rate pre-fills: 168 km at 0.529 €/km.
      OcptBudgetAllowanceRow(
        id: "allowance-1",
        sortKey: "V",
        isDeleted: false,
        personId: "person-1",
        kind: OcptBudgetAllowanceKind.travel,
        label: "Aller Paris — Le Havre",
        date: DateTime.utc(2026, 3, 2),
        quantityMilli: 168000,
        unitAmountMilliCents: 52900,
        notes: "",
      ),
      // A stay, the one kind that spans two dates, and the one naming nobody: a tombstone too.
      OcptBudgetAllowanceRow(
        id: "allowance-2",
        sortKey: "k",
        isDeleted: true,
        kind: OcptBudgetAllowanceKind.accommodation,
        label: "",
        date: DateTime.utc(2026, 3, 2),
        endDate: DateTime.utc(2026, 3, 15),
        quantityMilli: 13000,
        unitAmountMilliCents: 6000000,
        notes: "",
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
    shootingBlockCandidates: const [
      OcptShootingBlockCandidateRow(
        id: "block-candidate-1",
        blockId: "block-3",
        roleCandidateId: "role-candidate-1",
        sortKey: "V",
        notes: "Vient avec sa bande démo",
        isDeleted: false,
      ),
      OcptShootingBlockCandidateRow(
        id: "block-candidate-2",
        blockId: "block-3",
        roleCandidateId: "role-candidate-2",
        sortKey: "k",
        notes: "",
        isDeleted: true,
      ),
    ],
    defaultVatRateBasisPoints: 2000,
    mealPriceCents: 1250,
    snackPriceCents: 350,
    isBudgetSimplified: true,
  );

  /// [buildRichPayload] serialized and read back.
  OcptProjectVersionPayload roundTrip(OcptProjectVersionPayload payload) {
    final result = codec.decode(codec.encode(payload));

    expect(result.status, OcptProjectVersionPayloadStatus.ok);
    return result.value!;
  }

  group('OcptProjectVersionCodec round trip', () {
    test('a candidacy in any of the statuses decodes back to the one it was written in', () {
      // A `status` is stored by **name** and read back through `values.byName`: a value the tests
      // never actually put through the codec is exactly the kind that only ever fails in a user's
      // own file, months later. Walking `values` is what keeps a ninth status from being added
      // without this being true of it too.
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;

      for (final status in OcptRoleCandidateStatus.values) {
        final rewritten = {
          ...encoded,
          "roleCandidates": [
            for (final row in encoded["roleCandidates"] as List)
              {...row as Map<String, dynamic>, "status": status.name},
          ],
        };

        final result = codec.decode(jsonEncode(rewritten));

        expect(result.status, OcptProjectVersionPayloadStatus.ok, reason: "for $status");
        expect(
          result.value!.roleCandidates.map((row) => row.status),
          everyElement(status),
          reason: "for $status",
        );
      }
    });

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
      expect(roundTripped.assets.map((row) => row.isDeleted), [false, true, false]);

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

    test('every column of the twelve resource tables round trips, enums and nulls included', () {
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

      final roleElement = roundTripped.roleElements.first;
      expect(roleElement.roleId, "role-1");
      expect(roleElement.elementId, "element-1");
      expect(roleElement.notes, "Torn from scene 12 on");

      final candidate = roundTripped.roleCandidates.first;
      expect(candidate.roleId, "role-1");
      expect(candidate.personId, "person-1");
      expect(candidate.status, OcptRoleCandidateStatus.retained);
      expect(candidate.auditionedOn, DateTime.utc(2026, 2, 12, 14, 30));
      expect(candidate.notes, "Very sure of the last scene");
      expect(candidate.sortKey, "V");
      // The second candidacy was never dated: a self-tape, or somebody seen before the project was
      // opened, keeps a null there rather than a moment nobody recorded.
      final undatedCandidate = roundTripped.roleCandidates.last;
      expect(undatedCandidate.status, OcptRoleCandidateStatus.declined);
      expect(undatedCandidate.auditionedOn, isNull);
      expect(undatedCandidate.isDeleted, isTrue);

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

    test('the learned words come back, exactly as typed, tombstones included', () {
      final roundTripped = roundTrip(buildRichPayload());

      expect(
        roundTripped.projectDictionaryWords.map((row) => row.word),
        ["Séquence", "Marc"],
      );
      expect(
        roundTripped.projectDictionaryWords.map((row) => row.isDeleted),
        [false, true],
      );
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

    test("a receipt asset's budgetEntryId comes back", () {
      final asset = roundTrip(buildRichPayload()).assets.firstWhere((row) => row.id == "asset-3");
      expect(asset.kind, OcptAssetKind.receipt);
      expect(asset.budgetEntryId, "entry-1");
    });

    test('every column of the cash journal round trips, tombstones and nulls included', () {
      final roundTripped = roundTrip(buildRichPayload());

      final liveEntry = roundTripped.budgetEntries.firstWhere((row) => row.id == "entry-1");
      expect(liveEntry.date, DateTime.utc(2026, 3, 10));
      expect(liveEntry.label, "Location camion");
      expect(liveEntry.posteId, "poste-1");
      expect(liveEntry.debitCents, 15000);
      expect(liveEntry.creditCents, 0);
      expect(liveEntry.isTaxInclusive, isTrue);
      expect(liveEntry.vatRateBasisPoints, 550);
      expect(liveEntry.voucherNumber, "J-001");
      expect(liveEntry.isDeleted, isFalse);

      expect(liveEntry.commitmentId, "commitment-1");
      expect(liveEntry.personId, "person-1");

      final tombstonedEntry = roundTripped.budgetEntries.firstWhere((row) => row.id == "entry-2");
      expect(tombstonedEntry.posteId, isNull);
      expect(tombstonedEntry.commitmentId, isNull);
      expect(tombstonedEntry.personId, isNull);
      expect(tombstonedEntry.isDeleted, isTrue);

      final liveCommitment = roundTripped.budgetCommitments.firstWhere(
        (row) => row.id == "commitment-1",
      );
      expect(liveCommitment.dueDate, DateTime.utc(2026, 4, 15));
      expect(liveCommitment.label, "Assurance tournage");
      expect(liveCommitment.posteId, "poste-1");
      expect(liveCommitment.amountCents, 45000);
      expect(liveCommitment.isTaxInclusive, isFalse);
      expect(liveCommitment.vatRateBasisPoints, 2000);
      expect(liveCommitment.status, OcptBudgetCommitmentStatus.contractSigned);
      expect(liveCommitment.isDeleted, isFalse);

      final tombstonedCommitment = roundTripped.budgetCommitments.firstWhere(
        (row) => row.id == "commitment-2",
      );
      expect(tombstonedCommitment.dueDate, isNull);
      expect(tombstonedCommitment.isDeleted, isTrue);
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
        roleCandidates: [],
        budgetPostes: [],
        budgetLines: [],
        budgetEntries: [],
        budgetCommitments: [],
        budgetResources: [],
        budgetMileageRates: [],
        budgetRevenues: [],
        budgetShares: [],
        budgetAllowances: [],
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
        projectDictionaryWords: [],
        rowFieldVersions: [],
        pageSetup: OcptPageSetup.standard(),
        settingsJson: null,
        currencyCode: null,
        minimumRestMinutes: null,
        screenplayLanguage: null,
        shootingBlockCandidates: [],
        defaultVatRateBasisPoints: null,
        mealPriceCents: null,
        snackPriceCents: null,
        isBudgetSimplified: null,
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
        roleCandidates: payload.roleCandidates.reversed.toList(),
        budgetPostes: payload.budgetPostes.reversed.toList(),
        budgetLines: payload.budgetLines.reversed.toList(),
        budgetEntries: payload.budgetEntries.reversed.toList(),
        budgetCommitments: payload.budgetCommitments.reversed.toList(),
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords.reversed.toList(),
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      // Two states differing only in which episodes name a role are not the same project: a
      // digest that left `role_episodes` out would let the working-copy card claim no drift after
      // an afternoon spent saying, episode by episode, who speaks where.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewLink)));
    });

    test('changes when a candidate is added', () {
      // A week of casting moves no other table at all until somebody is retained, so a digest
      // blind to this one would let the working-copy card claim no drift after exactly the work
      // `role_candidates` exists to hold.
      final payload = buildRichPayload();
      final withNewCandidate = OcptProjectVersionPayload(
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
        roleCandidates: [
          ...payload.roleCandidates,
          const OcptRoleCandidateRow(
            id: "role-candidate-3",
            roleId: "role-2",
            personId: "person-2",
            status: OcptRoleCandidateStatus.shortlisted,
            notes: "",
            sortKey: "t",
            isDeleted: false,
          ),
        ],
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      // Two states differing only in which episodes name a role are not the same project: a
      // digest that left `role_episodes` out would let the working-copy card claim no drift after
      // an afternoon spent saying, episode by episode, who speaks where.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewCandidate)));
    });

    test("changes when a candidate's status changes", () {
      final payload = buildRichPayload();
      final withOtherStatuses = OcptProjectVersionPayload(
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
        roleCandidates: [
          for (final row in payload.roleCandidates)
            row.copyWith(status: OcptRoleCandidateStatus.shortlisted),
        ],
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      // Two states differing only in which episodes name a role are not the same project: a
      // digest that left `role_episodes` out would let the working-copy card claim no drift after
      // an afternoon spent saying, episode by episode, who speaks where.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withOtherStatuses)));
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewGuest)));
    });

    // A whole casting day is planned by writing rows of this one table: a payload that left it
    // out would let the working-copy card claim no drift after exactly the work it holds.
    test('changes when a candidate is named on an audition block', () {
      final payload = buildRichPayload();
      final withNewCandidate = OcptProjectVersionPayload(
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
        roleCandidates: payload.roleCandidates,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: [
          ...payload.shootingBlockCandidates,
          const OcptShootingBlockCandidateRow(
            id: "block-candidate-3",
            blockId: "block-3",
            roleCandidateId: "role-candidate-2",
            sortKey: "p",
            notes: "",
            isDeleted: false,
          ),
        ],
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewCandidate)));
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: OcptPageSetup(
          format: OcptPageFormat.usLetter,
          margins: payload.pageSetup.margins,
        ),
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: "USD",
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: 720,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: OcptScreenplayLanguage.enGb,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(relanguaged)));
    });

    test('changes when the learned words differ', () {
      final payload = buildRichPayload();
      final relearned = OcptProjectVersionPayload(
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: [
          ...payload.projectDictionaryWords,
          const OcptProjectDictionaryWordRow(id: "word-3", word: "Julien", isDeleted: false),
        ],
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
      );

      // Two projects agreeing on everything else but disagreeing on what the checker has been
      // taught are not the same project: a digest that left the lexicon out would let the
      // working-copy card claim no drift after a whole afternoon of teaching it names.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(relearned)));
    });

    test('changes when a budget poste is renamed', () {
      final payload = buildRichPayload();
      final renamed = OcptProjectVersionPayload(
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
        budgetPostes: [
          payload.budgetPostes.first.copyWith(label: "Personnel technique"),
          payload.budgetPostes.last,
        ],
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        roleCandidates: payload.roleCandidates,
        shootingBlockCandidates: payload.shootingBlockCandidates,
      );

      // A digest that left the budget out would let the working-copy card claim no drift after an
      // afternoon spent building the quote.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(renamed)));
    });

    test("changes when a budget poste's estimate to complete changes", () {
      final payload = buildRichPayload();
      final adjusted = OcptProjectVersionPayload(
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
        budgetPostes: [
          payload.budgetPostes.first.copyWith(
            estimateToCompleteCents: const drift.Value(90000),
          ),
          payload.budgetPostes.last,
        ],
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        roleCandidates: payload.roleCandidates,
        shootingBlockCandidates: payload.shootingBlockCandidates,
      );

      // Two projects agreeing on every quote line but disagreeing on what a human now expects a
      // poste to end up costing are not the same project: a digest that left the column out would
      // let the working-copy card claim no drift after a real cost report's own adjustment.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(adjusted)));
    });

    test('changes when a budget line is tombstoned', () {
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
        budgetPostes: payload.budgetPostes,
        budgetLines: [
          payload.budgetLines.first.copyWith(isDeleted: true),
          payload.budgetLines.last,
        ],
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        roleCandidates: payload.roleCandidates,
        shootingBlockCandidates: payload.shootingBlockCandidates,
      );

      expect(codec.contentDigest(payload), isNot(codec.contentDigest(tombstoned)));
    });

    test('changes when the default VAT rate changes', () {
      final payload = buildRichPayload();
      final rerated = OcptProjectVersionPayload(
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
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        defaultVatRateBasisPoints: 550,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
        roleCandidates: payload.roleCandidates,
        shootingBlockCandidates: payload.shootingBlockCandidates,
      );

      // Two projects agreeing on every quote line but disagreeing on the rate they read against are
      // not the same project.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(rerated)));
    });

    test('changes when a journal entry is added', () {
      final payload = buildRichPayload();
      final withNewEntry = OcptProjectVersionPayload(
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
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: [
          ...payload.budgetEntries,
          OcptBudgetEntryRow(
            id: "entry-3",
            sortKey: "m",
            isDeleted: false,
            date: DateTime.utc(2026, 3, 12),
            label: "Acompte",
            debitCents: 0,
            creditCents: 50000,
            isTaxInclusive: true,
            voucherNumber: "J-002",
          ),
        ],
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        roleCandidates: payload.roleCandidates,
        shootingBlockCandidates: payload.shootingBlockCandidates,
      );

      // A digest that left the journal out would let the working-copy card claim no drift after an
      // afternoon spent recording the cash journal.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(withNewEntry)));
    });

    test('changes when an entry stops naming the commitment it pays', () {
      final payload = buildRichPayload();
      final unsettled = OcptProjectVersionPayload(
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
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: [
          payload.budgetEntries.first.copyWith(commitmentId: const drift.Value(null)),
          ...payload.budgetEntries.skip(1),
        ],
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
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
        roleCandidates: payload.roleCandidates,
        shootingBlockCandidates: payload.shootingBlockCandidates,
      );

      // A digest that left an entry's own commitmentId out would let a settlement — or the lack of
      // one — go unnoticed.
      expect(codec.contentDigest(payload), isNot(codec.contentDigest(unsettled)));
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
        roleCandidates: payload.roleCandidates,
        budgetPostes: payload.budgetPostes,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
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
        projectDictionaryWords: payload.projectDictionaryWords,
        rowFieldVersions: payload.rowFieldVersions,
        pageSetup: payload.pageSetup,
        settingsJson: payload.settingsJson,
        currencyCode: payload.currencyCode,
        minimumRestMinutes: payload.minimumRestMinutes,
        screenplayLanguage: payload.screenplayLanguage,
        shootingBlockCandidates: payload.shootingBlockCandidates,
        defaultVatRateBasisPoints: payload.defaultVatRateBasisPoints,
        mealPriceCents: payload.mealPriceCents,
        snackPriceCents: payload.snackPriceCents,
        isBudgetSimplified: payload.isBudgetSimplified,
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

    test('a payload written in the current format decodes with no upgrade step', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value, buildRichPayload());
    });
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

    test('an element row missing its status is refused, not defaulted', () {
      // elements.status is read strictly: a payload missing the column is malformed, never
      // silently defaulted.
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["elements"] as List).first as Map<String, dynamic>).remove("status");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });
  });
}
