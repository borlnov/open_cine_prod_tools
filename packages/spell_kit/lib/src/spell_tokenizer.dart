// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';
import 'package:spell_kit/src/hunspell_affix_file.dart';
import 'package:spell_kit/src/spell_range.dart';

/// The characters trimmed off the leading and trailing edge of every token,
/// whatever [SpellTokenizerOptions.extraWordCharacters] holds: a word never
/// starts or ends with a dangling apostrophe or hyphen even when one of
/// those is itself an accepted interior character.
const Set<String> _trimmedBoundaryCharacters = {"'", '’', '-'};

/// Matches a decimal digit, in any script (`\p{Nd}`), for
/// [SpellTokenizerOptions.skipTokensWithDigits].
final RegExp _digitPattern = RegExp(r'\p{Nd}', unicode: true);

/// Options controlling how [spellTokensIn] cuts word tokens out of a text.
class SpellTokenizerOptions {
  /// Creates [SpellTokenizerOptions].
  const SpellTokenizerOptions({
    this.extraWordCharacters = const {"'", '’', '-'},
    this.skipAllCapsTokens = true,
    this.skipTokensWithDigits = true,
  });

  /// Builds [SpellTokenizerOptions] from an affix file's `WORDCHARS`,
  /// dropping `.` and every digit from it: a full stop ends a sentence far
  /// more often than it sits inside a word, and a token holding a digit is
  /// dropped by [skipTokensWithDigits] regardless of whether it is
  /// accepted here.
  factory SpellTokenizerOptions.fromAffixFile(
    HunspellAffixFile affixFile, {
    bool skipAllCapsTokens = true,
    bool skipTokensWithDigits = true,
  }) {
    final extraWordCharacters = <String>{
      for (final rune in affixFile.wordChars.runes) String.fromCharCode(rune),
    }..removeWhere((char) => char == '.' || _digitPattern.hasMatch(char));
    return SpellTokenizerOptions(
      extraWordCharacters: extraWordCharacters,
      skipAllCapsTokens: skipAllCapsTokens,
      skipTokensWithDigits: skipTokensWithDigits,
    );
  }

  /// Characters counted as part of a word besides letters.
  final Set<String> extraWordCharacters;

  /// Whether a token with no lowercase letter (a scene heading, a
  /// character cue, a shouted word) is dropped rather than checked.
  final bool skipAllCapsTokens;

  /// Whether a token holding a digit is dropped rather than checked.
  final bool skipTokensWithDigits;
}

/// One word-shaped run of text found by [spellTokensIn].
@immutable
class SpellToken {
  /// Creates a [SpellToken].
  const SpellToken(this.text, this.range);

  /// The token's text, already trimmed of leading/trailing apostrophes and
  /// hyphens.
  final String text;

  /// The token's span in the text it was found in, in UTF-16 code units.
  final SpellRange range;

  @override
  bool operator ==(Object other) =>
      other is SpellToken && other.text == text && other.range == range;

  @override
  int get hashCode => Object.hash(text, range);

  @override
  String toString() => 'SpellToken($text, $range)';
}

/// Matches a whitespace-delimited chunk of the text being tokenized.
final RegExp _chunkPattern = RegExp(r'\S+');

/// The compiled word pattern of every distinct extra-word-character set seen
/// so far. [spellTokensIn] is called once per checked text and a debounce
/// tick checks every changed block of a screenplay, so recompiling the same
/// pattern for each of them would be pure waste; the set of distinct options
/// a process ever uses is one or two.
final Map<String, RegExp> _wordPatternCache = {};

/// The word pattern for [extraWordCharacters], compiled once per distinct
/// set.
///
/// Digits are always part of a candidate token's body — not gated by
/// [SpellTokenizerOptions.extraWordCharacters] — so that, for example,
/// `page2` is cut out as one token and can then be dropped whole by
/// [SpellTokenizerOptions.skipTokensWithDigits], rather than silently
/// fragmenting into a clean-looking `page`.
RegExp _wordPatternFor(Set<String> extraWordCharacters) {
  final sorted = extraWordCharacters.toList()..sort();
  final key = sorted.join();
  return _wordPatternCache[key] ??= RegExp(
    '[\\p{L}\\p{Nd}${sorted.map(RegExp.escape).join()}]+',
    unicode: true,
  );
}

/// Whether [chunk] reads as a URI, an email address or a file path, and so
/// should never be offered up as word tokens at all.
bool _isNonWordChunk(String chunk) =>
    chunk.contains('@') ||
    chunk.contains('://') ||
    chunk.contains(r'\') ||
    chunk.contains('/') ||
    chunk.toLowerCase().startsWith('www.');

/// Whether [text] contains no lowercase letter and at least one cased
/// letter (so a token of only digits or punctuation does not count).
bool _isAllCaps(String text) =>
    text == text.toUpperCase() && text != text.toLowerCase();

/// Finds every word-shaped token in [text].
///
/// Tokenizing runs in two stages: [text] is first split into
/// whitespace-delimited chunks, and a chunk that reads as a URI, an email
/// address or a file name is dropped whole; each surviving chunk is then
/// cut into runs of letters, digits, and
/// [SpellTokenizerOptions.extraWordCharacters], with leading and trailing
/// apostrophes and hyphens trimmed off — a digit-holding run is then
/// dropped whole by [SpellTokenizerOptions.skipTokensWithDigits] rather
/// than silently fragmenting into a clean-looking token. Offsets
/// are UTF-16 code units, the unit `TextRange`, `AttributedText` and
/// `TextEditingValue` all count in.
List<SpellToken> spellTokensIn(
  String text, {
  SpellTokenizerOptions options = const SpellTokenizerOptions(),
}) {
  final wordPattern = _wordPatternFor(options.extraWordCharacters);

  final tokens = <SpellToken>[];
  for (final chunkMatch in _chunkPattern.allMatches(text)) {
    final chunk = chunkMatch.group(0)!;
    if (_isNonWordChunk(chunk)) {
      continue;
    }
    for (final wordMatch in wordPattern.allMatches(chunk)) {
      var start = wordMatch.start;
      var end = wordMatch.end;
      while (start < end && _trimmedBoundaryCharacters.contains(chunk[start])) {
        start++;
      }
      while (end > start &&
          _trimmedBoundaryCharacters.contains(chunk[end - 1])) {
        end--;
      }
      if (start == end) {
        continue;
      }
      final tokenText = chunk.substring(start, end);
      if (options.skipTokensWithDigits && _digitPattern.hasMatch(tokenText)) {
        continue;
      }
      if (options.skipAllCapsTokens && _isAllCaps(tokenText)) {
        continue;
      }
      tokens.add(
        SpellToken(
          tokenText,
          SpellRange(chunkMatch.start + start, chunkMatch.start + end),
        ),
      );
    }
  }
  return tokens;
}
