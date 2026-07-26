<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# M7 follow-up 2 — the title sheet nobody sees, and the text nobody can delete

This document is the correction plan for the two defects Benoit found while **using** commit
`d81a36e` ("fix: problems with page title", which shipped F2 and F4 of
[`styled-title-page-fixes.md`](styled-title-page-fixes.md)). Both defects are invisible to the
existing test suite, and both root causes are established: each one was reproduced from the host
before this plan was written.

**Read the repository `CLAUDE.md`, M7 of [`editor-and-export-fixes.md`](editor-and-export-fixes.md)
and [`styled-title-page-fixes.md`](styled-title-page-fixes.md) first.** This plan assumes their
architecture, ways of working, coding standards, licensing rules and verification gates, and never
repeats them. Work happens on branch `15-editor-and-export-fixes`.

## The two defects (Benoit's words, translated)

| #   | Symptom                                                                                     | Fix |
| --- | ------------------------------------------------------------------------------------------- | --- |
| 1   | In `d81a36e`, the title-page placeholders are not visible at all                             | F5  |
| 2   | Typing a value into a field, then pressing Backspace, does not delete the text — it stays    | F6  |

F5 and F6 are independent and touch disjoint files. F5 first: it is what makes the sheet visible
again, and F6's manual pass needs a visible sheet to check anything on.

### Evidence status

Unlike the previous batch, **both root causes were reproduced from the host**, inside the
devcontainer, before this plan was written:

1. **F5** — the styled editor was rendered to a PNG through a throwaway widget test (real Courier
   Prime loaded through a `FontLoader` inside `tester.runAsync`, page simulation on, no title page
   in the source, `RepaintBoundary.toImage()`), once with `areSceneNumbersVisible: false` and once
   with `true`. With scene numbers **off**, all six placeholders paint (Title bold-italic at
   `1.6 ×`, Credit/Author centred, Contact left and Draft date right **on the same row**, Source
   under Contact, body opening at the second sheet's top margin: F1, F3 and F4 all visibly correct).
   With scene numbers **on** — the app's own state — `find.text("Title")` and
   `find.text("Draft date")` both find **nothing** and the title sheet renders completely blank,
   exactly as Benoit sees it.
2. **F6** — traced through super_editor `0.3.0-dev.52`'s own sources in the devcontainer's pub
   cache; every line reference below can be re-checked in seconds. The reproduction test is
   step 1 of the fix.

**When an investigation contradicts a diagnosis written here, report it instead of silently
redesigning.**

---

## F5 — The title-page component builder never gets to render (defect 1)

**Symptom.** With page simulation on and scene numbers on (the default), the title sheet is blank:
no placeholder hints at all. The fields themselves work — a typed value shows up, at the right x, in
the right size — and Contact/Draft date are back on two separate rows.

**Root cause.** `SingleColumnDocumentLayout` resolves a component by walking
`SuperEditor.componentBuilders` in order and keeping the **first non-null**
`createComponent` result (`layout_single_column/_layout.dart:1001-1006` of the pinned release).
`OcptSceneNumberGutterComponentBuilder.createComponent`
(`ocpt_styled_scene_numbers.dart:151-181`) discriminates in `createViewModel` only: its
`createComponent` accepts **every** `ParagraphComponentViewModel`, and returns the delegate's plain
`base` component whenever the node has no scene number (line 164-167) instead of returning `null`.
Its own class doc comment already claims the opposite ("only intercepts scene-heading nodes").

`OcptStyledScreenplayEditor.build` puts that builder **before**
`OcptTitlePageComponentBuilder` (`ocpt_styled_screenplay_editor.dart:328-351`), so as soon as
`areSceneNumbersVisible` is true, every title-page node's component is built by the scene-number
builder's delegate, and `OcptTitlePageComponentBuilder.createComponent` is **never called**: no
placeholder hint (F1) and no `Transform.translate` row shift (F4). Only the parts of F1/F3/F4 that
live in the **view model** and the **stylesheet** survive — which is exactly the pattern of what
Benoit sees.

`OcptTitlePageComponentBuilder.createComponent` has the same over-claiming bug in the other
direction (it accepts every `ParagraphComponentViewModel`, body nodes included, and only *happens*
to render them identically to the default builder): with the builder order reversed, it would
swallow every scene heading's gutter number. Both builders must be fixed, not just the first one.

**Fix — every builder claims only the nodes it owns, in `createComponent` as well as in
`createViewModel`.**

- `OcptSceneNumberGutterComponentBuilder.createComponent`: return **`null`** instead of `base` when
  `sceneNumbers[componentViewModel.nodeId]` is null, so a non-heading node falls through to the next
  builder. Update the doc comment to say that the claim is made in *both* methods and why (with the
  `_layout.dart:1001-1006` reference).
- `OcptTitlePageComponentBuilder.createComponent`: claim a node only when it really is a title-page
  field node. `ParagraphComponentViewModel` carries the node's own `blockType` attribution
  (`paragraph.dart:154, 230`), so the check is stateless and cannot go stale:
  `componentViewModel.blockType == ocptTitlePageFieldAttribution` — anything else returns `null`.
- While in there, make the two per-node lookups the builder needs share one source of truth: have
  `createViewModel` record each claimed node's **field key** (and whether it is that field's
  *first* node) in a `Map<String, …>` keyed by node id, next to the existing `_rowShiftByNodeId`, and
  have `createComponent` read the placeholder label from that key. `placeholders` then becomes the
  plain `Map<String, String>` keyed by [ocptTitlePageFieldKeys] that
  `_titlePagePlaceholders(context)` already builds, and
  `_titlePagePlaceholdersByNodeId(context)` disappears from `ocpt_styled_screenplay_editor.dart`.
  Two side effects worth having, both deliberate:
  - a field's Enter-split second line no longer shows a duplicate hint (only the field's first node
    is hinted);
  - a node created after the last widget rebuild is hinted correctly instead of not at all.
