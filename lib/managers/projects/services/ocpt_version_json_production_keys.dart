// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';

/// The JSON keys `OcptProjectVersionCodec` writes and reads for the columns of the sets, elements,
/// assets, breakdown, schedule, budget, storyboard, floor plan, dictionary and field version
/// tables.
///
/// Every key is part of the stored format: a version sits in a user's `.ocpt` for as long as the
/// version does, so none of these strings may change. The payload's own structure and the
/// remaining columns are in [OcptVersionJsonKeys].
abstract final class OcptVersionJsonProductionKeys {
  /// This is the key used to stringify or parse a `setId` column (`scene_sets.setId`,
  /// `breakdown_tags.setId`, `shooting_slots.setId` or, from payload format 4,
  /// `floor_plan_symbols.setId`/`floor_plan_arrows.setId` — a different sense of "set" (a
  /// sequence's own floor plan décor rather than the resources catalogue's), but the same key name,
  /// following this codec's own convention of one key per column name across the whole schema) from
  /// a JSON object
  static const setIdKey = "setId";

  /// This is the key used to stringify or parse a `roleId` column
  /// (`breakdown_tags.roleId` — the sibling of [elementIdKey] and [setIdKey], non-null only when
  /// the tag's `targetKind` names a role —, `shooting_slot_cast.roleId`, always non-null, the role
  /// a slot convokes, `role_elements.roleId`, the role wearing an element, or, from payload format
  /// 13, `role_episodes.roleId`, the role an episode names, or, from payload format 16,
  /// `role_candidates.roleId`, the part somebody is seen for, or, from payload format 3,
  /// `shot_characters.roleId`, the role a shot's character is
  /// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`) — replacing that table's
  /// retired `characterName` column) from a JSON object
  static const roleIdKey = "roleId";

  /// This is the key used to stringify or parse an element's `category` column from a JSON object
  static const categoryKey = "category";

  /// This is the key used to stringify or parse an element's `subCategory` column from a JSON
  /// object
  static const subCategoryKey = "subCategory";

  /// This is the key used to stringify or parse a `quantity` column (`elements` or
  /// `scene_elements`) from a JSON object
  static const quantityKey = "quantity";

  /// This is the key used to stringify or parse an element's `sourceKind` column from a JSON object
  static const sourceKindKey = "sourceKind";

  /// This is the key used to stringify or parse an element's `ownerPersonId` column from a JSON
  /// object
  static const ownerPersonIdKey = "ownerPersonId";

  /// This is the key used to stringify or parse an element's `ownerNotes` column from a JSON object
  static const ownerNotesKey = "ownerNotes";

  /// This is the key used to stringify or parse an element's `broughtByPersonId` column from a
  /// JSON object
  static const broughtByPersonIdKey = "broughtByPersonId";

  /// This is the key used to stringify or parse an element's `storageNotes` column from a JSON
  /// object
  static const storageNotesKey = "storageNotes";

  /// This is the key used to stringify or parse an element's `isSecured` column from a JSON object
  static const isSecuredKey = "isSecured";

  /// This is the key used to stringify or parse an element's `isReadyForShoot` column from a JSON
  /// object
  static const isReadyForShootKey = "isReadyForShoot";

  /// This is the key used to stringify or parse an element's `isReturned` column from a JSON object
  static const isReturnedKey = "isReturned";

  /// This is the key used to stringify or parse an element's `cost` column from a JSON object
  static const costKey = "cost";

  /// This is the key used to stringify or parse an element's `purposeNotes` column from a JSON
  /// object
  static const purposeNotesKey = "purposeNotes";

  /// This is the key used to stringify or parse an `elementId` column (`scene_elements.elementId`,
  /// `role_elements.elementId` or `breakdown_tags.elementId`) from a JSON object
  static const elementIdKey = "elementId";

  /// This is the key used to stringify or parse a `budget_lines.inKindResourceId` column from a
  /// JSON object — the in-kind `budget_resources` contribution a quote line is the counterpart of,
  /// null for an ordinary line.
  static const inKindResourceIdKey = "inKindResourceId";

  /// The row key naming what provisioned a `budget_lines` row, null while a human typed it.
  static const provisionKeyKey = "provisionKey";

  /// The row key holding what the provisioning last wrote into a `budget_lines` row.
  static const provisionDigestKey = "provisionDigest";

  /// This is the key used to stringify or parse an asset's `path` column from a JSON object
  static const pathKey = "path";

