<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the screenplay

`fountain_kit`, `script_import_kit`, `spell_kit` and the screenplay mode: the parser and what it
guarantees, the readers turning a foreign screenplay into Fountain, the styled editor's document
model, the title page, the spell-checking, the docks and the syntax guide.

- `packages/fountain_kit`: pure-Dart Fountain parser/serializer with round-trip guarantee and
  `FountainLayoutMetrics` (US Letter/A4 Courier columns). Keep it free of Flutter imports.

- `packages/script_import_kit`: pure-Dart readers turning the screenplay files a production is
  actually sent — a Final Draft `.fdx`, a legacy Celtx `.celtx` — into Fountain text (ADR 0023).
  A sibling of `fountain_kit` rather than a subdirectory of it, so that package keeps knowing no
  format but Fountain, and **`fountain_kit` never references this one**. Free of Flutter imports
  and of I/O alike: it takes the file's bytes in and hands a `String` back, which is what lets
  every one of its tests build its document inline. One door, `ScriptImporter.read({bytes,
  fileName})`, dispatching on the extension; a file it cannot read raises a
  `ScriptImportException` carrying a `ScriptImportFailure` (`unsupportedFormat`, `malformedFile`,
  `noScriptDocument`, `emptyScript`) rather than returning the half of it that parsed. `.fountain`
  is deliberately not handled there — it needs no conversion, and reading it stays
  `OcptFountainIoService`'s business (`exports.md`).
- **A reader never writes one character of Fountain by hand**, and that is the package's whole
  shape: it produces a list of typed `ScriptLine`s — *this is a scene heading*, *this is a
  character cue*, plus a scene number, a dual-dialogue flag and the runs of inline emphasis — and
  one `ScriptFountainEmitter` renders them through `fountain_kit`'s own `FountainLineWriter`,
  `FountainInlineSerializer` and `FountainTitlePageWriter`, exactly as `OcptWysiwygCodec` does.
  Each line is written with the type of the one before it and the raw text of the one after it, the
  same context `FountainLineClassifier` reads, which is what makes the forcing markers land: an
  all-caps line of dialogue stays dialogue instead of becoming a cue, an action paragraph opening
  on `INT.` stays action. The emitter decides the layout and nothing else — a blank line between
  two blocks, never inside a dialogue block, an empty line dropped — and it restates one rule of
  the parser's, the title-page-key regex, because a screenplay with no title page opening on
  `FADE IN:` would otherwise have that first line swallowed as an empty title-page entry. **The
  round-trip test is the load-bearing one**: the emitted text is re-parsed by `FountainParser.parse`
  and the blocks compared to what the reader meant. Adding a third format is a third reader behind
  that same emitter and no new Fountain rule at all.
- `FdxScriptReader` reads the XML (`package:xml`): `<FinalDraft DocumentType="Script">`, then
  `<Content>`'s `<Paragraph Type="…">`, its text concatenated from the `<Text>` children whose
  `Style` becomes the emphasis runs. `Scene Heading` (its `Number` attribute becoming the `#N#`
  concatenated onto the heading text before the writer sees it), `Action`/`General`, `Character`
  (a `(V.O.)` extension staying in the text), `Parenthetical`, `Dialogue`, `Transition`, `Shot` as
  action, `New Act`/`End of Act` as centered text, and `Cast List` or any unknown type as action.
  A `<DualDialogue>` group's second cue takes the `^`. The `<TitlePage>` is free-form prose rather
  than named fields, so it is read the way a person reads it — first line the title, a "written
  by"/"scénario de" line the credit and the next one the author, a "based on"/"d'après" line the
  source, a "draft"/"version" line the draft date, everything left over the contact block — which
  is what keeps every line of it.
