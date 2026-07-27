// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';

/// Yields the rendered text of [block] — the same text
/// [FountainScriptComposer] would print, parentheses and scene numbers
/// included — and (for a dialogue group) of every child it introduces, if
/// [block] is part of the printed screenplay; yields nothing for a section,
/// synopsis, note, boneyard comment or page break, mirroring the filter
/// `FountainScriptComposer._printableBlocks` applies before pagination
/// (replicated rather than shared, since that filter is private to its own
/// file).
///
/// Shared by [FountainScriptStatistics] and [FountainSceneStatistics], which
/// both measure a body of printable Fountain text — the whole document for
/// one, a single scene for the other — the same way.
Iterable<String> printableTextsOf(FountainBlock block) sync* {
  switch (block) {
    case FountainSceneHeading(:final headingText, :final sceneNumber):
      yield sceneNumber == null ? headingText : '$sceneNumber. $headingText';
    case FountainActionBlock(:final lines):
      yield* lines;
    case FountainDialogueGroup(:final character, :final children):
      yield characterCueTextOf(character);
      for (final child in children) {
        yield* printableTextsOf(child);
      }
    case FountainParenthetical(:final text):
      yield '($text)';
    case FountainDialogueLine(:final text):
      yield text;
    case FountainTransition(:final text):
      yield text;
    case FountainLyrics(:final lines):
      yield* lines;
    case FountainCenteredText(:final text):
      yield text;
    case FountainCharacter():
      // Never a top-level or directly-nested block: only reached through
      // FountainDialogueGroup.character above.
      break;
    case FountainSection():
    case FountainSynopsis():
    case FountainNoteBlock():
    case FountainBoneyard():
    case FountainPageBreak():
      break;
  }
}

/// The full character cue text: the name, followed by its parenthetical
/// extension if any, exactly as it is printed.
String characterCueTextOf(FountainCharacter character) =>
    character.extension == null ? character.name : '${character.name} (${character.extension})';

/// Splits [text] on runs of whitespace and counts the resulting words; an
/// empty or all-whitespace [text] counts as zero.
int wordCountOf(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
}

/// Counts the non-whitespace characters of [text] — what a writer means by
/// "signs": every printed glyph, spaces excluded.
int signCountOf(String text) => text.replaceAll(RegExp(r'\s'), '').length;

/// Trims [name], collapses runs of internal whitespace to a single space,
/// and upper-cases it, so two spellings of the same role are recognized as
/// one.
String normalizeCharacterName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
