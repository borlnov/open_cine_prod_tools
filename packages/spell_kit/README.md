<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# spell_kit

A pure Dart hunspell dictionary reader, spell checker and suggester.

`spell_kit` has no Flutter dependency and no I/O of its own: it never reads
a file — the caller hands it the `.aff` and `.dic` contents as `String`s —
which is what keeps it testable from a miniature dictionary pair and
usable from any Dart project, on any platform. It is the checking engine
behind Open Cine Prod Tools' screenplay editor, but it does not depend on
the app and can be used standalone.

## Hunspell coverage

- `.aff` parsing: `SET`, `KEY`, `FLAG` (single-character and `long`
  widths), `TRY`, `WORDCHARS`, `MAP`, `REP`, `ICONV`/`OCONV`, `NEEDAFFIX`,
  `CIRCUMFIX`, `KEEPCASE`, `FORBIDDENWORD`, `NOSUGGEST`, `ONLYINCOMPOUND`,
  `FULLSTRIP`, `COMPOUNDMIN`, `COMPOUNDRULE`, `BREAK` (including
  hunspell's own default of `-`, `^-`, `-$` when a file declares none at
  all), and `PFX`/`SFX` blocks with condition classes and continuation
  flags.
- `.dic` parsing: word-to-flags entries, duplicate merging, `\/`
  unescaping, morphological fields dropped.
- Lookup: exact hit, one suffix, one prefix, and the prefix+suffix cross
  product — continuation classes satisfied from either side, `CIRCUMFIX`
  pairing enforced, case folding (`KEEPCASE` respected), `BREAK` splitting,
  and `COMPOUNDRULE` flag-pattern matching.
- Suggestions: the `REP` table, `MAP` group substitution, one edit
  (deletion, adjacent transposition, replacement, insertion), and a split
  into two known words — deduplicated, `NOSUGGEST` stems refused, capped,
  with the typed word's capitalisation carried onto each suggestion.

Not implemented, deliberately: grammar, `COMPOUNDFLAG` chaining, hunspell's
`n`-gram suggestion tier, and frequency ranking (neither bundled
dictionary ships frequencies).

## Usage

```dart
import 'dart:io';

import 'package:spell_kit/spell_kit.dart';

void main() {
  final dictionary = SpellDictionary.parse(
    affix: File('index.aff').readAsStringSync(),
    dictionary: File('index.dic').readAsStringSync(),
  );

  final checker = SpellChecker(dictionary);
  final ranges = checker.misspellingsIn('Ze cat sat on teh mat.');

  final suggester = SpellSuggester(checker);
  for (final range in ranges) {
    print(suggester.suggestionsFor('teh'));
  }
}
```

## Performance

A `SpellChecker` owns a bounded memo (an LRU of the last ~20 000 distinct
words) and a rule index (suffix rules bucketed by the last character of
their `append`, prefix rules by the first), so a warm pass over
already-seen text costs an order of magnitude less than the cold one, and
an uncached lookup only weighs the rules whose `append` the word could
actually carry rather than every rule the dictionary declares. How much
that narrows is the dictionary's own doing: on the French file's 5 184
suffix rules it ranges from 23 candidates for a word ending in `g` to
2 018 for one ending in `s`, thousands of conjugation suffixes genuinely
sharing that ending.

## License

Licensed under the Apache-2.0 license, like the rest of Open Cine Prod
Tools. See the repository's [LICENSES](../../LICENSES/) directory for the
full license text.
