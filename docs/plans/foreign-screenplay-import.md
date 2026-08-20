<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Foreign screenplay import — Final Draft (`.fdx`) and Celtx (`.celtx`)

This document is the implementation strategy for [issue #53][issue]. **Read the repository
`CLAUDE.md` first** — this plan assumes its architecture, ways of working, coding standards,
licensing rules and verification gates, and does not repeat them.

[issue]: https://github.com/borlnov/open_cine_prod_tools/issues/53

---

## 1. Why this step exists

Today the only screenplay that can enter the app is a `.fountain` file.
`OcptExportManager.pickAndReadFountain` opens a selector filtered on that single extension, and its
text feeds the two existing import flows: the `A screenplay` card of the home page's `Import…`
modal, which creates a project from it, and the editor's `⋮ Import and replace…`, which replaces
the selected episode's text behind a pre-import snapshot.

What a production is actually sent is an `.fdx` — and, for older or writing-side projects, a
`.celtx`. Nobody converts their screenplay to Fountain before opening the app: this is the entry
door that is missing most.

The outcome: those same two gestures accept `.fountain`, `.fdx` and `.celtx`, a foreign file being
converted to Fountain as it is read. **No export to either format**: the app's source of truth
stays Fountain, the conversion is one-way and knowingly lossy.

## 2. Decisions taken before writing this

1. One package, `packages/script_import_kit`, in `fountain_kit`'s sibling position — pure Dart, no
   Flutter.
2. Celtx means the **legacy container** (a zip holding `project.rdf` and `script-*.html`), and its
   **first script document** only. The catalogue, the storyboard, the scratch files and any
   further script document are ignored.
3. The `A screenplay` card keeps its place; its format label lists the three extensions and the
   native selector accepts all three.
4. A file that cannot be read as a screenplay gets a message of its own, distinct from an I/O
   failure.

## 3. The `script_import_kit` package

Plumbing modelled on `spell_kit` (pubspec, `analysis_options.yaml`, `README.md`, `CHANGELOG.md`,
SPDX headers). Dependencies: `fountain_kit` (`path:`), `xml`, `html`, `archive`, `equatable`,
`collection`, `meta` — `xml`, `html` and `archive` already resolve transitively in the current
lock. The root `pubspec.yaml` gains `script_import_kit: path: packages/script_import_kit`.
`fountain_kit` never references this package (a dependency does not know its dependents).

### 3.1 Public API (`lib/script_import_kit.dart`)

```dart
enum ScriptImportFormat { fountain, finalDraft, celtx }

/// The screenplay that was read, expressed in Fountain.
class ScriptImportResult { … }                    // format + fountainText

enum ScriptImportFailure { unsupportedFormat, malformedFile, noScriptDocument, emptyScript }
class ScriptImportException implements Exception { … }   // carries a ScriptImportFailure

class ScriptImporter {
  ScriptImportResult read({required Uint8List bytes, required String fileName});
}
```

`ScriptImporter` dispatches on `fileName`'s extension to `FdxScriptReader` or `CeltxScriptReader`,
and throws a `ScriptImportException` rather than returning a half-wrong text. `.fountain` is **not**
handled here: it stays `OcptFountainIoService`'s business (`ScriptImportFormat.fountain` only lets
the app-side service name that case).

### 3.2 The shared core: typed lines to Fountain text

Both readers produce the same intermediate list of `_ScriptLine`s (a `FountainLineType`, a text, an
optional scene number, a dual-dialogue flag), which one emitter renders as Fountain:

- every line goes through **`FountainLineWriter.writeLine`** (`fountain_kit`) with its
  `previousType` and the already-computed `nextRawLine`: it is what decides whether an all-caps
  dialogue line needs a forcing `@`, whether an action paragraph opening on `INT.` needs a `!`, and
  so on. `ocpt_wysiwyg_codec.dart` already does exactly this, and it is what guarantees that
  re-parsing the produced text yields the very types the reader meant;
- a scene number is concatenated onto the heading text (`INT. KITCHEN - DAY #4#`) before that call
  — the writer knows nothing about it, and the classifier tolerates the trailing tag;
- a blank line separates two blocks, never the inside of a dialogue block (character, parenthetical
  and dialogue lines stay glued together);
- inline styles (`<Text Style="Italic">`, Celtx's `<i>`/`<b>`/`<u>`) become `FountainStyledRun`s
  rendered by **`FountainInlineSerializer.write`** — the only code that knows how to escape a `*`
  that was in the source text itself;
- the title page is prepended with **`FountainTitlePageWriter.apply(existingRange: null, …)`**,
  from `FountainTitlePageEntry`s keyed by `ocptTitlePageFieldKeys`' own keys (`Title`, `Credit`,
  `Author`, `Draft date`, `Contact`, `Source`), in that order. Their `sourceRange` is a placeholder,
  as `editor_bloc.dart`'s `_placeholderTitlePageEntryRange` already is.