  /// This is the key used to stringify or parse an asset's `addedAt` column from a JSON object
  static const addedAtKey = "addedAt";

  /// This is the key used to stringify or parse an asset's `validFrom` column from a JSON object
  static const validFromKey = "validFrom";

  /// This is the key used to stringify or parse an asset's `validUntil` column from a JSON object
  static const validUntilKey = "validUntil";

  /// This is the key used to stringify or parse a scene-relative `startOffset` column
  /// (`shot_coverages.startOffset` or `breakdown_tags.startOffset`) from a JSON object
  static const startOffsetKey = "startOffset";

  /// This is the key used to stringify or parse a scene-relative `endOffset` column
  /// (`shot_coverages.endOffset` or `breakdown_tags.endOffset`) from a JSON object
  static const endOffsetKey = "endOffset";

  /// This is the key used to stringify or parse a breakdown tag's `taggedText` column from a JSON
  /// object: the tagged passage, verbatim — unlike the neighbouring `shot_coverages`, which stores
  /// only a digest (see `OcptBreakdownTagsTable`'s own doc comment for why).
  static const taggedTextKey = "taggedText";

  /// This is the key used to stringify or parse a coverage's `coveredTextDigest` column from a JSON
  /// object
  static const coveredTextDigestKey = "coveredTextDigest";

  /// This is the key used to stringify or parse a `shootingDayId` column (`shooting_slots`,
  /// `shooting_day_blocks`, `shooting_presences` or `shooting_day_events`) from a JSON object
  static const shootingDayIdKey = "shootingDayId";

  /// This is the key used to stringify or parse a `slotId` column (`shooting_slot_crew`,
  /// `shooting_slot_cast`, `shooting_day_blocks` or `shooting_slot_guests`) from a JSON object —
  /// the foreign key onto a `shooting_slots` row, not to be confused with
  /// [OcptVersionJsonKeys.slotKey], the day-part enum
  /// `person_unavailabilities`/`location_availabilities` carry.
  static const slotIdKey = "slotId";

  /// This is the key used to stringify or parse a `shooting_days.date` column, or, from payload
  /// format 17, a `budget_entries.date` column, from a JSON object
  static const dateKey = "date";

  /// This is the key used to stringify or parse a `shooting_day_events.minute` column from a JSON
  /// object — the hour it happens at, an offset from the day's own midnight.
  static const minuteKey = "minute";

  /// This is the key used to stringify or parse a `crewNote` column (`shooting_days.crewNote`, the
  /// note for the whole day, or `shooting_day_blocks.crewNote`, one block narrower) from a JSON
  /// object — both printed, unlike [OcptVersionJsonKeys.notesKey], which never is.
  static const crewNoteKey = "crewNote";

  /// This is the key used to stringify or parse a shooting day's `weatherNote` column from a JSON
  /// object
  static const weatherNoteKey = "weatherNote";

  /// This is the key used to stringify or parse a `shooting_day_blocks.durationMinutes` column from
  /// a JSON object
  static const durationMinutesKey = "durationMinutes";

  /// This is the key used to stringify or parse an `anchorMinute` column — a
  /// `shooting_day_blocks`', the minute a block is pinned to, or (from payload format 9) a
  /// `shooting_slots`', the hour its own anchored edge is pinned to — from a JSON object
  static const anchorMinuteKey = "anchorMinute";

  /// This is the key used to stringify or parse a `shooting_slots.anchorEdge` column from a JSON
  /// object
  static const anchorEdgeKey = "anchorEdge";

  /// This is the key used to stringify or parse a `shooting_slots.anchorSlotId` column from a JSON
  /// object — the slot whose opposite edge this one reads its hour off.
  static const anchorSlotIdKey = "anchorSlotId";

  /// This is the key used to stringify or parse a version stamp's `tableName` column from a JSON
  /// object
  static const tableNameKey = "tableName";

  /// This is the key used to stringify or parse a version stamp's `rowId` column from a JSON object
  static const rowIdKey = "rowId";

  /// This is the key used to stringify or parse a version stamp's `columnName` column from a JSON
  /// object
  static const columnNameKey = "columnName";

  /// This is the key used to stringify or parse a version stamp's `version` column from a JSON
  /// object
  static const versionKey = "version";

  /// This is the key used to stringify or parse a version stamp's `deviceId` column from a JSON
  /// object
  static const deviceIdKey = "deviceId";

  /// This is the key used to stringify or parse the project's `pageFormat` from a JSON object
  static const pageFormatKey = "pageFormat";

