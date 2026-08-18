// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One match `ocptFindTextMatches` found: the half-open `[start, end)` character range, in the
/// searched text, the query occupies.
class OcptTextMatch extends Equatable {
  /// The 0-based offset of the match's first character.
  final int start;

  /// The 0-based offset just past the match's last character (so `end - start` is the query's
  /// length).
  final int end;

  /// Class constructor
  const OcptTextMatch({required this.start, required this.end});

  /// Object properties
  @override
  List<Object?> get props => [start, end];
}

/// Every accented letter the app's two UI languages (English, French) actually write, both cases,
/// counted as a "word" character by [_isWordCharacterAt] — a screenplay is written in French too,
/// so a whole-word search must not treat `é`/`ç`/`œ` as a boundary the way a naive `[A-Za-z0-9_]`
/// class would.
const String _ocptWordDiacritics =
    "àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ"
    "ÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝŸŒÆ";

/// The set of code units [_isWordCharacterAt] treats as "word" characters beyond plain ASCII
/// letters/digits/underscore: every rune of [_ocptWordDiacritics], computed once.
final Set<int> _ocptWordDiacriticCodeUnits = _ocptWordDiacritics.codeUnits.toSet();

/// Whether the character of [text] at [index] counts as a "word" character for whole-word
/// matching: an ASCII letter, a digit, an underscore, or one of [_ocptWordDiacritics].
bool _isWordCharacterAt(String text, int index) {
  final codeUnit = text.codeUnitAt(index);
  if (codeUnit >= 0x30 && codeUnit <= 0x39) {
    return true; // 0-9
  }
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
    return true; // A-Z
  }
  if (codeUnit >= 0x61 && codeUnit <= 0x7A) {
    return true; // a-z
  }
  if (codeUnit == 0x5F) {
    return true; // _
  }
  return _ocptWordDiacriticCodeUnits.contains(codeUnit);
}

/// Whether the `[start, end)` match found in [text] is bordered, on both sides, by a non-word
/// character (or the start/end of [text] itself) — the whole-word test [ocptFindTextMatches]
/// applies when asked for one.
bool _isWholeWordMatch(String text, int start, int end) {
  if (start > 0 && _isWordCharacterAt(text, start - 1)) {
    return false;
  }
  if (end < text.length && _isWordCharacterAt(text, end)) {
    return false;
  }
  return true;
}

/// Every non-overlapping occurrence of [query] in [text], left to right, or an empty list while
/// [query] is empty — no search is the same as "nothing found", not "everything found".
///
/// [query] is matched literally: this never builds a `RegExp` out of it (a screenwriter's query is
/// ordinary text, where `(`, `.` or `*` are just characters, not metacharacters), scanning with
/// plain [String.indexOf] instead. [isCaseSensitive] folds both [text] and [query] through
/// [String.toLowerCase] first when false. [isWholeWord] additionally requires each candidate to be
/// bordered by a non-word character (or the string's own start/end) on both sides, through
/// [_isWholeWordMatch] — a candidate that fails this test is discarded, but the scan still resumes
/// right after it, so a rejected occurrence never hides a later, valid one.
///
/// Matches never overlap: once one is found (or a candidate is discarded by [isWholeWord]), the
/// scan resumes at its own end, so a query held entirely inside a longer run of itself (e.g. `aa`
/// over `aaa`) is only reported once.
List<OcptTextMatch> ocptFindTextMatches({
  required String text,
  required String query,
  required bool isCaseSensitive,
  required bool isWholeWord,
}) {
  if (query.isEmpty) {
    return const [];
  }

  final haystack = isCaseSensitive ? text : text.toLowerCase();
  final needle = isCaseSensitive ? query : query.toLowerCase();

  final matches = <OcptTextMatch>[];
  var searchStart = 0;
  while (searchStart <= haystack.length - needle.length) {
    final index = haystack.indexOf(needle, searchStart);
    if (index == -1) {
      break;
    }

    final end = index + needle.length;
    if (!isWholeWord || _isWholeWordMatch(text, index, end)) {
      matches.add(OcptTextMatch(start: index, end: end));
    }
    searchStart = end;
  }

  return matches;
}