### 3.3 `FdxScriptReader`

XML read with `package:xml`. Root `<FinalDraft DocumentType="Script">`; any other `DocumentType` is
refused (`unsupportedFormat`). Body: `<Content>`'s `<Paragraph Type="…">`, text concatenated from
its `<Text>` children.

| `Paragraph Type` | Fountain |
| --- | --- |
| `Scene Heading` | `sceneHeading`, the `Number` attribute becoming `#N#` |
| `Action`, `General` | `action` |
| `Character` | `character` (a `(V.O.)` extension stays in the text) |
| `Parenthetical` | `parenthetical` |
| `Dialogue` | `dialogue` |
| `Transition` | `transition` |
| `Shot` | `action` |
| `New Act`, `End of Act` | `centeredText` (`> ACT ONE <`) |
| `Cast List`, any unknown type | `action` |

- `<DualDialogue>`: the group's second `Character` takes the `^`.
- `<ScriptNote>` is dropped (it has no printed equivalent; recorded as an accepted loss).
- Title page: `<TitlePage>`'s content is a run of free-form paragraphs, so heuristics, in order —
  first non-empty line to `Title`; a "written by / screenplay by / scénario de" line to `Credit`
  with the next non-empty line to `Author`; a line opening on "based on / d'après" to `Source`; a
  line carrying "draft / version" to `Draft date`; whatever is left, at the end, to `Contact` (a
  multi-line entry). No line is lost.

### 3.4 `CeltxScriptReader`

1. `ZipDecoder().decodeBytes(bytes)` (`package:archive`, in memory — a `.celtx` is small, unlike
   an `.ocptz`, which is streamed).
2. `project.rdf` read with `package:xml`: `cx:Project`'s `dc:title` to `Title` and its `dc:creator`
   (when present) to `Author`; the first `cx:Document` of type `ScriptDocument` names the HTML file
   in its `cx:localFile`. No readable `project.rdf`, or no script document, is
   `noScriptDocument`.
3. The `script-*.html` is parsed with `package:html` (HTML 4.01, not XML: unclosed `<br>`,
   entities). Each `<p class="…">` yields a line; an inner `<br>` splits the paragraph into several
   lines of one same block.

| `class` | Fountain |
| --- | --- |
| `sceneheading` | `sceneHeading`, the `scenenumber` attribute becoming `#N#` |
| `action` | `action` |
| `character` | `character` |
| `dialog` | `dialogue` |
| `parenthetical` | `parenthetical` |
| `transition` | `transition` |
| `shot` | `action` |
| `act`, `actbreak` | `centeredText` |
| `text`, an unknown class, a `<p>` with no class | `action` |

Not one recognised paragraph (a two-column A/V script, an empty document) is `emptyScript`.

## 4. The application side

- **`lib/managers/export/services/ocpt_script_import_service.dart`** (new, `OcptExportManager`'s
  sixteenth service, `const`, a public field like every other one, RFL18): takes bytes and a file
  name and returns Fountain text, delegating `.fountain` to
  `fountainIoService.decodeFountainBytes` and the rest to `ScriptImporter`. It is what turns a
  `ScriptImportException` into an app-side status — the kit knows neither ACT nor `Tr`. It also
  holds `importableExtensions`.
- **`OcptExportManager.pickAndReadFountain` becomes `pickAndReadScreenplay`**: the selector's
  filter takes the three extensions, and the return value becomes a
  `ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>` (the ACT type
  `createProject` already returns), because a `null` can no longer tell "cancelled" from
  "unreadable". `OcptImportedFountainModel` keeps its name: its text *is* Fountain once the
  conversion is done, and its `sourceFileName` still feeds
  `OcptFountainIoService.suggestedProjectName` — so the converted title page's `Title` names the
  new project by itself, for all three formats.
- **`lib/types/ocpt_screenplay_import_status.dart`** (new, `with MixinResultStatus`): `ok`,
  `cancelled`, `unreadableFile`, `ioError`.
- **`OcptHomeBloc`**'s screenplay import: `cancelled` stays a silent no-op; `unreadableFile` feeds
  a new transient `screenplayImportError` field of `OcptHomeState` (and its
  `clearScreenplayImportError` in `copyWith`), modelled exactly on the `projectPackageImportError`
  already there; the page states it, then clears it.
- **`OcptEditorBloc`**'s import-and-replace: a new `OcptEditorIoNoticeKind.importUnreadable`
  alongside `importFailed` (which stays the write failure). The rest of the flow — saving first
  when the editor is dirty, the `OcptSnapshotReason.import` snapshot — does not move.
- **`OcptHomeImportDialog`**: the `A screenplay` card's format label becomes
  `.fountain · .fdx · .celtx`.

