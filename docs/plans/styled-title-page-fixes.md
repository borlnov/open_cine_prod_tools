<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# M7 follow-up — the styled view's title page

This document is the correction plan for the four defects Benoit found while **using** the editable
title sheet delivered by M7 of [`editor-and-export-fixes.md`](editor-and-export-fixes.md)
(commit `32c710f`, "feat(editor): editable title page in styled mode"). It is written for the
Sonnet 5 agents that will fix them, orchestrated and reviewed by the main session, with a user
checkpoint between each fix.

**Read the repository `CLAUDE.md` and M7 of `editor-and-export-fixes.md` first.** This plan assumes
their architecture, ways of working, coding standards, licensing rules and verification gates, and
never repeats them except where a fix needs a specific reminder. Work happens on branch
`15-editor-and-export-fixes`.

## The four defects (Benoit's words, translated)

| # | Symptom | Fix |
| --- | --- | --- |
| 1 | The title-page placeholders are not where the real values land (title/credit/author must be centred) | F1 |
| 2 | The draft date must sit on the contact's **first line** — draft date right, contact left | F4 |
| 3 | Pressing Back on an empty placeholder deletes the placeholder; it must never be deleted | F2 |
| 4 | With a title page, the styled view's sheets no longer line up with the text | F3 |

Ordering rationale: F1 and F2 are small, independent and touch disjoint files. F3 introduces the
shared title-page geometry module that F4 then builds on, so it must land before F4. F4 is the
riskiest piece (it moves a component off its own layout row) and comes last.

### Decisions locked with Benoit (do not revisit without asking)

1. **"The Back button" is the Backspace key** (`⌫`), not the toolbar's back arrow. F2 addresses that
   gesture.
2. **Defect 4 is the body drifting away from the painted sheets**, not the title sheet itself being
   misplaced: the offset is constant and gets more obvious the further you scroll. F3's diagnosis is
   the confirmed one.
3. **The contact wraps at half the content width**, and the draft date owns the other half — the
   PDF's `Row(spaceBetween)` split, applied literally (F4).

### Evidence status

Every root cause below was established by **reading the code** — this app's and super_editor
0.3.0-dev.52's own sources in the devcontainer's pub cache — not by running the app. Line references
to the pinned dev release are given so each one can be re-checked in seconds. **When an
investigation contradicts a diagnosis written here, report it instead of silently redesigning.**

The one thing no agent could do from the host is *watch* the defects happen. Step 1 of every fix is
therefore the same: write the failing test first, confirm it fails against HEAD for the reason
stated here, and only then change behaviour.

### Facts about super_editor 0.3.0-dev.52 that shape every fix

Verified in `~/.pub-cache/hosted/pub.dev/super_editor-0.3.0-dev.52/`:

1. **A component's box is laid out as**
   `ConstrainedBox(maxWidth: Styles.maxWidth) > SizedBox(width: double.infinity) >
   Padding(Styles.padding) > component`
   (`lib/src/default_editor/layout_single_column/_layout.dart:1004-1015`), inside a
   `Column(crossAxisAlignment: CrossAxisAlignment.center)` (`_layout.dart:736-738`). So a component
   whose `Styles.maxWidth` is **narrower than the document's width is horizontally centred**, while
   `Styles.padding` positions the text *inside* an otherwise full-width box. Every horizontal
   placement this plan introduces therefore goes through **padding**, never through a narrowed
   `maxWidth`.
2. **super_editor resolves the caret geometrically, not by widget hit testing.** A tap is turned
   into a `DocumentPosition` by `_findComponentClosestToOffset`/`_isOffsetInComponent`, which build
   each component's rect with `componentBox.localToGlobal(...)` (`_layout.dart:574-635`), and the
   caret is drawn from `getRectForPosition`, built the same way (`_layout.dart:253-266`). The
   `RenderBox` they measure is the one the **component key** is attached to — the inner
   `TextComponent`, not any wrapper a `ComponentBuilder` adds around it. Consequence: a paint-time
   transform *inside* a component moves the caret, the selection and the tap target with it. This is
   what makes F4 possible at all.
