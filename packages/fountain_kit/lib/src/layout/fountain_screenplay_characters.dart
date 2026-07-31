// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_printable_text.dart';
import 'package:fountain_kit/src/layout/fountain_speaking_characters.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';

/// The most words a run of upper-case words may hold and still be read as a
/// character's name.
///
/// A name runs to three or four words at the very most (`LE ROI ARTHUR`,
/// `MADAME DE LA FAYETTE`); a longer run is a screenwriter shouting a whole
/// sentence in capitals, and naming a character after it would be worse than
/// naming none.
const _maxNameWordCount = 4;

/// Splits a source line into whitespace-separated tokens.
final RegExp _tokenSeparator = RegExp(r'\s+');

/// Matches the characters that are never part of a name at either end of a
/// token: the punctuation, quotes and brackets an action line wraps a name
/// with (`(PAUL)`, `PAUL,`, `"ELISA"`).
final RegExp _tokenEdges = RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true);

/// The normalized names an action line introduces: every run of upper-case
/// words it holds, in reading order.
///
/// Writing a character's name in capitals the first time they appear in the
/// action is the screenwriting convention this reads — the only way a
/// character who never speaks (a silhouette, an extra, someone who only ever
/// crosses the frame) is ever named in a screenplay at all, and the reason
/// [speakingCharactersOf] alone is not the whole cast.
///
/// A run is a sequence of adjacent tokens that carry at least two letters, no
/// lower-case letter at all, and nothing but their own edge punctuation
/// stripped away (so `(PAUL)`, `PAUL,` and `PAUL.` all name `PAUL`, while
/// `J.R.` keeps its inner dots). Adjacency is what pairs the words of a
/// two-word name: `JEAN DUPONT entre` names `JEAN DUPONT`, `PAUL et PASCAL
/// entrent` names both of them separately, since the lower-case `et` between
/// them ends the first run. A run longer than [_maxNameWordCount] words names
/// nobody.
///
/// A line holding no lower-case letter at all names nobody either: a name is
/// introduced *among* ordinary prose, so a line written entirely in capitals
/// is a screenwriter emphasising a whole beat (`BLACKOUT.`), not a cast entry.
///
/// This is a convention, not a syntax: an acronym or an emphasised word
/// written in capitals (`OK`, `STOP`) is named here just like a character
/// would be. The caller decides what to do with a name it does not recognise.
List<String> charactersIntroducedInActionLine(String line) {
  if (_holdsNoLowerCaseLetter(line)) {
    return const [];
  }

  final names = <String>[];
  final run = <String>[];

  void flushRun() {
    if (run.isNotEmpty && run.length <= _maxNameWordCount) {
      names.add(normalizeCharacterName(run.join(' ')));
    }
    run.clear();
  }

  for (final token in line.split(_tokenSeparator)) {
    final word = token.replaceAll(_tokenEdges, '');
    if (_isNameWord(word)) {
      run.add(word);
    } else {
      flushRun();
    }
  }
  flushRun();

  return names;
}

/// Whether [line] holds at least one letter and not a single lower-case one.
bool _holdsNoLowerCaseLetter(String line) =>
    line.toUpperCase() == line && line.toLowerCase() != line;

/// Whether [word] (already stripped of its edge punctuation) reads as one word
/// of a character's name: at least two characters long, holding a letter, and
/// holding no lower-case letter.
bool _isNameWord(String word) =>
    word.length >= 2 && word.toUpperCase() == word && word.toLowerCase() != word;

/// The normalized, deduplicated, first-appearance-ordered names every action
/// block of [blocks] introduces, as [charactersIntroducedInActionLine] reads
/// them line by line.
List<String> charactersIntroducedInActionOf(Iterable<FountainBlock> blocks) {
  final seen = <String>{};
  final ordered = <String>[];

  for (final block in blocks) {
    if (block case FountainActionBlock(:final lines)) {
      for (final line in lines) {
        for (final name in charactersIntroducedInActionLine(line)) {
          if (seen.add(name)) {
            ordered.add(name);
          }
        }
      }
    }
  }

  return ordered;
}

/// Every character [blocks] name, normalized, deduplicated and in
/// first-appearance order: the roles [speakingCharactersOf] finds in the
/// dialogue cues, together with the ones
/// [charactersIntroducedInActionOf] finds written in capitals in the action.
///
/// This is the screenplay's cast as a production document needs it — a shot
/// list has to be able to put a silent character in a shot — where
/// [speakingCharactersOf] on its own answers the narrower question the
/// statistics ask: who actually speaks.
List<String> screenplayCharactersOf(Iterable<FountainBlock> blocks) {
  final seen = <String>{};
  final ordered = <String>[];

  void add(String name) {
    if (seen.add(name)) {
      ordered.add(name);
    }
  }

  for (final block in blocks) {
    switch (block) {
      case FountainDialogueGroup(:final character):
        add(normalizeCharacterName(character.name));
      case FountainActionBlock(:final lines):
        for (final line in lines) {
          charactersIntroducedInActionLine(line).forEach(add);
        }
      default:
        break;
    }
  }

  return ordered;
}
