// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_shooting_plan_pdf_service_test_doubles.dart';

/// Builds a scene-element link with the few fields these tests read, everything else neutral.
OcptSceneElementLink _buildSceneElementLink({required String id, required String sceneId}) =>
    OcptSceneElementLink(id: id, sceneId: sceneId, quantity: "", notes: "");

/// Builds an element with the few fields these tests read, everything else neutral.
OcptElement _buildElement({
  required String id,
  required String name,
  required String code,
  OcptElementCategory category = OcptElementCategory.prop,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: code,
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: sceneLinks,
  roleLinks: const [],
);

/// Run the tests of the shooting plan pdf service elements and file names.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptShootingPlanPdfService(logger: const SilentLogger());

  const pageSetup = OcptPageSetup.standard();

  final pinnedExportDate = DateTime(2026, 1, 15);

  group("elements grid", () {
    test("toggled on grows the document, toggled off leaves it as it was", () async {
      final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final element = _buildElement(
        id: "element-1",
        name: "Revolver",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final plan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
        elements: [element],
      );

      Future<Uint8List> generateFor({required bool includeElementsGrid}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: includeElementsGrid,
        exportDate: pinnedExportDate,
      );

      final without = await generateFor(includeElementsGrid: false);
      final withGrid = await generateFor(includeElementsGrid: true);
      final withGridAgain = await generateFor(includeElementsGrid: true);

      expect(withGrid.length, greaterThan(without.length));
      // Toggled off twice in a row, at the very same export date, draws exactly the same pages —
      // nothing about the rest of the document changed by the option existing at all.
      final withoutAgain = await generateFor(includeElementsGrid: false);
      expect(contentStreams(without), contentStreams(withoutAgain));
      expect(contentStreams(withGrid), contentStreams(withGridAgain));
    });

    test("an element linked to a scene the printed range never plays adds no row", () async {
      final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final playedElement = _buildElement(
        id: "element-1",
        name: "Revolver",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final unplayedElement = _buildElement(
        id: "element-2",
        name: "Getaway car",
        code: "VEH-1",
        category: OcptElementCategory.vehicle,
        sceneLinks: [_buildSceneElementLink(id: "link-2", sceneId: "scene-2")],
      );

      OcptSchedulePlanSnapshot buildPlan(List<OcptElement> elements) => buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
            ),
          ],
        },
        shotLists: [
          buildShotList(shots: [shot]),
        ],
        elements: elements,
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: true,
        exportDate: pinnedExportDate,
      );

      // The unplayed element contributes no row at all, so adding it changes nothing about the
      // printed grid.
      final onlyPlayed = await generateFor(buildPlan([playedElement]));
      final playedAndUnplayed = await generateFor(buildPlan([playedElement, unplayedElement]));

      expect(contentStreams(onlyPlayed), contentStreams(playedAndUnplayed));
    });

    test("a range wide enough to chunk the day columns adds at least one extra page", () async {
      // Eight days, each with its own single slot and shot on its own scene — eight day columns,
      // well past the grid's own per-page chunk size, and one element needed on the first of them
      // alone so the grid draws at least one row.
      final days = [for (var i = 1; i <= 8; i++) buildDay(id: "day-$i", dayNumber: i)];
      final slotsByDayId = {
        for (var i = 1; i <= 8; i++)
          "day-$i": [buildSlot(id: "slot-$i", shootingDayId: "day-$i", anchorMinute: 480)],
      };
      final shots = [
        for (var i = 1; i <= 8; i++) buildShot(id: "shot-$i", sceneId: "scene-$i", code: "$i/1"),
      ];
      final blocksByDayId = {
        for (var i = 1; i <= 8; i++)
          "day-$i": [
            buildBlock(
              id: "block-$i",
              shootingDayId: "day-$i",
              slotId: "slot-$i",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-$i",
            ),
          ],
      };
      final element = _buildElement(
        id: "element-1",
        name: "Revolver",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final dayIds = [for (var i = 1; i <= 8; i++) "day-$i"];
      final plan = buildSnapshot(
        days: days,
        slotsByDayId: slotsByDayId,
        blocksByDayId: blocksByDayId,
        shotLists: [buildShotList(shots: shots)],
        elements: [element],
      );

      Future<Uint8List> generateFor({required bool includeElementsGrid}) => service.generate(
        plan: plan,
        dayIds: dayIds,
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: includeElementsGrid,
        exportDate: pinnedExportDate,
      );

      final withGrid = await generateFor(includeElementsGrid: true);
      final withoutGrid = await generateFor(includeElementsGrid: false);

      expect(pageCount(withGrid) - pageCount(withoutGrid), greaterThanOrEqualTo(2));
    });
  });

  group("multiple episodes", () {
    /// Episode 1's own one-scene shot list: `scene-e1`, prefixed `1.3` — the number
    /// `OcptShotListService.loadShotList` would already have given it.
    OcptShotListSnapshot buildEpisodeOneShotList(OcptShot shot) => OcptShotListSnapshot.build(
      screenplayId: "episode-1",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-e1",
          heading: "INT. HOUSE - DAY",
          sceneNumber: null,
          displaySceneNumber: "1.3",
          charStart: 0,
          charEnd: 10,
          shots: [shot],
        ),
      ],
    );

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed [displaySceneNumber] (`2.4` unless
    /// a test deliberately hands in a bare number to simulate the prefix being dropped).
    OcptShotListSnapshot buildEpisodeTwoShotList(
      OcptShot shot, {
      String displaySceneNumber = "2.4",
    }) => OcptShotListSnapshot.build(
      screenplayId: "episode-2",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-e2",
          heading: "EXT. STREET - NIGHT",
          sceneNumber: null,
          displaySceneNumber: displaySceneNumber,
          charStart: 0,
          charEnd: 10,
          shots: [shot],
        ),
      ],
    );

    test("the sequences grid holds a row for each episode's own sequence, and the day agenda's "
        "shot "
        "table prints each episode's own prefixed shot code", () async {
      final slot = buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shotOne = buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1");
      final shotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1");
      final blocks = {
        "day-1": [
          buildBlock(
            id: "block-1",
            shootingDayId: "day-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-e1",
            durationMinutes: 60,
          ),
          buildBlock(
            id: "block-2",
            shootingDayId: "day-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-e2",
            durationMinutes: 60,
          ),
        ],
      };

      final bothEpisodesPlan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocks,
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
      );

      // Episode 2's own shot list is unchanged but for its display number, which is stripped of
      // its prefix here — the very string the day agenda's own shot-table cell (`shot.code`) and
      // the sequences grid's own row label both read from.
      final unprefixedShotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2", code: "4/1");
      final unprefixedPlan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocks,
        shotLists: [
          buildEpisodeOneShotList(shotOne),
          buildEpisodeTwoShotList(unprefixedShotTwo, displaySceneNumber: "4"),
        ],
      );

      // Episode 1 alone: the control this test's own "both episodes print a row each" assertion is
      // measured against.
      final episodeOneOnlyPlan = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [blocks["day-1"]!.first],
        },
        shotLists: [buildEpisodeOneShotList(shotOne)],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: true,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final bothEpisodesBytes = await generateFor(bothEpisodesPlan);
      final unprefixedBytes = await generateFor(unprefixedPlan);
      final episodeOneOnlyBytes = await generateFor(episodeOneOnlyPlan);

      // The prefixed reading of episode 2's own sequence draws differently from the unprefixed
      // one: the prefix genuinely reaches the page rather than being resolved and then dropped.
      expect(contentStreams(bothEpisodesBytes), isNot(contentStreams(unprefixedBytes)));
      // Both episodes' own sequence and shot draw more than episode 1's alone.
      expect(bothEpisodesBytes.length, greaterThan(episodeOneOnlyBytes.length));
    });

    test("the ten-minute grid draws a tile for a block of either episode", () async {
      final morning = buildSlot(id: "slot-morning", shootingDayId: "day-1", anchorMinute: 480);
      final evening = buildSlot(id: "slot-evening", shootingDayId: "day-1", anchorMinute: 1080);
      final shotOne = buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1");
      final shotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1");

      OcptSchedulePlanSnapshot buildPlan({required bool withEveningEpisode}) => buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": withEveningEpisode ? [morning, evening] : [morning],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
              durationMinutes: 60,
            ),
            if (withEveningEpisode)
              buildBlock(
                id: "block-2",
                shootingDayId: "day-1",
                slotId: "slot-evening",
                kind: OcptShootingBlockKind.shot,
                shotId: "shot-e2",
                durationMinutes: 60,
              ),
          ],
        },
        shotLists: withEveningEpisode
            ? [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)]
            : [buildEpisodeOneShotList(shotOne)],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: true,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final bothBytes = await generateFor(buildPlan(withEveningEpisode: true));
      final morningOnlyBytes = await generateFor(buildPlan(withEveningEpisode: false));

      expect(ascii.decode(bothBytes.sublist(0, 4)), "%PDF");
      expect(contentStreams(bothBytes), isNot(contentStreams(morningOnlyBytes)));
    });
  });

  group("shootingPlanFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.shootingPlanFileName(projectName: "My Movie", suffix: "shooting plan"),
        "My Movie - shooting plan.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.shootingPlanFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });
  });
}