3. **`Editor` picks the first request handler that recognises a request**
   (`lib/src/core/editor.dart:301-312`, `_findCommandForRequest`). A handler **prepended** to
   `requestHandlers` therefore overrides the default one for that request type. F2 relies on this.
4. **`DocumentNode.isDeletable`** (`lib/src/core/document.dart:368`, key `NodeMetadata.isDeletable`,
   line 677) is honoured by the multi-node deletion commands
   (`lib/src/default_editor/multi_node_editing.dart:802, 871, 903, 937, 1431, 1454`), but the
   paragraph-merge path only ever skips **`BlockNode`s** (`common_editor_operations.dart:1322`,
   `paragraph.dart:1028, 1079`) — and `ParagraphNode extends TextNode`, which is *not* a `BlockNode`
   (`paragraph.dart:28`, `text.dart:35`, `box_component.dart:19`). So `isDeletable` protects a
   title-page node from being deleted, but **not** from being merged into by Backspace. F2 needs
   both halves.

---

## F1 — Placeholders laid out exactly like the value they stand in for (defect 1)

**Symptom.** On an empty title sheet, "Title", "Credit" and "Author" are drawn at the page's left
margin in body-size text, while the values typed into those same fields render centred (and, for the
title, at 1.6× the body size). The placeholder is not a preview of where the text will go.

**Root cause — two independent bugs, both in the reuse of `TextWithHintComponent`.**
`OcptTitlePagePlaceholderComponentBuilder` (`lib/ui/pages/editor/super_editor/
ocpt_title_page_placeholder_builder.dart`) renders the hint through super_editor's own
`TextWithHintComponent`. In the pinned release
(`lib/src/default_editor/text.dart:785-814`) that widget builds:

```dart
Stack(children: [
  if (widget.text.isEmpty) IgnorePointer(child: Text.rich(hintSpan, maxLines: …, overflow: …)),
  TextComponent(key: …, textAlign: widget.textAlign, …),
]);
```

- The hint `Text.rich` receives **no `textAlign`** — only the real `TextComponent` does. It is also
  a non-positioned `Stack` child under loose constraints, so it sizes to its own intrinsic text
  width and sits at the stack's `topStart`. Passing `componentViewModel.textAlignment` down (as the
  builder already does) can therefore never centre or right-align a hint: it is always drawn flush
  left, at its own width.
- `_TextWithHintComponentState._styleBuilder` (`text.dart:772-782`) computes
  `contentStyle.merge(hintStyleBuilder(...))`. The app's `hintStyleBuilder`
  (`ocpt_styled_screenplay_editor.dart:344-350`) returns an explicit
  `fontFamily`/`fontSize`/`height`, so it **overwrites** the block style the stylesheet resolved for
  the node — including the Title rule's `fontSize * 1.6` and bold
  (`ocpt_fountain_editor_stylesheet.dart:244-248`). The Title placeholder is rendered at body size,
  so it is neither at the right x **nor** the right height, and the empty node is one line shorter
  than the same node with a value in it.

**Fix.** Stop reusing `TextWithHintComponent`; draw the hint alongside the delegate's own component,
the way `OcptSceneNumberGutterComponentBuilder` already draws a scene number
(`ocpt_styled_scene_numbers.dart:151-181`) — that is this directory's established pattern for
"decorate one specific kind of node without taking over its rendering".

- In `createViewModel`, keep delegating to `ParagraphComponentBuilder` and return its plain
  `ParagraphComponentViewModel` (no `HintComponentViewModel`, no `TextWithHintComponent`, and the
  `HintComponentViewModel`/`TextWithHintComponent` imports go away). Claim **every** title-page
  node, not only the empty ones — F4 needs the non-empty ones too — and keep returning `null` for
  every other node so the next builder handles it.
