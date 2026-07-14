<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Plan — True WYSIWYG styled screenplay editor

Implementation plan for reworking the styled editing mode into a Word / Final Draft-like
WYSIWYG editor. Read `CLAUDE.md` first: every norm there (house style, SPDX, l10n, tests,
verification gates, commit format) applies to every milestone below. Milestones are sized for
one Sonnet 5 subagent each and must land as one commit each, in order.

## Goals (validated with Benoit, 2026-07-13)

1. **True WYSIWYG** — Fountain markers hidden in styled mode; bold/italic/underline rendered;
   the super_editor document is the source of truth while in styled mode, (de)serialized to
   Fountain text (which remains the persisted source of truth).
2. **Auto-detect + manual override** — typing patterns (INT./EXT., ALL CAPS TO:, …) still
   reclassifies blocks, but a manual type choice (dropdown / Tab) locks the block's type; the
   lock clears when the block's text is emptied.
3. **Tab cycle on 6 common types** (Scene Heading → Action → Character → Parenthetical →
   Dialogue → Transition, wrap; Shift+Tab reverse); **dropdown lists all 11 assignable types**
   (+ Centered, Lyrics, Section, Synopsis, Page Break), localized en_GB + fr.
4. **Smart Enter** — the new block's type follows: sceneHeading→action, character→dialogue,
   parenthetical→dialogue, dialogue→action, transition→sceneHeading, others→action.
5. **Toolbar** — block-type dropdown reflecting the caret's block + B/I/U toggles (and
   Ctrl+B/I/U), serialized to `**` / `*` / `_`.

Engine stays **super_editor 0.3.0-dev.50** (pinned — dev.51+ does not compile with Flutter
3.41.9). The needed APIs were verified against the pinned source: `keyboardActions` receives
desktop hardware key events (incl. Tab/Enter; the IME "\n" delta is skipped on desktop),
`SplitParagraphRequest` places the caret in the new node, `ChangeParagraphBlockTypeRequest`,
`Add/Remove/ToggleTextAttributionsRequest`, `ComposerPreferences` (ChangeNotifier, collapsed
caret styles), custom `EditRequest`/`EditCommand` pairs for node metadata
(`replaceNodeById` + `copyWithAddedMetadata` + `executor.logChanges`, pattern of
`ChangeParagraphBlockTypeCommand`), and `defaultInlineTextStyler` already renders
bold/italics/underline attributions.

## Architecture decisions

### Document model — 1 node = 1 non-blank source line

One `ParagraphNode` per non-blank source line; blank lines become node metadata. Node metadata:

- `blockType` — the existing `NamedAttribution` (mapping unchanged in
  `ocpt_fountain_line_attributions.dart`).
- `ocptBlankLinesBefore` (int) — blank source lines preceding this line (0 inside a dialogue
  group). Preserves round-trip fidelity AND drives visual spacing: the stylesheet's top
  padding = count × line height (capped, e.g. at 3), keeping one mutually exclusive
  `StyleRule` per type (only textStyle/padding merge across rules — known pitfall).
- `ocptTypeLocked` (bool) — manual override flag; the reclassify pass skips locked nodes and
  clears the lock when a node's text becomes empty.
- `ocptHadForcingMarker` (bool) — the source line used an explicit forcing prefix; the
  serializer re-emits it even when auto-detection would suffice (byte-stable round trips).

Node text is the **display text**: forcing prefixes stripped, inline emphasis markers
converted to attributions. `[[notes]]` stay verbatim (brackets visible) with a `fountainNote`
attribution used for dimming only. A trailing-blank-lines count lives beside the line mapping
(not in nodes).

### Fountain ↔ document conversion

**fountain_kit (pure Dart, no Flutter imports):**

- `FountainStyledRun` model (`lib/src/models/fountain_styled_run.dart`): text +
  bold/italic/underline/note booleans (style *combinations*, unlike `FountainInlineStyle`'s
  single-value enum).
- `FountainInlineParser.parseRuns(line)` — new method reusing `parse()` plus one level of
  nesting (`_**x**_` → bold+underline, `***x***` → bold+italic); the existing `parse()` API
  and the raw-mode preview stay untouched.
