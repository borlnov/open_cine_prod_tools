// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_schedule_plan_snapshot_test_doubles.dart';

/// Builds an element with the few fields these tests read, everything else neutral.
OcptElement _buildElement({
  required String id,
  String name = "",
  OcptElementCategory category = OcptElementCategory.prop,
  String? broughtByPersonId,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: "",
  quantity: "1",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: broughtByPersonId,
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

/// Builds a *dépouillement* link with the few fields these tests read, everything else neutral.
OcptSceneElementLink _buildSceneElementLink({required String id, required String sceneId}) =>
    OcptSceneElementLink(id: id, sceneId: sceneId, quantity: "1", notes: "");

/// Builds a one-scene, one-shot shot list for one episode, its scene's own display number already
/// carrying the `<episode>.<scene>` prefix `OcptShotListService.loadShotList` would have given it —
/// what the "multiple episodes" tests below merge across [OcptSchedulePlanSnapshot.shotLists].
OcptShotListSnapshot _buildEpisodeShotList({
  required String screenplayId,
  required String sceneId,
  required String heading,
  required String displaySceneNumber,
  required OcptShot shot,
}) => OcptShotListSnapshot.build(
  screenplayId: screenplayId,
  sequences: [
    OcptSceneShotSequence(
      sceneId: sceneId,
      heading: heading,
      sceneNumber: null,
      displaySceneNumber: displaySceneNumber,
      charStart: 0,
      charEnd: 0,
      shots: [shot],
    ),
  ],
);

/// Run the tests of the schedule plan snapshot spans and elements.
void main() {
  group("sceneSpanBySceneId", () {
    test("a scene sequence's span is read back", () {
      final snapshot = buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              const OcptSceneShotSequence(
                sceneId: "scene-1",
                heading: "INT. KITCHEN - DAY",
                sceneNumber: null,
                displaySceneNumber: "1",
                charStart: 42,
                charEnd: 108,
                shots: [],
              ),
            ],
          ),
        ],
      );

      expect(snapshot.sceneSpanBySceneId, {"scene-1": (charStart: 42, charEnd: 108)});
    });

    test("an orphan sequence contributes no entry", () {
      final snapshot = buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              OcptOrphanShotSequence(shots: [buildShot(id: "shot-1")]),
            ],
          ),
        ],
      );

      expect(snapshot.sceneSpanBySceneId, isEmpty);
    });
  });

  group("convokedRoleIdsOfDay", () {
    test("the union of every live slot's own cast, deduplicated", () {
      final morning = buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        cast: [
          buildCastMember(id: "cast-1", slotId: "slot-morning", roleId: "role-1"),
          buildCastMember(id: "cast-2", slotId: "slot-morning", roleId: "role-2"),
        ],
      );
      final evening = buildSlot(
        id: "slot-evening",
        anchorMinute: 1080,
        // The same role, convoked twice in one day, is on that day once.
        cast: [buildCastMember(id: "cast-3", slotId: "slot-evening", roleId: "role-1")],
      );
      final snapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
      );

      expect(snapshot.convokedRoleIdsOfDay("day-1"), {"role-1", "role-2"});
    });

    test("names the role even when it is cast, an actor never standing in for it", () {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        cast: [buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final snapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        roles: [buildRole(id: "role-1", name: "Alice", personId: "person-1")],
      );

      expect(snapshot.convokedRoleIdsOfDay("day-1"), {"role-1"});
    });

    test("empty for a day with no slot at all", () {
      final snapshot = buildSnapshot(
        days: [buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: const {},
      );

      expect(snapshot.convokedRoleIdsOfDay("day-1"), isEmpty);
    });
  });

  group("elementsToBringOnDay", () {
    /// A day playing `scene-1` alone, through one placed shot — the fixture every test below places
    /// its element against.
    OcptSchedulePlanSnapshot buildDayPlayingSceneOne({required List<OcptElement> elements}) {
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final day = buildDay(id: "day-1", dayNumber: 1);
      final shot = buildShot(id: "shot-1");
      return buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
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
    }

    test(
      "an element brought by the right person but needed in no scene the day plays is absent",
      () {
        final element = _buildElement(
          id: "element-1",
          name: "Umbrella",
          broughtByPersonId: "person-1",
          sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-2")],
        );
        final snapshot = buildDayPlayingSceneOne(elements: [element]);

        final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

        expect(
          toBring,
          isEmpty,
          reason:
              "a call sheet says what to bring today, not everything this person was ever assigned",
        );
      },
    );

    test("an element needed in a scene the day plays but brought by somebody else is absent", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-2",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      expect(toBring, isEmpty);
    });

    test("an element brought by this person and needed in a scene the day plays is present", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      expect(toBring, [element]);
    });

    test("empty for a person id nobody brings anything for", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-404");

      expect(toBring, isEmpty);
    });

    test("sorted by category then by name", () {
      final costume = _buildElement(
        id: "element-costume",
        name: "Coat",
        category: OcptElementCategory.costume,
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-costume", sceneId: "scene-1")],
      );
      final propB = _buildElement(
        id: "element-prop-b",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-prop-b", sceneId: "scene-1")],
      );
      final propA = _buildElement(
        id: "element-prop-a",
        name: "Cane",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-prop-a", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [costume, propB, propA]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      // OcptElementCategory.prop comes before OcptElementCategory.costume in the enum's own
      // declaration order, and within `prop` the two elements sort by name ("Cane" before
      // "Umbrella").
      expect(toBring, [propA, propB, costume]);
    });
  });

  group("multiple episodes", () {
    const episodeOne = OcptEpisode(id: "episode-1", number: 1, title: "");
    const episodeTwo = OcptEpisode(id: "episode-2", number: 2, title: "");

    /// Episode 1's own one-scene shot list: `scene-e1`, prefixed `1.3` — the number
    /// `OcptShotListService.loadShotList` would already have given it.
    OcptShotListSnapshot buildEpisodeOneShotList(OcptShot shot) => _buildEpisodeShotList(
      screenplayId: episodeOne.id,
      sceneId: "scene-e1",
      heading: "INT. HOUSE - DAY",
      displaySceneNumber: "1.3",
      shot: shot,
    );

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed `2.4`.
    OcptShotListSnapshot buildEpisodeTwoShotList(OcptShot shot) => _buildEpisodeShotList(
      screenplayId: episodeTwo.id,
      sceneId: "scene-e2",
      heading: "EXT. STREET - NIGHT",
      displaySceneNumber: "2.4",
      shot: shot,
    );

    test("resolves shotById for a shot of either episode, and merges the heading and span maps "
        "across both", () {
      final shotOne = buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2");
      final snapshot = buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.shotById("shot-e1"), shotOne);
      expect(snapshot.shotById("shot-e2"), shotTwo);
      expect(snapshot.headingBySceneId, {
        "scene-e1": "INT. HOUSE - DAY",
        "scene-e2": "EXT. STREET - NIGHT",
      });
      expect(snapshot.sceneSpanBySceneId.keys, {"scene-e1", "scene-e2"});
    });

    test("sceneNumberBySceneId returns each episode's own prefixed number, unchanged by the "
        "merge", () {
      final shotOne = buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2");
      final snapshot = buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.sceneNumberBySceneId["scene-e1"], "1.3");
      expect(snapshot.sceneNumberBySceneId["scene-e2"], "2.4");
    });

    test("screenplayIdBySceneId names the right episode for a scene of each", () {
      final shotOne = buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2");
      final snapshot = buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.screenplayIdBySceneId["scene-e1"], episodeOne.id);
      expect(snapshot.screenplayIdBySceneId["scene-e2"], episodeTwo.id);
    });

    test("a day placing shots from both episodes reports both scenes through sceneIdsOfDay", () {
      final shotOne = buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = buildShot(id: "shot-e2", sceneId: "scene-e2");
      final slot = buildSlot(id: "slot-1", anchorMinute: 480);
      final day = buildDay(id: "day-1", dayNumber: 1);
      final snapshot = buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
            ),
            buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e2",
            ),
          ],
        },
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.sceneIdsOfDay("day-1"), {"scene-e1", "scene-e2"});
    });

    test("a single-episode plan behaves exactly as before — no prefix anywhere", () {
      final shot = buildShot(id: "shot-1");
      final snapshot = buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [
          buildShotList(shots: [shot]),
        ],
        episodes: const [OcptEpisode(id: "screenplay-1", number: 1, title: "")],
      );

      expect(snapshot.sceneNumberBySceneId["scene-1"], "1");
    });
  });
}
