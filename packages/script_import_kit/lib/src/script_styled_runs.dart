// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// Trims the outer whitespace of [runs] taken as one line — the leading
/// whitespace of the first run, the trailing whitespace of the last —
/// dropping any run left with nothing in it.
///
/// The whitespace *between* two runs is the text's own and is left alone: a
/// source that split `she waits ` from `quietly` meant the space between
/// them, and only the two ends of the line are the file format's own
/// layout.
///
/// Every reader needs this and none can do without it: an `.fdx` indents
/// its `<Text>` runs the way its writer laid them out, a Celtx `<p>`
/// carries whatever whitespace the HTML was pretty-printed with, and a
/// Fountain line that kept either would come back as something other than
/// what the file said.
List<FountainStyledRun> trimStyledRunEdges(List<FountainStyledRun> runs) {
  final trimmed = List.of(runs);

  while (trimmed.isNotEmpty) {
    final text = trimmed.first.text.trimLeft();
    if (text.isEmpty) {
      trimmed.removeAt(0);
      continue;
    }
    trimmed[0] = _withText(trimmed.first, text);
    break;
  }

  while (trimmed.isNotEmpty) {
    final text = trimmed.last.text.trimRight();
    if (text.isEmpty) {
      trimmed.removeLast();
      continue;
    }
    trimmed[trimmed.length - 1] = _withText(trimmed.last, text);
    break;
  }

  return trimmed;
}

/// [run] with its text replaced by [text], its styles kept.
FountainStyledRun _withText(FountainStyledRun run, String text) =>
    FountainStyledRun(
      text: text,
      isBold: run.isBold,
      isItalic: run.isItalic,
      isUnderline: run.isUnderline,
    );
