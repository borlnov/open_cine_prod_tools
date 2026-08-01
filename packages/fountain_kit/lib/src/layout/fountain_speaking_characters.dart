// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_printable_text.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';

/// The normalized, deduplicated, first-appearance-ordered speaking roles
/// introduced by a [FountainDialogueGroup] anywhere in [blocks]: every
/// [FountainCharacter.name], normalized (trimmed, internal whitespace
/// collapsed, upper-cased, see [normalizeCharacterName]) so the same role
/// cued with and without a parenthetical extension (`(V.O.)`, `(CONT'D)`,
/// … — already excluded from [FountainCharacter.name] itself) counts once.
/// A dual-dialogue pair contributes both of its cues.
///
/// Shared by `FountainScriptStatistics` (the whole document) and
/// `FountainSceneStatistics` (a single scene) — named in code spans rather
/// than doc references because both import this file, so importing them
/// back would be circular — and by any other caller that wants a
/// screenplay's speaking roles by name without composing pages.
List<String> speakingCharactersOf(Iterable<FountainBlock> blocks) {
  final seen = <String>{};
  final ordered = <String>[];
  for (final block in blocks) {
    if (block case FountainDialogueGroup(:final character)) {
      final normalized = normalizeCharacterName(character.name);
      if (seen.add(normalized)) {
        ordered.add(normalized);
      }
    }
  }
  return ordered;
}