- Do **not** reorder `componentBuilders`: the order is fine once each builder is honest, and the
  scene-number builder must keep coming first so a scene heading still gets its gutter.

**Tests** (`test/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor_test.dart`).

The blind spot that let this ship is that **every** title-page widget test pumps with
`areSceneNumbersVisible: false`, while the app runs with it on. Close it:

- parameterize the whole "title page" group over `areSceneNumbersVisible: [false, true]` (a `for`
  loop around the group, the test names carrying the flag), so the placeholder-alignment, Title
  font-size/weight, shared-row and **tap-routing** assertions all run in the app's own
  configuration. The `true` variants fail against HEAD — confirm that before changing behaviour;
- one test asserting the other direction still holds: with a title page **and** scene numbers on, a
  scene heading still renders its gutter number (`find.text("1")` next to the heading), i.e. the
  scene-number builder still claims its own nodes;
- one test asserting a multi-line field hints only its first line (two `Contact` nodes, exactly one
  `Contact` hint).

**Done when** the sheet Benoit sees with his own settings is the sheet the previous batch's PNG
shows: faint italic placeholders where the values will land, Contact and Draft date sharing the
bottom row, scene numbers still in the body's gutter.

---

## F6 — Backspace and Delete work again inside a title-page field (defect 2)

**Symptom.** Type "My Movie" into the Title field, put the caret after it, press Backspace: nothing
happens. The text can never be shortened, only added to. Same with the Delete key, and same when a
selection inside a field is deleted or typed over.

**Root cause — `NodeMetadata.isDeletable: false` does not only protect the node, it also forbids
editing its text.** In the pinned release, both deletion commands abort *any* deletion contained
within a single non-deletable node:

- `DeleteSelectionCommand.execute`: "The selection is contained within a single node. Prevent the
  deletion if the node is non-deletable." → `return` (`multi_node_editing.dart:1428-1449`);
- `DeleteContentCommand.execute`: same guard, same early `return`
  (`multi_node_editing.dart:798-822`).

Every Backspace path in this app ends in one of those two:

- the app's real desktop gesture (IME delta channel): `TextDeltaDocumentEditor` sends
  `ChangeSelectionRequest` + `DeleteSelectionRequest(TextAffinity.upstream)`
  (`document_ime/document_delta_editing.dart:615-620`) → `DeleteSelectionCommand` → blocked;
