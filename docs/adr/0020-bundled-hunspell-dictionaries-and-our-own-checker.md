<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0020 - Bundled hunspell dictionaries and our own checker

## Status

Accepted

## Context

The screenplay editor has two editing surfaces, and neither of them gets spell-checking from the
platform it runs on.

- The **styled** mode is super_editor, not an `EditableText`. The pinned `0.3.0-dev.52` ships
  `SpellingAndGrammarStyler` and nothing else: it *paints* the squiggle from
  `TextComponentViewModel.spellingErrors`, and expects the application to supply the ranges. There
  is no spell-check service in that package at all.
- The **raw** mode is a plain `TextField`, so it can take a `SpellCheckConfiguration` — and doing
  so would break the find bar. `EditableText._buildTextSpan` (Flutter 3.44.6,
  `editable_text.dart:5976`) calls `buildTextSpanWithSpellCheckSuggestions` as soon as one
  spell-check result has arrived, and never the controller's own `buildTextSpan` again;
  `OcptEditorSearchTextController.buildTextSpan` is the raw mode's only way of painting a search
  match, so every highlight would silently disappear. Two smaller findings point the same way: the
  check is triggered from the IME path alone (`_updateEditingValue`), so a programmatic write — a
  version restore, an import, an episode switch, `Replace all` — would leave the underlines
  describing the previous text; and `_performSpellCheck` passes `Localizations.maybeLocaleOf`, the
  **UI** locale, which is not the language a screenplay is written in.
- Underneath both, Flutter's own `DefaultSpellCheckService` talks to the `flutter/spellcheck`
  `OptionalMethodChannel`, which the desktop embedders this project ships first do not answer at
  all. Linux and Windows are the first two targets.

A screenplay also needs something a system checker cannot give: a **project dictionary** — the
invented names of the film — and the ability to leave scene headings, character cues and
transitions alone.

## Decision

The application detects misspellings itself, from dictionaries it ships.

- `packages/spell_kit` is a pure-Dart hunspell implementation next to `fountain_kit`, free of
  Flutter imports and of I/O: the caller hands it the `.aff` and `.dic` contents as `String`s.
  It covers affix lookup (prefix, suffix, their cross product, continuation classes), `BREAK`
  splitting with hunspell's documented default, `COMPOUNDRULE`, and a three-tier suggester
  (`REP`, `MAP`, one edit, plus a split into two known words).
- Two dictionaries are bundled **verbatim**, byte for byte, under `assets/dictionaries/`, taken
  from [`wooorm/dictionaries`](https://github.com/wooorm/dictionaries): `fr` (Dictionnaires
  français, Olivier R., **MPL-2.0**) and `en_GB` (`en_GB-ise`, derived from SCOWL by Kevin
  Atkinson, a bespoke permissive notice carrying the Ispell BSD grant inside it, shipped as
  `LicenseRef-SCOWL`). Each language directory carries its upstream `LICENCE.txt` next to the
  files it covers, which both licences require, and `REUSE.toml` annotates the pairs the way the
  fonts are annotated.
- Flutter's `SpellCheckConfiguration`/`SpellCheckService` is **not used anywhere in this app**, and
  the raw mode paints its own underlines inside the controller that already paints its search
  matches.

## Consequences

- The bundle grows by ~1.8 MB of dictionary data on every platform, mobile included, and the app
  ships two more licences it must keep compliant.
- Only the two languages the UI itself speaks can be checked. A third is two asset files, one enum
  entry and two ARB strings — deliberately, but it is still a release, not a user preference.
- The dictionaries' own gaps are ours: `backlit` is genuinely absent from `en_GB` at the SCOWL size
  upstream ships. That is why "Add to the project's dictionary" is part of the same feature rather
  than a later one.
- Parsing a dictionary costs ~250-350 ms and ~14 MB retained, which is why one worker isolate
  serves the whole app and is spawned lazily (`docs/architecture/foundations.md`).
- Bumping a dictionary is a file swap, and stays one only as long as the copies remain verbatim.
- Hunspell's behaviour is now ours to match. What is deliberately absent — grammar, `COMPOUNDFLAG`
  chaining, the `n`-gram suggestion tier, frequency ranking — is listed in the package's README, so
  a false alarm is diagnosed against a stated scope rather than against hunspell in general.

## Alternatives considered

- **The platforms' own services**, through `SpellCheckConfiguration`: unanswered on the desktop
  targets, destroys the raw mode's find highlight where it does answer, keyed on the UI locale
  rather than the project's language, and blind to a project dictionary. Rejected on the first
  of those alone.
- **An FFI binding to native hunspell**: a compiled artefact to build, ship and sign for five
  platforms, two of them mobile, for an algorithm that is a few hundred lines of Dart — and the
  dictionaries would still have to be bundled.
- **A word-list checker with no affix support**: a French list would need every conjugation
  enumerated, and `l'homme`, `presqu'île` and `arrière-plan` would all be misspellings. The affix
  machinery is what the language needs, not a refinement of it.
- **Downloading dictionaries on first run**: storage is local-only and the app must work offline on
  set. A network dependency to underline a word is the wrong trade.
