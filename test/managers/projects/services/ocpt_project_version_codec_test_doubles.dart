// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_weekday_mask.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'ocpt_project_version_codec_payload_rows_test_doubles.dart';

/// A payload covering everything the format has to survive: a live row and a tombstoned one in
/// every table, both nullable and non-null columns, both enum columns, the fractional sort keys,
/// and the version stamps of the rows it carries.
///
/// The second row of each table leaves every nullable column at its null default — a scene with
/// no number, an orphaned shot with no scene, no duration, no shooting day, no planned takes and
/// no check reason — so the round trip is exercised on null values as well as on set ones.
OcptProjectVersionPayload buildRichPayload() => OcptProjectVersionPayload(
  screenplays: richScreenplays(),
  scenes: richScenes(),
  shots: richShots(),
  shotCharacters: richShotCharacters(),
  shotCoverages: richShotCoverages(),
  people: richPeople(),
  personPositions: richPersonPositions(),
  personSkills: richPersonSkills(),
  personUnavailabilities: richPersonUnavailabilities(),
  roles: richRoles(),
  roleEpisodes: richRoleEpisodes(),
  locations: richLocations(),
  locationAvailabilities: richLocationAvailabilities(),
  sets: richSets(),
  sceneSets: richSceneSets(),
  elements: richElements(),
  sceneElements: richSceneElements(),
  roleElements: richRoleElements(),
  roleCandidates: richRoleCandidates(),
  assets: richAssets(),
  breakdownTags: richBreakdownTags(),
  sceneBreakdowns: richSceneBreakdowns(),
  shootingDays: richShootingDays(),
  shootingSlots: richShootingSlots(),
  shootingSlotCrew: richShootingSlotCrew(),
  shootingSlotCast: richShootingSlotCast(),
  shootingDayBlocks: richShootingDayBlocks(),
  shootingSlotGuests: richShootingSlotGuests(),
  shootingDayEvents: richShootingDayEvents(),
  projectDictionaryWords: richProjectDictionaryWords(),
  budgetAccounts: richBudgetAccounts(),
  budgetLines: richBudgetLines(),
  budgetEntries: richBudgetEntries(),
  budgetCommitments: richBudgetCommitments(),
  budgetResources: richBudgetResources(),
  budgetMileageRates: richBudgetMileageRates(),
  budgetRevenues: richBudgetRevenues(),
  budgetShares: richBudgetShares(),
  budgetAllowances: richBudgetAllowances(),
  storyboardPanels: richStoryboardPanels(),
  storyboardAnnotations: richStoryboardAnnotations(),
  floorPlanSets: richFloorPlanSets(),
  floorPlanSymbols: richFloorPlanSymbols(),
  floorPlanArrows: richFloorPlanArrows(),
  rowFieldVersions: richRowFieldVersions(),
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
  shootingBlockCandidates: richShootingBlockCandidates(),
  defaultVatRateBasisPoints: 2000,
  mealPriceCents: 1250,
  snackPriceCents: 350,
  isBudgetSimplified: true,
);

/// The `screenplays` rows of the payload [buildRichPayload] builds.
List<OcptScreenplayRow> richScreenplays() => [
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
];

/// The `scenes` rows of the payload [buildRichPayload] builds.
List<OcptSceneRow> richScenes() => const [
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
];

/// The `shots` rows of the payload [buildRichPayload] builds.
List<OcptShotRow> richShots() => const [
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
];

/// The `shotCharacters` rows of the payload [buildRichPayload] builds.
List<OcptShotCharacterRow> richShotCharacters() => const [
  OcptShotCharacterRow(
    shotId: "shot-1",
    roleId: "role-1",
    position: 0,
    sortKey: "V",
    isDeleted: false,
  ),
  OcptShotCharacterRow(
    shotId: "shot-1",
    roleId: "role-2",
    position: 1,
    sortKey: "k",
    isDeleted: true,
  ),
];

/// The `shotCoverages` rows of the payload [buildRichPayload] builds.
List<OcptShotCoverageRow> richShotCoverages() => const [
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
];

/// The `people` rows of the payload [buildRichPayload] builds.
List<OcptPersonRow> richPeople() => [
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
];

/// The `personPositions` rows of the payload [buildRichPayload] builds.
List<OcptPersonPositionRow> richPersonPositions() => const [
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
];

/// The `personSkills` rows of the payload [buildRichPayload] builds.
List<OcptPersonSkillRow> richPersonSkills() => const [
  OcptPersonSkillRow(
    id: "skill-1",
    personId: "person-1",
    label: "Permis B",
    sortKey: "V",
    isDeleted: false,
  ),
  OcptPersonSkillRow(id: "skill-2", personId: "person-1", label: "", sortKey: "k", isDeleted: true),
];

/// The `personUnavailabilities` rows of the payload [buildRichPayload] builds.
List<OcptPersonUnavailabilityRow> richPersonUnavailabilities() => [
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
];

/// The `roles` rows of the payload [buildRichPayload] builds.
List<OcptRoleRow> richRoles() => const [
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
];

/// The `roleEpisodes` rows of the payload [buildRichPayload] builds.
List<OcptRoleEpisodeRow> richRoleEpisodes() => const [
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
];

/// The `locations` rows of the payload [buildRichPayload] builds.
List<OcptLocationRow> richLocations() => [
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
];

/// The `locationAvailabilities` rows of the payload [buildRichPayload] builds.
List<OcptLocationAvailabilityRow> richLocationAvailabilities() => [
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
];

/// The `sets` rows of the payload [buildRichPayload] builds.
List<OcptSetRow> richSets() => const [
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
];

/// The `sceneSets` rows of the payload [buildRichPayload] builds.
List<OcptSceneSetRow> richSceneSets() => const [
  OcptSceneSetRow(id: "scene-set-1", sceneId: "scene-1", setId: "set-1", isDeleted: false),
  OcptSceneSetRow(id: "scene-set-2", sceneId: "scene-2", setId: "set-1", isDeleted: true),
];

/// The `elements` rows of the payload [buildRichPayload] builds.
List<OcptElementRow> richElements() => const [
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
];

/// The `sceneElements` rows of the payload [buildRichPayload] builds.
List<OcptSceneElementRow> richSceneElements() => const [
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
];

/// The `roleElements` rows of the payload [buildRichPayload] builds.
List<OcptRoleElementRow> richRoleElements() => const [
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
];

/// The `roleCandidates` rows of the payload [buildRichPayload] builds.
List<OcptRoleCandidateRow> richRoleCandidates() => [
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
];

/// The `assets` rows of the payload [buildRichPayload] builds.
List<OcptAssetRow> richAssets() => [
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
  // The two storyboard/floor plan kinds set none of the four owner columns: the panel's own
  // imageAssetId and the set's own underlayAssetId are the only link.
  OcptAssetRow(
    id: "asset-4",
    kind: OcptAssetKind.storyboardPanelImage,
    path: "/home/user/Pictures/panel-1.jpg",
    label: "",
    addedAt: DateTime.utc(2026, 4),
    sortKey: "n",
    isDeleted: false,
  ),
  OcptAssetRow(
    id: "asset-5",
    kind: OcptAssetKind.floorPlanUnderlay,
    path: "/home/user/Pictures/kitchen-plan.jpg",
    label: "",
    addedAt: DateTime.utc(2026, 4, 2),
    sortKey: "o",
    isDeleted: false,
  ),
];

/// The `breakdownTags` rows of the payload [buildRichPayload] builds.
List<OcptBreakdownTagRow> richBreakdownTags() => const [
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
];
