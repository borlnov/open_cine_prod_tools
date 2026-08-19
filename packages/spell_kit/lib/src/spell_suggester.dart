// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/spell_checker.dart';

/// The default cap on how many suggestions [SpellSuggester.suggestionsFor]
/// returns.
const int _defaultSuggestionLimit = 5;

/// Suggests corrections for a word a [SpellChecker] reports unknown.
///
/// Suggestions are drawn from four tiers, tried in hunspell's own order —
/// the `REP` table (the language's own catalogue of common typos), then
/// `MAP` groups (accent substitution, for example `sequence` →
/// `séquence`), then a single edit (a deletion, an adjacent transposition,
/// a replacement or an insertion, using the characters `TRY` declares),
/// then a split into two known words. This package deliberately does not
/// implement hunspell's third, `n`-gram suggestion tier: it costs a scan
/// of the whole dictionary per request, for candidates the first two tiers
/// already cover on a typo.
class SpellSuggester {
  /// Creates a [SpellSuggester] using [checker] both to validate
  /// candidates and to read the dictionary they are drawn from.
  const SpellSuggester(this.checker);

  /// The checker suggestions are validated against.
  final SpellChecker checker;

  /// Suggests up to [limit] corrections for [word], deduplicated, with
  /// [word]'s own capitalisation carried onto each one.
  List<String> suggestionsFor(
    String word, {
    int limit = _defaultSuggestionLimit,
  }) {
    // REP/MAP/TRY tables and the dictionary itself are keyed on the
    // language's own (typically lowercase) casing, so candidates are
    // generated against a lowercased working word whenever the writer
    // typed anything else, and the typed capitalisation is carried back
    // onto the result at the very end.
    final workingWord = word == word.toLowerCase() ? word : word.toLowerCase();

    final seen = <String>{};
    final results = <String>[];

    void tryCandidate(String candidate, {required bool Function(String) isValid}) {
      if (results.length >= limit || !seen.add(candidate)) {
        return;
      }
      if (isValid(candidate)) {
        results.add(candidate);
      }
    }

    for (final candidate in _repCandidates(workingWord)) {
      if (results.length >= limit) {
        break;
      }
      tryCandidate(candidate, isValid: _isSuggestable);
    }
    for (final candidate in _mapCandidates(workingWord)) {
      if (results.length >= limit) {
        break;
      }
      tryCandidate(candidate, isValid: _isSuggestable);
    }
    for (final candidate in _editCandidates(workingWord)) {
      if (results.length >= limit) {
        break;
      }
      tryCandidate(candidate, isValid: _isSuggestable);
    }
    for (final candidate in _splitCandidates(workingWord)) {
      if (results.length >= limit) {
        break;
      }
      // Already validated (both halves independently known) by
      // _splitCandidates itself: isKnown has no notion of a two-word
      // phrase, so it must not be asked to re-validate the joined string.
      tryCandidate(candidate, isValid: (_) => true);
    }

    final caseShape = _classifyCase(word);
    return [for (final result in results) _applyCase(result, caseShape)];
  }

  /// Whether [candidate] is fit to suggest: known to [checker], and — when
  /// it is itself a bare dictionary entry — not flagged `NOSUGGEST` (a
  /// dictionary word the checker must still accept as correctly spelled,
  /// but never offer as a correction).
  bool _isSuggestable(String candidate) {
    if (!checker.isKnown(candidate)) {
      return false;
    }
    final flags = checker.dictionary.entries[candidate];
    if (flags == null) {
      return true;
    }
    return !checker.dictionary.affixFile.containsFlag(
      flags,
      checker.dictionary.affixFile.noSuggestFlag,
    );
  }

  /// Candidates from the `REP` table: each rule tried at every position it
  /// applies to (every occurrence for an unanchored rule, only the start
  /// or the end for an anchored one).
  Iterable<String> _repCandidates(String word) sync* {
    for (final rule in checker.dictionary.affixFile.repRules) {
      if (rule.anchoredStart && rule.anchoredEnd) {
        if (word == rule.from) {
          yield rule.to;
        }
        continue;
      }
      if (rule.anchoredStart) {
        if (word.startsWith(rule.from)) {
          yield rule.to + word.substring(rule.from.length);
        }
        continue;
      }
      if (rule.anchoredEnd) {
        if (word.endsWith(rule.from)) {
          yield word.substring(0, word.length - rule.from.length) + rule.to;
        }
        continue;
      }
      if (rule.from.isEmpty) {
        continue;
      }
      var searchFrom = 0;
      while (true) {
        final index = word.indexOf(rule.from, searchFrom);
        if (index == -1) {
          break;
        }
        yield word.substring(0, index) +
            rule.to +
            word.substring(index + rule.from.length);
        searchFrom = index + 1;
      }
    }
  }

