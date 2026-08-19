// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/hunspell_affix_file.dart';

/// A parsed hunspell dictionary pair: the `.aff` rules and the `.dic`
/// word list they apply to, ready to hand to a spell checker or a
/// suggester.
///
/// The engine never reads a file itself — `parse` takes the two sources as
/// plain `String`s, which is what keeps this package free of `dart:io` and
/// testable from a miniature pair written straight into a test.
class SpellDictionary {
  /// Creates a [SpellDictionary]. Prefer [SpellDictionary.parse].
  const SpellDictionary({required this.affixFile, required this.entries});

  /// Parses [affix] and [dictionary] (the verbatim contents of a `.aff`
  /// file and its matching `.dic` file) into a [SpellDictionary].
  factory SpellDictionary.parse({
    required String affix,
    required String dictionary,
  }) => SpellDictionary(
    affixFile: HunspellAffixFile.parse(affix),
    entries: _parseDictionaryEntries(dictionary),
  );

  /// The parsed `.aff` rules.
  final HunspellAffixFile affixFile;

  /// Every `.dic` entry: the dictionary word mapped to its raw,
  /// concatenated flag string (kept as a string, not a `Set`, per the
  /// package's own memory budget — a `Set` per entry costs tens of
  /// megabytes for no benefit over striding the string one or two
  /// characters at a time). Duplicate entries in the source (the French
  /// dictionary carries 1 903 of them) are merged by concatenating their
  /// flag strings, so no flag either copy declared is lost.
  final Map<String, String> entries;
}

/// Parses the body of a `.dic` file into a word-to-flags map.
///
/// The first line is conventionally the entry count; it is skipped when it
/// parses as an integer and otherwise tolerated as a missing header (in
/// which case the line is read as a word like any other). Each remaining
/// line is `word` or `word/flags`; a `\/` inside the word is unescaped to a
/// literal `/`, and any morphological fields (space-separated `key:value`
/// tokens hunspell allows after the flags) are dropped, since neither
/// bundled dictionary carries any.
Map<String, String> _parseDictionaryEntries(String source) {
  final lines = source.split('\n');
  final startIndex =
      lines.isNotEmpty && int.tryParse(lines.first.trim()) != null ? 1 : 0;

  final entries = <String, String>{};
  for (var i = startIndex; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final firstToken = trimmed.split(RegExp(r'\s+')).first;
    final entry = _parseDictionaryLine(firstToken);
    final existing = entries[entry.word];
    entries[entry.word] = existing == null
        ? entry.flags
        : existing + entry.flags;
  }
  return entries;
}

/// One `.dic` entry's word and raw flag string, before duplicate merging.
class _DictionaryEntry {
  /// Creates a [_DictionaryEntry].
  const _DictionaryEntry({required this.word, required this.flags});

  /// The dictionary word, with any `\/` escape already unescaped.
  final String word;

  /// The raw, concatenated flag string (empty if the entry carried none).
  final String flags;
}

/// Parses a single `.dic` token (morphological fields already stripped)
/// into its word and flags, splitting on the first unescaped `/`.
_DictionaryEntry _parseDictionaryLine(String token) {
  final word = StringBuffer();
  var i = 0;
  while (i < token.length) {
    if (token[i] == r'\' && i + 1 < token.length && token[i + 1] == '/') {
      word.write('/');
      i += 2;
    } else if (token[i] == '/') {
      break;
    } else {
      word.write(token[i]);
      i++;
    }
  }
  final flags = i < token.length ? token.substring(i + 1) : '';
  return _DictionaryEntry(word: word.toString(), flags: flags);
}
