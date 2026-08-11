// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';

void main() {
  group("ocptSceneDisplayNumberOf", () {
    test(
      "a null episode number returns exactly what every call site returned before it existed",
      () {
        // sceneNumber ?? "${position + 1}" — the property a single-episode project depends on.
        expect(ocptSceneDisplayNumberOf(sceneNumber: null, position: 0, episodeNumber: null), "1");
        expect(
          ocptSceneDisplayNumberOf(sceneNumber: null, position: 11, episodeNumber: null),
          "12",
        );
        expect(
          ocptSceneDisplayNumberOf(sceneNumber: "4A", position: 11, episodeNumber: null),
          "4A",
        );
      },
    );

    test("prefixes an unnumbered scene's position-derived number with the episode", () {
      expect(ocptSceneDisplayNumberOf(sceneNumber: null, position: 11, episodeNumber: 2), "2.12");
    });

    test("prefixes an explicit scene number with the episode", () {
      expect(ocptSceneDisplayNumberOf(sceneNumber: "4A", position: 11, episodeNumber: 2), "2.4A");
    });
  });

  group("ocptEpisodePrefixNumberOf", () {
    const first = OcptEpisode(id: "ep-1", number: 1, title: "");
    const second = OcptEpisode(id: "ep-2", number: 2, title: "Le Départ");

    test("null on an empty episode list", () {
      expect(ocptEpisodePrefixNumberOf(episodes: const [], screenplayId: "ep-1"), isNull);
    });

    test("null on a project holding a single episode, even when it names it", () {
      expect(ocptEpisodePrefixNumberOf(episodes: const [first], screenplayId: "ep-1"), isNull);
    });

    test("the named episode's own number on a project holding more than one", () {
      expect(ocptEpisodePrefixNumberOf(episodes: const [first, second], screenplayId: "ep-2"), 2);
      expect(ocptEpisodePrefixNumberOf(episodes: const [first, second], screenplayId: "ep-1"), 1);
    });

    test("null when screenplayId names none of the episodes, a stale id rather than a throw", () {
      expect(
        ocptEpisodePrefixNumberOf(episodes: const [first, second], screenplayId: "gone"),
        isNull,
      );
    });
  });
}
