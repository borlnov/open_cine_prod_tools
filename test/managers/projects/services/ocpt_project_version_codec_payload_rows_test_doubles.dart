// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// The `sceneBreakdowns` rows of the payload `buildRichPayload` builds.
List<OcptSceneBreakdownRow> richSceneBreakdowns() => const [
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
];

/// The `shootingDays` rows of the payload `buildRichPayload` builds.
List<OcptShootingDayRow> richShootingDays() => [
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
];

/// The `shootingSlots` rows of the payload `buildRichPayload` builds.
List<OcptShootingSlotRow> richShootingSlots() => const [
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
];

/// The `shootingSlotCrew` rows of the payload `buildRichPayload` builds.
List<OcptShootingSlotCrewRow> richShootingSlotCrew() => const [
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
];

/// The `shootingSlotCast` rows of the payload `buildRichPayload` builds.
List<OcptShootingSlotCastRow> richShootingSlotCast() => const [
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
];

/// The `shootingDayBlocks` rows of the payload `buildRichPayload` builds.
List<OcptShootingDayBlockRow> richShootingDayBlocks() => const [
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
];

/// The `shootingSlotGuests` rows of the payload `buildRichPayload` builds.
List<OcptShootingSlotGuestRow> richShootingSlotGuests() => const [
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
];

/// The `shootingDayEvents` rows of the payload `buildRichPayload` builds.
List<OcptShootingDayEventRow> richShootingDayEvents() => const [
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
];

/// The `projectDictionaryWords` rows of the payload `buildRichPayload` builds.
List<OcptProjectDictionaryWordRow> richProjectDictionaryWords() => const [
  OcptProjectDictionaryWordRow(id: "word-1", word: "Séquence", isDeleted: false),
  OcptProjectDictionaryWordRow(id: "word-2", word: "Marc", isDeleted: true),
];

/// The `budgetPostes` rows of the payload `buildRichPayload` builds.
List<OcptBudgetPosteRow> richBudgetPostes() => const [
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
];

/// The `budgetLines` rows of the payload `buildRichPayload` builds.
List<OcptBudgetLineRow> richBudgetLines() => const [
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
];

/// The `budgetEntries` rows of the payload `buildRichPayload` builds.
List<OcptBudgetEntryRow> richBudgetEntries() => [
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
];

/// The `budgetCommitments` rows of the payload `buildRichPayload` builds.
List<OcptBudgetCommitmentRow> richBudgetCommitments() => [
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
];

/// The `budgetResources` rows of the payload `buildRichPayload` builds.
List<OcptBudgetResourceRow> richBudgetResources() => const [
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
];

/// The `budgetMileageRates` rows of the payload `buildRichPayload` builds.
List<OcptBudgetMileageRateRow> richBudgetMileageRates() => const [
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
];

/// The `budgetRevenues` rows of the payload `buildRichPayload` builds.
List<OcptBudgetRevenueRow> richBudgetRevenues() => [
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
];

/// The `budgetShares` rows of the payload `buildRichPayload` builds.
List<OcptBudgetShareRow> richBudgetShares() => const [
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
];

/// The `budgetAllowances` rows of the payload `buildRichPayload` builds.
List<OcptBudgetAllowanceRow> richBudgetAllowances() => [
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
];

/// The `storyboardPanels` rows of the payload `buildRichPayload` builds.
List<OcptStoryboardPanelRow> richStoryboardPanels() => const [
  OcptStoryboardPanelRow(
    id: "panel-1",
    shotId: "shot-1",
    sortKey: "V",
    imageAssetId: "asset-4",
    comment: "Wide establishing",
    isDeleted: false,
  ),
  // No image imported yet, and a tombstone: a panel outlives its image, and a removed panel
  // is a row like any other.
  OcptStoryboardPanelRow(
    id: "panel-2",
    shotId: "shot-1",
    sortKey: "k",
    comment: "",
    isDeleted: true,
  ),
];

/// The `storyboardAnnotations` rows of the payload `buildRichPayload` builds.
List<OcptStoryboardAnnotationRow> richStoryboardAnnotations() => const [
  OcptStoryboardAnnotationRow(
    id: "annotation-1",
    panelId: "panel-1",
    kind: OcptStoryboardAnnotationKind.movementArrow,
    sortKey: "V",
    x1: 0.1,
    y1: 0.2,
    x2: 0.8,
    y2: 0.75,
    labelText: "dolly in",
    isDeleted: false,
  ),
  OcptStoryboardAnnotationRow(
    id: "annotation-2",
    panelId: "panel-1",
    kind: OcptStoryboardAnnotationKind.label,
    sortKey: "k",
    x1: 0.5,
    y1: 0.5,
    x2: 0,
    y2: 0,
    labelText: "",
    isDeleted: true,
  ),
];