- In `createComponent`, build the delegate's component and, when the node's text is empty and its
  `ocptTitlePageKeyMetadataKey` has a placeholder, wrap it:

  ```dart
  Stack(children: [
    // First child: painted *behind* the real component, so the caret is never hidden by the hint
    // (this is also the order `TextWithHintComponent` itself uses). `Positioned.fill` stretches the
    // hint across the box the delegate's component defines, which is what makes `textAlign` mean
    // anything at all.
    Positioned.fill(child: IgnorePointer(child: Text(placeholder, textAlign: …, style: …))),
    base,
  ]);
  ```

  The `Stack` must stay sized by `base` (its only non-positioned child), so the node keeps the exact
  height it has today.
- Build the hint's style from the view model's own resolved style —
  `componentViewModel.textStyleBuilder(const {})` — and `copyWith` **only** the italic slope and the
  dimmed colour on top of it. Never a fresh `TextStyle`: inheriting is what guarantees the
  placeholder's size and weight match the value that will replace it. `hintStyleBuilder`'s signature
  in `OcptTitlePagePlaceholderComponentBuilder` changes accordingly (it now decorates a style rather
  than replacing it); update its doc comment and the call site in
  `ocpt_styled_screenplay_editor.dart:342-351`, which must stop passing `fontFamily`/`fontSize`/
  `height`.
- Rewrite the class doc comment: it currently explains at length why `HintComponentBuilder` is
  reused and why it is selected by metadata rather than position. The first half becomes false —
  say instead that super_editor's own hint component cannot align a hint (with the `text.dart` line
  reference), which is why the hint is drawn here.

**Tests** (`test/ui/pages/editor/super_editor/`, new
`ocpt_title_page_placeholder_builder_test.dart` or the existing styled-editor widget test file):

- pump the styled editor with page simulation on and **no** title page in the source, then assert,
  for the Title/Credit/Author placeholders, that the hint `Text`'s rendered rect is centred on the
  page's content area (its centre x equals the content area's centre x, within a pixel), and that
  the Draft date's is right-aligned;
- assert the Title placeholder's `Text.style.fontSize` equals the Title rule's own
  (`OcptEditorPreviewLayout.fontSize * 1.6`) and its `fontWeight` is bold — this is the assertion
  that fails today;
- assert that typing into a field makes the hint disappear and leaves exactly one rendered text for
  that node.

**Done when** an empty title sheet reads as a faint, italic preview of the filled sheet: same x,
same size, same weight, only dimmer — and typing a value does not make the text jump.

---

## F2 — A title-page field can never be deleted (defect 3)

**Symptom.** With the caret in an empty placeholder, pressing Back(space) removes the field from the
sheet. It only comes back on a full re-decode (a mode toggle, or reopening the project).

Benoit confirmed the gesture is the **Backspace key** (`⌫`), not the toolbar's back arrow.

**Root cause.** Nothing in this app claims Backspace. On desktop `SuperEditor` runs on
`TextInputSource.ime`, and `defaultImeKeyboardActions`
(`lib/src/default_editor/super_editor.dart:1543-1562`) contains **no** backspace *deletion* action
at all — only the indent/task/blockType shortcuts (the app already excludes
`backspaceToClearParagraphBlockType`). The deletion arrives through the IME delta channel and ends
up in `CommonEditorOperations.deleteUpstream()`
(`lib/src/default_editor/common_editor_operations.dart:1121`). With a collapsed caret at
`TextNodePosition(offset: 0)` and a `TextNode` above, it takes the branch at line 1189-1202 and
calls `mergeTextNodeWithUpstreamTextNode()` (line 1315), which executes a
**`CombineParagraphsRequest`** followed by a `ChangeSelectionRequest`. The default handler happily
combines a title-page field node with whatever precedes it and deletes the second node.

Two consequences, not one:

