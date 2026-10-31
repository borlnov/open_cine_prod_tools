// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// Parses [screenplayText] and delegates to `fountain_kit`'s `screenplayCharactersOf`, whose
/// normalisation matches `shot_characters.characterName`'s own (both go through
/// `normalizeCharacterName`) so a shot's character and a screenplay's own compare equal
/// byte-for-byte.
///
/// The whole cast, not only the speaking roles: a character introduced in capitals in an action
/// line and never given a single line of dialogue (a silhouette, an extra, someone who only
/// crosses the frame) still has to be attachable to a shot, and would otherwise be reported as
/// removed from the screenplay by `OcptShotListState.removedCharacterAlerts` the moment somebody
/// attached them.
List<String> ocptScreenplayCharactersOf(String screenplayText) {
  final document = const FountainParser().parse(screenplayText);
  return screenplayCharactersOf(document.blocks);
}