- `CeltxScriptReader` reads the legacy container: a zip decoded in memory (`package:archive` — a
  `.celtx` is small, unlike the streamed `.ocptz` of `foundations.md`), its `project.rdf` giving
  the `dc:title` and `dc:creator` that become the title page and naming the **first**
  `ScriptDocument`'s HTML file. That file is parsed as HTML, not XML (`package:html`: unclosed
  `<br>`, entities), each `<p class="…">` yielding a line — `sceneheading` (its `scenenumber`
  attribute becoming the `#N#`), `action`, `character`, `dialog`, `parenthetical`, `transition`,
  `shot` as action, `act`/`actbreak` as centered text, and `text`, an unknown class or no class at
  all as action — an inner `<br>` splitting the paragraph into several lines of one same block, and
  `<b>`/`<i>`/`<u>` with their `<strong>`/`<em>` spellings becoming the emphasis runs.
- **What a conversion loses is written down, in each reader's own documentation and in the
  package's `README.md`**, since a lossy conversion nobody documented is one whose losses are
  discovered on set: an `.fdx` leaves behind its `<ScriptNote>` margin notes, its revision marks,
  its locked pages and every style Fountain has no marker for; a `.celtx` leaves behind every
  document but the first script — the catalogue, the storyboard, the schedule, the scratch files
  and any further script — along with the project's media, index cards and notes. Bytes are decoded
  as UTF-8 with malformed sequences replaced rather than thrown on, the BOM dropped and every line
  ending normalised, so a file saved in a legacy encoding still opens with a handful of wrong
  accents instead of not opening at all.

- One screenplay at a time, and it is **the episode the workspace has selected** (ADR 0019): the
  mode reads and writes that screenplay where it reached for `primaryScreenplayId` before, and
  switching episode remounts it wholesale (see `foundations.md`). Nothing else about the mode
  changes, an episode being one screenplay — and **the script is never prefixed**: the computed
  scene numbers, the raw preview and the screenplay PDF all print the author's own `#N#`, where the
  shot list, the breakdown and the schedule read `<episode>.<scene>`. The mode's two exports name
  the episode in their **suggested file name** instead, so two episodes saved into one folder cannot
  overwrite each other. This mode is also the only one offering `Add an episode…` — the button the
  workspace toolbar draws in the episode selector's own place while the project holds a single
  episode, opening the project settings on their card (see `foundations.md`).