- a title-page field disappears from the always-complete sheet
  (`OcptWysiwygCodec.decodeWithTitlePage`'s invariant is "all six fields, always"), and on the next
  encode that field is simply absent from the source;
- the **first body line** can be merged *into* the `Source` field the same way (caret at offset 0 of
  the first body node, Backspace), which mixes body text into a title-page node — the same defect,
  one node further down, and worse.

**Fix — guard the model, not the keystroke.** Because the gesture never travels through a keyboard
action, guarding it there would leave the IME path open (this is the same trap `OcptFountainTabInterceptor`
exists for). Guard the requests instead, so every path — IME delta, hardware key, a future toolbar
button, a test — is covered by one rule:

- New `lib/ui/pages/editor/super_editor/ocpt_title_page_guard_requests.dart` (or a section of
  `ocpt_wysiwyg_edit_requests.dart` if it fits its idioms better — pick one and say why in the
  commit body) holding:
  - `ocptTitlePageGuardRequestHandler`, an `EditRequestHandler` that recognises
    `CombineParagraphsRequest` and returns a **no-op `EditCommand`** whenever the two nodes are not
    two nodes of the *same* title-page field, i.e. whenever either one carries
    `ocptTitlePageKeyMetadataKey` and their two values differ (a body node's value being absent).
    Merging two lines of the *same* multi-line field (`Author`, `Contact`) stays allowed: it is the
    exact undo of the Enter gesture `_splitTitlePageField` provides.
  - The no-op command must be a real `EditCommand` whose `execute` does nothing and which returns no
    changes, documented as "the request is deliberately dropped"; do not throw, and do not return
    `null` from the handler (that would fall through to the default handler and delete the node).
- Register it at the **head** of `requestHandlers` in **both** places that build an `Editor`:
  `_rebuildEditorFrom` and `_flushPendingSync`'s throwaway editor
  (`ocpt_styled_screenplay_editor.dart:522-527` and `297-302`). The two lists must stay identical —
  a flush that behaved differently from the live editor is exactly the class of bug the
  `_flushPendingSync` doc comment already warns about.
- Additionally mark every synthesized title-page node **`NodeMetadata.isDeletable: false`** in
  `OcptWysiwygCodec._titlePageNodesFrom` and in `_splitTitlePageField`'s new node
  (`ocpt_fountain_keyboard_actions.dart:264-280`). That is what protects the sheet from the
  *multi-node* deletion paths (select-all + Delete, a selection dragged across the sheet), which go
  through `DeleteSelectionCommand`/`DeleteNodeCommand` and do honour the flag
  (`multi_node_editing.dart:1431, 1454`). Check that `OcptChangeNodeMetadataRequest`'s merge
  semantics keep the flag on a node it updates, and that `encodeWithTitlePage` ignores it (it reads
  only `ocptTitlePageKeyMetadataKey` and the text, so it should — assert it in a codec test).

**Tests.**

- Request-level (deterministic, path-independent, no IME simulation needed), in
  `ocpt_wysiwyg_codec_test.dart`'s neighbourhood or the new file's own test:
  build a live `Editor` over a `decodeWithTitlePage` document with the guard installed, execute a
  `CombineParagraphsRequest` for (a) `Draft date` + `Contact` → nothing changes, (b) `Source` + the
  first body node → nothing changes, (c) two `Contact` lines → they merge normally.
- Widget-level in `ocpt_styled_screenplay_editor_test.dart`: place the caret at offset 0 of an empty
  field and drive the same gesture the app really uses. **Do not assume `tester.sendKeyEvent(
  LogicalKeyboardKey.backspace)` reproduces it** — as shown above, no keyboard action handles
  backspace in IME mode, so a hardware key event may do nothing at all in the test environment.
  Establish first what actually reaches the document (super_editor's own test tooling in
  `lib/src/test/super_editor_test/` offers IME-level helpers), report what you find, and write the
  test against that. If no gesture can be driven from a widget test, say so and rely on the
  request-level tests plus the manual pass, rather than writing a test that proves nothing.
- Assert the document still has its six field nodes, and that the encoded source is unchanged.

**Done when** Backspace in an empty (or non-empty) field never removes it, an extra line added to a
multi-line field can still be removed with Backspace, and the first body line can no longer be
merged into `Source`.

---

## F3 — The sheets line up again with a title page (defect 4)

**Symptom.** With page simulation on and a title sheet present, the body's pages drift away from the
painted white sheets: the first body page starts well below page 2's top margin, and the offset is
carried through every page after it.

Benoit confirmed it is the **body** that slides against the white sheets, by a constant amount that
gets more obvious the further you scroll — not the title sheet being misplaced on page 1.

**Root cause.** `computeOcptStyledPagination` (`ocpt_styled_page_pagination.dart:86-162`) skips
title-page nodes entirely — `continue` at line 111 — and states in its doc comment that they "never
advance this estimate". They do. They are ordinary `ParagraphNode`s in the same single-column
layout, laid out by the same `Column` as the body, and the stylesheet gives each of them a real top
padding and a real line of text (`ocpt_fountain_editor_stylesheet.dart:237-265`). Everything after
them is pushed down by the height they occupy, while the pass computes every page-start padding as
if the flow started at `layout.marginTop` with nothing before it (line 107).

The padding it computes for the first body node is therefore short by exactly the title page's
rendered height, and — because every later page's padding is derived from the same running `currentY`
— **every** body page inherits the same constant offset. `trailingBottomPadding` (line 153-154) is
short by the same amount, so the last sheet also ends before the content does.

Worked example, US Letter (`8.5 × 11 in`, margins `1.5/1/1/1`, 10 chars/in, 6 lines/in, font size 13
⇒ `glyphWidth ≈ 7.8`, `pixelsPerInch ≈ 78`, `lineHeight ≈ 13`, `pageHeight ≈ 858`), with an empty
title page (one node per field):

| Field | Top gap (px) | Text height (px) |
| --- | --- | --- |
| Title | `0.32 × 858 ≈ 274.6` | `1.6 × 13 ≈ 20.8` |
| Credit | `2 × 13 = 26` | 13 |
| Author | 13 | 13 |
| Draft date | `0.22 × 858 ≈ 188.8` | 13 |
| Contact | 13 | 13 |
| Source | 13 | 13 |
| **Total** | | **≈ 614 px** |

614 px is 72 % of a sheet — the body starts three quarters of a page too low. Confirm these numbers
in the reproduction test rather than trusting the table.

**Fix — one module owns the title page's geometry, and the pagination reads it.**

- New `lib/ui/pages/editor/super_editor/ocpt_styled_title_page_layout.dart`, pure Dart over a
  `Document` + `FountainLayoutMetrics` (same contract as `computeOcptStyledPagination`: no live
  `SuperEditor`, unit-testable on its own), exposing:
  - the per-field typesetting the stylesheet currently hardcodes — top gap, text alignment, font
    scale, weight, and the left/right insets F4 will need — as one documented function of the field
    key and an `OcptEditorPreviewLayout` (the fractions `_titlePageTitleTopFraction` and
    `_titlePageBottomGroupTopFraction` move here with their doc comments);
  - `computeOcptStyledTitlePageMetrics(...)` returning at least the **flow height** the title-page
    nodes occupy: `Σ (topGap(field) + wrappedLines(node) × lineHeight × fontScale)` over the
    document's title-page nodes, where the top gap is only counted on a field's **first** node and
    `wrappedLines` uses `OcptEditorPreviewLayout.wrappedLineCount` against that field's own column
    count (mind the Title: its glyphs are `1.6 ×` wider, so it wraps at `contentWidth /
    (glyphWidth × 1.6)` columns, and its line box is `1.6 × lineHeight` tall).
- `ocpt_fountain_editor_stylesheet.dart:237-265` now reads that module instead of its own `switch`,
  so the geometry has exactly one definition. Its doc comment must keep explaining *why* one rule
  covers six fields, and point at the new module for the numbers.
- `computeOcptStyledPagination` initialises `currentY = layout.marginTop + titlePageFlowHeight`
  (still `layout.marginTop` when there is no title page) and keeps everything else as it is. Update
  the doc comments at lines 71-76 and 101-107, which currently assert the opposite.
- Guard the degenerate case: if the title page's flow height ever exceeded a sheet, the first body
  node's padding would clamp to 0 and the body would overlap the title sheet. Assert it fits (or
  clamp and document what happens), and cover it with a test using a deliberately long
  contact/source.

**Tests** in `ocpt_styled_page_pagination_test.dart`'s existing "with a title page" group:

- the regression test that would have caught this: with a title page and a one-line body, the first
  body node's `pageStartTopPaddings` value must equal
  `sheetExtent - titlePageFlowHeight` (i.e. it must be **smaller** than a full `sheetExtent`) — the
  current code returns a full `sheetExtent` and fails;
- a body long enough to span three pages: every page-start padding lands its node at
  `pageIndex × sheetExtent + marginTop` once the title page's height is added back, which is the
  property the sheets painter needs;
- `trailingBottomPadding` puts the document's bottom exactly at the last sheet's bottom edge;
- new unit tests for the geometry module: an empty title page's flow height matches the hand
  computation, a multi-line `Contact` adds exactly one `lineHeight` per extra line, a title long
  enough to wrap adds `1.6 × lineHeight`.

**Done when** a screenplay with a title page shows its first body page starting exactly at the
second sheet's top margin, every later page stays aligned as you scroll, and the last sheet's bottom
margin is reachable.

---

## F4 — Draft date on the contact's first line, right-aligned (defect 2)

**Symptom.** The draft date and the contact are stacked on two separate lines. Benoit wants the PDF's
bottom row: contact on the left, draft date on the right, **on the same first line**.

**Why this is not a stylesheet change.** super_editor's `SingleColumnDocumentLayout` puts one node
per `Column` row, and the two fields are two nodes (they must stay two: they are two Fountain
title-page keys, edited in place). `Styles.padding` cannot be negative (`Padding` asserts a
non-negative `EdgeInsets`), and there is no height style. The current rendering is a faithful
consequence of that constraint, which the stylesheet's own doc comment already documents
(`ocpt_fountain_editor_stylesheet.dart:229-236`).

**What makes it possible anyway.** Fact 2 of the preamble: the caret, the selection and the tap
target are all computed from the **component key's `RenderBox` position via `localToGlobal`**, not
from widget hit testing. A `Transform` applied *inside* a component therefore moves the text **and**
everything the editor knows about where that text is — while the `Column` keeps its own row
untouched.

**Design.**

- The two fields share the row by **shifting the contact (and source) up by the draft date's own
  height**, not by moving the draft date down:
  - `Draft date` keeps its big top gap and stays the flow's row owner; the shift amount is the
    height its own node(s) occupy — normally one `lineHeight`, computed from
    `computeOcptStyledTitlePageMetrics` (F3's module gains a `rowShift` value) so a wrapped or
    Enter-split draft date stays correct;
  - `Contact`'s top gap becomes 0 (the shift replaces it) and `Source` keeps its one-line gap; both
    are rendered inside `Transform.translate(offset: Offset(0, -rowShift))` by the title-page
    component builder.
- The two must not overlap horizontally, or `_findComponentClosestToOffset` (which returns the
  **first** component whose rect contains the tap, in document order — the draft date) would swallow
  every click meant for the contact. Split the row with **padding**, never with `Styles.maxWidth`
  (fact 1 — a narrowed `maxWidth` would centre the box instead):
  - `Draft date`: `padding.left = marginLeft + contentWidth / 2`, `textAlign: right`;
  - `Contact`: `padding.left = marginLeft`, `padding.right = contentWidth / 2`, `textAlign: left`.

  Both keep `Styles.maxWidth = marginLeft + contentWidth`, exactly as today. `Source`, being below
  the row, keeps the full content width. The half-and-half split is Benoit's own call (decision 3):
  the contact wraps at `contentWidth / 2`, exactly like the PDF's `Row(mainAxisAlignment:
  spaceBetween)` leaves it.
- All of this lives in the F3 module (the insets) and in the title-page component builder (the
  transform). Rename `ocpt_title_page_placeholder_builder.dart` →
  `ocpt_title_page_component_builder.dart` and the class accordingly in this fix: after F1 and F4 it
  owns the sheet's whole per-node rendering, not just placeholders. Update the class doc comment to
  state, with the `_layout.dart` line references, why a paint-time transform is safe here.
- `computeOcptStyledTitlePageMetrics`'s **flow** height is unchanged by the transform (the `Column`
  still lays out both rows); F3's pagination keeps using the flow height, and the sheet simply shows
  one line of slack at the bottom of the title page. Say so in a doc comment so nobody "fixes" it by
  subtracting the shift.

**Tests** (`ocpt_styled_screenplay_editor_test.dart`, plus the module's unit tests):

- with a filled title page, the `Draft date` text's rendered rect and the `Contact` text's rendered
  rect have the **same top**, the contact's right edge is at or left of the page's horizontal
  centre, and the draft date's left edge is at or right of it;
- the same holds when both are empty (the two placeholders share the row — this is where F1 and F4
  meet);
- **the risky one, which must not be skipped:** tap on the draft date's text and assert the composer's
  selection lands in the *draft date* node; tap on the contact's and assert it lands in the
  *contact* node. This is the assertion that proves the transform did not break editing;
- a multi-line contact (two nodes) still stacks its lines under the row, and `Source` follows
  immediately after the last contact line with no leftover gap;
- the encoded source is unchanged by any of this (`encodeWithTitlePage` round trip) — the layout must
  stay purely visual.

**If the tap test fails**, stop and report: the fallback is to keep the two fields on their own rows
(today's behaviour) rather than ship a sheet whose fields cannot be clicked. Do not attempt to
"fix" it with a `Positioned` overlay outside the component's box — a `Stack` child painted outside
its parent's bounds is not reachable by `_isOffsetInComponent` either, and the field would stop being
editable in place, which is decision 3 of `editor-and-export-fixes.md`.

---

## Cross-cutting notes

- **Do not touch** `FountainScriptComposer`, `OcptPdfExportService` or `FountainTitlePageWriter`:
  none of these four defects is an export defect, and the PDF is the reference the editor imitates,
  not the other way round.
- The `⋮ ▸ Title page…` dialog and the inline sheet must keep agreeing: both go through
  `FountainTitlePageWriter`, and F1-F4 change nothing about encoding. A codec round-trip test in
  each fix is the cheapest proof of that.
- Every fix keeps the "title-page nodes only exist while page simulation is on" rule
  (`_decode`/`_encode` in `ocpt_styled_screenplay_editor.dart:697-710`). Nothing here may make the
  fluid surface grow a title sheet.
- No new user-visible string is expected. If one appears, it goes through `Tr.of(context)` and into
  **both** `intl_en_GB.arb` and `intl_fr.arb`.

### Observed in passing, **not** part of this batch

While checking fact 1, `Styles.maxWidth` for `dialogue` and `lyrics` resolves to
`indent + width = 2.5in + 3.5in = 6.0in` against a document width of `pageWidth - marginRight =
7.5in` (US Letter defaults), so those two element boxes look like they would be **centred**, landing
their text ~0.75 in right of the raw preview's column. Every other element's box is exactly
`rightEdge` wide, so only these two could be affected. This was **not** verified by rendering
anything and is **not** in scope here — mention it to Benoit as a separate candidate defect rather
than fixing it inside one of these milestones.

## Verification

The `CLAUDE.md` gates, inside the devcontainer, before **every** commit (analyze + test at minimum,
the full list before finishing a fix):

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

1. `flutter pub get`
2. `dart run intl_utils:generate`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `flutter analyze` → 0 issues
5. `flutter test` → all green (plus `packages/fountain_kit` if it ever changes — it should not)
6. `flutter build linux --debug`
7. `reuse lint` → compliant
8. `git grep -l 'allcircuits.com' -- ':!actlibs' ':!CLAUDE.md' ':!docs/plans'` → empty

**Manual end-to-end pass** (after F1+F2, then after F3+F4), in both themes and both languages:
open a project with **no** title page and one **with** a full one; check the placeholders sit where
the values land; type into each field and confirm nothing jumps; press Backspace in an empty field
and at the start of the first body line; scroll to the third body page and confirm the text stays
inside its sheet; click directly on the draft date and on the contact; export the PDF and confirm it
still matches the sheet.

One commit per fix, Conventional Commits, subject ≤ 50 characters, ending with:

```text
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
```
