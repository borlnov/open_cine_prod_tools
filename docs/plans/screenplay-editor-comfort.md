<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Screenplay editor — the silent cast, page numbers, search and the context menu

This document is the implementation strategy for [issue 65](https://github.com/borlnov/open_cine_prod_tools/issues/65).
It is written for the Sonnet 5 agents that will build it, orchestrated and reviewed by the main
session, with a user checkpoint between each milestone. **Read the repository `CLAUDE.md` first**,
then [`docs/architecture/screenplay.md`](../architecture/screenplay.md) and, for M1,
[`docs/architecture/resources.md`](../architecture/resources.md) — this plan assumes their
architecture, ways of working, coding standards, licensing rules and verification gates, and does
not repeat them.

---

## 1. Why this step exists

The screenplay mode is complete enough to write a real screenplay in, and that is exactly how
these four gaps were found: by writing one. None of them is a missing feature of the format —
they are the things one reaches for on the second day.

Milestones are independent and land in order. M1 is the only one that touches data, M4 the only
one that introduces a new piece of UI.

Two things are deliberately **not** here:

- **Spell-checking** is [issue 66](https://github.com/borlnov/open_cine_prod_tools/issues/66). It
  needs bundled dictionaries and a checker written from scratch (super_editor `0.3.0-dev.52`
  exports `SpellingAndGrammarStyler` and no detector at all; Linux and Windows expose no platform
  spell-check service to Flutter), which is more work than the four milestones below put together.
  It builds on M3's context menu, which is why it waits rather than merges in.
- **More air between blocks.** The styled editor already indents every element at the raw
  preview's own columns and spaces two blocks by exactly one blank line, both derived from
  `OcptEditorPreviewLayout` — verified on screen, and locked by
  `ocpt_styled_screenplay_editor_test.dart`. Loosening it would make the simulated page breaks, and
  the page count in the status bar, stop matching the PDF. Decided against.

---

## 2. M1 — The cast sees the characters who never speak

### 2.1 The gap

Writing a character's name in capitals the first time they appear in the action is the convention
that names a character who never speaks. `fountain_kit` reads it already
(`charactersIntroducedInActionOf` / `screenplayCharactersOf`,
`packages/fountain_kit/lib/src/layout/fountain_screenplay_characters.dart`), and the shot list
already offers those names when a shot's characters are picked
(`_screenplayCharactersOf`, `shot_list_bloc.dart`).

`OcptRoleIndexService.reconcile`
(`lib/managers/projects/services/ocpt_role_index_service.dart`) does not: it reads
`speakingCharactersOf` alone, so a character is absent from the `roles` table until their first
line of dialogue, however long their name has been standing in capitals in the action. The shot
list and the cast therefore disagree about who is in the screenplay, which is the one thing that
service's own doc comment says must never happen.

### 2.2 The rules

`reconcile` reads `screenplayCharactersOf(document.blocks)` and additionally needs to know **which
of those names came from a cue**, so it keeps `speakingCharactersOf` as a second call rather than
inferring it. **No schema change**: the origin of a role is already expressible with the two
columns the table has.

| `isFromScreenplay` | `kind` | Means |
| --- | --- | --- |
| true | `speaking` | Cued in the dialogue of at least one episode |
| true | `silent` | **New** — introduced in capitals in an action line, never cued |
| false | any | Added by hand, or kept through `keepOrphanedRoleAsSilent` |

That the second row is unambiguous is what makes the schema change unnecessary:
`keepOrphanedRoleAsSilent` always clears `isFromScreenplay` when it turns a role silent, so no
other path in the app can produce a role wearing both.

The three rules `reconcile`'s doc comment already lists keep their meaning, matched by exact name
across every live, from-screenplay role of the project, and gain:

1. **Creation.** A name found only in the action creates a `silent`, `isFromScreenplay` role,
   appended after every live role of the project, plus its `role_episodes` link. A name found in a
   cue creates a `speaking` one, exactly as today.
2. **Promotion.** A live `silent`, `isFromScreenplay` role whose name appears in this episode's
   cues becomes `speaking`. Writing a mute character's first line must not split them in two — it
   is the very scenario this milestone exists for, taken one step further. There is **no
   demotion**: a role that has spoken stays `speaking` even if the line is later cut, because a
   `speaking` role may have been cast in the meantime and the orphan path (rule 2 below) is what
   already handles a character leaving the script.
3. **Rejection is final.** `reconcile` refuses to create a role for a name that matches a
   **tombstoned** `silent`, `isFromScreenplay` role. Reading a name out of an action line is a
   convention, not a syntax, so an acronym or a shouted word (`OK`, `STOP`, `INTERPOL`) will
   occasionally be read as a character, and deleting it has to be the last word on it. This is a
   new query — the existing one filters `isDeleted.not()` — and it is deliberately scoped to
   action-detected roles: a deleted `speaking` role still comes back, because its cue is still in
   the script and the script is the source of truth.

Rule 2 of the existing doc comment (a role this episode no longer names loses its link, and is
orphaned when it has no live link left) is unchanged and applies to both kinds.

### 2.3 The work

- `ocpt_role_index_service.dart`: `reconcile` as above. Its doc comment is the specification of
  this service and has to be rewritten, not appended to.
- The resources mode tells the two origins apart: a role detected in the action reads as such, and
  is not silently mistaken for a hand-added `silent` role, whose name and episodes are editable
  where this one's are owned by `reconcile`.
- `docs/architecture/resources.md` records the new rule and the table above.
- Tests: creation from an action-only name, promotion on the first cue, no demotion, rejection
  surviving a save, a name in both an action line and a cue counting once, and the existing
  speaking-character behaviour unchanged.

---

## 3. M2 — Page numbers in the styled mode

Page simulation paints the sheets (`OcptStyledPageSheetsPainter`,
`ocpt_styled_screenplay_editor.dart`) but numbers none of them.

The rule is **already written**, in `OcptScriptPagePainter`
(`lib/managers/export/services/ocpt_script_page_painter.dart`): the number is printed as `N.` at
the top right, `_pageNumberTopInches` (0.5") from the sheet's top edge, page 1 is never numbered,
and the title page is not counted. The styled mode prints that rule and no other — a number on
screen that disagreed with the number on paper would be worse than no number at all.

`computeOcptStyledPagination` already reserves the whole of page 1 for the title page when there is
one, and already knows each sheet's index, so nothing about pagination changes: this is a painter
change plus the theme colour question (the sheets are always white, so the number is painted in the
same fixed paper colours the stylesheet uses under page simulation, never a theme-derived one).

Only visible while page simulation is on — there are no sheets to number otherwise.

---

## 4. M3 — Default parentheses, and a context menu

Two small, independent changes in the same area.

### 4.1 The parenthetical block opens on `()`

Switching a block to `FountainLineType.parenthetical` inserts `()` and places the caret between
them — **only while the block's text is empty**. The guard is not a nicety: Tab cycles through the
six common types (`ocptTabCycleTypes`, `ocpt_fountain_keyboard_actions.dart`), so without it every
pass through the type would inject another pair into a block already holding text.

The three gestures that reach the type must all behave the same: the toolbar dropdown
(`OcptEditorBlockTypeDropdown` through `OcptStyledEditorController`), Tab/Shift+Tab
(`ocptCycleBlockTypeAtSelection` — and therefore the IME path `OcptFountainTabInterceptor` shares
with it), and Enter after a character cue (`ocptEnterToSmartSplit`, whose successor for
`character` is the parenthetical's own predecessor case). One helper, called by all of them.

Encoding is unaffected: `()` is what a parenthetical's source text looks like, so
`OcptWysiwygCodec` needs no change and the round trip is already covered.

### 4.2 A context menu in the styled editor

Right-clicking in the styled editor does nothing today. The raw mode is a plain `TextField`
(`OcptEditorSourceField`) and gets Flutter's native menu for free; only the styled mode needs one.

Entries: cut, copy, paste, select all, and the block type as a submenu. Cut/copy/paste **reuse
`ocpt_fountain_clipboard_actions.dart` as it stands** — the file already factors the Fountain-aware
clipboard behind the key handlers, and the private copy helper is promoted rather than duplicated,
so the clipboard payload keeps being plain Fountain source whichever gesture asks for it. The block
type submenu goes through the same helper the dropdown uses.

Mind the known pitfall: a `MenuItemButton` may not go inside a `Wrap`. This menu is a plain single
column, so it is not affected, but a submenu laying its entries out in a grid would be.

An entry that would write is **withheld, not disabled** under a read-only preview, per the
repository rule.

---

## 5. M4 — Find and replace

### 5.1 Scope

Find **and** replace, over the episode the workspace has selected, in both editing modes. Replace
is in scope because the search that actually matters is the one that follows a character being
renamed. Searching across every episode of the project is **not** in scope: it would mean loading
and rewriting screenplays that are not mounted, which is a different feature.

- `Ctrl+F` opens the bar on find, `Ctrl+H` on replace, `Escape` closes it. Both are added to the
  page-level `Shortcuts` in `editor_page.dart`, which already owns `Ctrl+S` and `Ctrl+Shift+M`;
  neither is claimed by `ocptFountainKeyboardActions`, so nothing has to be excluded from it.
- Matches are highlighted, the current one distinctly; previous/next walk them; a counter reads
  `n / total`. Case-sensitivity and whole-word are toggles.
- Replace, and replace-all. **Replace-all goes through `OcptConfirmDialog`**, opened by the page:
  it is irreversible while [issue 58](https://github.com/borlnov/open_cine_prod_tools/issues/58) is
  open, and the repository rule admits no inline confirmation.
- Withheld entirely under a read-only preview for the replace half; find stays.

### 5.2 The two modes

The raw mode is a `TextEditingController` over the Fountain source, so matching is a plain offset
search and the highlight is a `TextSpan` decoration.

The styled mode is a super_editor document whose nodes each hold one source line. Matching runs per
node over its text, and the highlight is applied the way super_editor styles a range — the same
mechanism `SpellingAndGrammarStyler` uses, which is the reason issue 66 will find this milestone
already did half of its work. Navigating to a match scrolls to its node and places the selection on
it. A replacement is an ordinary edit request, so the existing reclassify/autosave debounces carry
it without any special case.

The search state itself belongs to the editor bloc — one search, one screenplay, surviving a mode
toggle.

### 5.3 The design is settled first

The bar is a new piece of UI, so **its layout and style are agreed with Benoit before it is
written**, per the repository rule. The proposal to put in front of him: a single compact row
docked at the top of the editing zone, under the toolbar, spanning the centre column only (not the
docks), find and replace fields stacked when replace is open, matching the studio component themes
with no radius or padding of its own.

---

## 6. Verification

Every milestone runs the eight code gates before its commit, and
`dart run tool/check_markdown.dart` whenever it touches a `.md` file. M1 additionally needs
`dart run build_runner build` to have been run, even though it introduces no schema change, since
it reads generated companions.

Screenshots for a checkpoint come from `tool/screenshot-app.sh`, never from launching the app by
hand.

---

## 7. When this is done

Delete this file. `docs/architecture/screenplay.md` records M2, M3 and M4;
`docs/architecture/resources.md` records M1. The code, those two files and the ADRs are the record
from then on.
