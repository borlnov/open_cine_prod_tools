// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// Get the index, in the character cue source [line], of the dual-dialogue `^` ending the cue, or
/// null when the cue carries none.
///
/// The marker is the last character of the cue once the whitespace and the inline notes after it
/// are set aside, which is exactly where `parseFountainCharacterCue` reads it from. A `^` inside
/// the name, or inside a note, is no marker.
int? ocptCueDualMarkerIndexOf(String line) {
  final notes = FountainCommentSpans.notes(line);
  var index = line.length - 1;
  while (index >= 0) {
    final note = notes.where((span) => index >= span.start && index < span.end).firstOrNull;
    if (note != null) {
      index = note.start - 1;
    } else if (line[index].trim().isEmpty) {
      index--;
    } else {
      break;
    }
  }

  return index >= 0 && line[index] == "^" ? index : null;
}