  /// This is the key used to stringify or parse the project's `currencyCode` from a JSON object
  static const currencyCodeKey = "currencyCode";

  /// This is the key used to stringify or parse the project's `settingsJson` from a JSON object
  static const settingsJsonKey = "settingsJson";

  /// This is the key used to stringify or parse the project's `minimumRestMinutes` from a JSON
  /// object
  static const minimumRestMinutesKey = "minimumRestMinutes";

  /// This is the key used to stringify or parse the project's `screenplayLanguage` from a JSON
  /// object
  static const screenplayLanguageKey = "screenplayLanguage";

  /// This is the key used to stringify or parse the `project_dictionary_words` rows from a JSON
  /// object, from payload format 15: the words a writer has taught this project's spell checker.
  static const projectDictionaryWordsKey = "projectDictionaryWords";

  /// This is the key used to stringify or parse a `project_dictionary_words.word` column from a
  /// JSON object
  static const wordKey = "word";

  /// This is the key used to stringify or parse the `budget_postes` rows from a JSON object, from
  /// payload format 16: the budget mode's own catalogue.
  static const budgetPostesKey = "budgetPostes";

  /// This is the key used to stringify or parse the `budget_lines` rows from a JSON object, from
  /// payload format 16: the quote lines inside each poste.
  static const budgetLinesKey = "budgetLines";

  /// This is the key used to stringify or parse a `budget_postes.simpleLabel` column from a JSON
  /// object
  static const simpleLabelKey = "simpleLabel";

  /// This is the key used to stringify or parse a `budget_postes.estimateToCompleteCents` column
  /// from a JSON object, from payload format 30: what is still expected to be spent on a poste
  /// beyond what has already been paid and committed against it, or absent meaning "derive it".
  static const estimateToCompleteCentsKey = "estimateToCompleteCents";

  /// This is the key used to stringify or parse a `posteId` column (`budget_lines.posteId` or,
  /// from payload format 17, `budget_entries.posteId`/`budget_commitments.posteId`) from a JSON
  /// object
  static const posteIdKey = "posteId";

  /// This is the key used to stringify or parse a `budget_lines.quantityMilli` column from a JSON
  /// object
  static const quantityMilliKey = "quantityMilli";

  /// This is the key used to stringify or parse a `budget_lines.unit` column from a JSON object
  static const unitKey = "unit";

  /// This is the key used to stringify or parse a `budget_lines.unitAmountCents` column from a JSON
  /// object
  static const unitAmountCentsKey = "unitAmountCents";

  /// The row key holding a `budget_allowances` row's own unit price, in thousandths of a cent.
  static const unitAmountMilliCentsKey = "unitAmountMilliCents";

  /// This is the key used to stringify or parse an `isTaxInclusive` column (`budget_lines`'s or,
  /// from payload format 17, `budget_entries`'s/`budget_commitments`'s) from a JSON object
  static const isTaxInclusiveKey = "isTaxInclusive";

  /// This is the key used to stringify or parse a `vatRateBasisPoints` column (`budget_lines`'s or,
  /// from payload format 17, `budget_entries`'s/`budget_commitments`'s) from a JSON object
  static const vatRateBasisPointsKey = "vatRateBasisPoints";

  /// This is the key used to stringify or parse the project's `defaultVatRateBasisPoints` from a
  /// JSON object, from payload format 16
  static const defaultVatRateBasisPointsKey = "defaultVatRateBasisPoints";

  /// This is the key used to stringify or parse the project's `mealPriceCents` from a JSON object,
  /// from payload format 16
  static const mealPriceCentsKey = "mealPriceCents";

  /// This is the key used to stringify or parse the project's `snackPriceCents` from a JSON object,
  /// from payload format 16
  static const snackPriceCentsKey = "snackPriceCents";

  /// This is the key used to stringify or parse the `budget_entries` rows from a JSON object, from
  /// payload format 17: the cash journal's own movements.
  static const budgetEntriesKey = "budgetEntries";

  /// This is the key used to stringify or parse the `budget_commitments` rows from a JSON object,
  /// from payload format 17: money committed against a poste but not yet paid.
  static const budgetCommitmentsKey = "budgetCommitments";

  /// This is the key used to stringify or parse a `budget_entries.debitCents` column from a JSON
  /// object
  static const debitCentsKey = "debitCents";

  /// This is the key used to stringify or parse a `budget_entries.creditCents` column from a JSON
  /// object
  static const creditCentsKey = "creditCents";