- `FountainInlineSerializer` (`lib/src/serializer/fountain_inline_serializer.dart`): runs →
  marked-up line. Canonical markers: `***` for boldItalic, `_` outermost for underline
  combinations; adjacent same-style runs merged first. **Escaping = verify-by-reparse**:
  re-`parseRuns` the emitted line; if the runs differ from the input (e.g. a literal `*`
  found a mate), escape the offending `*` / `_` / `[` and retry — no gratuitous escaping of
  harmless lone characters.
- `FountainLineClassifier.classifyLine(...)` promoted to public API (context-aware "what
  would this line classify as, given previous line types and the next raw line").
- `FountainLineWriter` (`lib/src/serializer/fountain_line_writer.dart`): given (display text
  with inline markers, intended type, hadForcingMarker, context), returns the raw source
  line — prepending the forcing marker (`.` `@` `!` `>` `~` `#` `=`, wrapping `>…<` for
  centered, `===` for pageBreak) only when `hadForcingMarker` is set or `classifyLine` on the
  candidate would not yield the intended type in context.

**App side (`lib/ui/pages/editor/super_editor/` — the ONLY directory importing
package:super_editor):**

- `ocpt_wysiwyg_codec.dart` — replaces `ocpt_fountain_super_document.dart` (deleted). Static,
  widget-free helpers:
  - `decode(String text)` → `MutableDocument` + `OcptWysiwygLineMapping` + trailing blank
    count. Classifies lines with `FountainLineClassifier`, folds blanks into
    `ocptBlankLinesBefore`, strips forcing markers, builds `AttributedText` from `parseRuns`
    (bold/italics/underline/fountainNote attributions).
  - `encode(Document)` → text + fresh mapping. Left-to-right: emit `blankLinesBefore` blanks
    (forced to 0 for dialogue-group members following character/parenthetical/dialogue,
    raised to ≥1 when the intended type requires a preceding blank for auto-detection and no
    marker is used), serialize inline runs, let `FountainLineWriter` decide markers with the
    already-fixed earlier lines as context.
  - `reclassifyRequests(Document)` — rebuilds the virtual line list (with implicit blanks)
    for context-faithful classification; skips locked nodes; skips empty nodes (no signal —
    type kept); clears `ocptTypeLocked` on nodes whose text became empty.
  - `noteAttributionRequests(Document)` — recomputes `fountainNote` spans for `[[…]]`
    regions (Add/RemoveTextAttributionsRequest), run in the same debounced pass.
- `ocpt_wysiwyg_edit_requests.dart` — `OcptChangeNodeMetadataRequest` / `Command`, appended
  to the `Editor`'s `requestHandlers`.

**Dialogue/parenthetical fallback (documented + tested):** Fountain has no forcing marker for
dialogue/parenthetical (contextual only). A dialogue node not following a character serializes
as its plain text and degrades to action on reparse; the display honors a lock but the
serialized text still degrades. Doc comment on `encode` spells this out.

### Node ↔ source-line mapping

`OcptWysiwygLineMapping` (in the codec file), produced by both `decode` and `encode`:
`lineOfNodeIndex(int)` (caret → scene panel line) and `nodeIndexOfCharOffset(int)` (scene
jumps; blank lines snap to the next node). The widget keeps the mapping of the **last synced
text**, so bloc-computed jump offsets resolve against the same text version (≤120 ms lag,
same as today's reclassify lag).

### Editor ↔ toolbar: app-level controller

`OcptStyledEditorController extends ChangeNotifier`
(`lib/ui/pages/editor/ocpt_styled_editor_controller.dart`) — no super_editor imports; speaks
`FountainLineType` plus a new app enum `OcptInlineStyle { bold, italic, underline }`.
Read side: `currentBlockType`, `activeInlineStyles`, `isAttached`. Commands:
`setBlockType(FountainLineType)`, `toggleInlineStyle(OcptInlineStyle)`, delegated through a
private attach/detach delegate interface implemented by `_OcptStyledScreenplayEditorState`
(attach in `initState`/rebuild, detach in `dispose`), which feeds the read side from composer
selection + `ComposerPreferences` listeners. Rationale: follows the page's existing
`TextEditingController` precedent, avoids per-keystroke bloc churn, keeps the bloc
engine-agnostic. `_EditorViewState` owns the instance and passes it to both the toolbar and
the styled editor; the toolbar hides format controls when detached (raw mode).

### Keyboard handling

New `ocpt_fountain_keyboard_actions.dart`, passed as `keyboardActions` to `SuperEditor`:

```text
[ ocptTabToCycleBlockType,   // Tab & Shift+Tab, halts
  ocptEnterToSmartSplit,     // Enter/numpadEnter + Shift+Enter, halts
  ocptCmdUToToggleUnderline, // mirrors cmdBToToggleBold with underlineAttribution
  ...defaultImeKeyboardActions filtered ]
```

Filtered out of the defaults: `tabToIndentParagraph`, `shiftTabToUnIndentParagraph`,
`tabToIndentTask`, `shiftTabToUnIndentTask`, `enterToUnIndentParagraph`,
`backspaceToClearParagraphBlockType` (would strip our blockType instead of merging),
`shiftEnterToInsertNewlineInBlock` (an embedded `\n` would break 1-node-per-line).

- Tab never reaches Flutter focus traversal: super_editor's own `Focus.onKeyEvent` runs
  `keyboardActions` first and reports handled.
- Ctrl+S / Ctrl+Shift+M stay unclaimed and bubble to the page-level `Shortcuts`
  (`editor_page.dart`) exactly as today — pinned by a widget test.
- **Smart Enter** executes atomically:
  `SplitParagraphRequest(replicateExistingMetadata: false)` +
  `ChangeParagraphBlockTypeRequest(newNode, nextType)` + `OcptChangeNodeMetadataRequest`
  (`blankLinesBefore: nextType ∈ {dialogue, parenthetical} ? 0 : 1`, unlocked, no marker).
  The new node is NOT locked (auto-detect must keep working on it). Enter mid-text carries
  the remainder into the new node.
- **Shift+Enter** splits into a node of the SAME type with `blankLinesBefore: 0`.
- **Tab cycle**: sceneHeading→action→character→parenthetical→dialogue→transition→(wrap);
  Shift+Tab reversed. Entry from outside the cycle: Tab → sceneHeading, Shift+Tab →
  transition. Dropdown and Tab both set `ocptTypeLocked: true` and clear
  `ocptHadForcingMarker`.
- Ctrl+B/I: inherited defaults already toggle the attributions (selection, or composer
  preferences when collapsed).
- Mobile IME (Android delivers Enter via deltas, not key events) is out of scope
  (Linux/Windows first) — doc comment on the file.

### Inline formatting

`boldAttribution` ↔ `**`, `italicsAttribution` ↔ `*`, both ↔ `***`,
`underlineAttribution` ↔ `_` (outermost when combined: `_**text**_`). Emphasis never crosses
node boundaries (Fountain forbids emphasis spanning line breaks — free with this model).
Notes: dim style (`onSurfaceVariant` + reduced opacity) via a small `inlineTextStyler`
wrapping `defaultInlineTextStyler`; serialization ignores the note attribution (text passes
through verbatim). Emphasis attributions overlapping a note region are dropped at
serialization (the note is atomic in Fountain; documented).

### Preserved behaviors

- Caret line reporting & scene jumps go through the mapping (was node index == line).
- Autosave/dirty/parse pipeline unchanged: the debounced `encode` feeds `onTextChanged` →
  same `OcptEditorTextChangedEvent` flow.
- **New:** flush the pending sync synchronously in the widget's `dispose()`/`deactivate()`
  (cancel timer, `encode`, report if changed) — the last <120 ms of edits must survive a mode
  toggle or back navigation.
- Mode switches / project switch / external text change: the `didUpdateWidget` rebuild path
  is unchanged (`decode` instead of `buildDocument`); `_lastSyncedText` semantics unchanged
  (no rebuild loops). Passing through styled mode may normalize equivalent Fountain
  (canonical emphasis markers, corrected blank runs) — accepted normalizations are
  enumerated in the corpus tests, ideally none.
- Raw mode, preview, bloc, persistence: untouched.

### Toolbar UI

`OcptEditorToolbar` gains an optional `styledController`; when attached, a
`ListenableBuilder` section between the title and the right-side actions renders:

- `widgets/ocpt_editor_block_type_dropdown.dart` (new) — compact dropdown in the discreet
  toolbar style, wrapped in `Focus(canRequestFocus: false)` + explicit editor refocus after
  applying, listing the 11 assignable types with localized labels.
- Three toggle `IconButton`s (format_bold / format_italic / format_underlined, `isSelected`
  from `activeInlineStyles`, localized tooltips with shortcut hints).

~15 new ARB keys in BOTH `lib/l10n/intl_en_GB.arb` and `lib/l10n/intl_fr.arb`.

## Milestones

Every milestone: SPDX headers + doc comments on every declaration, then the full CLAUDE.md
verification gates inside the devcontainer, then one Conventional Commit with the Sonnet
trailer. Sizes: S/M/L.

- **M1 (M) — fountain_kit: styled runs + inline serializer.** `FountainStyledRun`,
  `parseRuns`, `FountainInlineSerializer` (verify-by-reparse escaping), exports in
  `fountain_kit.dart`. Tests: round-trips both directions, `***`, `_**…**_`, adjacency
  pairs, escapes, notes verbatim, per-line round-trip over every line of
  `packages/fountain_kit/test/corpus/*.fountain`. No app changes.
- **M2 (S) — fountain_kit: context-aware line writing.** Public `classifyLine`,
  `FountainLineWriter` (all forcing markers, `hadForcingMarker` preservation, `>…<`, `===`,
  `#`, `=`). Tests: every type × (auto-detectable / needs marker / marker preserved);
  classifier regression suite untouched.
- **M3 (L) — app codec.** `ocpt_wysiwyg_codec.dart` (+ `OcptWysiwygLineMapping`,
  decode/encode results), `ocpt_wysiwyg_edit_requests.dart`; delete
  `ocpt_fountain_super_document.dart`, migrate its callers and tests. Unit tests: corpus
  text→doc→text identity (explicit allow-list of normalizations), blank-run & forced-marker
  preservation, dialogue fallback degradation, locked/empty reclassify rules, mapping both
  ways, note attribution ranges.
- **M4 (L) — styled editor rework.** `ocpt_styled_screenplay_editor.dart` (decode/encode,
  mapping, flush-on-dispose, metadata request handler, preferences listener),
  `ocpt_fountain_keyboard_actions.dart`, stylesheet updates (blankLinesBefore top padding,
  note dimming styler). Widget tests (`BlinkController.indeterminateAnimationsEnabled =
  false`): smart-Enter map per type, Tab cycle/wrap/out-of-cycle entry/lock set, lock cleared
  on emptied text, reclassify skips locked, typing `INT. ` reclassifies an unlocked block,
  Ctrl+B/I/U effects, Ctrl+S & Ctrl+Shift+M bubble to the page, jumps & caret lines via the
  mapping.
- **M5 (M) — controller + toolbar + l10n.** Controller + `OcptInlineStyle`, attach/detach in
  the styled editor, dropdown widget, toolbar integration, `editor_page.dart` wiring, ARB
  strings (en_GB + fr) + `dart run intl_utils:generate`. Tests: controller read/command
  round-trips against a pumped styled editor, dropdown reflects/applies/locks, B/I/U toggles
  reflect/apply, controls absent in raw mode, `editor_page_test.dart` updates.
- **M6 (S) — integration polish + docs.** End-to-end mode-switch tests (edits survive both
  directions, flush-on-back), full-corpus smoke through the live widget, update CLAUDE.md's
  architecture note ("1 ParagraphNode = 1 source line" → new invariant + controller +
  metadata keys), doc-comment sweep, full gates, then manual `flutter run -d linux`
  checkpoint for Benoit (he validates UI himself).

## Risks & mitigations

- **Round-trip byte-instability → spurious dirty flag on mode entry**: `hadForcingMarker` +
  `blankLinesBefore` metadata, verify-by-reparse escaping, corpus identity tests; worst case
  a benign one-time dirty flag.
- **dev.50 quirks** (undo grouping of multi-request executes): smart-Enter may undo in two
  steps — acceptable v1, noted in code.
- **Encode/reclassify cost at 120 ms on feature-length scripts**: same order as today's
  full parse (single-digit ms). Ready fallback (not built up-front): restrict the pass to
  changeLog-touched nodes.
- **Toolbar stealing editor focus**: `canRequestFocus: false` wrappers + explicit refocus;
  widget test.

## Final verification (M6)

All gates per milestone, plus manually in the devcontainer (`flutter run -d linux`): dropdown
reflects the caret block and changes it; Tab/Shift+Tab cycles with wrap; Enter follows the
smart map; B/I/U via toolbar and Ctrl+B/I/U; typing `INT. ` converts an unlocked block; mode
toggle preserves edits both ways; raw mode shows the expected markers; Ctrl+S saves; the
scene panel follows the caret and jumps work.
