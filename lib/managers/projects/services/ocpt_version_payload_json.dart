// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_budget_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_resources_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_schedule_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_shot_list_json.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// Build a payload out of the JSON object a version's row stores: every table's rows through its
/// own parser, and the two settings objects.
///
/// The walk is `OcptProjectVersionCodec.decode`'s: it never throws on a bad field, it records the
/// first one in `OcptVersionJsonReader` and answers neutral values so the walk can finish.
abstract final class OcptVersionPayloadJson {
  /// Build the payload described by [json], written at [payloadFormat].
  ///
  /// [payloadFormat] drives two branches. For `payloadFormat < 3`, `shotCharacters` is read as
  /// empty rather than through [OcptVersionShotListJson.shotCharacterFromJson] — a pre-3 payload's
  /// rows are shaped around the retired `characterName` column, not `roleId`, and cannot be parsed
  /// as format 3's shape at all (`OcptProjectVersionCodec.decode`'s own doc comment). For
  /// `payloadFormat < 4`, the five storyboard and floor plan lists are read as empty rather than
  /// through [OcptVersionJsonReader.readRows]: unlike every other field, whose absent keys already
  /// fall back to the nullable defaults [OcptVersionJsonReader.readNullableString] and its siblings
  /// return, [OcptVersionJsonReader.readRows] itself fails on a missing key (it reads a required
  /// list, not an optional scalar), so a pre-4 payload — which never wrote these five keys at all —
  /// needs this one explicit default rather than reading through unguarded, exactly as
  /// `shotCharacters` does one format earlier. Every other field is read the same way whatever
  /// [payloadFormat] says.
  static OcptProjectVersionPayload fromJson(
    Map<String, dynamic> json, {
    required int payloadFormat,
  }) {
    final projectSettings = OcptVersionJsonReader.readObject(
      json,
      OcptVersionJsonKeys.projectSettingsKey,
    );
    final pageMargins = OcptVersionJsonReader.readObject(json, OcptVersionJsonKeys.pageMarginsKey);

    return OcptProjectVersionPayload(
      screenplays: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.screenplaysKey))
          OcptVersionShotListJson.screenplayFromJson(row),
      ],
      scenes: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.scenesKey))
          OcptVersionShotListJson.sceneFromJson(row),
      ],
      shots: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.shotsKey))
          OcptVersionShotListJson.shotFromJson(row),
      ],
      shotCharacters: payloadFormat < 3
          ? const []
          : [
              for (final row in OcptVersionJsonReader.readRows(
                json,
                OcptVersionJsonKeys.shotCharactersKey,
              ))
                OcptVersionShotListJson.shotCharacterFromJson(row),
            ],
      shotCoverages: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shotCoveragesKey,
        ))
          OcptVersionShotListJson.shotCoverageFromJson(row),
      ],
      people: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.peopleKey))
          OcptVersionResourcesJson.personFromJson(row),
      ],
      personPositions: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.personPositionsKey,
        ))
          OcptVersionResourcesJson.personPositionFromJson(row),
      ],
      personSkills: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.personSkillsKey))
          OcptVersionResourcesJson.personSkillFromJson(row),
      ],
      personUnavailabilities: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.personUnavailabilitiesKey,
        ))
          OcptVersionResourcesJson.personUnavailabilityFromJson(row),
      ],
      roles: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.rolesKey))
          OcptVersionResourcesJson.roleFromJson(row),
      ],
      roleEpisodes: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.roleEpisodesKey))
          OcptVersionResourcesJson.roleEpisodeFromJson(row),
      ],
      locations: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.locationsKey))
          OcptVersionResourcesJson.locationFromJson(row),
      ],
      locationAvailabilities: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.locationAvailabilitiesKey,
        ))
          OcptVersionResourcesJson.locationAvailabilityFromJson(row),
      ],
      sets: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.setsKey))
          OcptVersionResourcesJson.setFromJson(row),
      ],
      sceneSets: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.sceneSetsKey))
          OcptVersionResourcesJson.sceneSetFromJson(row),
      ],
      elements: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.elementsKey))
          OcptVersionResourcesJson.elementFromJson(row),
      ],
      sceneElements: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.sceneElementsKey,
        ))
          OcptVersionResourcesJson.sceneElementFromJson(row),
      ],
      roleElements: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.roleElementsKey))
          OcptVersionResourcesJson.roleElementFromJson(row),
      ],
      roleCandidates: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.roleCandidatesKey,
        ))
          OcptVersionResourcesJson.roleCandidateFromJson(row),
      ],
      assets: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.assetsKey))
          OcptVersionResourcesJson.assetFromJson(row),
      ],
      breakdownTags: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.breakdownTagsKey,
        ))
          OcptVersionScheduleJson.breakdownTagFromJson(row),
      ],
      sceneBreakdowns: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.sceneBreakdownsKey,
        ))
          OcptVersionScheduleJson.sceneBreakdownFromJson(row),
      ],
      shootingDays: [
        for (final row in OcptVersionJsonReader.readRows(json, OcptVersionJsonKeys.shootingDaysKey))
          OcptVersionScheduleJson.shootingDayFromJson(row),
      ],
      shootingSlots: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingSlotsKey,
        ))
          OcptVersionScheduleJson.shootingSlotFromJson(row),
      ],
      shootingSlotCrew: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingSlotCrewKey,
        ))
          OcptVersionScheduleJson.shootingSlotCrewFromJson(row),
      ],
      shootingSlotCast: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingSlotCastKey,
        ))
          OcptVersionScheduleJson.shootingSlotCastFromJson(row),
      ],
      shootingDayBlocks: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingDayBlocksKey,
        ))
          OcptVersionScheduleJson.shootingDayBlockFromJson(row),
      ],
      shootingSlotGuests: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingSlotGuestsKey,
        ))
          OcptVersionScheduleJson.shootingSlotGuestFromJson(row),
      ],
      shootingBlockCandidates: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingBlockCandidatesKey,
        ))
          OcptVersionScheduleJson.shootingBlockCandidateFromJson(row),
      ],
      shootingDayEvents: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.shootingDayEventsKey,
        ))
          OcptVersionScheduleJson.shootingDayEventFromJson(row),
      ],
      projectDictionaryWords: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.projectDictionaryWordsKey,
        ))
          OcptVersionResourcesJson.projectDictionaryWordFromJson(row),
      ],
      budgetPostes: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetPostesKey,
        ))
          OcptVersionBudgetJson.budgetPosteFromJson(row),
      ],
      budgetLines: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetLinesKey,
        ))
          OcptVersionBudgetJson.budgetLineFromJson(row),
      ],
      budgetEntries: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetEntriesKey,
        ))
          OcptVersionBudgetJson.budgetEntryFromJson(row),
      ],
      budgetCommitments: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetCommitmentsKey,
        ))
          OcptVersionBudgetJson.budgetCommitmentFromJson(row),
      ],
      budgetResources: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetResourcesKey,
        ))
          OcptVersionBudgetJson.budgetResourceFromJson(row),
      ],
      budgetMileageRates: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetMileageRatesKey,
        ))
          OcptVersionBudgetJson.budgetMileageRateFromJson(row),
      ],
      budgetRevenues: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetRevenuesKey,
        ))
          OcptVersionBudgetJson.budgetRevenueFromJson(row),
      ],
      budgetShares: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetSharesKey,
        ))
          OcptVersionBudgetJson.budgetShareFromJson(row),
      ],
      budgetAllowances: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonProductionKeys.budgetAllowancesKey,
        ))
          OcptVersionBudgetJson.budgetAllowanceFromJson(row),
      ],
      storyboardPanels: payloadFormat < 4
          ? const []
          : [
              for (final row in OcptVersionJsonReader.readRows(
                json,
                OcptVersionJsonProductionKeys.storyboardPanelsKey,
              ))
                OcptVersionShotListJson.storyboardPanelFromJson(row),
            ],
      storyboardAnnotations: payloadFormat < 4
          ? const []
          : [
              for (final row in OcptVersionJsonReader.readRows(
                json,
                OcptVersionJsonProductionKeys.storyboardAnnotationsKey,
              ))
                OcptVersionShotListJson.storyboardAnnotationFromJson(row),
            ],
      floorPlanSets: payloadFormat < 4
          ? const []
          : [
              for (final row in OcptVersionJsonReader.readRows(
                json,
                OcptVersionJsonProductionKeys.floorPlanSetsKey,
              ))
                OcptVersionShotListJson.floorPlanSetFromJson(row),
            ],
      floorPlanSymbols: payloadFormat < 4
          ? const []
          : [
              for (final row in OcptVersionJsonReader.readRows(
                json,
                OcptVersionJsonProductionKeys.floorPlanSymbolsKey,
              ))
                OcptVersionShotListJson.floorPlanSymbolFromJson(row),
            ],
      floorPlanArrows: payloadFormat < 4
          ? const []
          : [
              for (final row in OcptVersionJsonReader.readRows(
                json,
                OcptVersionJsonProductionKeys.floorPlanArrowsKey,
              ))
                OcptVersionShotListJson.floorPlanArrowFromJson(row),
            ],
      rowFieldVersions: [
        for (final row in OcptVersionJsonReader.readRows(
          json,
          OcptVersionJsonKeys.rowFieldVersionsKey,
        ))
          OcptVersionResourcesJson.rowFieldVersionFromJson(row),
      ],
      pageSetup: OcptPageSetup(
        format: OcptVersionJsonReader.readEnum(
          projectSettings,
          OcptVersionJsonProductionKeys.pageFormatKey,
          OcptPageFormat.values.asNameMap(),
        ),
        margins: FountainPageMargins(
          leftInches: OcptVersionJsonReader.readDouble(
            pageMargins,
            OcptVersionJsonProductionKeys.marginLeftKey,
          ),
          rightInches: OcptVersionJsonReader.readDouble(
            pageMargins,
            OcptVersionJsonProductionKeys.marginRightKey,
          ),
          topInches: OcptVersionJsonReader.readDouble(
            pageMargins,
            OcptVersionJsonProductionKeys.marginTopKey,
          ),
          bottomInches: OcptVersionJsonReader.readDouble(
            pageMargins,
            OcptVersionJsonProductionKeys.marginBottomKey,
          ),
        ),
      ),
      settingsJson: OcptVersionJsonReader.readNullableString(
        projectSettings,
        OcptVersionJsonProductionKeys.settingsJsonKey,
      ),
      currencyCode: OcptVersionJsonReader.readNullableString(
        projectSettings,
        OcptVersionJsonProductionKeys.currencyCodeKey,
      ),
      minimumRestMinutes: OcptVersionJsonReader.readNullableInt(
        projectSettings,
        OcptVersionJsonProductionKeys.minimumRestMinutesKey,
      ),
      screenplayLanguage: OcptVersionJsonReader.readNullableEnum(
        projectSettings,
        OcptVersionJsonProductionKeys.screenplayLanguageKey,
        OcptScreenplayLanguage.values.asNameMap(),
      ),
      defaultVatRateBasisPoints: OcptVersionJsonReader.readNullableInt(
        projectSettings,
        OcptVersionJsonProductionKeys.defaultVatRateBasisPointsKey,
      ),
      mealPriceCents: OcptVersionJsonReader.readNullableInt(
        projectSettings,
        OcptVersionJsonProductionKeys.mealPriceCentsKey,
      ),
      snackPriceCents: OcptVersionJsonReader.readNullableInt(
        projectSettings,
        OcptVersionJsonProductionKeys.snackPriceCentsKey,
      ),
      isBudgetSimplified: OcptVersionJsonReader.readNullableBool(
        projectSettings,
        OcptVersionJsonProductionKeys.isBudgetSimplifiedKey,
      ),
    );
  }
}