/// The `floorPlanSets` rows of the payload `buildRichPayload` builds.
List<OcptFloorPlanSetRow> richFloorPlanSets() => const [
  OcptFloorPlanSetRow(
    id: "case-1",
    underlayAssetId: "asset-5",
    underlayXM: 1.2,
    underlayYM: 0.8,
    underlayWidthM: 4,
    underlayHeightM: 3,
    underlayRotationDeg: 15,
    isDeleted: false,
  ),
  // No underlay placed yet, and a tombstone.
  OcptFloorPlanSetRow(id: "case-2", isDeleted: true),
];

/// The `floorPlanSymbols` rows of the payload `buildRichPayload` builds.
List<OcptFloorPlanSymbolRow> richFloorPlanSymbols() => const [
  // A set-scope symbol: sceneId/shotId both null, a footprint of its own, a set-element shape.
  OcptFloorPlanSymbolRow(
    id: "symbol-1",
    setId: "case-1",
    layer: OcptFloorPlanLayer.set,
    sortKey: "V",
    xM: 0.5,
    yM: 0.5,
    rotationDeg: 0,
    widthM: 5,
    heightM: 4,
    label: "North wall",
    setElementShape: OcptFloorPlanSetElementShape.wall,
    isHidden: false,
    isDeleted: false,
  ),
  // A shot-scope symbol: shotId set, a field-of-view wedge instead of a footprint, no
  // set-element shape — a camera symbol doesn't use it.
  OcptFloorPlanSymbolRow(
    id: "symbol-2",
    setId: "case-1",
    shotId: "shot-1",
    layer: OcptFloorPlanLayer.cameras,
    sortKey: "k",
    xM: 1.5,
    yM: 2,
    rotationDeg: 45,
    fovDeg: 84,
    fovReachM: 6,
    label: "85mm",
    isHidden: false,
    isDeleted: false,
  ),
  // A shot-scope symbol, tombstoned.
  OcptFloorPlanSymbolRow(
    id: "symbol-3",
    setId: "case-1",
    shotId: "shot-1",
    layer: OcptFloorPlanLayer.characters,
    sortKey: "m",
    xM: 2,
    yM: 2,
    rotationDeg: 0,
    label: "",
    isHidden: false,
    isDeleted: true,
  ),
  // A scene-scope override symbol: sceneId set, no shotId, replacing symbol-1 in scene-1,
  // masking it for that one sequence (isHidden) — the round trip of the
  // `isHidden` column.
  OcptFloorPlanSymbolRow(
    id: "symbol-4",
    setId: "case-1",
    sceneId: "scene-1",
    layer: OcptFloorPlanLayer.set,
    sortKey: "w",
    xM: 0.6,
    yM: 0.6,
    rotationDeg: 0,
    widthM: 5,
    heightM: 4,
    label: "North wall, re-dressed",
    setElementShape: OcptFloorPlanSetElementShape.wall,
    overridesSymbolId: "symbol-1",
    isHidden: true,
    isDeleted: false,
  ),
];

/// The `floorPlanArrows` rows of the payload `buildRichPayload` builds.
List<OcptFloorPlanArrowRow> richFloorPlanArrows() => const [
  // A curved arrow: a bezier control point of its own.
  OcptFloorPlanArrowRow(
    id: "arrow-1",
    setId: "case-1",
    shotId: "shot-1",
    kind: OcptFloorPlanArrowKind.movement,
    fromSymbolId: "symbol-2",
    toSymbolId: "symbol-3",
    label: "walks in",
    ctrlXM: 1.1,
    ctrlYM: 1.6,
    isDeleted: false,
  ),
  // A straight arrow: no control point, tombstoned.
  OcptFloorPlanArrowRow(
    id: "arrow-2",
    setId: "case-1",
    shotId: "shot-1",
    kind: OcptFloorPlanArrowKind.cameraMove,
    fromSymbolId: "symbol-2",
    toSymbolId: "symbol-3",
    label: "",
    isDeleted: true,
  ),
];

/// The `rowFieldVersions` rows of the payload `buildRichPayload` builds.
List<OcptRowFieldVersionRow> richRowFieldVersions() => const [
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
];

/// The `shootingBlockCandidates` rows of the payload `buildRichPayload` builds.
List<OcptShootingBlockCandidateRow> richShootingBlockCandidates() => const [
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
];