## 5. Localization

Both ARB files, as always:

- `editorImportFileTypeLabel`: `Fountain screenplay` becomes `Screenplay` — the filter now covers
  three formats; same for the home's own label.
- `homeImportScreenplayDescription`: names the three formats.
- New `editorImportUnreadableError` and `homeImportScreenplayUnreadableError`: "This file could not
  be read as a screenplay." / « Ce fichier n'a pas pu être lu comme un scénario. »

The French rule holds: a screenplay's scene is « une séquence ».

## 6. Documentation

- `docs/architecture/screenplay.md`: the new package, what it is for, both mapping tables and what
  the conversion loses.
- `docs/architecture/exports.md`: the entry door now takes three extensions, the extra service, the
  new status and the two error surfaces.
- `docs/adr/0023-foreign-screenplay-import-only.md`: why a sibling package rather than a
  subdirectory of `fountain_kit` (ADR 0002 keeps that package ignorant of every proprietary
  format), and why the conversion is one-way — the source of truth stays Fountain, and an `.fdx`
  export would mean maintaining a Final Draft pagination nothing here can check. Listed in
  `docs/adr/README.md`.

## 7. Milestones

Each milestone ends with the full verification gate of `CLAUDE.md` §*Verification gates*, one commit
per logical change, and a user checkpoint before the next one starts. Every milestone's fixtures are
written **inline** in its tests (XML/HTML strings, a Celtx zip built on the fly with `ZipEncoder`):
no binary file, therefore no `.license` sidecar, and the house style wants local test doubles rather
than a shared helpers directory.

**M1 is what everything else stands on**; M2 only adds a second reader behind the same emitter, and
M3 is the only milestone that touches the app.

### M1 — The package and the Final Draft reader

`packages/script_import_kit` as described in §3: its plumbing, its public API, the shared
typed-lines-to-Fountain emitter, and `FdxScriptReader`. The root `pubspec.yaml` gains the path
dependency, so the package is wired into the app's resolution from the start even though nothing
calls it yet.

Tests: every paragraph type of §3.3, the scene number, dual dialogue, inline styles, the title-page
heuristics, a refused `DocumentType`, malformed XML. Plus **the round-trip test, which matters
most** — the produced text is re-parsed by `FountainParser.parse` and the resulting `FountainBlock`s
are compared to what the reader meant, which is what proves the forcing markers did their job.

No app code, no UI, nothing localized: at the end of M1 an `.fdx` can be turned into Fountain text
by a test and by nothing else.

### M2 — The Celtx reader

`CeltxScriptReader` (§3.4) behind the very same emitter: the zip, `project.rdf`, the script HTML and
its class mapping. `ScriptImporter`'s dispatch gains its second branch.

Tests: the whole zip, an inner `<br>`, `scenenumber`, an unknown class, a zip with no
`project.rdf`, a script with no recognised paragraph, and the dispatch by extension including an
unknown one. The round-trip check of M1 is run for this reader too.

Still no app code. M1 and M2 are each worth shipping on their own.

### M3 — The two import gestures

The application side of §4 and the localization of §5: `OcptScriptImportService`,
`pickAndReadScreenplay` with its `ResultWithStatus`, `OcptScreenplayImportStatus`, the home page's
transient `screenplayImportError`, the editor's `importUnreadable` notice, and the `A screenplay`
card's format label.

Tests: `ocpt_script_import_service_test.dart` (the three extensions, a `ScriptImportException`
turning into `unreadableFile`), and the two bloc tests following the new signature with one
"unreadable file" case each.

This is the milestone the end-to-end verification of §8 belongs to: it is the first point at which
an `.fdx` or a `.celtx` can be opened by a person rather than by a test.

### M4 — The record

The documentation of §6: `docs/architecture/screenplay.md`, `docs/architecture/exports.md` and
ADR 0023, listed in `docs/adr/README.md`. This plan file is deleted in the same commit — from then
on the code, the architecture files and the ADR are the record.

## 8. Verification

The full gates before each commit, plus `dart run tool/check_markdown.dart` for the documentation
commit. The package has its own tests, run from its own root as `fountain_kit`'s are.

End to end in the real app through `tool/screenshot-app.sh` (release bundle rebuilt first), with an
`.fdx` and a `.celtx` built in a scratch directory from the tests' own fixtures:

1. home, `Import…`, `A screenplay`: the selector offers the three extensions;
2. import the `.fdx`: the project is created under the title page's title, and the editor shows
   scenes, characters and dialogue correctly typed (the scene panel is populated);
3. in the editor, `⋮ Import and replace…` with the `.celtx`: the text is replaced and the
   pre-import snapshot shows up in the `Versions` dock;
4. import a deliberately truncated file: the "unreadable" message shows and the current screenplay
   is left untouched.
