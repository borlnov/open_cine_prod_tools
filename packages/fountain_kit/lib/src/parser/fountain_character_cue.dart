// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The three pieces a character cue source line carries, as
/// [parseFountainCharacterCue] splits them apart: the character's own
/// `name`, the parenthetical `extension` written after it (`V.O.`,
/// `CONT'D`, … or null when the cue has none), and whether the cue was
/// suffixed with the dual-dialogue `^` marker.
typedef FountainCharacterCue = ({String name, String? extension, bool isDualDialogue});

/// Matches a character extension in parentheses at the end of a cue, for
/// example ` (V.O.)` in `SARAH (V.O.)`.
final RegExp _characterExtension = RegExp(r'^(.*?)\s*\(([^()]*)\)\s*$');

/// Split the character cue source line [rawLine] into its
/// [FountainCharacterCue] parts, dropping the forcing `@` prefix, the
/// dual-dialogue `^` suffix and the parenthetical extension from the name
/// itself.
///
/// This only takes a line apart as if it were a cue, whatever it really is:
/// `FountainLineClassifier` calls it on a line not yet classified, to tell
/// whether the name part alone is upper case, the extension being free to
/// be written in either case.
///
/// Shared by `FountainBlockBuilder` (which parses a whole document into
/// blocks), by `FountainLineClassifier`, and by any caller holding a single
/// line rather than a document — both named in a code span rather than a doc
/// reference because they import this file, so importing them back would be
/// circular.
FountainCharacterCue parseFountainCharacterCue(String rawLine) {
  var work = rawLine.trim();
  if (work.startsWith('@')) {
    work = work.substring(1).trim();
  }

  var isDualDialogue = false;
  if (work.endsWith('^')) {
    isDualDialogue = true;
    work = work.substring(0, work.length - 1).trim();
  }

  final match = _characterExtension.firstMatch(work);
  if (match == null) {
    return (name: work, extension: null, isDualDialogue: isDualDialogue);
  }

  return (
    name: match.group(1)!.trim(),
    extension: match.group(2)!.trim(),
    isDualDialogue: isDualDialogue,
  );
}
