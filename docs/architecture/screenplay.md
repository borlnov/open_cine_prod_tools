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
  line**, bar one exception below; a blank source line carries no node of its own, folded into the
  following node's `ocptBlankLinesBefore` metadata instead. The exception is a note running over
  several lines: `decode` folds the lines it covers into one node holding it as a placeholder whose
  text keeps its newlines, when that changes nothing the parser reads of those lines (no boneyard
  on them, and either nothing but notes, or no blank line and one same element of action,
  dialogue or parenthetical for all of them); any other group stays text. The layout then gives
  each node a range of lines (`OcptWysiwygDocumentLayout.lineRangeOfNode`), `encode` writes the
  first line of such a node through the line writer and the rest as it is, and the live passes
  neither create nor dissolve a placeholder holding a newline: a node's own text never holds one
  outside a placeholder, so only a decode folds or unfolds a note. Other node metadata:
  `blockType` (the line's `FountainLineType` as a `NamedAttribution`, stylesheet-only styling),
  `ocptTypeLocked` (a manual type override — dropdown or Tab — sticky for the node's **whole
  lifetime**, including while its text is empty: only a new node created by Enter/Shift+Enter
  starts unlocked),
  `ocptHadForcingMarker` (the source line used an explicit forcing marker, re-emitted on encode
  even when auto-detection alone would already suffice, and spared by the uppercase pass on a
  character cue: `@McCLANE` keeps its case, and every renderer prints it that way: the parser
  flags it `FountainCharacter.forced` and the composer, the raw preview and so the PDF skip the
  print-time upper-casing for it, extension and `(CONT'D)` included; scene headings and
  transitions stay upper-cased even when forced), `ocptSectionLevel` (the `#` run of a section,
  1 to 6, written back on encode), `ocptSceneNumberMetadataKey` (a scene
  heading's `#N#`, stripped out of the display text on decode and re-appended on encode) and
  `ocptTitlePageKeyMetadataKey` (which of `ocptTitlePageFieldKeys` a title-page field node is, see
  below). `OcptWysiwygCodec`
  (`lib/ui/pages/editor/super_editor/`, the only directory besides `fountain_kit` that knows
  about this format) is the Fountain ↔ document (de)serializer, built on `fountain_kit`'s
  `FountainLineClassifier`/`FountainLineWriter`/`FountainInlineParser`/`FountainInlineSerializer`.
  Commented text is read through one rule, `FountainCommentSpans` (`fountain_kit`): the boneyard
  `/* ... */` and the note `[[ ... ]]`, each running to its first closing marker, over several
  lines if need be. The parser, the spell checker and the editor all use it. A node whose whole
  text lies inside such a span is **inert**, the way the parser sees no screenplay element there.
  Inertness is recomputed from the nodes' plain texts on every pass (`OcptWysiwygCommentLayout`),
  never stored. **A node holds its text in one form, inert or live:** the whole line's inline runs
  parsed into attributions (emphasis, notes) and written back by the one serializer, so commenting
  or uncommenting a line never changes its representation and nothing is re-parsed. An inert node
  differs from a live one only by its type (action, no marker stripped on decode and none added on
  `encode`), by being left alone by the reclassify, uppercase and scene-number passes (the computed
  scene numbers skip it), and by being dimmed. The other lines are classified on the same lines the
  parser classifies, the boneyards and the standalone notes blanked out, so editor and parser agree
  on their types; a line with live text and a trailing `/*` or a leading `*/` keeps its normal
  type. Classification also ignores the inline notes of a line (`[[x]]INT. HOUSE - DAY` is a
  heading, `CUT TO:[[x]]` a transition, in the parser and in the editor), and the uppercase pass
  leaves the text of a note or of a comment as written. The spans are found on the plain texts, so
  they need no offset mapping. The inline parser and serializer behave as ever unless handed the
  offsets of the `*` of real boneyard delimiters (`literalStars`), which the codec takes from the
  boneyard spans only: on decode from the whole source text, on encode from the layout. Those
  stars are plain text, never emphasis, never escaped; a `/*` with no closing `*/` is no span.
  A `[[` preceded by an odd number of backslashes is escaped, printed text and no note, for the
  parser and the spell checker alike; the parser drops the backslash, so the node marks the `[`
  with `ocptFountainEscapedAttribution` and the spans are looked for in a copy of its text where
  that character is blanked. `OcptWysiwygInlineRuns.writeLine` writes the backslash back in front
  of a marked `[` that no `]]` follows on the line: the serializer reads one line at a time, and
  would otherwise leave it bare, for a `]]` on a later line to close into a note.
  A derived pass, run with the others inside the settle pass (so with no undo step of its own),
  puts `ocptFountainCommentAttribution` on every commented span, across nodes too; the stylesheet
  dims it like a note. `decode` puts the same attributions itself, so a decoded document is
  already settled: the editor's first history snapshot carries them, and no pass has a request to
  make on it, which is what keeps Ctrl+Z, then redo, working on a freshly opened text. The
  document is laid out as lines of plain text once per settle (`OcptWysiwygCodec.layoutOf`, an
  `OcptWysiwygDocumentLayout` handed to each pass, laid out again only after a pass that changed
  a text); `OcptWysiwygCommentLayout.of` also answers the last layout again to the builds.
  A line whose marker cannot be stripped and written back exactly (a marker preceded by a note or
  a boneyard, a page break or a centered text in any form but its canonical one) is kept as
  written, its text the whole source line and its type the parser's; `encode` writes it back as it
  is. `encode` gives an inert node the type and the following line the parser reads (the layout's
  classification lines), so a forcing marker is never added around a multi-line comment.
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
  *because* of it. Never the derived half alone. `Editor` (built by `ocptStyledEditorFor`,
  `ocpt_styled_editor_builder.dart`) runs with `isHistoryEnabled: true` and `OcptSettleMergePolicy`
  (`ocpt_settle_merge_policy.dart`) as its `historyGroupingPolicy`:
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
  own — staling the redo stack, and appending an undo step that un-numbers the screenplay. The
  decoded document is **settled before that base state is taken**: `_rebuildEditorFrom` runs the
  whole settle on it through a history-less editor (`ocptStyledSettlingEditorFor`, the one the
  flush uses on its throwaway copy) and only then builds the `MutableDocument` the real editor
  edits, since a `MutableDocument` keeps the nodes it was built with as the state `undo()` resets
  to. What the settle derives from a text the writer has not touched yet — a heading typed in
  lower case and uppercased — is therefore the starting point, never a first undo step.
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
  mode is a plain `TextField` and gets Flutter's native menu for free). Cut, Copy, Paste, Select
  all, Insert note and Remove note, and the block type as a submenu; the clipboard entries call the
  very helpers the Ctrl+C/X/V handlers do, and the submenu the same `applyBlockType` the toolbar
  dropdown does, so no gesture can behave differently from its keyboard or toolbar twin. The two
  note entries form their own group between the clipboard and the block type, and
  `OcptFountainNoteActions` (`ocpt_fountain_note_actions.dart`) holds their rules as pure functions
  of a document and a selection, answering the requests to run or null; `OcptStyledNoteEditing`
  runs them. Insert note puts an empty note at the caret, or at the end of a selection inside one
  block, the selected text left as it is, selects it and gives its card the focus (see **Notes**
  below); it is withheld across several blocks, on a title-page field or a page break, and wherever
  the selection touches a note still held as text, since notes never nest. Remove note appears when
  the caret touches a note, the selection holds one alone, a note is selected in the margin, or the
  caret lies inside a `[[...]]` range kept as text, and deletes it whole, brackets and content, and
  the one space it would leave doubled or dangling, with no confirmation. A note running over
  several blocks goes the same way: the blocks it covers are dropped, and what stood before it in
  its first block joins what stood after it in its last. Each command is one `Editor.execute`,
  hence one undo step. The
  list of assignable types lives once, as `ocptAssignableFountainLineTypes`
  (`lib/ui/widgets/helpers/ocpt_fountain_line_type_labels.dart`). An entry with nothing to act on is
  **withheld, not disabled** (a null callback), which is what hides Cut/Copy over a collapsed caret.
  The secondary tap resolves the document position under the pointer and places the caret there,
  unless it lands inside an expanded selection, which it never destroys. A left click landing back
  on the document closes the menu, which a `MenuAnchor` does not do on its own: its anchor child —
  the whole editing surface here — belongs to the same `TapRegion` group as the menu, so a
  `Listener` above the gesture detector watches for the primary button and closes it, observing the
  click rather than competing for it. Nothing is withheld for a read-only preview: the styled editor
  is not mounted under one at all, `OcptEditorCentre` substituting the read-only preview for both
  editing modes.

- **Notes**: the styled editor shows a Fountain note `[[...]]` as a small speech bubble in the
  line, and its text in a card in a margin column beside the page, the way a word processor shows
  its comments. The UI says *note*, never *comment*. A boneyard stays dimmed text in the line.
- **A note is an inline placeholder**, `OcptFountainNote` (`ocpt_fountain_note.dart`): one
  position of the node's `AttributedText`, carrying the note's text and an identifier minted when
  the note is created and never reused, which follows the note through the edits of its text and
  tells two notes holding the same words apart. Its `expansion` is always `[[text]]`. The layout
  the passes read is the **expanded** text, each placeholder written back as its expansion, and
  `OcptWysiwygNoteOffsets` is the one place that maps a range of a line back to its node: a range
  covering part of a note covers the whole note, so a placeholder is never cut in two. The
  simulated pagination counts a bubble as two characters, its drawn width.
- **The invariant** (`OcptWysiwygNotes`, `ocpt_wysiwyg_notes.dart`): a node holds a placeholder
  for exactly each note the parser would see that opens and closes within the lines the node
  covers, lies outside every boneyard and holds neither `/*` nor `*/`; every other note stays text,
  bracketed and dimmed. `decode` builds it, and a pass run first in the settle (before any pass
  reads a text, in an `execute` of its own, the document laid out again after it) keeps it: a note
  typed or pasted as text is **absorbed** into a placeholder as soon as it satisfies the invariant,
  and a placeholder whose expansion stops being such a note is **dissolved** back into its text. So
  the Fountain source a node writes never depends on which form its notes took, and a note's text
  never holds `]]`, `/*` or `*/`. A node an input method is still composing is left for the next
  settle. A note running over several lines is the one the live passes never create nor dissolve
  (see the node model above): only a decode folds or unfolds it.
- **The bubble** is an inline widget (`OcptFountainNoteMarker`, `ocpt_fountain_note_marker.dart`),
  built for the placeholder through the stylesheet's `inlineWidgetBuilders`: the app's accent on a
  light tint of itself, fixed like the rest of the paper styling, sized from the zoomed font, drawn
  solid while its note is selected and over the search highlight colours while the query matches
  inside its note. Its semantics label is the translated `Note`. `OcptNoteTapDelegate`, a content
  tap delegate, makes it clickable: a tap on it selects the note and goes no further, a tap anywhere
  else in the text drops the selection and goes on as usual.
- **The selected note is view state** of the editing surface, like the composer's selection:
  `OcptStyledNotes` (`ocpt_styled_notes.dart`) holds the notes of the document in document order
  (`OcptNoteEntry`: node, offset, note, and whether its node holds nothing but notes) and the
  selected identifier, which the bubble, the card and the line between them all follow. Nothing of
  it reaches the document or the bloc, and it is dropped as soon as the document no longer holds
  that note.
- **The margin column** (`OcptStyledNotesMargin`, `ocpt_styled_notes_margin.dart`) stands to the
  right of the sheets in page simulation, the sheets and the column centred together, and at the
  right of the text in fluid mode, the text narrowing to leave it room. It is there only when the
  document holds a note and `OcptStyledNotesMargin.fits` says the whole of it fits beside the page,
  or beside the text at its minimum width, so it never makes the page scale down or the text scroll
  sideways; a compact surface never has one. Both surfaces keep one tree whether it is there or not,
  so the editor is never mounted again when the first note appears. The column reads where each
  bubble is from the document layout after a frame that may have moved one (notes, size, zoom), in
  the coordinates of the scrolled content, and follows the scroll by itself.
  `ocptStackNoteCards` (`ocpt_note_card_stacking.dart`, a pure function) places the cards: each at
  the line of its bubble, pushed down below the previous one when they would overlap; with a
  selection, the selected card sits exactly at its line, the cards after it pushed down and the
  ones before it pushed up, so no two cards overlap and the document order is kept.
  `OcptNoteCardsLayoutDelegate` lays them out, the selected card shifted towards the page and
  joined to its bubble by a thin line (`OcptNoteConnectorPainter`), drawn over the text it crosses.
  A click on a card selects its note.
- **Without room for the column, the selected note opens in a popover** under its bubble
  (`OcptStyledNotePopover`, `ocpt_styled_note_popover.dart`), shown through an `OverlayPortal` so
  that nothing clips it. `OcptNotePopoverPlacement`, pure, places it: under the bubble, above it
  when there is no room below, kept inside the visible area, its pointer centred on the bubble.
  Escape, Enter and a click outside close it, and it gives way to the card when the column comes
  back. There is no setting choosing between the two: the room alone decides, and compact always
  uses the popover.
- **A note is written in its card**: the selected card, in the column or the popover, swaps its
  text for `OcptNoteCardField` (`lib/ui/pages/editor/widgets/`), a multi-line field reporting every
  change. Enter and Escape give the focus back to the text, the caret just after the bubble;
  Shift+Enter breaks the line; Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y act on the editor's history, never
  on the field's own. `OcptNoteTextInputFormatter` refuses an edit that would put `]]`, `/*` or
  `*/` in the note, or end it with a `]`, so the invariant holds whatever is typed or pasted, and
  writes a line left empty as two spaces, the way Fountain keeps a blank line inside a note. A note
  sharing its node with other text holds no blank line, since one would split that text into two
  paragraphs. `OcptStyledNoteEditing` (`ocpt_styled_note_editing.dart`) makes every write to a
  note, from the card and from the menu, each one `Editor.execute`: it resolves the document, the
  editor and the composer at call time, since the styled editor replaces all three whenever its
  text is rebuilt from outside. **A note left empty is removed** when the writer leaves it, in the
  undo step that created it when nothing else happened in between; the removal waits a microtask so
  that a tap which put the caret elsewhere has set it first.
- **The edits of one note are one undo step**, from its creation to the moment the writer leaves
  it. They are ordinary text replacements, so `OcptNoteEditMergePolicy`
  (`ocpt_note_edit_merge_policy.dart`), which `OcptSettleMergePolicy` consults first, cannot tell
  them apart by itself: `OcptStyledHistory.runNoteEdit` runs each one under a token naming the
  note, and a transaction closed under the same token as the one before merges onto it. The token
  survives the selection changes made meanwhile and ends with any other document change, an undo
  or a redo, and `endNoteSession`, which the field losing the focus calls.

- **Dual dialogue**: a speech whose cue ends with `^` is printed beside the one before it
  (ADR 0035). `fountain_kit` owns the rule, once: `fountainDualDialoguePairs` over blocks and
  `fountainDualDialogueLinePairs` over classified lines pair two dialogue groups **strictly
  adjacent** (only blank lines between them), the second carrying `^` and the first not already
  being the second of another pair, so `A`, `B^`, `C^` pairs A and B and leaves `C^` an orphan, and
  a note, a section, a synopsis, a boneyard or any printed line between the groups breaks the pair.
  The block rule is run over **every** block of the document (`fountainPrintableDualDialoguePairs`,
  which maps the pairs to the numbering of the printed blocks), never over the printable ones alone,
  since the printable blocks have already dropped what must break the pair, and the line rule ends
  a dialogue group at a line holding only notes, as the note block does. The composer then
  prints a pair as **one row of two cells**: `FountainScriptPage.lines` stays one entry per printed
  row, and each row carries a `dualSide` and, on its left cell, a `dualCompanion` for the right
  one (`cells`, `cellOf(side)`); `sourceRange` stays the cell's own and is never the union of the
  two. The columns come from `FountainLayoutMetrics.dualDialogue` (28 columns in US Letter, 26 in
  A4, a four-column gutter), `null` when a column would be under 16 columns wide, in which case the
  pair prints stacked. **The pair is never split across pages**: it moves whole to the next page when
  it does not fit, taking along the scene heading that would otherwise be left alone at the foot of
  the page (the raw preview's pagination does the same), and is only stacked, with the usual
  `(MORE)`/`(CONT'D)`, when it is taller than a page. The raw preview, the PDF, the coverage, the
  sides and the word views of the breakdown and the shot list all print it side by side; the
  **styled editor does not**.
- **The `^` in the styled editor** is node metadata, not text: `OcptWysiwygCodec.decode` takes the
  suffix off a character cue (spaces included) into `ocptDualDialogueMetadataKey`
  (`ocpt_wysiwyg_dual_dialogue.dart`), keeping its exact spelling, `^` or ` ^`, since the corpus
  holds both and a round trip is byte for byte; `encode` writes the stored suffix back on a
  non-empty cue, an inert cue included. A `^` set by the interface is written ` ^`.
  `OcptWysiwygDualDialogue.requests` is the derived pass, a sibling of `sceneNumberRequests` run at
  the same point of the settle (so merged into the typing's undo step through `runDerivedPass`): it
  absorbs a `^` typed at the end of a cue, and, run again after the reclassify, **writes the stored
  suffix back into the text** of a node that is no longer a cue (a letter typed after the name, an
  extension, a cue emptied), so no character of the source is ever lost and the next absorb picks
  it up if the node reads as a cue again. `OcptReplaceNodeTextCommand` brings a selection end the
  shorter text leaves past its end back inside it, so absorbing a `^` or a `#N#` never leaves the
  caret outside its node, and a composing region the same way. Every derived pass that rewrites a
  node's text (this one, the `#N#` absorb, the uppercasing) skips the node holding the composing
  region while an input method is composing, and acts at the settle that follows the composition's
  end. `Enter` replicates no metadata, but the suffix belongs to the end of the
  cue: a split in the middle (or at the start) gives it to the tail node, and only a split at the
  very end leaves it on the original. A copy writes the suffix through `encode` only when the
  copied range reaches the end of the cue, and a paste puts it back at the end of the cue's text,
  where the next settle absorbs it. A `^` followed by a note (`KIM ^ [[aside]]`) is not absorbed,
  since writing it back would move it past the note: it stays in the text, and the pairing,
  the bracket and the toggle read it through the pairing rule. A freshly decoded document yields
  no request. Styled search reads the display text, so a `^` is no longer findable there.
- **The styled editor stacks a pair**, one speech under the other, and **brackets it**:
  `OcptDualDialogueBracketComponentBuilder` (`ocpt_dual_dialogue_bracket.dart`, modelled on
  `OcptSceneNumberGutterComponentBuilder`) draws a vertical bracket in the left margin, one
  segment per node of the pair from the first cue to the last line of the second speech, bridging
  the blank lines between the two speeches (not a simulated page boundary), with a short end
  at each extremity, in the page's text colour at reduced opacity. A cue carrying `^` with no
  group before it to pair with, an orphan, gets no bracket but a dimmed `^` painted after its name,
  as does the marked cue that is the left member of a pair (`X^`, `Y^`), the `^` that does not
  mark a right member; the marker is measured from the cue's own text layout and is not part of the
  node's text, so the caret and the selection never reach it. The bracket finds the page's left
  edge from the width of the document column (`OcptDualDialogueColumnScope`), so every segment sits
  in one column on a compact surface too, and a node whose page start is repaginated to `0.0` is
  bridged to the node above like any other. The pairs are read off the nodes with the shared
  pairing rule (`OcptWysiwygDualDialogue.analysisOf` builds the source lines from the nodes'
  types, their blank runs and their stored suffix, once per change of the document, with a cheap
  fast path for a document holding no `^` at all), and the editor rebuilds the builder when
  its `key` changes after a settle. **Why stacked**: super_editor's
  layout is a `Column` that `SuperEditor` instantiates itself, and its drag selection
  (`getDocumentSelectionInRegion`, over a binary search `_findComponentIndexAtOffset`, both
  private) assumes components ordered from the top of the page to its bottom; a prototype setting
  the right speech beside the left one by painting its nodes shifted up selected nothing in 310 of
  460 drags starting in the left column (ADR 0035). The simulated page's pagination keeps counting
  a stacked pair as it always did, so a page holding one differs from the preview and the PDF,
  which is accepted; side by side comes back if super_editor's selection ever takes unordered
  components.
- **The dual-dialogue toggle**: a checkable `Dual dialogue` entry in `OcptEditorContextMenu`, in
  `OcptEditorFormatControls` and in `OcptEditorFormatOverflowMenu`, and **Ctrl+Alt+D**
  (Cmd+Alt+D on macOS, `ocptToggleDualDialogueAction`; nothing in `editor_page.dart`'s shortcuts
  claims it). `OcptStyledEditorController.toggleDualDialogue()` and its read state
  (`canToggleDualDialogue`, `isDualDialogueChecked`, mirrored by `updateReadState`) carry it with no
  super_editor import. `OcptWysiwygDualDialogue.toggleAt` decides: with the caret in a pair, the
  entry is checked and unpairs by removing the **second** cue's marker, from either speech (the
  stored suffix, or the `^` written out in the text when a note follows it); in a speech carrying a
  marker with no partner it is checked and removes it; in any other speech it pairs with the group
  before it by marking its own cue, or, when that one already is a member of a pair, with the group
  after it by marking that one's, unless that one is the left member of a pair of its own, which
  marking it would break. It reads only the run of dialogue groups the caret's group belongs to
  (the nodes around the caret, never the whole document), since it runs on every document and
  selection change and on every build of the context menu. It is **withheld, not disabled**, where
  there is nothing to pair (a line that is no speech, no other speech next to the caret's, the raw
  mode) or nothing to write, so there is never an empty undo step. One request, hence one undo
  step.
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
  line, so a title page with no entries at all is dropped. Entries outside the six (`Copyright`,
  `Notes`, `Revision`…, matched case-insensitively, `Authors` counting as `Author`;
  `ocpt_title_page_standard_keys.dart`) are neither shown nor editable: they ride on the first field
  node under `ocptTitlePageExtraEntriesMetadataKey`, are written back verbatim after the six, and
  the `Title page…` dialog appends them the same way. `OcptTitlePageComponentBuilder`
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
  painted by the same `OcptPageSheetsPainter` that paints the sheets themselves and gated on page
  simulation (there is nothing to number on the fluid surface). The rule itself lives once, in
  `lib/models/rules/ocpt_script_page_number.dart`: `N.` at the top right,
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
  was picked. On a phone that forced fluid surface is additionally painted with the fixed paper
  colours (white ground, black text) rather than following the theme
  (`OcptStyledScreenplayEditor.usesPaperColorsWhileFluid`, passed to
  `OcptFountainEditorStylesheet.build`'s own `usePaperColors`): the desktop default is white paper
  sheets, so without it a phone in dark mode would be the one place the screenplay turned dark, and
  painting it as paper keeps it reading the way the desktop's simulated page does — colours alone,
  the compact indents below still apply. Below the compact width breakpoint (`ocptIsCompactWidth`, a
  phone included) the
  toolbar's format controls (the block-type dropdown, the B/I/U toggles) fold into
  `OcptEditorFormatOverflowMenu`'s own single `⋮` button — the same block-type choice as a submenu
  and the same three toggles as checkable entries, reading and writing the very same
  `OcptStyledEditorController` `OcptEditorFormatControls` does above that width — for want of room
  beside everything else the toolbar already carries there (`foundations.md`); a phone writer
  additionally reaches every block type through `OcptEditorContextMenu`'s own submenu, or simply by
  typing the Fountain markup.
- Below the compact breakpoint (`ocptIsCompactWidth`), and only on the fluid (page-simulation-off)
  surface, `OcptFountainEditorStylesheet.build(isCompact: true)` scales every element's indent and
  box width down by `OcptEditorPreviewLayout.compactLayoutScale` (0.5), carrying the block hierarchy
  by **style** — character bold/accent, parenthetical italic, dialogue slightly inset — rather than
  by the real, screenplay-sized indents (a character cue ≈ 3.7″ in) a phone has no room for. A
  uniform multiplier on both halves of every element's box keeps the desktop proportions intact at
  half scale, rather than redesigning each type on its own. That scale lives on
  `OcptEditorPreviewLayout` rather than the stylesheet because the breakdown mode's own script view
  reuses it for the very same purpose (`breakdown.md`). A paginated page never sees it: the flag
  only ever applies while page simulation is off, since a simulated sheet is sized from the very
  real metrics the PDF exporter agrees with pixel for pixel, and compressed ones would desync the
  two —
  `OcptFountainEditorStylesheet.build` guards that itself rather than trusting every caller to.
  Desktop output is byte-identical, the flag defaulting off everywhere a desktop call site builds
  the stylesheet.

- **Page zoom.** The page (the styled editor's and the raw mode's paper preview, never the raw
  source, the breakdown script or the coverage dialog) is zoomed **through the font size**:
  `OcptEditorPreviewLayout` takes a `zoom` (1 by default), its `fontSize` is `baseFontSize × zoom`
  and `glyphWidth` is measured at that size, so the page, its margins, every element's box and the
  line height follow, the text is re-typeset sharp and the stylesheet, the pagination, the title
  page and the sheets painter all read the factor of their own layout. A `Transform.scale` around
  the editor was rejected: super_editor measures its components through `localToGlobal` and
  places its IME, handles and autoscroll on that basis, and the text would not be re-wrapped. The
  wrap points do not move with the zoom (everything is in columns), so **the pagination is the
  same at every zoom** (`computeOcptStyledPagination(zoom:)` gives the same page-start nodes), and
  **what is stored in the document does not depend on it either**: a page-start node carries, in
  `ocptStartsNewPageMetadataKey`, its padding in inches of page minus the one page gap it always
  holds (`ocptPageStartMetadataOf`), and the stylesheet turns that back into pixels at the zoom it
  renders at (`ocptPageStartPaddingOf`); a padding clamped to nothing (a title page taller than a
  sheet) stores one fixed value that reads back as no padding at every zoom. A zoom therefore
  writes nothing to the document: pixels
  would have made it an undo step that marks the redo stack stale, and an undo would have brought
  back the paddings of the old zoom for a debounce.
  - The zoom is `OcptPageZoom` (`lib/models/rules/ocpt_page_zoom.dart`): one of ten steps (50, 67,
    75, 90, 100, 110, 125, 150, 175, 200 %) or **fit to width**, a *mode*, not a step: the sheet
    fills the area it is shown in, follows the window, bounded to 50–200 %, and `OcptEditorZoomArea`
    resolves it from the width it is given and reports the factor
    (`OcptEditorFitPageZoomMeasuredEvent`, never stored) — the status bar shows it, and a step
    out of that mode starts from the nearest step. It is stored as one text by
    `OcptPropertiesManager.styledPageZoom` (`fit` or the step's percentage, so a stored value out of
    the bounds is brought back to the nearest step and an unknown text reads as 100 %), for the user
    and whatever the project, loaded on entry and written on every change like
    `styledSceneNumbersVisible`; it lives in `OcptEditorState.styledPageZoom`, changed by
    `OcptEditorPageZoomSelectedEvent` and `OcptEditorPageZoomSteppedEvent`.
  - Ways to zoom: the status bar's `−  100 %  +` (`OcptEditorZoomControl`, in the status bar's
    `control` slot, centred in it, a menu of the steps and *Fit to width* behind the percentage, a
    button at the end of the steps withheld), **Ctrl + wheel** (Cmd on macOS, `OcptEditorZoomWheel`)
    and **Ctrl** and `+`/`=`/`−`/`0` (`OcptEditorZoomIntent`, mapped by the page; the styled
    editor's keyboard actions claim none of them, so they bubble up like Ctrl+S). The bloc refuses
    a step with `OcptPageZoom.canStep`, the very answer the buttons are withheld on, so a shortcut
    never goes where they don't, in the fit to width mode included.
  - **Keyboard layouts.** The shortcuts are not a static map of keys: `OcptEditorZoomKeyActivator`
    matches the character the key *produces* (`-`, `+`, `=`, `0`), because a French AZERTY layout
    has its minus on the key QWERTY calls 6 (which Flutter reports as `digit6`) and a German QWERTZ
    its unshifted plus on the one it calls `add`, while a Ctrl+6 on QWERTY produces a 6 and zooms
    nothing. When a platform gives no character for the chord, the logical key of the keys that
    mean the same everywhere (minus, equals, plus, zero, and the numpad's) decides. Windows never
    gives a Ctrl chord a character, and its AZERTY minus arrives as a bare `digit6`: a `digit6` with
    no character zooms out, a trade-off that makes Ctrl+6 zoom out on a Windows QWERTY keyboard too,
    whereas on Linux a QWERTY Ctrl+6 carries its character, a 6, and does nothing.
  - **The wheel and the scrolling.** The wheel claims its event through
    `GestureBinding.pointerSignalResolver`, but the scrollable nearest to the pointer registers
    first and would scroll the page too, so every scrollable under it refuses the user's offset
    while the modifier is held (`OcptZoomWheelPhysics`, over the platform's own physics, which stay
    underneath, and only where the page can be zoomed). Flutter asks that same question a second
    time, when a scrollable's content changes size, to decide whether it reacts to a drag at all:
    answering "no" then would leave touch and trackpad drags dead until the next resize, after a
    zoom or a paste made with the modifier held. The two are told apart by the phase: a wheel
    event arrives between two frames, the drag check is made while one is built, so the offset is
    only refused between frames. The physics is a **constant** per parent: a new instance at every
    build is a new scroll behavior, and it made the styled editor's history non-empty on mount.
    A step is a notch: an event of at least `OcptEditorZoomWheel.stepDelta` (40 px, under the 53 of
    a Linux notch and the 67 to 200 of a Windows one) steps once, never more however far it turns,
    the first event of a turn steps at once, and smaller ones (a smooth wheel) add up to a step.
  - **Scrolling with the zoom** (`OcptStyledZoomAnchor`). The point the zoom is made around stays
    under the pointer for a wheel notch (its position is only kept for the frame that follows, a
    refused step leaves nothing behind), under the caret when it is in view for the other ways, and
    at the centre of the area otherwise. It is the *line of text* under the point that is found
    again once laid out, not a ratio of the scroll offset, which the gap between two sheets (that
    doesn't scale) and the text's own rounding would throw off further and further down the page.
    A sheet scaled down to fit a narrow area is drawn smaller than it is laid out, so the distance
    measured on screen is brought back to the laid-out units before it moves the offset.
    Once the page is wider than its area, the caret, and a find match, are kept in view sideways.
  - A page zoomed in wider than its area scrolls **horizontally**, centred while it fits; at 100 %
    or less it is still scaled down to fit a narrow area. The three outcomes share **one tree**
    (`OcptStyledScaledToFit`: the app's `OcptHorizontalScrollView` around a `FittedBox`, only what
    they are told changes), and so do a step and the fit to width mode (`OcptEditorZoomArea` is
    always a layout builder), and the raw mode's preview uses the same widget: a page that moved to
    another shape of tree would be mounted again, losing its scroll position, caret, focus and
    history. A **compact** window
    (`ocptIsCompactWidth`: a phone, a narrow window) has no zoom at all: the control is withheld,
    the wheel and the shortcuts are ignored. Zoom is a view setting, not a write, so it stays
    available under a read-only preview, whose preview shares the layout.
  - In raw mode the preview in the right dock measures **its own width** through its own
    `OcptEditorZoomArea` and reports the factor like the styled editor does: only one surface is
    shown at a time, so they share the one measured factor, and the status bar shows the one of
    the surface on screen (the last measure while the dock is closed).

- A **scene jump** (a click in the scene panel) and a **find match** both land their target a
  third of the way down the editor's viewport, and each mode has its own trap to avoid. The styled
  editor moves its selection with its own reason, `ocptProgrammaticNavigationSelectionReason`,
  never `SelectionReason.userInteraction`: super_editor answers a user-interaction selection change
  with a minimal caret reveal on the next frame, which would pull the target back to the viewport's
  edge just as `Scrollable.ensureVisible` started placing it. The raw field **measures** where the
  target line is (`EditableTextState.renderEditable.getLocalRectForCaret`) rather than counting
  newlines, since every wrapped action or dialogue paragraph above the target would put a newline
  count one visual line further short; the count remains only as the fallback for a field not laid
  out yet.

- **The screenplay mode is one mode bloc and four function blocs** (ADR 0034;
  `lib/ui/pages/workspace/blocs/` holds the machinery, `foundations.md` the recipe). Styled and raw
  are two renderings of one text, not two views, so the cut is by function, and each satellite
  extends `AbsOcptViewBloc` and is built with the mode (`OcptEditorPage`'s `MultiBlocProvider`,
  `lazy: false`):
  - `OcptEditorBloc`, the mode bloc, owns **the text, which is the source of truth**: the typed text
    and its dirty flag, the parse, autosave and save (a failed save raises the transient error once,
    keeps the text dirty, and the next save works), the parsed document, the caret line, the title
    page, the docks, the editing mode, the page setup and the two display switches the other blocs
    read (`isSpellCheckVisible`, `screenplayLanguage`). It mixes in `MixinOcptModeBloc`:
    `flushAllPendingWrites` saves a dirty text tagged `manual`, answers true whatever happened (a
    failed save is shown by the mode and the action behind the flush goes ahead on the stored text,
    as it always did), and `flushPendingProjectWrites` is the same call. `reloadEpoch` moves on a
    whole load, on a text replaced by an action (an import, a title page rewrite) and on a page
    setup change, with `reloadCause` saying which; `selectionEpoch` moves on a scene jump request.
    Typing moves neither.
  - `OcptEditorSpellCheckBloc` owns the underlines of both surfaces, the two caches and their keys
    (`OcptEditorSpellCheckCaches`, mutable on purpose, carried by every copy of the state and left
    out of its `props`: a cache is filled by the very answer that emits the ranges, so comparing it
    would make a state differ from itself), the learned words and the suggestions. It reads the
    document, the mode, the two switches and the preview flag off the mode's state when it runs.
    A whole load drops the caches and every underline and pushes the project's learned words; a
    new document or raw becoming the mounted mode requests a raw pass; a switch or language change
    drives the dictionary, and once a dictionary is ready both surfaces are re-checked (the styled
    editor reported its texts as it mounted, before the dictionary, and has nothing new to say).
    Opening the styled editor renumbers the headings and autosaves: pinned.
  - `OcptEditorSearchBloc` owns `OcptEditorSearchState`, which is why a search survives a mode
    switch. It reads nothing of the mode: each surface counts what it shows and reports the count.
  - `OcptEditorIoBloc` owns the notice of the `.fountain` and PDF exports and of the import. An
    export asks the mode to save a dirty text tagged `export` first (`addToModeAndWait`), then
    reads the text the mode holds. An import has the mode save the typed text first, so the
    snapshot of the replaced screenplay holds it, writes the imported text, and has the mode show
    it (`OcptEditorImportedTextAppliedEvent`, which moves `reloadEpoch` with `textReplaced`).
  - `OcptEditorStatisticsBloc` owns the counters. A new document refreshes the scene's counters
    and restarts its own 500 ms debounce, after the parse debounce that produced it; a reload of
    any cause recomputes both at once; the caret changing scene refreshes the scene's counters.
  The page watches only what it shows: the find bar slot rebuilds on the search state, the status
  bar and the two dock panels on the counters, so a keystroke rebuilds what it rebuilt before and
  no more, and the editing surfaces' controllers and the caret are never recreated. The page's
  controller wiring is split the same way: `OcptEditorSearchSync` (what each surface highlights
  and replaces), `OcptEditorRawScroller` (a jump or a match in the raw field) and
  `OcptEditorDialogFlows` (every dialog the page opens, `OcptConfirmDialog` included).

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
  living inside the find field itself. The search *state* is `OcptEditorSearchState`, in `OcptEditorSearchBloc`,
  which is what makes it survive a raw ⇄ styled toggle; the bar and both surfaces only ever report
  into it.
- **Each mode matches what it shows**, and the counter says so: raw mode searches the Fountain
  source, the very characters its field displays, where the styled mode searches each node's
  *display* text — no forcing marker, no `#N#`, no `*`/`_` emphasis, and the six title-page fields
  included, so its count moves with the page-simulation toggle that creates them. The two counts
  can therefore differ for a query holding markup, which is the rule rather than a defect. The bloc
  holds the query, the two options and the current index; the **count is reported up by whichever
  surface is mounted**, which is what keeps `Replace all` consistent with the number the bar just
  showed. The matcher itself is `ocptFindTextMatches` (`lib/models/rules/ocpt_text_search.dart`),
  shared by both: literal — a query is never compiled into a `RegExp`, since `(`, `.` and `*` are ordinary
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
- **The styled search reaches the text of the notes** too, which the page shows in their cards.
  `OcptStyledSearch.orderedSearchMatches` orders a match inside a note where the note's bubble
  stands in its block, and among the matches of that note in the order of its text
  (`OcptStyledSearchMatch`). The bubble of a note holding a match is tinted, more strongly for the
  current match; the current match inside a note selects that note without taking the focus, so
  its card, or its popover, opens with the match highlighted (`OcptNoteMatches`, painted by
  `OcptNoteHighlightController` in the field and `OcptNoteHighlightSpans` in a read-only card),
  and the caret is collapsed just after the bubble, so no text match stays selected. `Replace` and
  `Replace all` write into a note through `OcptStyledSearchNotes.replacedText`, which answers null
  when the note could not hold the result (a `]]`, a `/*` or a `*/` in it, or a trailing `]`): that
  note is skipped and the others are still replaced. `Replace all` stays one undo step.
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
  `lib/models/rules/ocpt_spell_checked_lines.dart`: `ocptIsSpellCheckedLineType` returns true for action,
  dialogue, parenthetical and centered text, and false for scene headings (a set name in capitals),
  character cues (a writer's invented names are exactly what a dictionary does not have),
  transitions (a fixed vocabulary that is not the language's), sections, synopses and lyrics. Title
  page fields never reach it at all — they are left out of what a caller hands over, a title being
  invented on purpose and the six fields existing only under page simulation, so the squiggles
  would otherwise appear and disappear with a display toggle. `ocptLineTypeOfBlock` expresses the
  same rule over `FountainDocument.blocks` rather than restating it, and
  `ocptSpellCheckSkipSpansIn` drops the tokens sitting inside an inline note or boneyard comment,
  reading the spans from `fountain_kit`'s `FountainCommentSpans`, the rule the parser uses too.
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
  itself clickable (`onTabSelected`) and only ever selects (the active tab does nothing, the dock
  never closes), while the toolbar's preview/syntax buttons — **raw mode only**, the styled mode
  reaches every tab through the tab row alone — *toggle* their tab, through
  `OcptEditorRightDockTabSelectedEvent.closesWhenActive`: they open a closed dock on it and close
  the dock when it already shows it (inspector/metadata/versions have no toolbar button in either
  mode). The shell's
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
  are recomputed on the editor's existing 150 ms parse debounce, never per keystroke (the
  statistics bloc, after the mode's parse).

- The Fountain syntax guide (`OcptEditorSyntaxGuidePanel`) renders the `const`
  `ocptFountainSyntaxEntries` table (`lib/models/ocpt_fountain_syntax_entry.dart`, one entry per
  `OcptFountainSyntaxTopic`) as read-only snippets in both editing modes (the *panel* is
  mode-agnostic; only the toolbar shortcut opening it is raw-mode only); its titles reuse the 11
  existing `editorBlockType*` ARB keys where a topic already had one.
