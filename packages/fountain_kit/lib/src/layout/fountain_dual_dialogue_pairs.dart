// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/parser/fountain_character_cue.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:fountain_kit/src/parser/fountain_line_type.dart';

/// A pair of dialogue groups set side by side, as the indices of its two members.
typedef FountainDualDialoguePair = ({int left, int right});

/// A run of consecutive source lines, from `start` included to `end` excluded.
typedef FountainLineRange = ({int start, int end});

/// A pair of dialogue groups set side by side, as the line ranges of its two members.
typedef FountainDualDialogueLinePair = ({FountainLineRange left, FountainLineRange right});

/// Find the dual-dialogue pairs among [blocks], as the indices of their members.
///
/// A pair is two [FountainDialogueGroup]s strictly adjacent in [blocks], the second one carrying
/// `^` and the first one not being already the right member of another pair. So `A`, `B^`, `C^`
/// gives the pair (A, B) and leaves `C^` set as an ordinary dialogue, and so does a `^` with no
/// dialogue group just before it. Any other block in between (a section, a synopsis, a note, a
/// boneyard…) breaks the pair.
List<FountainDualDialoguePair> fountainDualDialoguePairs(List<FountainBlock> blocks) {
  final pairs = <FountainDualDialoguePair>[];
  var index = 0;
  while (index < blocks.length) {
    final block = blocks[index];
    final next = index + 1 < blocks.length ? blocks[index + 1] : null;
    if (block is FountainDialogueGroup && next is FountainDialogueGroup && next.isDualDialogue) {
      pairs.add((left: index, right: index + 1));
      index += 2;
    } else {
      index++;
    }
  }
  return pairs;
}

/// Find the dual-dialogue pairs among the classified source [lines], as their line ranges.
///
/// This is the rule of [fountainDualDialoguePairs] for a caller holding lines rather than blocks.
/// [types] holds the [FountainLineType] of each line of [lines], in the same order. A group is a
/// character line followed by the parenthetical and dialogue lines right after it. A pair is a
/// group, then one or more lines with nothing on them, then a group whose cue carries `^`; the
/// first group is not already the right member of another pair. A line holding anything else,
/// even a note alone, between the two groups breaks the pair.
List<FountainDualDialogueLinePair> fountainDualDialogueLinePairs(
  List<FountainLineType> types,
  List<String> lines,
) {
  assert(types.length == lines.length, 'Every line needs its type.');

  final pairs = <FountainDualDialogueLinePair>[];
  var cursor = 0;
  while (cursor < types.length) {
    final left = _groupAt(types, cursor);
    if (left == null) {
      cursor++;
      continue;
    }
    final right = _rightGroupAfter(types, lines, left);
    if (right == null) {
      cursor = left.end;
      continue;
    }
    pairs.add((left: left, right: right));
    cursor = right.end;
  }
  return pairs;
}

/// Get the dialogue group starting at [start], or null when no character line is there.
FountainLineRange? _groupAt(List<FountainLineType> types, int start) {
  if (types[start] != FountainLineType.character) {
    return null;
  }
  var end = start + 1;
  while (end < types.length &&
      (types[end] == FountainLineType.parenthetical || types[end] == FountainLineType.dialogue)) {
    end++;
  }
  return (start: start, end: end);
}

/// Get the group carrying `^` that follows [left] after nothing but empty lines, or null.
FountainLineRange? _rightGroupAfter(
  List<FountainLineType> types,
  List<String> lines,
  FountainLineRange left,
) {
  var next = left.end;
  while (next < types.length &&
      types[next] == FountainLineType.blank &&
      lines[next].trim().isEmpty) {
    next++;
  }
  if (next == left.end) {
    return null;
  }
  final group = next < types.length ? _groupAt(types, next) : null;
  if (group == null) {
    return null;
  }
  final cue = parseFountainCharacterCue(
    FountainLineClassifier.withoutInlineNotes(lines[group.start]),
  );
  return cue.isDualDialogue ? group : null;
}
