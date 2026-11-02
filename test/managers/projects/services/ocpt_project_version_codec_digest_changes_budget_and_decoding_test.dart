// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'ocpt_project_version_codec_test_doubles.dart';

/// Run the tests of the project version codec digest changes budget and decoding.
void main() {
  // The codec logs through appLogger(), which requires a global manager instance to be set; merely
  // accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec(logger: SilentLogger());

  group('OcptProjectVersionCodec contentDigest', () {
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
        budgetAccounts: payload.budgetAccounts,
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
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
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
        budgetAccounts: payload.budgetAccounts,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
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
        budgetAccounts: payload.budgetAccounts,
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
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
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
        budgetAccounts: payload.budgetAccounts,
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
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
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
        budgetAccounts: payload.budgetAccounts,
        budgetLines: payload.budgetLines,
        budgetEntries: payload.budgetEntries,
        budgetCommitments: payload.budgetCommitments,
        budgetResources: payload.budgetResources,
        budgetMileageRates: payload.budgetMileageRates,
        budgetRevenues: payload.budgetRevenues,
        budgetShares: payload.budgetShares,
        budgetAllowances: payload.budgetAllowances,
        storyboardPanels: payload.storyboardPanels,
        storyboardAnnotations: payload.storyboardAnnotations,
        floorPlanSets: payload.floorPlanSets,
        floorPlanSymbols: payload.floorPlanSymbols,
        floorPlanArrows: payload.floorPlanArrows,
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
      final result = codec.decode(encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value, buildRichPayload());
    });

    test('a retired payload-format-1 budgetLines row, written before inKindResourceId existed, '
        'decodes with a null inKindResourceId', () {
      // Format 1 is the shape 0.1.0 froze: `budget_lines.inKindResourceId` did not exist yet, so
      // a real format-1 payload's `budgetLines` rows carry no such key at all, rather than the
      // key present with a null value. This is the fixture the codec's own doc comment asks to be
      // kept once a stable release has frozen a format the next one moves past.
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      encoded["payloadFormat"] = 1;
      encoded["budgetLines"] = [
        for (final row in encoded["budgetLines"] as List)
          (Map<String, dynamic>.from(row as Map<String, dynamic>)..remove("inKindResourceId")),
      ];

      final result = codec.decode(jsonEncode(encoded));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value!.budgetLines.map((row) => row.inKindResourceId), everyElement(isNull));
    });

    test('a retired payload-format-2 payload decodes with its shot_characters dropped, not '
        'remapped to roles', () {
      // Format 2 is the shape 0.2.0 froze: `shot_characters` was still keyed by the retired
      // `characterName` column, not `roleId`
      // (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`) — a reshape, not an
      // addition, so a pre-3 payload's rows cannot be read as format 3's shape at all. Remapping
      // names to roles on restore was considered and turned down (this class's own doc comment,
      // and the ADR's "Consequences" section): a version captured before the reshape restores
      // with every plan except its shot list's cast, everything else untouched.
      final rich = buildRichPayload();
      final encoded = jsonDecode(codec.encode(rich)) as Map<String, dynamic>;
      encoded["payloadFormat"] = 2;
      encoded["shotCharacters"] = [
        for (final row in rich.shotCharacters)
          {
            "shotId": row.shotId,
            "characterName": "SOMEONE",
            "position": row.position,
            "sortKey": row.sortKey,
            "isDeleted": row.isDeleted,
          },
      ];

      final result = codec.decode(jsonEncode(encoded));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value!.shotCharacters, isEmpty);
      expect(result.value!.shots, rich.shots);
    });

    test('a retired payload-format-3 payload decodes with the five storyboard and floor plan lists '
        'empty', () {
      // Format 3 is the shape 0.2.1 froze: none of the five storyboard/floor plan keys existed
      // yet, so a real format-3 payload's JSON carries none of them at all, rather than the keys
      // present with an empty list. This is the fixture the codec's own doc comment asks to be
      // kept once a stable release has frozen a format the next one moves past.
      final rich = buildRichPayload();
      final encoded = jsonDecode(codec.encode(rich)) as Map<String, dynamic>;
      encoded["payloadFormat"] = 3;
      encoded
        ..remove("storyboardPanels")
        ..remove("storyboardAnnotations")
        ..remove("floorPlanSets")
        ..remove("floorPlanSymbols")
        ..remove("floorPlanArrows");

      final result = codec.decode(jsonEncode(encoded));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value!.storyboardPanels, isEmpty);
      expect(result.value!.storyboardAnnotations, isEmpty);
      expect(result.value!.floorPlanSets, isEmpty);
      expect(result.value!.floorPlanSymbols, isEmpty);
      expect(result.value!.floorPlanArrows, isEmpty);
      // Nothing else about the payload is disturbed by the missing keys.
      expect(result.value!.shots, rich.shots);
    });

    test('a format-4 payload written before setElementShape/ctrlXM/ctrlYM existed decodes with '
        'those columns null', () {
      // Schema version 4 was still an open development cycle: `setElementShape`, `ctrlXM` and
      // `ctrlYM` were added straight onto the v4 tables rather than through a v5 migration
      // (`OcptFloorPlanSymbolsTable`/`OcptFloorPlanArrowsTable`'s own doc comments), so an
      // already-written format-4 payload's row JSON carries none of the three keys at all,
      // unlike the whole-table-missing case format 3 exercises above.
      final rich = buildRichPayload();
      final encoded = jsonDecode(codec.encode(rich)) as Map<String, dynamic>;
      encoded["floorPlanSymbols"] = [
        for (final row in encoded["floorPlanSymbols"] as List)
          (row as Map<String, dynamic>)..remove("setElementShape"),
      ];
      encoded["floorPlanArrows"] = [
        for (final row in encoded["floorPlanArrows"] as List)
          (row as Map<String, dynamic>)
            ..remove("ctrlXM")
            ..remove("ctrlYM"),
      ];

      final result = codec.decode(jsonEncode(encoded));

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(
        result.value!.floorPlanSymbols.map((row) => row.setElementShape),
        everyElement(isNull),
      );
      expect(result.value!.floorPlanArrows.map((row) => row.ctrlXM), everyElement(isNull));
      expect(result.value!.floorPlanArrows.map((row) => row.ctrlYM), everyElement(isNull));
      // Nothing else about the payload is disturbed by the missing keys.
      expect(result.value!.shots, rich.shots);
    });
  });

  group('OcptProjectVersionCodec malformed payloads', () {
    test("text that isn't JSON at all is refused", () {
      final result = codec.decode("not json");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test('an unknown enum name on an otherwise well-formed payload escapes as an error', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shootingSlots"] as List).first as Map<String, dynamic>)["anchorEdge"] = "x";

      expect(() => codec.decode(jsonEncode(encoded)), throwsArgumentError);
    });

    test('an unknown enum name after a field already found unreadable is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      encoded["screenplays"] = "bad";
      ((encoded["shootingSlots"] as List).first as Map<String, dynamic>)["anchorEdge"] = "x";

      final result = codec.decode(jsonEncode(encoded));

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

    test('a row section holding something other than objects is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      (encoded["shots"] as List).add(42);

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a refusal leaves nothing behind for the next decode', () {
      final good = codec.encode(buildRichPayload());
      final encoded = jsonDecode(good) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>)["status"] = "teleported";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
      expect(codec.decode(good).status, OcptProjectVersionPayloadStatus.ok);
    });
  });
}
