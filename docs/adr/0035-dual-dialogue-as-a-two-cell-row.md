<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0035 - Dual dialogue as a two-cell row

## Status

Accepted

## Context

Fountain marks a dual dialogue by ending the second cue with `^`. The parser read the marker and
the serializer wrote it back, but nothing printed two speeches side by side: every surface set the
second one under the first. The screenplay has four places that lay it out, and each had to be
decided, as they share one rule for what a pair is and nothing else:

- the printed page (the composer, the PDF, the coverage, the sides), whose model is a list of rows,
  one per printed line, each holding one run of text and the source range it came from (ADR 0012);
- the word views of the breakdown and the shot list, which read the same screenplay as clickable
  words;
- the raw mode's paper preview;
- the styled editor, one super_editor `ParagraphNode` per source line (ADR 0003).

A pair printed side by side breaks two assumptions of ADR 0012: that the order of the rows is the
order of the source, and that one row is one source range. In a row, the left cell is line *k* of
the first speech and the right cell is line *k* of the second.

The styled editor is the hard case. A prototype set the right speech beside the left one while
keeping ordinary nodes, by painting each right-hand node shifted up into the row of the left one.
Clicks, arrows, typing, Enter and the simulated pagination all worked, but dragging a selection
did not: in the left column, **310 of 460 drags selected nothing** (67%, depending on where the
pair sat in the document), and only 13 of 96 left-to-right drags reached the right column. The cause
lies in super_editor `0.3.0-dev.52`: `SingleColumnDocumentLayout` is a `Column` that `SuperEditor`
instantiates itself, and `getDocumentSelectionInRegion` starts from a binary search over the
components, `_findComponentIndexAtOffset`, which assumes they are ordered from the top of the page
to its bottom, then stops at the first component outside the region. Both are private, and the
layout cannot be replaced.

## Decision

- **One pairing rule**, in `fountain_kit` (`fountainDualDialoguePairs` over blocks,
  `fountainDualDialogueLinePairs` over classified lines): two dialogue groups strictly adjacent, the
  second one carrying `^` and the first not already the second of another pair. Everything that
  needs to know what a pair is calls it.
- **The printed row has two cells.** `FountainScriptPage.lines` stays one entry per printed row;
  `FountainScriptLine` gains a `dualSide` and, on its left cell, a `dualCompanion`. The source range
  of a cell is its own, never the union of the two. Reading order is no longer the source order of
  the rows: the coverage and the sides resolve a range per cell, and the left cells of a run
  precede the right ones in the source order they are read in.
- **A pair is never split across pages**: it moves whole to the next page when it does not fit, and
  is composed stacked, with the usual `(MORE)` and `(CONT'D)`, only when it is taller than a page
  or when the page has no room for two columns.
- **The styled editor stacks a pair** and says it is one with a bracket in the left margin, a
  decorator component builder in the manner of the scene-number gutter. The `^` leaves the cue's
  text for node metadata, so a cue reads as a name; the interface offers a toggle, as a menu entry
  and as a shortcut, that writes it. An orphan `^` is shown dimmed after its cue.

## Consequences

- The paper preview, the PDF and the word views show what is printed; the styled editor does not,
  and the page the simulation counts for a pair differs from the printed one. This is accepted and
  documented in `docs/architecture/screenplay.md`.
- Anything reading `FountainScriptLine.runs` alone ignores the right column without any error: each
  consumer of the layout has a test with a pair for that reason.
- A pair can leave blank rows at the foot of a page, and move the page count.
- Going side by side in the styled editor is possible again if super_editor makes its drag
  selection tolerate components not ordered from top to bottom, or lets an app supply the layout.
  The bracket, the metadata and the toggle would stay.
- The styled editor's cue text no longer holds the `^`, so styled search cannot find it.

## Alternatives considered

- **A composite node for the pair** in the styled editor: it would need insertion, deletion, the
  IME, the stylers and the clipboard rewritten over a node that is no text node, and ADR 0003's one
  node per source line would no longer hold.
- **A read-only overlay of the pair on the editor**, editing staying stacked: the rendering would
  change with the caret, or the painted text would not be the edited one.
- **Right-hand nodes painted shifted up** (the prototype above): it works but for the selection, and
  the part that fails is private to a pre-1.0 dependency, so each upgrade of it would have to
  revalidate the whole.
- **A new row type holding one or two cells** instead of a row with a companion: the compiler would
  flag every consumer, but the invariant that a row is a printed line would change everywhere for
  a rare case.
