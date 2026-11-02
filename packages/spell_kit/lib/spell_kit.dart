// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A pure Dart hunspell dictionary reader, spell checker and suggester.
///
/// `spell_kit` has no Flutter dependency and no I/O of its own: it never
/// reads a file — the caller hands it the `.aff` and `.dic` contents as
/// `String`s, through `SpellDictionary.parse` — which is what keeps it
/// testable from a miniature dictionary pair and usable from any Dart
/// project, on any platform.
library;

export 'package:spell_kit/src/hunspell_affix_file.dart' show HunspellAffixFile;
export 'package:spell_kit/src/hunspell_affix_rule_index.dart' show HunspellAffixRuleIndex;
export 'package:spell_kit/src/hunspell_dictionary.dart' show SpellDictionary;
export 'package:spell_kit/src/spell_checker.dart' show SpellChecker;
export 'package:spell_kit/src/spell_range.dart' show SpellRange;
export 'package:spell_kit/src/spell_suggester.dart' show SpellSuggester;
export 'package:spell_kit/src/spell_token.dart';
export 'package:spell_kit/src/spell_tokenizer.dart' show SpellTokenizerOptions, spellTokensIn;
