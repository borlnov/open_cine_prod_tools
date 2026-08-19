<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.1.0

- Initial release: a pure Dart hunspell dictionary reader, spell checker
  and suggester, built to be fed the two bundled `fr` and `en_GB`
  dictionaries but not tied to either.
- Parses `.aff` files: `SET`, `KEY`, `FLAG` (single-character and `long`
  widths), `TRY`, `WORDCHARS`, `MAP`, `REP`, `ICONV`/`OCONV`, `NEEDAFFIX`,
  `CIRCUMFIX`, `KEEPCASE`, `FORBIDDENWORD`, `NOSUGGEST`, `ONLYINCOMPOUND`,
  `FULLSTRIP`, `COMPOUNDMIN`, `COMPOUNDRULE`, `BREAK` (with hunspell's own
  default when a file declares none), and `PFX`/`SFX` blocks, in a single
  forward pass over the source.
- Parses `.dic` files into a word-to-flags map, merging duplicate entries
  and unescaping `\/`.
- `SpellChecker.isKnown` resolves a word through exact, single-affix and
  cross-product dictionary lookup (continuation classes and `CIRCUMFIX`
  honoured both ways, case folding respecting `KEEPCASE`), `BREAK`
  splitting, and `COMPOUNDRULE` flag-pattern matching, backed by a bounded
  LRU memo and a rule index bucketed by affix-append character.
- `SpellChecker.setExtraWords` layers in a caller-provided set of extra
  known words (learned/ignored), matched case-insensitively unless typed
  with an interior capital.
- `spellTokensIn` cuts word tokens out of running text, skipping URIs,
  emails, file paths, all-caps tokens and tokens holding a digit, with
  offsets in UTF-16 code units.
- `SpellSuggester.suggestionsFor` ranks corrections through the `REP`
  table, `MAP` group substitution, a single edit, and a two-word split,
  capped and with the typed word's capitalisation carried onto the result.