- a mid-text hardware Backspace: `CommonEditorOperations.deleteUpstream()` →
  `DeleteUpstreamCharacterRequest` (`common_editor_operations.dart:1211`) →
  `DeleteUpstreamCharacterCommand` → `DeleteContentCommand`
  (`common_editor_operations.dart:2884-2892`) → blocked.

So F2's "additionally mark every synthesized title-page node `isDeletable: false`" is the defect:
`styled-title-page-fixes.md`'s fact 4 read the multi-node deletion commands only, and missed that
the same flag also gates *intra-node content* deletion. Blast radius: Backspace, Delete, deleting an
expanded selection inside a field, typing over such a selection, and cutting from a field — all
silently do nothing.

**Fix — drop the flag, and move the protection it was there for into the request guard.**
`ocptTitlePageGuardRequestHandler` is already the one place every path goes through
(`ocpt_title_page_guard_requests.dart`), and it can distinguish "delete text inside a field" from
"delete the field", which `isDeletable` cannot.

1. **Remove `NodeMetadata.isDeletable: false`** from `OcptWysiwygCodec._titlePageNodesFrom`
   (`ocpt_wysiwyg_codec.dart:601`) and from `_splitTitlePageField`'s new node
   (`ocpt_fountain_keyboard_actions.dart:281`), and from the codec's own doc comment
   (`ocpt_wysiwyg_codec.dart:581-586`). Update the two codec tests that assert the flag
   (`ocpt_wysiwyg_codec_test.dart:872, 890`); keep the "`encodeWithTitlePage` ignores it" test's
   *intent* by asserting instead that the encoded source is unaffected by node metadata.