  /// This is the key used to stringify or parse a `budget_entries.voucherNumber` column from a JSON
  /// object
  static const voucherNumberKey = "voucherNumber";

  /// This is the key used to stringify or parse a `budget_commitments.dueDate` column from a JSON
  /// object
  static const dueDateKey = "dueDate";

  /// This is the key used to stringify or parse a `budget_commitments.amountCents` column, or, from
  /// payload format 18, a `budget_resources.amountCents` column, from a JSON object
  static const amountCentsKey = "amountCents";

  /// This is the key used to stringify or parse a `budget_entries.commitmentId` column from a JSON
  /// object, from payload format 31: which commitment a debit actually pays.
  static const commitmentIdKey = "commitmentId";

  /// This is the key used to stringify or parse a `budget_commitments.lineId` column from a JSON
  /// object, from payload format 29: the quote line a commitment was promoted from.
  static const commitmentLineIdKey = "lineId";

  /// This is the key used to stringify or parse an `assets.budgetEntryId` column from a JSON
  /// object, from payload format 17: the journal entry a receipt asset is the voucher for.
  static const budgetEntryIdKey = "budgetEntryId";

  /// This is the key used to stringify or parse the `budget_resources` rows from a JSON object,
  /// from payload format 18: the production's financing plan — subsidies, cash and in-kind
  /// contributions.
  static const budgetResourcesKey = "budgetResources";

  /// This is the key used to stringify or parse the `budget_mileage_rates` rows from a JSON object,
  /// from payload format 18: the per-kilometre rates a production names for itself.
  static const budgetMileageRatesKey = "budgetMileageRates";

  /// This is the key used to stringify or parse a `budget_resources.groupKind` column from a JSON
  /// object
  static const groupKindKey = "groupKind";

  /// This is the key used to stringify or parse a `budget_resources.isReimbursable` column from a
  /// JSON object
  static const isReimbursableKey = "isReimbursable";

  /// This is the key used to stringify or parse a `budget_mileage_rates.ratePerKmMilliCents`
  /// column from a JSON object
  static const ratePerKmMilliCentsKey = "ratePerKmMilliCents";

  /// This is the key used to stringify or parse a `budget_entries.resourceId` column from a JSON
  /// object, from payload format 18: which financing resource a movement settles.
  static const resourceIdKey = "resourceId";

  /// This is the key used to stringify or parse a person's `commuteKmMilli` column from a JSON
  /// object, from payload format 18: their own one-way commute to set.
  static const commuteKmMilliKey = "commuteKmMilli";

  /// This is the key used to stringify or parse a person's `mileageRateId` column from a JSON
  /// object, from payload format 18: which of the project's own rates applies to them.
  static const mileageRateIdKey = "mileageRateId";

  /// This is the key used to stringify or parse the `budget_revenues` rows from a JSON object,
  /// from payload format 19: the takings the production expects.
  static const budgetRevenuesKey = "budgetRevenues";

  /// This is the key used to stringify or parse the `budget_shares` rows from a JSON object, from
  /// payload format 19: the participants splitting what the takings bring in.
  static const budgetSharesKey = "budgetShares";

  /// The payload key holding every `budget_allowances` row.
  static const budgetAllowancesKey = "budgetAllowances";

  /// This is the key used to stringify or parse a `budget_shares.sharePermille` column from a JSON
  /// object
  static const sharePermilleKey = "sharePermille";

  /// This is the key used to stringify or parse the project's `isBudgetSimplified` from a JSON
  /// object, from payload format 25: the budget mode's simplified/detailed header toggle.
  static const isBudgetSimplifiedKey = "isBudgetSimplified";

  /// This is the key used to stringify or parse a `budget_shares.reinvestPermille` column from a
  /// JSON object
  static const reinvestPermilleKey = "reinvestPermille";

  /// This is the key used to stringify or parse a `budget_entries.revenueId` column from a JSON
  /// object, from payload format 19: which taking a credit is the actual cash for.
  static const revenueIdKey = "revenueId";

  /// This is the key used to stringify or parse a `budget_entries.shareId` column from a JSON
  /// object, from payload format 19: which participant a debit actually pays.
  static const shareIdKey = "shareId";

  /// This is the key used to stringify or parse the `storyboard_panels` rows from a JSON object,
  /// from payload format 4: a shot's ordered storyboard frames.
  static const storyboardPanelsKey = "storyboardPanels";

  /// This is the key used to stringify or parse the `storyboard_annotations` rows from a JSON
  /// object, from payload format 4: the marks drawn over a panel's frame.
  static const storyboardAnnotationsKey = "storyboardAnnotations";