  /// Candidates from `MAP` groups: substituting, one position at a time,
  /// each character for another member of a group it belongs to.
  Iterable<String> _mapCandidates(String word) sync* {
    final codePoints = word.runes.toList();
    for (var i = 0; i < codePoints.length; i++) {
      final char = String.fromCharCode(codePoints[i]);
      for (final group in checker.dictionary.affixFile.mapGroups) {
        final members = group.runes.map(String.fromCharCode).toList();
        if (!members.contains(char)) {
          continue;
        }
        for (final replacement in members) {
          if (replacement == char) {
            continue;
          }
          final candidate = [...codePoints];
          candidate[i] = replacement.runes.single;
          yield String.fromCharCodes(candidate);
        }
      }
    }
  }

  /// Candidates one edit away from [word]: a deletion, an adjacent
  /// transposition, a replacement, or an insertion, the replacement and
  /// insertion characters drawn from `TRY`.
  Iterable<String> _editCandidates(String word) sync* {
    final codePoints = word.runes.toList();
    final tryChars = checker.dictionary.affixFile.tryChars.runes
        .map(String.fromCharCode)
        .toList();

    for (var i = 0; i < codePoints.length; i++) {
      final withoutI = [...codePoints]..removeAt(i);
      yield String.fromCharCodes(withoutI);
    }

    for (var i = 0; i < codePoints.length - 1; i++) {
      final swapped = [...codePoints];
      final tmp = swapped[i];
      swapped[i] = swapped[i + 1];
      swapped[i + 1] = tmp;
      yield String.fromCharCodes(swapped);
    }

    for (var i = 0; i < codePoints.length; i++) {
      for (final char in tryChars) {
        final replaced = [...codePoints];
        replaced[i] = char.runes.single;
        yield String.fromCharCodes(replaced);
      }
    }

    for (var i = 0; i <= codePoints.length; i++) {
      for (final char in tryChars) {
        final inserted = [...codePoints]..insert(i, char.runes.single);
        yield String.fromCharCodes(inserted);
      }
    }
  }

  /// Candidates from splitting [word] into two known words, joined by a
  /// space (`alot` → `a lot`).
  Iterable<String> _splitCandidates(String word) sync* {
    for (var i = 1; i < word.length; i++) {
      final first = word.substring(0, i);
      final second = word.substring(i);
      if (checker.isKnown(first) && checker.isKnown(second)) {
        yield '$first $second';
      }
    }
  }

  /// Classifies [word]'s case shape, mirroring [SpellChecker]'s own
  /// classification so a suggestion drawn from the (typically lowercase)
  /// dictionary can be re-cased to match what the writer typed.
  _SuggesterWordCase _classifyCase(String word) {
    final hasUpper = word != word.toLowerCase();
    final hasLower = word != word.toUpperCase();
    if (!hasUpper) {
      return _SuggesterWordCase.allLower;
    }
    if (!hasLower) {
      return _SuggesterWordCase.allCaps;
    }
    final rest = word.substring(1);
    final isTitleCase =
        word[0] == word[0].toUpperCase() && rest == rest.toLowerCase();
    return isTitleCase
        ? _SuggesterWordCase.titleCase
        : _SuggesterWordCase.mixed;
  }

  /// Applies [caseShape] to [suggestion]: an all-caps typed word gets an
  /// all-caps suggestion, a title-case typed word gets a title-case
  /// suggestion, and anything else is left as generated.
  String _applyCase(String suggestion, _SuggesterWordCase caseShape) {
    switch (caseShape) {
      case _SuggesterWordCase.allCaps:
        return suggestion.toUpperCase();
      case _SuggesterWordCase.titleCase:
        return suggestion.isEmpty
            ? suggestion
            : suggestion[0].toUpperCase() + suggestion.substring(1);
      case _SuggesterWordCase.allLower:
      case _SuggesterWordCase.mixed:
        return suggestion;
    }
  }
}

/// The case shape of the word a suggestion is being generated for, used to
/// carry the writer's own capitalisation onto the suggestion.
enum _SuggesterWordCase {
  /// No letter in the word is uppercase.
  allLower,

  /// The first letter is uppercase and every other letter is lowercase.
  titleCase,

  /// Every cased letter in the word is uppercase.
  allCaps,

  /// Anything else, most notably an interior capital.
  mixed,
}