2. **Extend `ocptTitlePageGuardRequestHandler`** — same file, same "recognise and drop" shape, one
   documented rule per request type:
   - `CombineParagraphsRequest`: unchanged (blocks cross-field and field↔body merges, allows two
     lines of the same field to merge).
   - `DeleteUpstreamAtBeginningOfNodeRequest`: **new, and mandatory.** This is the request the IME
     path actually sends when Backspace is pressed at offset 0
     (`document_delta_editing.dart:600-608`), and its command
     (`DeleteUpstreamAtBeginningOfParagraphCommand`, `paragraph.dart:1002-1063`) calls
     `mergeTextNodeWithUpstreamTextNode`, which executes `CombineParagraphsCommand` **directly on
     the executor** (`paragraph.dart:1093-1099`) — never as a request, so the guard above never sees
     it. Drop the request when `request.node` is a title-page node, or when the node immediately
     above it is one whose field key differs (the "first body line merged into `Source`" case).
     Two lines of the same field must still merge, so let it through in that case.
   - `DeleteSelectionRequest` / `DeleteContentRequest`: **allow** whenever the range is contained in
     a single node (this is the fix — deleting text inside a field is ordinary editing). When the
     range spans several nodes and at least one is a title-page node, replace it with a request for
     the **body-only** sub-range (start clamped to the first non-title-page node's start), so
     select-all + Delete still clears the screenplay and leaves the six fields standing; drop it
     entirely when there is no body part left in the range.
   - `DeleteNodeRequest`: drop it when it targets a title-page node (cheap, closes the programmatic
     path `isDeletable` used to cover).
3. Keep the handler pure and document each rule with the line reference that justifies it, the way
   the current one does. `OcptNoOpCommand` stays as-is for the dropped cases.

**Tests.**

- **Reproduction first** (`ocpt_styled_screenplay_editor_test.dart`, "title page" group): place the
  caret in a filled field, press Backspace, assert the character is gone and the encoded source
  shrank. A plain `tester.sendKeyEvent(LogicalKeyboardKey.backspace)` reproduces it (the hardware
  path is blocked by the same `DeleteContentCommand` guard) — confirm it fails against HEAD.
- **Add the IME path too**, at least for the offset-0 case, because it is genuinely a different
  code path from `sendKeyEvent` (see the `DeleteUpstreamAtBeginningOfNodeRequest` note above, and
  note that the existing "Backspace at the start of …" tests only ever exercised the hardware one):
  `flutter_test_robots` 0.0.24 (already a transitive dependency, used by
  `tester.typeImeText`) ships `tester.ime.backspace(getter: () => imeClientGetter(…))`. Establish
  what it actually delivers before asserting on it, and report what you find.
- Regression tests for what the flag used to protect, now via the guard: select-all + Delete leaves
  the six field nodes and clears the body; Backspace at offset 0 of an empty *and* of a filled field
  still never removes it; the first body line still cannot merge into `Source`; two lines of the
  same field still merge.
- A codec round trip after each of those, asserting the source is exactly what it should be.

**Done when** a title-page field edits like any other line — type, Backspace, select, replace, cut —
while the sheet still always has its six fields, and the body can still be cleared in one
select-all + Delete.

---

## Cross-cutting notes

- **Do not touch** `FountainScriptComposer`, `OcptPdfExportService` or `FountainTitlePageWriter`:
  neither defect is an export defect.
- No new user-visible string is expected. If one appears, it goes through `Tr.of(context)` and into
  **both** `intl_en_GB.arb` and `intl_fr.arb`.
- One commit per fix, Conventional Commits, subject ≤ 50 characters, ending with the
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` trailer. Do not bundle F5 and F6.

### Observed in passing, **not** part of this batch

1. **Backspace at the start of *any* line resets its block type on desktop.**
   `DeleteUpstreamAtBeginningOfParagraphCommand` starts with "if this node's `blockType` is not
   `paragraphAttribution`, change it to `paragraphAttribution` and return"
   (`paragraph.dart:1019-1026`). Every node in this app carries a Fountain `blockType`, never
   `paragraphAttribution`, so on the IME path that command mangles the block type instead of merging
   anything — which is also why the app deliberately excludes `backspaceToClearParagraphBlockType`
   from its keyboard actions, and why F2's `CombineParagraphsRequest` guard is probably never
   reached on desktop at all. Worth its own investigation (and probably its own guard) with Benoit.
2. **The row shift's lifetime is coupled to an incidental super_editor behaviour.**
   `OcptTitlePageComponentBuilder` fills `_rowShiftByNodeId` in `createViewModel` and reads it in
   `createComponent`. Those two run on the same builder instance only because
   `SuperEditor.didUpdateWidget` recreates its layout presenter whenever `widget.stylesheet` is a
   new instance (`super_editor.dart:648-651`, and `Stylesheet` has no `operator ==`), which
   `OcptStyledScreenplayEditor.build` happens to do on every build. If that ever stops being true,
   the shift silently disappears (F4 without F5's symptom to make it obvious). Worth a comment at
   minimum, or moving the value into the view model.
3. **Placeholder contrast.** The hints paint at `Colors.black.withValues(alpha: 0.4)` ≈ `#999` on
   the white sheet. That is what the plan asked for ("a faint, italic preview"), but if Benoit finds
   them too faint once F5 makes them appear, raising the alpha to ~0.55 is a one-line change.
4. **`d81a36e` committed unrelated files** — `.claude/worktrees/m3-clipboard/**` (1790 files),
   `packages/fountain_kit/build/**` (8 build artifacts) and `test.fountain`. `reuse lint` (gate 7) is
   now non-compliant and gate 8's `git grep` returns 1039 files instead of none. A separate cleanup
   commit (`git rm -r --cached`, plus `.claude/` and `packages/*/build/` in `.gitignore`) should land
   before or alongside this batch.

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
5. `flutter test` → all green
6. `flutter build linux --debug`
7. `reuse lint` → compliant (see note 4 above: fails on HEAD for unrelated reasons)
8. `git grep -l 'allcircuits.com' -- ':!actlibs' ':!CLAUDE.md' ':!docs/plans'` → empty (idem)

**Manual end-to-end pass** (after F5, then after F6), in both themes and both languages, **with
scene numbers on and off**: open a project with no title page and one with a full one; check the
placeholders are where the values land; type into each field, then Backspace over what you typed,
then select part of it and replace it; press Backspace at the very start of a field and at the start
of the first body line; select all and press Delete; click directly on the draft date and on the
contact; export the PDF and confirm it still matches the sheet.
