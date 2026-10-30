// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_episode.dart';

/// The number a scene is shown by, as `docs/adr/0019` settles it: its own explicit [sceneNumber]
/// when it has one, otherwise its 1-based [position] among its episode's scenes — prefixed with
/// `<episodeNumber>.` as soon as the project holds more than one episode.
///
/// A null [episodeNumber] means "this project has one episode" and returns **exactly** what every
/// call site returned before this function existed: `sceneNumber ?? "${position + 1}"`. That is
/// the one property a single-episode project depends on, since it is what keeps a feature (a
/// project that never grows a second episode) printing the same numbers it always has. A non-null
/// [episodeNumber] prefixes that same answer, so `4A` in episode 2 reads `2.4A` and an unnumbered
/// scene at position 11 reads `2.12`.
///
/// This is the one implementation of the prefix rule: `OcptSceneRef.displayNumber`,
/// `OcptBreakdownScene.displayNumber`, `OcptShotListService`'s own `displayNumber` and
/// `OcptSchedulePlanSnapshot.sceneNumberBySceneId` (through the shot list) all call it rather than
/// restating it.
String ocptSceneDisplayNumberOf({
  required String? sceneNumber,
  required int position,
  required int? episodeNumber,
}) {
  final ownNumber = sceneNumber ?? "${position + 1}";
  return episodeNumber == null ? ownNumber : "$episodeNumber.$ownNumber";
}

/// The episode number [ocptSceneDisplayNumberOf] prefixes a scene of screenplay [screenplayId]
/// with, read off [episodes] — the other half of the same rule, so "more than one episode" also
/// has one implementation.
///
/// Null in the two cases that mean "do not prefix": a project holding one episode or none (the
/// prefix would say nothing a reader does not already know), and a [screenplayId] that names none
/// of [episodes] — a caller holding a stale id, mid-reload or mid-deletion, gets today's
/// unprefixed answer rather than an exception over a scene it cannot show anyway.
int? ocptEpisodePrefixNumberOf({
  required List<OcptEpisode> episodes,
  required String screenplayId,
}) {
  if (episodes.length <= 1) {
    return null;
  }

  for (final episode in episodes) {
    if (episode.id == screenplayId) {
      return episode.number;
    }
  }

  return null;
}
