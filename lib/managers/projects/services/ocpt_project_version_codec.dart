// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'dart:convert';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:crypto/crypto.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_budget_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_production_keys.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_json_reader.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_payload_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_resources_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_schedule_json.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_version_shot_list_json.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';

/// The single place that knows the shape of `project_versions.payload`: it turns an
/// [OcptProjectVersionPayload] into the JSON text stored in a version's row, and back.
///
/// Reading the rows out of a project and writing them back into one is
/// `OcptProjectVersionsService`'s job; this class never touches a database. What it owns is the
/// **format**, and the format outlives the app build that wrote it: a payload sits in a user's
/// `.ocpt` for as long as the version does, so [decode] is written as a migration path rather than
/// only a guard, ready for the day a stable release has actually shipped one —
///
/// - a payload written in an **older** format would be upgraded, in memory, step by step, up to
/// [currentPayloadFormat]; the stored text is never rewritten, so a version stays byte-identical to
/// what was captured. The 0.1.0 release froze the first such format at 1; the 0.2.0 release froze
/// format 2 in turn, added for `budget_lines.inKindResourceId` (`docs/architecture/budget.md`) —
/// additive and nullable, so a format-1 payload, missing the key outright, already decodes through
/// the very same [OcptVersionJsonReader.readNullableString] read a format-2 one does, with no
/// dedicated upgrade step to write. The 0.2.1 release froze format 3, the first that **isn't**
/// additive: `shot_characters` drops `characterName` for `roleId`
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), so a pre-3 payload's
/// `shotCharacters` rows cannot be reshaped into roles the way a project's live database is
/// migrated — [decode] drops them instead, a version captured before the reshape restoring with
/// every plan except its shot list's cast (this class's own [decode] doc comment, and the ADR's
/// "Consequences" section, spell out why remapping was turned down). The 0.3.0 release froze format
/// 4, which adds the storyboard and floor plan tables — additive, so a pre-4 payload decodes with
/// its five new lists empty. The retired format-1, format-2 and format-3 shapes are pinned in
/// `test/managers/projects/services/ocpt_project_version_codec_digest_changes_budget_and_decoding_test.dart`,
/// per the guidance below;
/// - a payload written in a **newer** format — the file has been opened by a later build of the
///   app — is refused with [OcptProjectVersionPayloadStatus.unsupportedFutureFormat] rather than
///   half-restored.
///
/// The column lists below are a **hand-written mirror of the schema**: a synchronised table gaining
/// a column means this codec, and very probably [currentPayloadFormat], need looking at. When that
/// day comes, once a stable release has frozen [lastStablePayloadFormat], add a named upgrade step
/// and keep a fixture of the retired format in the tests — the point of the format field is lost if
/// nothing ever exercises the old branch.
class OcptProjectVersionCodec extends AbsOcptService {
  /// The payload format this build writes, and the highest one it can read.
  ///
  /// Deliberately **independent of the database's schema version**: the two evolve for different
  /// reasons and a payload is read long after the file it lives in has been migrated.
  ///
  /// A payload format owes the same promise a schema version does, and [currentPayloadFormat] /
  /// [lastStablePayloadFormat] drive the same overwrite-vs-create rule
  /// [OcptProjectDatabase.currentSchemaVersion]'s own doc comment states
  /// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`): when
  /// `currentPayloadFormat == lastStablePayloadFormat`, the format is frozen, so a change to what
  /// [encode] writes bumps [currentPayloadFormat] and adds a fresh upgrade step for [decode]; when
  /// `currentPayloadFormat == lastStablePayloadFormat + 1`, a development cycle is already open, so
  /// a change is folded into the current format in place instead. [currentPayloadFormat] is always
  /// one of those two values. Freezing a stable release sets
  /// `lastStablePayloadFormat = currentPayloadFormat`, done at release prep alongside the schema's
  /// own freeze.
  static const currentPayloadFormat = 4;

  /// The highest payload format a stable release has frozen.
  ///
  /// See [currentPayloadFormat]'s own doc comment for the overwrite-vs-create rule these two
  /// constants drive together.
  static const lastStablePayloadFormat = 4;