  /// This is the key used to stringify or parse the `floor_plan_sets` rows from a JSON object,
  /// from payload format 4: a sequence's floor plan décors.
  static const floorPlanSetsKey = "floorPlanSets";

  /// This is the key used to stringify or parse the `floor_plan_symbols` rows from a JSON object,
  /// from payload format 4: the symbols placed on a floor plan case.
  static const floorPlanSymbolsKey = "floorPlanSymbols";

  /// This is the key used to stringify or parse the `floor_plan_arrows` rows from a JSON object,
  /// from payload format 4: the movement and camera-move arrows drawn between two floor plan
  /// symbols.
  static const floorPlanArrowsKey = "floorPlanArrows";

  /// This is the key used to stringify or parse a `storyboard_panels.imageAssetId` column from a
  /// JSON object, from payload format 4.
  static const imageAssetIdKey = "imageAssetId";

  /// This is the key used to stringify or parse a `storyboard_panels.comment` column from a JSON
  /// object, from payload format 4.
  static const commentKey = "comment";

  /// This is the key used to stringify or parse a `storyboard_annotations.panelId` column from a
  /// JSON object, from payload format 4.
  static const panelIdKey = "panelId";

  /// This is the key used to stringify or parse an `x1` column (`storyboard_annotations`', a mark's
  /// first end, normalised 0..1 to the frame) from a JSON object, from payload format 4.
  static const x1Key = "x1";

  /// This is the key used to stringify or parse a `storyboard_annotations.y1` column from a JSON
  /// object, from payload format 4. See [x1Key].
  static const y1Key = "y1";

  /// This is the key used to stringify or parse a `storyboard_annotations.x2` column from a JSON
  /// object, from payload format 4. See [x1Key].
  static const x2Key = "x2";

  /// This is the key used to stringify or parse a `storyboard_annotations.y2` column from a JSON
  /// object, from payload format 4. See [x1Key].
  static const y2Key = "y2";

  /// This is the key used to stringify or parse a `storyboard_annotations.text` column from a JSON
  /// object, from payload format 4 — a label's own words, or an arrow's optional caption.
  static const textKey = "text";

  /// This is the key used to stringify or parse a `floor_plan_sets.underlayAssetId` column from a
  /// JSON object, from payload format 4. `floor_plan_sets.id` is `sets.id` (see
  /// `OcptFloorPlanSetsTable`'s own doc comment) and reuses [OcptVersionJsonKeys.idKey] directly,
  /// so this row carries no `sceneId`/`name`/`sortKey` of its own any more.
  static const underlayAssetIdKey = "underlayAssetId";

  /// This is the key used to stringify or parse a `floor_plan_sets.underlayXM` column from a JSON
  /// object, from payload format 4 — the underlay's own frame, in metres.
  static const underlayXMKey = "underlayXM";

  /// This is the key used to stringify or parse a `floor_plan_sets.underlayYM` column from a JSON
  /// object, from payload format 4. See [underlayXMKey].
  static const underlayYMKey = "underlayYM";

  /// This is the key used to stringify or parse a `floor_plan_sets.underlayWidthM` column from a
  /// JSON object, from payload format 4. See [underlayXMKey].
  static const underlayWidthMKey = "underlayWidthM";

  /// This is the key used to stringify or parse a `floor_plan_sets.underlayHeightM` column from a
  /// JSON object, from payload format 4. See [underlayXMKey].
  static const underlayHeightMKey = "underlayHeightM";

  /// This is the key used to stringify or parse a `floor_plan_sets.underlayRotationDeg` column
  /// from a JSON object, from payload format 4. See [underlayXMKey].
  static const underlayRotationDegKey = "underlayRotationDeg";

  /// This is the key used to stringify or parse a `floor_plan_symbols.layer` column from a JSON
  /// object, from payload format 4 — its own key rather than a reuse of
  /// [OcptVersionJsonKeys.kindKey], for the same reason [OcptVersionJsonKeys.targetKindKey] has its
  /// own: a symbol's `layer` describes which of the floor plan's two scopes it belongs to, a
  /// distinct enough idea from what [OcptVersionJsonKeys.kindKey] already serves elsewhere.
  static const layerKey = "layer";

  /// This is the key used to stringify or parse an `xM` column (`floor_plan_symbols`', a symbol's
  /// own centre, in metres) from a JSON object, from payload format 4.
  static const xMKey = "xM";