- Source provenance (ADR 0012): every printed line `FountainScriptComposer` emits carries a nullable
  `FountainScriptLine.sourceRange` — the union of its runs' own `FountainStyledRun.sourceRange`s,
  anchored into `FountainDocument.sourceText` — plus `isSynthetic` for the `(MORE)` token and the
  repeated `NAME (CONT'D)` cue. It is what maps a stored source offset onto a printed row, and it is
  **best effort**: a line the composer cannot anchor verbatim gets no range rather than a wrong one,
  so every consumer bridges over an unanchored line instead of assuming one. A position *inside* a
  run is interpolated, never counted (`toUpperCase()` and `\`-escapes are not length-preserving).

- `FountainScriptStatistics` (`fountain_kit`): pure page/scene/speaking-character/word/sign
  counters over the printable body, page count via `FountainScriptComposer`, surfaced by the
  editor's status bar.

- Editor: super_editor styled mode keeps **one `ParagraphNode` per non-blank Fountain source
  line**; a blank source line carries no node of its own, folded into the following node's
  `ocptBlankLinesBefore` metadata instead. Other node metadata: `blockType` (the line's
  `FountainLineType` as a `NamedAttribution`, stylesheet-only styling), `ocptTypeLocked` (a
  manual type override — dropdown or Tab — sticky for the node's **whole lifetime**, including
  while its text is empty: only a new node created by Enter/Shift+Enter starts unlocked),
  `ocptHadForcingMarker` (the source line used an explicit forcing marker, re-emitted on encode
  even when auto-detection alone would already suffice), `ocptSceneNumberMetadataKey` (a scene
  heading's `#N#`, stripped out of the display text on decode and re-appended on encode) and
  `ocptTitlePageKeyMetadataKey` (which of `ocptTitlePageFieldKeys` a title-page field node is, see
  below). `OcptWysiwygCodec`
  (`lib/ui/pages/editor/super_editor/`, the only directory besides `fountain_kit` that knows
  about this format) is the Fountain ↔ document (de)serializer, built on `fountain_kit`'s
  `FountainLineClassifier`/`FountainLineWriter`/`FountainInlineParser`/`FountainInlineSerializer`.
  `ocpt_fountain_keyboard_actions.dart` handles Tab/Shift+Tab (cycles 6 common types, locks the
  block) and Enter (splits into the type's usual screenplay successor, unlocked; Shift+Enter
  keeps the same type). Whichever gesture sets a block to `parenthetical` opens it on `()` with the
  caret between them (`ocptParentheticalTemplateRequests`, shared by the Tab cycle, smart Enter and
  the toolbar dropdown), but **only while the block's text is empty**: Tab cycles *through* the type
  on its way elsewhere, so an unguarded template would inject a pair per pass.
  `OcptStyledEditorController extends ChangeNotifier`
  (`lib/ui/pages/editor/ocpt_styled_editor_controller.dart`) bridges the toolbar's block-type
  dropdown and B/I/U toggles to the live editor without a `package:super_editor` import; it is
  attached only while a styled editor is mounted (detached in raw mode). Debounces: parse
  150 ms, autosave 2 s, styled reclassify 120 ms (flushed synchronously on `deactivate()` so a
  pending edit survives a mode toggle or back navigation). Ctrl+S saves, Ctrl+Shift+M toggles
  mode, both left unclaimed by the styled editor's `keyboardActions` and bubbling to the page.
  Ctrl+C/X/V (`ocpt_fountain_clipboard_actions.dart`) replace super_editor's defaults: the
  clipboard payload is always plain Fountain source text
  (`OcptWysiwygCodec.encodeSelectionToFountain`/`decodeNodesFromFountain`), so block types and
  spacing survive a copy/paste round trip inside the app while text to and from outside the app
  still decodes through ordinary auto-detection.

- Undo and redo: **one undo step is one gesture of the writer's, plus everything the editor derived
  from it** — a keystroke run, an Enter, a Tab, a dropdown pick, a paste or a replace, together with
  the reclassification, the uppercasing, the `#N#` renumbering and the metadata the editor computed
  *because* of it. Never the derived half alone. `Editor` runs with `isHistoryEnabled: true` and
  `OcptSettleMergePolicy` (`ocpt_fountain_history_policy.dart`) as its `historyGroupingPolicy`:
  every derived pass goes through `runDerivedPass`, which merges the transactions it closes onto the
  gesture's own — without it, Ctrl+Z pops the derived transaction, the 120 ms debounce restarts, the
  pass re-derives exactly what was undone and pushes it back forever, which is a manual Tab that
  cannot be undone at all. A typing run merges up to `ocptTypingMergeWindow` (**700 ms**, against
  super_editor's own 100 ms, shorter than a 60 wpm hand's inter-key gap); a caret move, an Enter, a
  Tab, a paste or a deletion end the run on their own whatever the timing. Every `MutableDocument`
  is built from a `List<DocumentNode>`, never a typed subclass list: `undo()` restores each
  `Editable` by `_nodes..clear()..addAll(snapshot)`, and a `List<ParagraphNode>` makes that throw
  *after* the clear, leaving the document empty.
- Redo is guarded, undo is not: `Editor` never clears its `future` when a new edit arrives (its own
  doc comment says it should, and nothing in the package does), so replaying it blind writes text
  the writer never wrote. `redoWhenCmdShiftZOrCtrlShiftZIsPressed` is therefore excluded from the
  inherited defaults and replaced by this app's own action (Ctrl+Shift+Z **and** Ctrl+Y, the Windows
  habit), which refuses a redo the styled editor's `canRedo` calls stale — a flag raised by any
  document change that is neither an undo/redo nor a derived pass, lowered by an undo. That same
  predicate is what the `Redo` affordance reads; nothing recomputes one of its own.