  /// Class constructor
  const OcptProjectVersionCodec({required super.logger});

  /// Serializes [payload] into the JSON text stored in `project_versions.payload`, stamped with
  /// [currentPayloadFormat].
  String encode(OcptProjectVersionPayload payload) => jsonEncode({
    OcptVersionJsonKeys.payloadFormatKey: currentPayloadFormat,
    OcptVersionJsonKeys.screenplaysKey: [
      for (final row in payload.screenplays) OcptVersionShotListJson.screenplayToJson(row),
    ],
    OcptVersionJsonKeys.scenesKey: [
      for (final row in payload.scenes) OcptVersionShotListJson.sceneToJson(row),
    ],
    OcptVersionJsonKeys.shotsKey: [
      for (final row in payload.shots) OcptVersionShotListJson.shotToJson(row),
    ],
    OcptVersionJsonKeys.shotCharactersKey: [
      for (final row in payload.shotCharacters) OcptVersionShotListJson.shotCharacterToJson(row),
    ],
    OcptVersionJsonKeys.shotCoveragesKey: [
      for (final row in payload.shotCoverages) OcptVersionShotListJson.shotCoverageToJson(row),
    ],
    OcptVersionJsonKeys.peopleKey: [
      for (final row in payload.people) OcptVersionResourcesJson.personToJson(row),
    ],
    OcptVersionJsonKeys.personPositionsKey: [
      for (final row in payload.personPositions) OcptVersionResourcesJson.personPositionToJson(row),
    ],
    OcptVersionJsonKeys.personSkillsKey: [
      for (final row in payload.personSkills) OcptVersionResourcesJson.personSkillToJson(row),
    ],
    OcptVersionJsonKeys.personUnavailabilitiesKey: [
      for (final row in payload.personUnavailabilities)
        OcptVersionResourcesJson.personUnavailabilityToJson(row),
    ],
    OcptVersionJsonKeys.rolesKey: [
      for (final row in payload.roles) OcptVersionResourcesJson.roleToJson(row),
    ],
    OcptVersionJsonKeys.roleEpisodesKey: [
      for (final row in payload.roleEpisodes) OcptVersionResourcesJson.roleEpisodeToJson(row),
    ],
    OcptVersionJsonKeys.locationsKey: [
      for (final row in payload.locations) OcptVersionResourcesJson.locationToJson(row),
    ],
    OcptVersionJsonKeys.locationAvailabilitiesKey: [
      for (final row in payload.locationAvailabilities)
        OcptVersionResourcesJson.locationAvailabilityToJson(row),
    ],
    OcptVersionJsonKeys.setsKey: [
      for (final row in payload.sets) OcptVersionResourcesJson.setToJson(row),
    ],
    OcptVersionJsonKeys.sceneSetsKey: [
      for (final row in payload.sceneSets) OcptVersionResourcesJson.sceneSetToJson(row),
    ],
    OcptVersionJsonKeys.elementsKey: [
      for (final row in payload.elements) OcptVersionResourcesJson.elementToJson(row),
    ],
    OcptVersionJsonKeys.sceneElementsKey: [
      for (final row in payload.sceneElements) OcptVersionResourcesJson.sceneElementToJson(row),
    ],
    OcptVersionJsonKeys.roleElementsKey: [
      for (final row in payload.roleElements) OcptVersionResourcesJson.roleElementToJson(row),
    ],
    OcptVersionJsonKeys.roleCandidatesKey: [
      for (final row in payload.roleCandidates) OcptVersionResourcesJson.roleCandidateToJson(row),
    ],
    OcptVersionJsonKeys.assetsKey: [
      for (final row in payload.assets) OcptVersionResourcesJson.assetToJson(row),
    ],
    OcptVersionJsonKeys.breakdownTagsKey: [
      for (final row in payload.breakdownTags) OcptVersionScheduleJson.breakdownTagToJson(row),
    ],
    OcptVersionJsonKeys.sceneBreakdownsKey: [
      for (final row in payload.sceneBreakdowns) OcptVersionScheduleJson.sceneBreakdownToJson(row),
    ],
    OcptVersionJsonKeys.shootingDaysKey: [
      for (final row in payload.shootingDays) OcptVersionScheduleJson.shootingDayToJson(row),
    ],
    OcptVersionJsonKeys.shootingSlotsKey: [
      for (final row in payload.shootingSlots) OcptVersionScheduleJson.shootingSlotToJson(row),
    ],
    OcptVersionJsonKeys.shootingSlotCrewKey: [
      for (final row in payload.shootingSlotCrew)
        OcptVersionScheduleJson.shootingSlotCrewToJson(row),
    ],
    OcptVersionJsonKeys.shootingSlotCastKey: [
      for (final row in payload.shootingSlotCast)
        OcptVersionScheduleJson.shootingSlotCastToJson(row),
    ],
    OcptVersionJsonKeys.shootingDayBlocksKey: [
      for (final row in payload.shootingDayBlocks)
        OcptVersionScheduleJson.shootingDayBlockToJson(row),
    ],
    OcptVersionJsonKeys.shootingSlotGuestsKey: [
      for (final row in payload.shootingSlotGuests)
        OcptVersionScheduleJson.shootingSlotGuestToJson(row),
    ],
    OcptVersionJsonKeys.shootingBlockCandidatesKey: [
      for (final row in payload.shootingBlockCandidates)
        OcptVersionScheduleJson.shootingBlockCandidateToJson(row),
    ],
    OcptVersionJsonKeys.shootingDayEventsKey: [
      for (final row in payload.shootingDayEvents)
        OcptVersionScheduleJson.shootingDayEventToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetPostesKey: [
      for (final row in payload.budgetPostes) OcptVersionBudgetJson.budgetPosteToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetLinesKey: [
      for (final row in payload.budgetLines) OcptVersionBudgetJson.budgetLineToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetEntriesKey: [
      for (final row in payload.budgetEntries) OcptVersionBudgetJson.budgetEntryToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetCommitmentsKey: [
      for (final row in payload.budgetCommitments)
        OcptVersionBudgetJson.budgetCommitmentToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetResourcesKey: [
      for (final row in payload.budgetResources) OcptVersionBudgetJson.budgetResourceToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetMileageRatesKey: [
      for (final row in payload.budgetMileageRates)
        OcptVersionBudgetJson.budgetMileageRateToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetRevenuesKey: [
      for (final row in payload.budgetRevenues) OcptVersionBudgetJson.budgetRevenueToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetSharesKey: [
      for (final row in payload.budgetShares) OcptVersionBudgetJson.budgetShareToJson(row),
    ],
    OcptVersionJsonProductionKeys.budgetAllowancesKey: [
      for (final row in payload.budgetAllowances) OcptVersionBudgetJson.budgetAllowanceToJson(row),
    ],
    OcptVersionJsonProductionKeys.storyboardPanelsKey: [
      for (final row in payload.storyboardPanels)
        OcptVersionShotListJson.storyboardPanelToJson(row),
    ],
    OcptVersionJsonProductionKeys.storyboardAnnotationsKey: [
      for (final row in payload.storyboardAnnotations)
        OcptVersionShotListJson.storyboardAnnotationToJson(row),
    ],
    OcptVersionJsonProductionKeys.floorPlanSetsKey: [
      for (final row in payload.floorPlanSets) OcptVersionShotListJson.floorPlanSetToJson(row),
    ],
    OcptVersionJsonProductionKeys.floorPlanSymbolsKey: [
      for (final row in payload.floorPlanSymbols)
        OcptVersionShotListJson.floorPlanSymbolToJson(row),
    ],
    OcptVersionJsonProductionKeys.floorPlanArrowsKey: [
      for (final row in payload.floorPlanArrows) OcptVersionShotListJson.floorPlanArrowToJson(row),
    ],
    OcptVersionJsonProductionKeys.projectDictionaryWordsKey: [
      for (final row in payload.projectDictionaryWords)
        OcptVersionResourcesJson.projectDictionaryWordToJson(row),
    ],
    OcptVersionJsonKeys.rowFieldVersionsKey: [
      for (final row in payload.rowFieldVersions)
        OcptVersionResourcesJson.rowFieldVersionToJson(row),
    ],
    OcptVersionJsonKeys.projectSettingsKey: {
      OcptVersionJsonProductionKeys.pageFormatKey: payload.pageSetup.format.name,
      OcptVersionJsonProductionKeys.settingsJsonKey: payload.settingsJson,
      OcptVersionJsonProductionKeys.currencyCodeKey: payload.currencyCode,
      OcptVersionJsonProductionKeys.minimumRestMinutesKey: payload.minimumRestMinutes,
      OcptVersionJsonProductionKeys.screenplayLanguageKey: payload.screenplayLanguage?.name,
      OcptVersionJsonProductionKeys.defaultVatRateBasisPointsKey: payload.defaultVatRateBasisPoints,
      OcptVersionJsonProductionKeys.mealPriceCentsKey: payload.mealPriceCents,
      OcptVersionJsonProductionKeys.snackPriceCentsKey: payload.snackPriceCents,
      OcptVersionJsonProductionKeys.isBudgetSimplifiedKey: payload.isBudgetSimplified,
    },
    OcptVersionJsonKeys.pageMarginsKey: {
      OcptVersionJsonProductionKeys.marginLeftKey: payload.pageSetup.margins.leftInches,
      OcptVersionJsonProductionKeys.marginRightKey: payload.pageSetup.margins.rightInches,
      OcptVersionJsonProductionKeys.marginTopKey: payload.pageSetup.margins.topInches,
      OcptVersionJsonProductionKeys.marginBottomKey: payload.pageSetup.margins.bottomInches,
    },
  });

  /// Parses [payloadJson], the text stored in `project_versions.payload`.
  ///
  /// Format 3 is the first to actually need an upgrade step: it drops `characterName` from
  /// `shot_characters` in favour of `roleId`
  /// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), a reshape rather than an
  /// addition, so a pre-3 payload's `shotCharacters` rows cannot be read as format 3's shape at all
  /// — `OcptVersionPayloadJson.fromJson` drops them outright for `payloadFormat < 3` rather than
  /// remapping their names to roles, deliberately (see this class's own doc comment and the ADR): a
  /// version captured before the reshape restores with every plan except its shot list's cast.
  /// Every other upgrade so far has been additive-only, so an older payload already decodes through
  /// the very same nullable readers a current one does, with nothing to branch on here.
  ///
  /// Never throws: every failure comes back as an [OcptProjectVersionPayloadStatus], because the
  /// caller of a decode is always about to tell the user why a version can't be opened.
  ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload> decode(
    String payloadJson,
  ) {
    OcptVersionJsonReader.reset();
    ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload> result;
    try {
      result = _decodeUnguarded(payloadJson);
    } on FormatException catch (error, stackTrace) {
      if (OcptVersionJsonReader.firstReadFailure != null) {
        result = _malformed(null);
      } else {
        // A JSON error quotes the text around the fault, which is the user's own content.
        logger.e(
          "The project version payload isn't valid JSON: ${error.runtimeType}",
          null,
          stackTrace,
        );
        result = const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
      }
    } catch (_) {
      // Once a field read has failed, the readers hand back neutral values so the rest of the
      // payload can be walked; anything that then trips over one is that same malformed payload.
      if (OcptVersionJsonReader.firstReadFailure != null) {
        result = _malformed(null);
      } else {
        rethrow;
      }
    } finally {
      OcptVersionJsonReader.reset();
    }

    return result;
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
  ///   `locations`, `sets`, `sceneSets`, `elements`, `sceneElements`, `roleElements`,
  ///   `roleCandidates`, `assets`, `breakdownTags`, `sceneBreakdowns`, `shootingDays`,
  ///   `shootingSlots`, `shootingSlotCrew`, `shootingSlotCast`, `shootingDayBlocks`,
  ///   `shootingSlotGuests`, `shootingBlockCandidates`, `shootingDayEvents`,
  ///   `projectDictionaryWords`, `budgetPostes`, `budgetLines`, `budgetEntries`,
  ///   `budgetCommitments`, `budgetResources`, `budgetMileageRates`, `budgetRevenues`,
  ///   `budgetShares` — every column of each — plus `pageSetup.format`, `settingsJson` and
  ///   `currencyCode`. This is "the project", as a user would describe it, and the resources tables
  ///   are not optional here: leave them out and two states differing only in their people,
  ///   locations or elements would hash identically — the working-copy card would claim no drift
  ///   after an afternoon of typing resources in, and a restore would skip the safety version it
  ///   promised to keep. `roleEpisodes` is the same case in miniature, from payload format 13 on:
  ///   two states differing only in which episodes name a role are not the same project — a
  ///   character cut from episode 2 but kept in episode 3 is a real edit — and leaving the link
  ///   table out would let the working-copy card claim no drift after an afternoon spent saying,
  ///   episode by episode, who speaks where. The breakdown tables are exactly the same case: leave
  ///   them out and an afternoon spent tagging the script, or marking scenes done, would hash
  ///   identically to a screenplay nobody has ever broken down. The six schedule tables are the
  ///   same case again: leave them out and planning a whole shoot — a day added, a slot crewed, a
  ///   shot placed onto a block — would hash identically to a project nobody has ever scheduled, so
  ///   the working-copy card would claim no drift and a restore over that afternoon's work would
  ///   skip the safety version it owes. `shootingSlotGuests` and `shootingDayEvents` are the same
  ///   case again: leave them out and entering the mayor lending a square, or the fireworks nobody
  ///   controls, would hash identically to a day carrying neither. `projectDictionaryWords` is the
  ///   same case once more, from payload format 15 on: leave it out and a word learned, or
  ///   un-learned, since the version was captured would hash identically to a project whose lexicon
  ///   never changed — the working-copy card would claim no drift, and a restore that is about to
  ///   silently un-teach a word would skip the safety version it owes for it. `roleCandidates` is
  ///   the same case again, from payload format 16 on, and a costly one to get wrong: a whole week
  ///   of casting — twelve people seen, noted and ranked for one part — moves no other table at all
  ///   until somebody is retained, so leaving it out would let the working-copy card claim no drift
  ///   after exactly the work this table exists to hold. `currencyCode` is only ever null on a
  ///   payload decoded from a format predating it (never on one freshly captured from a live
  ///   database, which always reads a real value), so this never makes an old and a current capture
  ///   of the very same project disagree; `minimumRestMinutes` is different — it is null exactly as
  ///   often on a live capture as on an old one, since the column is nullable by design — but it
  ///   stays **in**, not out alongside the margins: two projects agreeing on every shooting day but
  ///   disagreeing on the rest they owe between them are not the same project, and leaving it out
  ///   would hide that; `screenplayLanguage` is the same case again, for the same reason: two
  ///   projects agreeing on everything else but disagreeing on the language their screenplays are
  ///   written in are not the same project — one of them would be spell-checked and the other would
  ///   not — so it stays in, null exactly as legitimately as `minimumRestMinutes`. `budgetPostes`
  ///   and `budgetLines` are the same case once more, from payload format 16 on: leave them out and
  ///   a whole quote typed in would hash identically to a project with no budget at all — the
  ///   working-copy card would claim no drift, and a restore over that afternoon's work would skip
  ///   the safety version it owes. `defaultVatRateBasisPoints`, `mealPriceCents` and
  ///   `snackPriceCents` are `minimumRestMinutes`'s own case again: nullable by design, in rather
  ///   than out alongside the margins, since two projects agreeing on every quote line but
  ///   disagreeing on the rate or the catering prices they read against are not the same project.
  ///   `budgetEntries` and `budgetCommitments` are the quote's own case yet again, from payload
  ///   format 17 on: leave them out and a whole afternoon spent recording the cash journal, or the
  ///   commitments still owed, would hash identically to a project with no movement in its account
  ///   at all. `budgetResources` and `budgetMileageRates` are the very same case once more, from
  ///   payload format 18 on: leave them out and a whole financing plan typed in — a subsidy applied
  ///   for, a rate named for the crew's own car — would hash identically to a project with no
  ///   financing plan at all, the working-copy card claiming no drift and a restore over that
  ///   afternoon's work skipping the safety version it owes. `budgetRevenues` and `budgetShares`
  ///   are the same case once more again, from payload format 19 on: leave them out and a whole
  ///   sharing plan typed in — a taking recorded, a participant's share agreed — would hash
  ///   identically to a project with no sharing plan at all, the working-copy card claiming no
  ///   drift and a restore over that afternoon's work skipping the safety version it owes.
  ///   `isBudgetSimplified` is `minimumRestMinutes`'s own case once more, from payload format 25
  ///   on: nullable by design, in rather than out alongside the margins, since two projects
  ///   agreeing on every figure but disagreeing on which of the header's two views they were last
  ///   left on are not the same project. `budget_resources.personId` needs no entry of its own
  ///   here: it is a column of `budgetResources`, already in above. `storyboardPanels`,
  ///   `storyboardAnnotations`, `floorPlanSets`, `floorPlanSymbols` and `floorPlanArrows` are the
  ///   same case once more, from payload format 4 on: leave them out and a whole storyboard drawn,
  ///   or a floor plan placed, would hash identically to a shot list nobody has ever boarded — the
  ///   working-copy card claiming no drift and a restore over that work skipping the safety version
  ///   it owes;
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
      OcptVersionJsonKeys.screenplaysKey: _canonicalRows(
        payload.screenplays,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.screenplayToJson,
      ),
      OcptVersionJsonKeys.scenesKey: _canonicalRows(
        payload.scenes,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.sceneToJson,
      ),
      OcptVersionJsonKeys.shotsKey: _canonicalRows(
        payload.shots,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.shotToJson,
      ),
      OcptVersionJsonKeys.shotCharactersKey: _canonicalRows(
        payload.shotCharacters,
        primaryKeyOf: (row) => ocptCompositeRowStampKey([row.shotId, row.roleId]),
        toJson: OcptVersionShotListJson.shotCharacterToJson,
      ),
      OcptVersionJsonKeys.shotCoveragesKey: _canonicalRows(
        payload.shotCoverages,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.shotCoverageToJson,
      ),
      OcptVersionJsonKeys.peopleKey: _canonicalRows(
        payload.people,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.personToJson,
      ),
      OcptVersionJsonKeys.personPositionsKey: _canonicalRows(
        payload.personPositions,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.personPositionToJson,
      ),
      OcptVersionJsonKeys.personSkillsKey: _canonicalRows(
        payload.personSkills,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.personSkillToJson,
      ),
      OcptVersionJsonKeys.personUnavailabilitiesKey: _canonicalRows(
        payload.personUnavailabilities,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.personUnavailabilityToJson,
      ),
      OcptVersionJsonKeys.rolesKey: _canonicalRows(
        payload.roles,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.roleToJson,
      ),
      OcptVersionJsonKeys.roleEpisodesKey: _canonicalRows(
        payload.roleEpisodes,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.roleEpisodeToJson,
      ),
      OcptVersionJsonKeys.locationsKey: _canonicalRows(
        payload.locations,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.locationToJson,
      ),
      OcptVersionJsonKeys.locationAvailabilitiesKey: _canonicalRows(
        payload.locationAvailabilities,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.locationAvailabilityToJson,
      ),
      OcptVersionJsonKeys.setsKey: _canonicalRows(
        payload.sets,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.setToJson,
      ),
      OcptVersionJsonKeys.sceneSetsKey: _canonicalRows(
        payload.sceneSets,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.sceneSetToJson,
      ),
      OcptVersionJsonKeys.elementsKey: _canonicalRows(
        payload.elements,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.elementToJson,
      ),
      OcptVersionJsonKeys.sceneElementsKey: _canonicalRows(
        payload.sceneElements,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.sceneElementToJson,
      ),
      OcptVersionJsonKeys.roleElementsKey: _canonicalRows(
        payload.roleElements,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.roleElementToJson,
      ),
      OcptVersionJsonKeys.roleCandidatesKey: _canonicalRows(
        payload.roleCandidates,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.roleCandidateToJson,
      ),
      OcptVersionJsonKeys.assetsKey: _canonicalRows(
        payload.assets,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.assetToJson,
      ),
      OcptVersionJsonKeys.breakdownTagsKey: _canonicalRows(
        payload.breakdownTags,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.breakdownTagToJson,
      ),
      OcptVersionJsonKeys.sceneBreakdownsKey: _canonicalRows(
        payload.sceneBreakdowns,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.sceneBreakdownToJson,
      ),
      OcptVersionJsonKeys.shootingDaysKey: _canonicalRows(
        payload.shootingDays,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingDayToJson,
      ),
      OcptVersionJsonKeys.shootingSlotsKey: _canonicalRows(
        payload.shootingSlots,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingSlotToJson,
      ),
      OcptVersionJsonKeys.shootingSlotCrewKey: _canonicalRows(
        payload.shootingSlotCrew,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingSlotCrewToJson,
      ),
      OcptVersionJsonKeys.shootingSlotCastKey: _canonicalRows(
        payload.shootingSlotCast,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingSlotCastToJson,
      ),
      OcptVersionJsonKeys.shootingDayBlocksKey: _canonicalRows(
        payload.shootingDayBlocks,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingDayBlockToJson,
      ),
      OcptVersionJsonKeys.shootingSlotGuestsKey: _canonicalRows(
        payload.shootingSlotGuests,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingSlotGuestToJson,
      ),
      OcptVersionJsonKeys.shootingBlockCandidatesKey: _canonicalRows(
        payload.shootingBlockCandidates,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingBlockCandidateToJson,
      ),
      OcptVersionJsonKeys.shootingDayEventsKey: _canonicalRows(
        payload.shootingDayEvents,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionScheduleJson.shootingDayEventToJson,
      ),
      OcptVersionJsonProductionKeys.projectDictionaryWordsKey: _canonicalRows(
        payload.projectDictionaryWords,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionResourcesJson.projectDictionaryWordToJson,
      ),
      OcptVersionJsonProductionKeys.budgetPostesKey: _canonicalRows(
        payload.budgetPostes,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetPosteToJson,
      ),
      OcptVersionJsonProductionKeys.budgetLinesKey: _canonicalRows(
        payload.budgetLines,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetLineToJson,
      ),
      OcptVersionJsonProductionKeys.budgetEntriesKey: _canonicalRows(
        payload.budgetEntries,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetEntryToJson,
      ),
      OcptVersionJsonProductionKeys.budgetCommitmentsKey: _canonicalRows(
        payload.budgetCommitments,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetCommitmentToJson,
      ),
      OcptVersionJsonProductionKeys.budgetResourcesKey: _canonicalRows(
        payload.budgetResources,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetResourceToJson,
      ),
      OcptVersionJsonProductionKeys.budgetMileageRatesKey: _canonicalRows(
        payload.budgetMileageRates,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetMileageRateToJson,
      ),
      OcptVersionJsonProductionKeys.budgetRevenuesKey: _canonicalRows(
        payload.budgetRevenues,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetRevenueToJson,
      ),
      OcptVersionJsonProductionKeys.budgetSharesKey: _canonicalRows(
        payload.budgetShares,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetShareToJson,
      ),
      OcptVersionJsonProductionKeys.budgetAllowancesKey: _canonicalRows(
        payload.budgetAllowances,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionBudgetJson.budgetAllowanceToJson,
      ),
      OcptVersionJsonProductionKeys.storyboardPanelsKey: _canonicalRows(
        payload.storyboardPanels,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.storyboardPanelToJson,
      ),
      OcptVersionJsonProductionKeys.storyboardAnnotationsKey: _canonicalRows(
        payload.storyboardAnnotations,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.storyboardAnnotationToJson,
      ),
      OcptVersionJsonProductionKeys.floorPlanSetsKey: _canonicalRows(
        payload.floorPlanSets,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.floorPlanSetToJson,
      ),
      OcptVersionJsonProductionKeys.floorPlanSymbolsKey: _canonicalRows(
        payload.floorPlanSymbols,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.floorPlanSymbolToJson,
      ),
      OcptVersionJsonProductionKeys.floorPlanArrowsKey: _canonicalRows(
        payload.floorPlanArrows,
        primaryKeyOf: (row) => row.id,
        toJson: OcptVersionShotListJson.floorPlanArrowToJson,
      ),
      OcptVersionJsonProductionKeys.pageFormatKey: payload.pageSetup.format.name,
      OcptVersionJsonProductionKeys.settingsJsonKey: payload.settingsJson,
      OcptVersionJsonProductionKeys.currencyCodeKey: payload.currencyCode,
      OcptVersionJsonProductionKeys.minimumRestMinutesKey: payload.minimumRestMinutes,
      OcptVersionJsonProductionKeys.screenplayLanguageKey: payload.screenplayLanguage?.name,
      OcptVersionJsonProductionKeys.defaultVatRateBasisPointsKey: payload.defaultVatRateBasisPoints,
      OcptVersionJsonProductionKeys.mealPriceCentsKey: payload.mealPriceCents,
      OcptVersionJsonProductionKeys.snackPriceCentsKey: payload.snackPriceCents,
      OcptVersionJsonProductionKeys.isBudgetSimplifiedKey: payload.isBudgetSimplified,
    };

    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  /// The walk of [decode], whose exceptions [decode] turns into a status: reads [payloadJson] and
  /// answers the status of the first thing found wrong, or the payload itself.
  ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload> _decodeUnguarded(
    String payloadJson,
  ) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      return _malformed("the payload isn't a JSON object");
    }

    final payloadFormat = OcptVersionJsonReader.readInt(
      decoded,
      OcptVersionJsonKeys.payloadFormatKey,
    );
    if (OcptVersionJsonReader.firstReadFailure != null) {
      return _malformed(null);
    }
    if (payloadFormat > currentPayloadFormat) {
      logger.w(
        "The project version payload is written in the format $payloadFormat, while this "
        "build of the app only knows up to $currentPayloadFormat: it was created by a later "
        "version of Open Cine Prod Tools",
      );
      return const ResultWithStatus(
        status: OcptProjectVersionPayloadStatus.unsupportedFutureFormat,
      );
    }

    final payload = OcptVersionPayloadJson.fromJson(decoded, payloadFormat: payloadFormat);
    if (OcptVersionJsonReader.firstReadFailure != null) {
      return _malformed(null);
    }

    return ResultWithStatus(status: OcptProjectVersionPayloadStatus.ok, value: payload);
  }

  /// The [OcptProjectVersionPayloadStatus.malformedPayload] answer, logging [reason] or, when it is
  /// null, the first thing a field reader found wrong.
  ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload> _malformed(
    String? reason,
  ) {
    logger.e(
      "The project version payload can't be read: ${reason ?? OcptVersionJsonReader.firstReadFailure}",
    );
    return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
  }

  /// [rows], sorted by [primaryKeyOf] and each turned into a JSON map (through the same
  /// `OcptVersionShotListJson.screenplayToJson`-shaped serializer [encode] itself uses, so an enum
  /// column comes out as the plain string `jsonEncode` can write rather than the `TypeConverter`'s
  /// own Dart value) whose keys are themselves sorted — the two orderings [contentDigest] needs to
  /// be canonical.
  static List<Map<String, dynamic>> _canonicalRows<D>(
    List<D> rows, {
    required String Function(D row) primaryKeyOf,
    required Map<String, dynamic> Function(D row) toJson,
  }) {
    final sortedRows = [...rows]..sort((a, b) => primaryKeyOf(a).compareTo(primaryKeyOf(b)));

    return [for (final row in sortedRows) SplayTreeMap<String, dynamic>.of(toJson(row))];
  }
}