  /// This is the key used to stringify or parse a `floor_plan_symbols.yM` column from a JSON
  /// object, from payload format 4. See [xMKey].
  static const yMKey = "yM";

  /// This is the key used to stringify or parse a `floor_plan_symbols.rotationDeg` column from a
  /// JSON object, from payload format 4.
  static const rotationDegKey = "rotationDeg";

  /// This is the key used to stringify or parse a `floor_plan_symbols.widthM` column from a JSON
  /// object, from payload format 4 — a set element's footprint width; null on every other layer.
  static const widthMKey = "widthM";

  /// This is the key used to stringify or parse a `floor_plan_symbols.heightM` column from a JSON
  /// object, from payload format 4. See [widthMKey].
  static const heightMKey = "heightM";

  /// This is the key used to stringify or parse a `floor_plan_symbols.fovDeg` column from a JSON
  /// object, from payload format 4 — a camera's field-of-view wedge; null meaning the drawing's own
  /// default.
  static const fovDegKey = "fovDeg";

  /// This is the key used to stringify or parse a `floor_plan_symbols.setElementShape` column from
  /// a JSON object, from payload format 4 — a set element's visual primitive; null on every camera,
  /// character and light symbol. Added while schema version 4 was still an open development cycle,
  /// so a payload written before this column existed carries no such key at all: read back through
  /// [OcptVersionJsonReader.readNullableEnum], which already tolerates that as null, the same as
  /// every other nullable field this codec reads.
  static const setElementShapeKey = "setElementShape";

  /// This is the key used to stringify or parse a `floor_plan_symbols.isHidden` column from a JSON
  /// object, from payload format 4 — meaningful only on a scene-scope override; see
  /// `OcptFloorPlanSymbolsTable`'s own doc comment. Added while schema version 4 was still an open
  /// development cycle: unlike [setElementShapeKey] and its own siblings, this column is **not**
  /// nullable (its own SQL default is `false`), so an older format-4 payload with no such key reads
  /// back through [OcptVersionJsonReader.readBoolWithFalseDefault] rather than
  /// [OcptVersionJsonReader.readBool], which would otherwise throw on it.
  static const isHiddenKey = "isHidden";

  /// This is the key used to stringify or parse a `floor_plan_symbols.fovReachM` column from a
  /// JSON object, from payload format 4 — a camera's field-of-view wedge reach, in metres; null
  /// meaning the drawing's own default. Added while schema version 4 was still an open development
  /// cycle: see [setElementShapeKey]'s own doc comment for what that means for an older format-4
  /// payload.
  static const fovReachMKey = "fovReachM";

  /// This is the key used to stringify or parse a `floor_plan_symbols.overridesSymbolId` column
  /// from a JSON object, from payload format 4 — the live set-scope symbol a scene-scope override
  /// replaces; null for every other symbol. Added while schema version 4 was still an open
  /// development cycle: see [setElementShapeKey]'s own doc comment for what that means for an
  /// older format-4 payload.
  static const overridesSymbolIdKey = "overridesSymbolId";

  /// This is the key used to stringify or parse a `floor_plan_arrows.fromSymbolId` column from a
  /// JSON object, from payload format 4.
  static const fromSymbolIdKey = "fromSymbolId";

  /// This is the key used to stringify or parse a `floor_plan_arrows.toSymbolId` column from a JSON
  /// object, from payload format 4.
  static const toSymbolIdKey = "toSymbolId";

  /// This is the key used to stringify or parse a `floor_plan_arrows.ctrlXM` column from a JSON
  /// object, from payload format 4 — a curved arrow's bezier control point X, in metres; null
  /// meaning a straight arrow. Added while schema version 4 was still an open development cycle:
  /// see [setElementShapeKey]'s own doc comment for what that means for an older format-4 payload.
  static const ctrlXMKey = "ctrlXM";

  /// This is the key used to stringify or parse a `floor_plan_arrows.ctrlYM` column from a JSON
  /// object, from payload format 4. See [ctrlXMKey].
  static const ctrlYMKey = "ctrlYM";

  /// This is the key used to stringify or parse the left page margin from a JSON object
  static const marginLeftKey = "leftInches";

  /// This is the key used to stringify or parse the right page margin from a JSON object
  static const marginRightKey = "rightInches";

  /// This is the key used to stringify or parse the top page margin from a JSON object
  static const marginTopKey = "topInches";

  /// This is the key used to stringify or parse the bottom page margin from a JSON object
  static const marginBottomKey = "bottomInches";
}