- A restore lands on the document's **base state**, which the load-time scene-number pass is part of
  but the history is not: `_applyHistoryChange` re-runs `_syncSceneNumbers` inside the same window,
  non-historically. Left to the settle instead, that renumbering would come back as a change of its
  own — staling the redo stack, and appending an undo step that un-numbers the screenplay.
- **The undo history belongs to the editing surface, and switching surface starts a fresh one**
  (as does an episode switch, an import or a version restore, each of which rebuilds the styled
  editor): the styled editor owns its `Editor` history, raw mode owns the `UndoHistoryController`
  the page hands its `TextField`, and a single stack shared across a raw ⇄ styled toggle is
  deliberately out of scope — it would have to live above both, as Fountain snapshots plus the
  source-offset ⇄ document-position mapping ADR 0012 only does best effort. The `⋮` menu's `Undo`
  and `Redo` entries state their shortcut like `Find…` does and act on **whichever surface is
  showing** (`_historyAvailability` in `editor_page.dart` asks the active one); each is withheld,
  not disabled, when there is nothing left to take back or put back, and both are withheld entirely
  under a read-only preview, which carries no editing surface at all.

- Right-click menu: the styled mode alone carries one (`OcptEditorContextMenu`,
  `lib/ui/pages/editor/widgets/`, a `MenuAnchor` free of any `package:super_editor` import — the raw
  mode is a plain `TextField` and gets Flutter's native menu for free). Cut, Copy, Paste, Select all
  and the block type as a submenu; the clipboard entries call the very helpers the Ctrl+C/X/V
  handlers do, and the submenu the same `applyBlockType` the toolbar dropdown does, so no gesture
  can behave differently from its keyboard or toolbar twin. The list of assignable types lives once,
  as `ocptAssignableFountainLineTypes` (`lib/ui/utils/ocpt_fountain_line_type_labels.dart`). An
  entry with nothing to act on is **withheld, not disabled** (a null callback), which is what hides
  Cut/Copy over a collapsed caret. The secondary tap resolves the document position under the
  pointer and places the caret there, unless it lands inside an expanded selection, which it never
  destroys. A left click landing back on the document closes the menu, which a `MenuAnchor` does not
  do on its own: its anchor child — the whole editing surface here — belongs to the same `TapRegion`
  group as the menu, so a `Listener` above the gesture detector watches for the primary button and
  closes it, observing the click rather than competing for it. Nothing is withheld for a read-only
  preview: the styled editor is not mounted under one
  at all, `editor_page.dart` substituting the read-only preview for both editing modes.

- Scene numbers: a heading's `#N#` is a first-class WYSIWYG field
  (`ocptSceneNumberMetadataKey`), kept in sync with the display text by
  `OcptWysiwygCodec.sceneNumberRequests` on every reclassify pass. Styled mode can additionally
  *display* a computed number for every heading that has none of its own
  (`ocpt_styled_scene_numbers.dart`), gated by `OcptPropertiesManager.styledSceneNumbersVisible`
  (`⋮` menu, on by default) — display-only, it never writes into the Fountain source, and an
  explicit `#N#` always wins over a computed number. The raw preview and the PDF are unaffected:
  they only ever print an explicit number. Renumbering runs in two places, and they differ on
  purpose: `sceneNumberNormalizationRequests` is historical inside the settle pass (the renumbering
  belongs to the gesture that caused it) and **non-historical** on the load path and inside every
  undo/redo, where it corrects a badly ordered `#N#` before the writer has touched anything — an
  undo step there could only ever un-correct it.

- Title page: the styled editor renders it as an editable first sheet, not a dialog-only flow.
  `OcptWysiwygCodec` synthesizes one `ParagraphNode` per `ocptTitlePageFieldKeys` entry (`Title`,
  `Credit`, `Author`, `Draft date`, `Contact`, `Source`, always all six, empty ones included),
  tagged with the `ocptTitlePageFieldAttribution` `blockType` and `ocptTitlePageKeyMetadataKey`;
  encoding always goes through `FountainTitlePageWriter.apply`, never a hand-written `Key: value`
  line, so a title page with no entries at all is dropped. `OcptTitlePageComponentBuilder`
  (`ocpt_title_page_component_builder.dart`) paints the field layout (large centred title,
  centred credit/author, bottom-left contact, bottom-right draft date) and each empty field's
  placeholder hint, and `ocptTitlePageGuardRequestHandler`
  (`ocpt_title_page_guard_requests.dart`) is the single place that keeps the six field nodes from
  being merged into the body or deleted as nodes, while still allowing ordinary text editing
  (typing, Backspace, Delete, replace) inside a field — do not reach for
  `NodeMetadata.isDeletable`, which blocks both. `computeOcptStyledPagination` always reserves the
  whole of page 1 for the title page when one is present, matching the PDF exporter, and reports
  that as `titlePageSheetCount` — the offset between a painted sheet's index and its 1-based
  **script** page number.

- Page numbers: every simulated sheet carries the number the printed screenplay would show on it,
  painted by the same `_OcptPageSheetsPainter` that paints the sheets themselves and gated on page
  simulation (there is nothing to number on the fluid surface). The rule itself lives once, in
  `lib/utils/ocpt_script_page_number.dart`: `N.` at the top right,
  `ocptScriptPageNumberTopInches` (0.5") below the sheet's top edge whatever the configured margin,
  the title page never counted and the first script page never numbered. `OcptScriptPagePainter`
  prints that same rule on paper — a number on screen disagreeing with the number on the PDF would
  be worse than no number at all. Fixed paper colours, like the rest of the page-simulation
  styling, and a sheet scrolled out of view is skipped rather than laid out on every scroll frame.

- On a phone (`ocptIsPhoneWidth`, the width seam `foundations.md` describes) the styled editor is
  forced as the **only** live editing surface, page simulation off, regardless of what
  `OcptEditorState.mode`/`isPageSimulationEnabled` are persisted as — `_EditorViewState._liveMode`/
  `_isPageSimulationLive` in `editor_page.dart` read the width rather than the state, so raw source
  (with its own find/replace and spell-check wiring) and a real-size simulated page are never what a
  phone shows. The user's own raw/styled toggle and page-simulation checkbox keep reading and
  writing the persisted preference untouched, so widening the window back out returns to whichever
  was picked. The toolbar's format controls (the block-type dropdown, the B/I/U toggles) are
  withheld at that width for want of room beside everything else the phone toolbar already carries
  (`foundations.md`); a phone writer still reaches every block type through
  `OcptEditorContextMenu`'s own submenu, or simply by typing the Fountain markup.
- Below the compact breakpoint (`ocptIsCompactWidth`), and only on the fluid (page-simulation-off)
  surface, `OcptFountainEditorStylesheet.build(isCompact: true)` scales every element's indent and
  box width down by `_compactLayoutScale` (0.5), carrying the block hierarchy by **style** —
  character bold/accent, parenthetical italic, dialogue slightly inset — rather than by the real,
  screenplay-sized indents (a character cue ≈ 3.7″ in) a phone has no room for. A uniform multiplier
  on both halves of every element's box keeps the desktop proportions intact at half scale, rather
  than redesigning each type on its own. A paginated page never sees it: the flag only ever applies
  while page simulation is off, since a simulated sheet is sized from the very real metrics the PDF
  exporter agrees with pixel for pixel, and compressed ones would desync the two —
  `OcptFountainEditorStylesheet.build` guards that itself rather than trusting every caller to.
  Desktop output is byte-identical, the flag defaulting off everywhere a desktop call site builds
  the stylesheet.

- Find and replace: one search, over **the episode the workspace has selected**, in both editing
  modes. `Ctrl+F` opens the bar on find, `Ctrl+H` on replace, `Escape` closes it — page-level
  `Shortcuts` in `editor_page.dart`, beside `Ctrl+S`/`Ctrl+Shift+M`, none of the three claimed by
  `ocptFountainKeyboardActions` or by super_editor's defaults — and the `⋮` menu reaches it without
  the keyboard, through **two entries rather than one**, `Find…` and `Find and replace…`, each
  opening the bar the way its own shortcut does and stating that shortcut on the right
  (`OcptToolbarMenuItemLabel`, the platform's modifier resolved by `ocptPrimaryShortcutLabel`).
  `OcptEditorFindBar`
  (`lib/ui/pages/editor/widgets/`) is a docked band at the top of the **centre column only**, two
  stacked rows whose replace row folds behind a chevron, the match-case and whole-word toggles
  living inside the find field itself. The search *state* is `OcptEditorSearchState`, in the bloc,
  which is what makes it survive a raw ⇄ styled toggle; the bar and both surfaces only ever report
  into it.
- **Each mode matches what it shows**, and the counter says so: raw mode searches the Fountain
  source, the very characters its field displays, where the styled mode searches each node's
  *display* text — no forcing marker, no `#N#`, no `*`/`_` emphasis, and the six title-page fields
  included, so its count moves with the page-simulation toggle that creates them. The two counts
  can therefore differ for a query holding markup, which is the rule rather than a defect. The bloc
  holds the query, the two options and the current index; the **count is reported up by whichever
  surface is mounted**, which is what keeps `Replace all` consistent with the number the bar just
  showed. The matcher itself is `ocptFindTextMatches` (`lib/utils/ocpt_text_search.dart`), shared by
  both: literal — a query is never compiled into a `RegExp`, since `(`, `.` and `*` are ordinary
  characters to a screenwriter — and its whole-word test counts accented letters as word characters,
  a screenplay being written in French too.
- The highlight is painted by each surface in its own way, from the same two fixed colours
  (`lib/ui/pages/editor/ocpt_editor_search.dart`): fixed, not theme-derived, for the reason the rest
  of the page-simulation styling already is. Raw mode overrides `buildTextSpan`
  (`OcptEditorSearchTextController`). Styled mode uses `OcptSearchMatchStyler`, a
  `SingleColumnLayoutStylePhase` handed to `SuperEditor`'s `customStylePhases`, which adds its two
  attributions to the **copied** component view model and wraps that copy's `textStyleBuilder` —
  never the document, where they would be encoded straight back into the Fountain source. Its
  `markDirty()` is **deferred to a post-frame callback** when it comes from the document-change
  listener: firing it inside the still-open `Editor.execute` transaction reaches super_editor's own
  selection styler before the composer's selection has been reconciled, and crashes on any
  delete or cut.
- Navigating to a match places the selection **without taking keyboard focus** — the find field is
  what must keep it — which the styled editor's existing `clearSelectionWhenEditorLosesFocus: false`
  already allows. `Replace` moves on to the first match starting at or past the end of what it just
  wrote (wrapping), never simply to whatever now sits at the same index: renaming `MARIE` into
  `MARIE-JEANNE` writes text that still matches, and keeping the index would compound it on every
  further press. `Replace all` goes through `OcptConfirmDialog`, opened by the page with the same
  words in both modes. The whole bar is withheld under a read-only preview, shortcuts included:
  there is no editing surface to search there at all.
- Spell-checking as you type, in both editing modes, from dictionaries the app bundles rather than
  from the platform (ADR 0020): `packages/spell_kit` is the pure-Dart hunspell engine (no Flutter
  import, no I/O — the caller hands it the `.aff` and `.dic` text), and
  `OcptSpellCheckManager`'s one worker isolate is where a dictionary is parsed and a text is checked
  (`foundations.md`). Flutter's own `SpellCheckConfiguration`/`SpellCheckService` is used
  **nowhere in this app**, and the raw mode is the reason: `EditableText._buildTextSpan` calls
  `buildTextSpanWithSpellCheckSuggestions` as soon as one spell-check result has arrived and never
  the controller's own `buildTextSpan` again, which is the raw mode's only way of painting a search
  match — one configuration and the find bar's highlight is gone forever. That path is also
  triggered from the IME alone (a version restore, an import, an episode switch or a `Replace all`
  would leave the underlines describing the previous text) and keyed on the **UI** locale, which is
  not the language a screenplay is written in.
- **Two switches, and both must be on**: the project's own `screenplayLanguage`
  (`project_info`, picked in the project settings page — null means "nobody has said", and nothing
  is checked) says *what* language is checked, and `OcptPropertiesManager.spellCheckVisible`
  (the `⋮` menu, below `Show scene numbers`, null reading as `true`) says whether *this machine*
  wants to see the underlines at all. With either off no request is made, the isolate stays
  unloaded, and nothing is painted; a **read-only preview** checks nothing either, there being no
  editing surface to correct.
- What is checked is the screenplay's **prose and nothing else**, decided once in
  `lib/utils/ocpt_spell_checked_lines.dart`: `ocptIsSpellCheckedLineType` returns true for action,
  dialogue, parenthetical and centered text, and false for scene headings (a set name in capitals),
  character cues (a writer's invented names are exactly what a dictionary does not have),
  transitions (a fixed vocabulary that is not the language's), sections, synopses and lyrics. Title
  page fields never reach it at all — they are left out of what a caller hands over, a title being
  invented on purpose and the six fields existing only under page simulation, so the squiggles
  would otherwise appear and disappear with a display toggle. `ocptLineTypeOfBlock` expresses the
  same rule over `FountainDocument.blocks` rather than restating it, and
  `ocptSpellCheckSkipSpansIn` drops the tokens sitting inside an inline note or boneyard comment.
  The remaining two rules are the tokenizer's own (`SpellTokenizerOptions`, on by default): a token
  in all capitals is skipped (a shouted word, the convention that introduces a silent character)
  and so is one holding a digit.
- The pass rides the editor's existing **150 ms parse debounce**, never a keystroke, exactly where
  the inspector and metadata panels recompute: `_onParseRequested` already holds a fresh
  `FountainDocument`, which is what makes the block-type rules above free. Only *changed* texts are
  sent — the bloc keeps the last text checked per key and skips the identical ones, so a keystroke
  in one paragraph costs one paragraph — and each surface's cache is keyed on
  `(language, visibility, manager generation)`, so learning a word or changing the language throws
  it away rather than answering from it. An answer whose generation no longer matches the
  manager's, or whose checked text has since changed, is **dropped**.
- **Each mode matches what it shows**, the same rule the find bar already obeys. Raw mode is
  checked over the Fountain **source text**, block by block, the ranges translated back to
  document-absolute offsets by the block's own start; the styled mode is checked over each node's
  **display text**, keyed by node id, because that is what `SpellingAndGrammarStyler` addresses.
  The styled editor reports its checkable texts up through
  `OcptStyledEditorController.reportSpellCheckTexts` and receives the ranges back through
  `updateSpellCheckRanges` — the mirror of `reportSearchMatchCount`/`updateSearch` — so the bloc
  never learns about node ids from anywhere else.
- The underline is painted by each surface in its own way, from one colour
  (`ocptEditorSpellCheckErrorColor`, `lib/ui/pages/editor/ocpt_editor_search.dart`). Styled mode
  hands super_editor's own `SpellingAndGrammarStyler` to `customStylePhases` beside
  `_searchMatchStyler` and feeds it `TextError`s per node id: `text.dart` turns a component view
  model's `spellingErrors` into the squiggle, so nothing here paints anything. Raw mode's
  `OcptEditorSearchTextController.buildTextSpan` segments the text on the boundaries of **both**
  range sets, so a misspelled word inside a search match wears the wash and the wavy underline at
  once. Two traps the search styler already paid for once apply here too: the styler's
  `markDirty()` is deferred to a post-frame callback when it comes from a document-change path, and
  a range computed against a text that has since changed is **dropped outright** rather than
  clamped — a spelling range arrives one isolate round trip later than a search match does, so it
  is more exposed to this, not less.
- Corrections are offered in the **styled mode alone**, through `OcptEditorContextMenu`: a
  right-click landing on a misspelling opens the menu with up to five suggestions on top, then
  `Ignore this word` and `Add to the project's dictionary`, then the existing Cut/Copy/Paste/Select
  all and the block-type submenu. Suggestions are fetched when the menu opens (a right-click can
  await one warm isolate round trip; computing them for every misspelling on every debounce tick
  would be work for a menu that never opens), and picking one rewrites the word through the same
  `OcptReplaceNodeTextRequest` path a replace uses, so it is **one undo step**. On a correctly
  spelled word — or with spell-checking off — the whole group is **withheld, not disabled**. The
  raw mode underlines and offers nothing: it keeps Flutter's native menu, and the `⋮` menu is where
  a raw-mode writer switches the underlines off. `Ignore this word` is session-only, held by the
  manager and gone when the app closes; `Add to the project's dictionary` is persisted in the
  project file and read back — and unlearned — from the project settings page (`foundations.md`).

- Editor docks: `OcptWorkspaceDock`/`OcptWorkspaceDockDivider`
  (`lib/ui/pages/workspace/widgets/ocpt_workspace_dock.dart`) give the scene panel and the right
  dock draggable-divider resizing with a 320 px centre floor (right dock yields width first);
  widths are fractions of the editing row, persisted through
  `OcptPropertiesManager.editorLeftDockFraction`/`editorRightDockFraction`.
  `OcptWorkspaceDockLayoutController extends ChangeNotifier` holds the live fractions during a
  drag so it never emits a bloc state per frame; the bloc only sees one
  `OcptEditorDockFractionsChangedEvent` on `onHorizontalDragEnd`. The right dock
  (`OcptEditorRightDock`, under `lib/ui/pages/editor/widgets/`) is tabbed
  (`OcptEditorRightDockTab { preview, syntax, inspector, metadata, versions }`); its tab row is
  itself clickable (`onTabSelected`), while the toolbar's preview/syntax buttons — **raw mode
  only**, the styled mode reaches every tab through the tab row alone — additionally *open* a closed
  dock on their tab (inspector/metadata/versions have no toolbar button in either mode). The shell's
  own right-dock toggle closes the dock whichever tab it shows, and reopens it on
  `lastRightDockTab` (the last tab explicitly selected, never null, `preview` by default), falling
  back to `syntax` when that tab is `preview` and the styled mode is active. Switching to styled
  mode auto-closes an open preview tab and remembers it (`autoClosedRightDockTab`, a separate
  memory) for the next switch back to raw, unless the user explicitly closed the dock themselves.

- Right dock content: `OcptEditorInspectorPanel` shows the scene under the caret (heading, speaking
  characters, estimated duration, page-eighths) from `FountainSceneStatistics.of` (`fountain_kit`,
  the scene-scoped sibling of `FountainScriptStatistics`, exposing `pageEighths` — never a minutes
  field, duration is derived at the call site on the one-page-per-minute convention).
  `OcptEditorMetadataPanel` shows the title-page fields and the script-wide statistics, read-only,
  with an "Edit…" button opening the existing title-page dialog through `OcptRouterManager`. Both
  are recomputed on the editor's existing 150 ms parse debounce, never per keystroke.

- The Fountain syntax guide (`OcptEditorSyntaxGuidePanel`) renders the `const`
  `ocptFountainSyntaxEntries` table (`lib/models/ocpt_fountain_syntax_entry.dart`, one entry per
  `OcptFountainSyntaxTopic`) as read-only snippets in both editing modes (the *panel* is
  mode-agnostic; only the toolbar shortcut opening it is raw-mode only); its titles reuse the 11
  existing `editorBlockType*` ARB keys where a topic already had one.
