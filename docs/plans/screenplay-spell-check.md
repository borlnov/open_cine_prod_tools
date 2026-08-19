<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Screenplay editor — spell-checking as you type

This document is the implementation strategy for
[issue 66](https://github.com/borlnov/open_cine_prod_tools/issues/66). It is written for the
Sonnet 5 agents that will build it, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `CLAUDE.md` first**, then
[`docs/architecture/screenplay.md`](../architecture/screenplay.md) and
[`docs/architecture/foundations.md`](../architecture/foundations.md) — this plan assumes their
architecture, ways of working, coding standards, licensing rules and verification gates, and does
not repeat them.

---

## 1. What the ground truth actually is

The issue is right about the platform giving us nothing, and right that the detector has to be this
application. Two of its implementation sentences are wrong, and one of them changes the shape of a
milestone. Everything in this section was read in the pinned sources or measured by a throw-away
spike, never guessed.

### 1.1 The styled mode's half is genuinely free

`SpellingAndGrammarStyler` (`super_editor/lib/src/default_editor/spelling_and_grammar/`, exported
by `package:super_editor/super_editor.dart` in the pinned `0.3.0-dev.52`) is a
`SingleColumnLayoutStylePhase` taking `TextError`s keyed by node id and writing
`TextComponentViewModel.spellingErrors` onto a **copy** of each component view model — the very
shape `OcptSearchMatchStyler` already has, down to `markDirty()` being what makes a re-style
happen. `text.dart:642` turns those ranges into the component's `underlines`, so the squiggle is
painted by super_editor itself. `OcptTitlePageComponentBuilder` extends `ParagraphComponentBuilder`
and defers to `super.createComponent`, so title-page fields would be underlined the same way any
body block is — which is a decision to make (§4.3), not a limitation.

So the styled mode needs **no styler of our own**: the package's is handed to `SuperEditor`'s
`customStylePhases` next to `_searchMatchStyler`, and the work is entirely in *who computes the
ranges*.

### 1.2 The raw mode cannot use `SpellCheckConfiguration` — it would delete the find bar's highlight

The issue says the raw mode "is a plain `TextField` and takes a `SpellCheckConfiguration`". It
takes one, and the moment it does, the find/replace highlight stops being painted.

`EditableText._buildTextSpan` (`editable_text.dart:5976`, Flutter 3.44.6) reads:

```dart
if (_spellCheckResultsReceived) {
  return buildTextSpanWithSpellCheckSuggestions(…);
}
return widget.controller.buildTextSpan(context: context, style: _style, withComposing: …);
```

`OcptEditorSearchTextController.buildTextSpan` is the raw mode's **only** way of painting a search
match (`docs/architecture/screenplay.md`, "Find and replace"). As soon as one spell-check result
arrives, that override is never called again, and every match highlight silently disappears. There
is no seam to share: `buildTextSpanWithSpellCheckSuggestions` is a `TextSelectionDelegate` mixin
method building the whole span from `spellCheckResults` alone.

Two smaller findings point the same way:

- spell-checking is triggered only from `_updateEditingValue`'s IME path
  (`editable_text.dart:4631`, guarded by `_value.text != value.text` **inside** the formatter
  block), so a programmatic write to the controller — which is how the page pushes a version
  restore, an import, an episode switch or a `Replace all` into the field — would leave the
  underlines describing the previous text;
- `_performSpellCheck` asserts a `Locale` is in scope and passes `Localizations.maybeLocaleOf`,
  i.e. the **UI** locale, which §4.1 says is precisely not the language a screenplay is written in.

**Consequence for the plan**: the raw mode paints misspellings itself, inside the controller that
already paints its search matches, from ranges the same manager computes for both modes. Flutter's
`SpellCheckConfiguration`/`SpellCheckService` is not used anywhere in this app, and
`docs/architecture/screenplay.md` records why.

### 1.3 The dictionaries exist, with licences we can ship

Both are hunspell `.dic`/`.aff` pairs, taken verbatim from
[`wooorm/dictionaries`](https://github.com/wooorm/dictionaries) (which republishes the upstream
projects unmodified):

| Language | Upstream | Licence | Size | Flags | Stems |
| --- | --- | --- | --- | --- | --- |
| `fr` | Dictionnaires français 7.5, Olivier R. (Grammalecte) | MPL-2.0 | 1.2 MB dic + 200 kB aff | `FLAG long` | 82 327 |
| `en_GB` | `en_GB-ise`, derived from SCOWL 2020.12.07 (Kevin Atkinson) | SCOWL's own permissive notice, with the Ispell BSD notice for the affix file | 552 kB dic + 3 kB aff | single char | 49 601 |

The French `.aff` uses 5 184 suffix rules, 197 prefix rules, `CIRCUMFIX`, `NEEDAFFIX`, `KEEPCASE`,
`FORBIDDENWORD`, `FULLSTRIP`, 7 `BREAK` patterns, and `REP`/`TRY`/`MAP` tables for suggestions. The
English one adds `COMPOUNDRULE`/`ONLYINCOMPOUND` (3 rules, for the `1st`/`2nd` ordinal family) and
declares **no** `BREAK` at all, which matters — see §1.4.

### 1.4 The engine works: measured, not assumed

A throw-away spike implemented what §2 calls the reader and the reverse lookup — `.aff` parsing
(both flag widths), a `Map<String, flags>` index over the `.dic`, and hunspell's own lookup
strategy of *stripping* affixes off the typed word and checking the stem carries the rule's flag,
including the prefix+suffix cross product and the continuation classes French elision needs. It ran
on the real dictionaries, on a probe list per language:

- **French: 30 correct words and 7 misspellings, 0 false alarms and 0 misses.** The correct list
  deliberately included the hard cases: conjugations (`chuchotèrent`, `aperçoive`, `irions`,
  `eussent`), elisions written as one token (`l'homme`, `aujourd'hui`, `qu'elle`, `presqu'île`,
  `s'approche`), hyphenated compounds (`arrière-plan`, `contre-jour`, `peut-être`) and screenplay
  vocabulary (`crépuscule`, `fondu`, `travelling`).
- **English: 20 correct words and 6 misspellings, 0 misses, 2 false alarms** — `close-up` and
  `backlit`. They are the two findings that shaped §2.3 and §4.4:
  - `close-up` is a false alarm **because the spike ignored `BREAK`**. The `en_GB` affix file
    declares none, and hunspell's documented default is then `-`, `^-`, `-$`: the word is checked
    as `close` + `up`, both of which the dictionary has. Every hyphenated English compound depends
    on this, so `BREAK` (with that default) is part of the engine, not an option.
  - `backlit` is genuinely absent from this dictionary at the SCOWL size upstream ships. Nothing in
    the engine can fix that, which is the whole argument for "add to the project's dictionary"
    being in the same issue as the underline.
- **Load cost** (JIT, cold): French `.aff` 621 ms + `.dic` index 236 ms; English 17 ms + 252 ms.
  The 621 ms is the spike's own fault — it rescanned the file backwards for each rule's block
  header instead of remembering the current block — so the real figure to plan around is roughly
  **250-350 ms per language**, once, in an isolate.
- **Throughput**: French ~49 µs/word (2 000 words in 98 ms), English ~3 µs/word. French is the slow
  one because 5 184 suffix rules are candidates; §2.3 says how it is indexed and memoised. A 20 000
  word screenplay is ~1 s of cold checking, which is why the pass is incremental and cached rather
  than whole-document per debounce tick.
- **Retained memory**, measured on the French index: `Map<String, Set<String>>` costs ~37 MB while
  `Map<String, String>` — flags kept as the raw flag string, membership tested by a 1- or 2-char
  stride — costs ~14 MB. The engine keeps the string form; 82 327 `Set`s is a 23 MB tax for nothing.

---

## 2. `packages/spell_kit` — the engine

A new pure-Dart package next to `fountain_kit`, **free of Flutter imports** like it, for the same
reason: it is a text algorithm with a round-trip-ish guarantee to test, and the app layer above it
should be able to hand it a `String` and get ranges back with no plumbing in the way.

### 2.1 What it holds

| File | Content |
| --- | --- |
| `lib/src/hunspell_affix_file.dart` | `.aff` parsing: `SET`, `FLAG`, `TRY`, `WORDCHARS`, `BREAK`, `MAP`, `REP`, `ICONV`/`OCONV`, `NEEDAFFIX`, `CIRCUMFIX`, `KEEPCASE`, `FORBIDDENWORD`, `NOSUGGEST`, `ONLYINCOMPOUND`, `FULLSTRIP`, `PFX`/`SFX` blocks. One pass, remembering the current block header. |
| `lib/src/hunspell_dictionary.dart` | the `.dic` index: `Map<String, String>` word → raw flag string, morphological fields dropped, `\/` unescaped, duplicate entries merged. |
| `lib/src/spell_checker.dart` | `isKnown(String word)`: `ICONV` folding, exact hit, one suffix, one prefix, prefix+suffix cross product with continuation classes, case folding (`KEEPCASE` respected), `FORBIDDENWORD`/`NEEDAFFIX`/`ONLYINCOMPOUND` refusals, `BREAK` splitting with hunspell's default when the file declares none, `COMPOUNDRULE` for the flag patterns `en_GB` needs. |
| `lib/src/spell_suggester.dart` | `suggestionsFor(word, limit)`: `REP` table first (hunspell's own ordering, they are the real typos of the language), then `MAP` groups (French accents: `sequence` → `séquence`), then one edit — deletion, transposition, replacement and insertion drawn from `TRY` — then a split into two known words. Deduplicated, `NOSUGGEST` stems refused, capped. |
| `lib/src/spell_tokenizer.dart` | `spellTokensIn(String text)` → `(start, end, text)` records over a text, using the affix file's `WORDCHARS`, plus the skip rules of §4.3 as a plain options object. Offsets are UTF-16 code units, the unit every consumer of this (`TextRange`, `AttributedText`, `TextEditingValue`) counts in. |
| `lib/src/spell_range.dart` | `SpellRange(start, end)`, `Equatable`-less value type (the package has no Flutter/equatable dependency; `==`/`hashCode` written by hand, as `fountain_kit` does). |

Public surface: `lib/spell_kit.dart` exporting `SpellDictionary.parse({required String affix,
required String dictionary})`, `SpellChecker`, `SpellRange`, `SpellTokenizerOptions`. The package
never reads a file: **the caller hands it the two sources as strings**, which is what keeps it free
of `dart:io`, of `rootBundle`, and testable from a `test/fixtures/` miniature pair.

### 2.2 What it deliberately does not do

- No grammar, per the issue.
- No compounding beyond `COMPOUNDRULE`'s flag patterns: German-style `COMPOUNDFLAG`/`COMPOUNDMIN`
  chaining is unused by both shipped dictionaries and would be dead code.
- No `PHONE`, no `n`-gram suggestion pass: hunspell's third suggestion tier costs a scan of the
  whole dictionary per request, for candidates the first two tiers already cover on a typo.
- No frequency ranking. Neither dictionary ships frequencies.

### 2.3 The two performance rules the tests pin

1. Suffix rules are indexed by the **last character of their `append`** (and prefix rules by the
   first), with the empty-`append` rules in their own bucket, so a lookup considers a few dozen
   candidates instead of 5 184.
2. `SpellChecker` memoises `isKnown` per word in a `Map<String, bool>` it owns, bounded (an LRU of
   the last ~20 000 distinct words is more than a feature film's vocabulary). A screenplay repeats
   its words heavily, and the second pass over a paragraph must cost nothing. The cache is dropped
   whenever the extra-word set changes (§5.3).

`test/` carries a benchmark-shaped test asserting the *shape* of these (a warm second pass is an
order of magnitude cheaper than the cold one), never a wall-clock threshold — a CI runner's timing
is not a specification.

### 2.4 The dictionaries as assets

```text
assets/dictionaries/fr/index.dic        # verbatim upstream, MPL-2.0
assets/dictionaries/fr/index.aff
assets/dictionaries/fr/LICENCE.txt      # upstream licence text, verbatim
assets/dictionaries/en_GB/index.dic     # verbatim upstream, SCOWL notice
assets/dictionaries/en_GB/index.aff
assets/dictionaries/en_GB/LICENCE.txt
```

- Declared in `pubspec.yaml`'s `assets:` **one directory per language**, next to the fonts.
- Verbatim, byte for byte: it is what makes the licensing statement true, and what lets a later
  dictionary bump be a file swap rather than a re-derivation.
- REUSE: a `REUSE.toml` block per language (binary-ish data files with no comment syntax, exactly
  like the fonts), `SPDX-License-Identifier = "MPL-2.0"` for `fr` and
  `"LicenseRef-SCOWL"` for `en_GB`, with `LICENSES/MPL-2.0.txt` and
  `LICENSES/LicenseRef-SCOWL.txt` added. `LicenseRef-` is the honest form for `en_GB`: the upstream
  notice is a bespoke permissive grant carrying the Ispell BSD and several public-domain notices
  inside it, and no SPDX id names that collection; the repository already ships
  `LicenseRef-ALLCircuits-ACT-1.1` the same way. `reuse lint` staying at 100% is the acceptance
  criterion.
- The `LICENCE.txt` copies inside each language directory are for the user who unpacks the bundle
  and needs the notice next to the file it covers, which both licences require.

### 2.5 CI

`.github/workflows/flutter_lint.yml` gets a third matrix entry, `{ name: spell_kit, path:
packages/spell_kit }`. Its per-package steps are keyed on `matrix.package.path != '.'`, so they
already cover a second package — only their **names** say `fountain_kit`; rename those four steps
to "(package)" rather than adding a duplicated pair.

---

## 3. Where it lives in the app

```text
OcptSpellCheckManager (AbsWithLifeCycle, registered in OcptGlobalManager)
  └── one long-lived worker isolate
        └── SpellChecker (spell_kit) + the project's learned words + the session's ignored words
OcptProjectDictionaryService (lib/managers/projects/services/)
  └── the learned words of the open project, in a synchronised table
OcptEditorBloc
  ├── asks the manager for ranges on the existing 150 ms parse debounce
  └── holds them in OcptEditorState, per editing surface's own addressing
        ├── styled: SpellingAndGrammarStyler ← TextError per node id
        └── raw: OcptEditorSearchTextController ← ranges over the source text
```

### 3.1 The manager and its isolate

`OcptSpellCheckManager` (`lib/managers/ocpt_spell_check_manager.dart`), registered in
`OcptGlobalManager` with a builder factory, `dependsOn` nothing but the config/properties managers
it reads its on/off preference from. It owns:

- `Future<void> useLanguage(OcptScreenplayLanguage? language)` — loads the two assets on the **main**
  isolate (`rootBundle.loadString`, ~1.8 MB, cheap) and sends the two strings to the worker, which
  parses them there. This is deliberate: `rootBundle` in a plain isolate needs a
  `BackgroundIsolateBinaryMessenger.ensureInitialized(RootIsolateToken)` dance, and sending two
  strings avoids the platform channel entirely. `null` unloads the dictionary and stops the worker.
- `Future<Map<K, List<SpellRange>>> check<K>(Map<K, String> textsByKey)` — one round trip per
  debounce tick, batching every text the caller wants checked. Requests carry a **generation**
  number; a response from a stale generation (language changed, word list changed) is dropped by
  the manager rather than reaching the UI.
- `Future<List<String>> suggestionsFor(String word)` — on demand only, from the right-click.
- `void ignoreWords(Set<String>)` / `void setLearnedWords(Set<String>)` — pushed in by the bloc,
  bumping the generation and clearing the worker's memo.

The worker is one isolate for the whole app, not one per editor mount: the dictionary costs 14 MB
and 300 ms, and the editor is remounted by an episode switch, a mode toggle, an import and a
version restore. It is spawned lazily on the first `useLanguage`, and `disposeLifeCycle` kills it.

The manager sees **no `Tr`** and no project row: the bloc resolves both.

### 3.2 The bloc and the debounce

The check rides the editor's existing 150 ms parse debounce, exactly as
`OcptEditorInspectorPanel`/`OcptEditorMetadataPanel`'s recomputes do, and never a keystroke:
`_onParseRequested` already runs there with a fresh `FountainDocument` in hand, which is what makes
the block-type skip rules of §4.3 free — the classification has just been done.

What is sent depends on the mounted surface, and the two are not interchangeable (this is the same
"each mode matches what it shows" rule the find bar already obeys): raw mode is checked over the
**Fountain source text**, whose offsets are what its controller paints in; the styled mode is
checked over each node's **display text**, keyed by node id, because that is what
`SpellingAndGrammarStyler` addresses. The styled editor therefore reports the texts to check up
through `OcptStyledEditorController` (a new `reportSpellCheckTexts` on the delegate, mirroring
`reportSearchMatchCount`'s direction) and receives ranges back the way `updateSearch` already
travels; the bloc never learns about node ids from anywhere else.

Only *changed* texts are sent: the bloc keeps the last text it checked per key and skips the ones
that are identical, so a keystroke in one paragraph costs one paragraph's check, not the
screenplay's. Combined with `SpellChecker`'s memo, the steady-state cost of typing is a handful of
words.

Nothing is checked while a **read-only preview** is showing: there is no editing surface there, no
correction to apply, and the plan withholds the whole feature exactly as the find bar is withheld.

---

## 4. The decisions this feature has to make

### 4.1 The language is the project's, and the UI's locale is only its seed

A new `screenplayLanguage` column on `project_info`, beside `pageFormat` and `currencyCode`, whose
doc comment reuses their argument: a screenplay written in French stays French on a colleague's
machine running the app in English, so the fact travels inside the `.ocpt` file.

- Typed `OcptScreenplayLanguage { fr, enGb }` in `lib/types/`, stored through a
  `TypeConverter` like `OcptPageFormat`'s, **nullable**: `null` means "nobody said", and nothing is
  checked. That is what a project created before this feature reads as, and it is also the honest
  answer for a project whose language we would otherwise have to guess.
- Seeded at project creation from the UI locale (`fr` → `fr`, anything else → `enGb`), which is a
  guess made once, at the only moment where a wrong guess costs a dropdown pick.
- Shown by a new `OcptProjectSettingsLanguageSection` in the project settings page, next to the
  currency and page-format sections, with the same `DropdownButton` shape. Its two entries are the
  two bundled dictionaries plus a "None" entry, and picking "None" is the honest off switch for a
  project (§4.2 covers the app-level one).
- Not per episode: a series is written in one language, and the plan refuses to put a language
  picker in the episode selector for the case of a bilingual series that this project has never
  seen. If it ever appears, a nullable column on `screenplays` overriding this one is an additive
  migration.

### 4.2 On and off

Two switches, each answering a different question, and neither is a new kind of control:

- **the project's language** (§4.1) says *what* is checked — "None" means this screenplay is in a
  language we cannot check;
- **`OcptPropertiesManager.spellCheckVisible`**, a `SharedPreferencesItem<bool>` next to
  `styledSceneNumbersVisible`, says whether *this machine* wants to see the underlines, offered as
  a checkbox entry in the editor's `⋮` menu right below `Show scene numbers`. Null reads as `true`.
  It is the switch for "I am doing a read-through and the red is in my way", it costs a
  `SharedPreferences` write, and it does not touch the project file.

With either off, no check request is made at all — the isolate stays unloaded, and nothing is
painted.

### 4.3 What is checked inside a screenplay, and what is left alone

A screenplay is not prose, and checking it like prose would produce a page of red on a correct
script. The rules, applied by the bloc from the `FountainDocument` it already has, plus the
tokenizer's own:

| Left alone | Why |
| --- | --- |
| Scene headings | `INT. CUISINE DE MARIE - JOUR` is a set name in capitals: proper nouns, abbreviations, and a syntax of its own. |
| Character cues and `(CONT'D)`/`(MORE)` | a cue is a name, and the writer's names are exactly what a dictionary does not have. |
| Transitions | `CUT TO:`, `FADE OUT.` — a fixed vocabulary that is not the language's. |
| Notes, boneyard, synopses, sections | authoring scaffolding, not the script. |
| Title-page fields | a title is invented on purpose; the six fields exist only under page simulation, and underlining them would make the squiggles appear and disappear with a display toggle. |
| Lyrics | sung text is written as it is heard. |
| Any token in all capitals | the convention that introduces a silent character (`docs/architecture/resources.md`) and every shouted word — the same guard `charactersIntroducedInActionOf` already needs. |
| Any token holding a digit, or reading as a URL, an email or a file name | not words. |

**Checked**: action, dialogue, parenthetical, and general text — the prose of the screenplay, which
is all a writer wants a checker for.

### 4.4 Ignore, and learn

- **"Ignore this word"** — session-only, held by the manager, dropped when the app closes. It is
  the answer to "not now", and persisting it would silently build a second dictionary nobody can
  see or edit.
- **"Add to the project's dictionary"** — persisted in the project file, in a **new synchronised
  table** `project_dictionary_words` (`id` UUID, `word`, `isDeleted`, primary key `id`), written by
  a new `OcptProjectDictionaryService`. A table rather than a key in `project_info.settingsJson`
  because it is the difference, once sync lands, between two writers merging the two names they
  each taught the checker and one of them overwriting the other's list (ADR 0010: no service ever
  deletes a synchronised row, and every read filters tombstones). Case: the word is stored as
  typed, and matched case-insensitively unless it was typed with an interior capital, which is what
  makes `Marie` cover `marie`'s absence without `MacGuffin` covering `macguffin`.
- Both appear in the styled editor's right-click menu (§4.5). Neither has a management screen in
  this issue — a learned word is removed by no UI yet, which is a deliberate gap worth stating
  rather than a forgotten one; the resources mode is where such a list would eventually belong.

### 4.5 Where a correction is offered

The styled mode's `OcptEditorContextMenu`, which #65's M3 built for exactly this:

- when the right-click lands on a misspelled word, the menu opens with **up to five suggestions**
  at the top, then a divider, then `Ignore this word` and `Add to the project's dictionary`, then
  the existing Cut/Copy/Paste/Select all and the block-type submenu;
- picking a suggestion replaces the word through the same `Editor` request path a paste uses, so it
  is **one undo step** (`docs/architecture/screenplay.md`, "Undo and redo") and the reclassification
  it triggers merges into it;
- when the click lands on a correctly spelled word — or spell-checking is off — nothing spelling
  related appears at all: entries are **withheld, not disabled**, the repository-wide rule the menu
  already follows for Cut and Copy;
- suggestions are fetched when the menu opens, not on every check pass: a right-click can await one
  isolate round trip (~1 ms warm), and computing suggestions for every misspelling in a screenplay
  on every debounce tick would be work for a menu that never opens.

The raw mode underlines and offers nothing, per the decision recorded in the issue: it is the
surface one drops into to read or fix the source, and it keeps Flutter's native menu untouched. The
`⋮` menu is where a raw-mode writer switches the underlines off.

---

## 5. Milestones

Each milestone ends green on the full gate list of `CLAUDE.md` §"Verification gates", is one or a
few commits, and stops for a user checkpoint. Milestones are delegated to Sonnet 5 agents; the main
session reviews.

### M1 — the engine and the dictionaries

`packages/spell_kit` as §2 describes it, the four asset files with their REUSE annotations and
licence texts, the CI matrix entry. **Nothing is wired into the app**, and `flutter analyze` will
not even see the package's code from the app side.

Acceptance:

- `dart test` inside the package covers, from `test/fixtures/` miniature `.aff`/`.dic` pairs: both
  flag widths, a suffix, a prefix, the cross product, a continuation class, `NEEDAFFIX`,
  `KEEPCASE`, `FORBIDDENWORD`, `FULLSTRIP`, `BREAK` including the declared-none default, and
  `COMPOUNDRULE`;
- plus a test over the **real** bundled dictionaries (they are in the repository, so the package's
  tests may read them from `../../assets/`) asserting the two probe lists of §1.4 word for word:
  the French list passes with no false alarm, the English list passes with `close-up` accepted
  through `BREAK` and `backlit` documented in the test itself as the dictionary's own gap;
- the memo and the rule indexing exist and are covered by the shape test of §2.3;
- `reuse lint` is compliant, and `LICENSES/` has gained exactly two files.

### M2 — the project's language

The `project_info.screenplayLanguage` column, `OcptScreenplayLanguage`, the seeding at project
creation, the project settings section, both ARB files, and the whole schema round trip: one new
schema version **allocated at merge time** (ADR 0007) covering this column *and* M4's table, the
`OcptProjectVersionCodec` payload/`contentDigest`/`_applyPayload` triple, and
`OcptProjectVersionsService`'s capture and restore.

Visible outcome: the language can be chosen and survives a save, a reopen, a version capture and a
version restore. Nothing is checked yet.

Acceptance: a project settings page test for the dropdown, a codec round-trip test carrying the new
column, a migration test opening a pre-migration file and reading `null`, French terminology
respected in `intl_fr.arb` (« la langue d'écriture », never « scène » anywhere near it).

### M3 — the underline, in both modes

`OcptSpellCheckManager` and its isolate, the `⋮` toggle, the bloc's debounced pass, the skip rules
of §4.3, `SpellingAndGrammarStyler` wired into the styled editor's `customStylePhases`, and the raw
controller painting misspellings under its own search highlight.

The two known traps, both already paid for once by the search styler and named here so they are not
rediscovered:

- the styler's `markDirty()` must be **deferred to a post-frame callback** when it comes from a
  document-change path, or a delete/cut crashes inside the still-open `Editor.execute` transaction
  (`docs/architecture/screenplay.md`, "Find and replace");
- ranges computed against a text that has since changed must be **clamped and dropped**, never fed
  to `AttributedText.addAttribution` — `OcptSearchMatchStyler` and
  `OcptEditorSearchTextController` both already carry that guard, and a spelling range arrives one
  isolate round trip later than a search match does, so it is *more* exposed, not less.

Acceptance: a styled editor widget test (`BlinkController.indeterminateAnimationsEnabled = false`)
asserting the view model's `spellingErrors` over a misspelled action line and nothing over a
character cue or a scene heading; a raw controller test asserting a misspelling's underline and a
search match's wash coexist in the same span; a bloc test with a fake manager asserting only
changed texts are sent, that the read-only preview sends nothing, and that a stale generation's
answer is dropped.

### M4 — the corrections

`suggestionsFor` through the manager, the suggestion/ignore/learn entries in
`OcptEditorContextMenu`, the replacement as one undo step, `project_dictionary_words` +
`OcptProjectDictionaryService` (on M2's schema version), and the learned words pushed into the
manager on project open.

Acceptance: a context-menu widget test for the entries and for their withholding on a correct word;
a page-level test that picking a suggestion rewrites the word and that one Ctrl+Z puts it back
whole; a service test proving a learned word is tombstoned rather than deleted and filtered back
out on read; a manager test proving learning a word re-checks the paragraph it was learned from
(the generation bump).

### M5 — the record

`docs/adr/0020-bundled-hunspell-dictionaries-and-our-own-checker.md` (why not the platforms' own
services, why not a native hunspell package, why verbatim `.dic`/`.aff`, what the licences oblige),
a "Spell-checking" section in `docs/architecture/screenplay.md` (including §1.2's finding, which is
the kind of thing a future session will otherwise re-discover the hard way), the manager and the new
table in `docs/architecture/foundations.md`, the README's feature list, and **this plan deleted**.

---

## 6. What is out of scope, and said so

- Grammar, per the issue.
- A screen to review or un-learn the project's dictionary (§4.4).
- Any language beyond the two the UI itself speaks: a third dictionary is two asset files and one
  enum entry, and the plan is shaped so it stays that.
- Spell-checking anywhere else in the app — a location's notes, a shot's description, a person's
  biography. The engine is a package and the manager is app-wide, so it is reachable; nothing in
  this issue asks for it.
- Autocorrect. Nothing here ever rewrites the writer's text on its own.
