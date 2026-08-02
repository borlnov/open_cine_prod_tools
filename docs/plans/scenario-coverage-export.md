<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Scenario coverage export (issue #42)

This document is the implementation strategy for the scenario coverage PDF export of the shot list
mode. It is written for the Sonnet 5 agents that will build it, orchestrated and reviewed by the
main session, with a user checkpoint between each milestone. **Read the repository `CLAUDE.md`
first** — this plan assumes its architecture, ways of working, coding standards, licensing rules
and verification gates, and does not repeat them.

---

## 1. Why this step exists

The shot list already records, per shot, which passages of the screenplay that shot covers:
`shot_coverages` holds scene-relative character ranges, `OcptShotCoverageLayout` turns a scene's
text into the blocks and words the coverage dialog clicks on, and `OcptShotCoverageService`
re-checks a range's freshness on every save. All of that is *authoring*. Nothing yet prints it
back as a document a director can read on set or a first assistant director can annotate.

The one question this export answers is: **is every line of the screenplay covered by at least one
shot, and where is it not?** A shot list read as a table cannot answer it — the gaps are exactly
what a table has no row for.

The reference is a document Benoit built by hand on a previous production,
`debug/covers/20220327-Scénario-couverture.pdf` (*Le cadeau*, 8 pages, exported from Celtx and
annotated afterwards). This export reproduces it and extends it.

## 2. What the reference document does

Worth stating precisely, because most of the rendering work is reproducing it.

- The screenplay is printed in the ordinary professional layout: Courier, scene numbers in both
  margins, a title page. That is what `OcptPdfExportService` already produces.
- Alongside every passage a shot covers, a **coloured vertical bar** is drawn in the margin,
  starting on the first printed line of the passage and ending on its last.
- Bars stack into **lanes** when they overlap vertically: the innermost lane sits next to the text,
  each further bar moves one lane outward, and when the left margin is full the next bar goes into
  the **right** margin (`GP3/4`, `GP4/2`, `GP5/2` on pages 2 and 3 of the reference).
- Each bar carries a **label** at its vertical middle, in its own colour: `PM1/1`, `PL3/1`,
  `GP3/3`, `PS5/5`. The label is the shot-size abbreviation followed by the shot's code.
- Where a passage starts or ends **mid-line**, a short vertical **tick** is drawn inside the text
  at that exact character (`…sérieux.▌A sa gauche…`).
- One bar per coverage **range**, not per shot: a shot covering two disjoint passages draws two
  bars, same colour, same label (`GP5/3` appears twice on page 3).
- A bar spanning a page break is drawn on both pages, label repeated (`PT5/1` at the top of
  page 3).
- Bars run continuously across the blank lines separating two paragraphs of the same passage.

## 3. What this export adds

Decided with Benoit before this plan was written:

- **Explicitly marked uncovered passages.** The reference only shows a gap in the negative, by the
  absence of a bar. Here the passages no shot covers are marked in their own right (§7.3).
- **A shot legend page**: every shot, its colour swatch, its label, its shot size, framing and
  camera move — so the bars are readable without the shot list at hand.
- **A coverage summary page**: per sequence, the covered share, the shot count and the passages
  left uncovered.
- **A short abbreviation field on a shot** (§6), which the bar labels use. Without it the app has
  no `PM`/`GP` to print: `OcptShot.code` is only `1/1`, and `shotSize` is deliberately free text.

Explicitly **out of scope**: any filtering. The export always covers the whole shot list — no
shooting-day filter, no status filter. Its options are the page setup, the title page and the
scene numbers, exactly as the screenplay PDF export's are, plus a toggle for each of the two extra
pages.

## 4. The hard part: from a stored offset to a printed position

Everything else in this plan is ordinary work. This is the one piece with no existing answer.

A coverage range is a pair of character offsets **into the raw Fountain source**, relative to its
scene's `charStart`. The PDF is a list of pages of `FountainScriptLine`s produced by
`FountainScriptComposer`, and a `FountainScriptLine` today carries **no source provenance at all**:
the composer parses inline runs (dropping `**`/`_` markers), upper-cases what the print style says
to upper-case, and greedily wraps the result into columns. Nothing survives that says which source
characters a printed line came from.

So the bars cannot be drawn until the paginator can answer: *given source offsets `[s, e)`, which
`(page, row, column)` does the passage start at, and which does it end at?*

### 4.1 The change in `fountain_kit`

Threaded through in three steps, each one a small, testable addition:

1. **`FountainInlineParser.parseRuns`** gains the same optional `line` / `startOffset` parameters
   `parse` already has, and each `FountainStyledRun` gains a nullable `sourceRange`. The parser
   already computes exactly this on every `FountainInlineSpan`; `_toStyledRun` currently throws it
   away. Nesting resolution (`_resolveNesting`) narrows a run's text, so it narrows its range by
   the marker lengths it consumed.
2. **`FountainScriptComposer` threads a source anchor** into `_wrapToLines`, so the runs it parses
   are anchored in the document rather than at offset 0. The anchor is resolved from the block's
   own `FountainBlock.sourceRange` plus, for the multi-line blocks (`FountainActionBlock`,
   `FountainLyrics`, and a dialogue group's children), a forward scan of
   `FountainDocument.sourceText` from that block's start for each line's verbatim text. The scan is
   **best effort by design**: a line the scan cannot find verbatim (a forced-element marker
   stripped by the parser, an escaped character) simply gets no anchor, and every consumer degrades
   to §4.2's bridge rule for it. `compose` already has `document`, so no new argument is needed
   from the caller.
3. **`FountainScriptLine` gains `sourceRange`** (nullable), derived from the min/max of its runs'
   own ranges, plus **`isSynthetic`** — true for the `(MORE)` token and the repeated
   `NAME (CONT'D)` cue, which are composed text with no source behind them.

Two documented imprecisions, both sub-character-level and both harmless for a marker bar:

- `_printed`'s `toUpperCase()` can change a string's length for a handful of code points (`ß` →
  `SS`). When it does, the run keeps its source range but the position of a tick *inside* that run
  is interpolated proportionally rather than counted exactly.
- A plain span containing an escaped character (`\*`) renders one character shorter than its
  source. Same proportional interpolation.

Neither can move a bar's first or last **row**, only a tick's column, by at most a character or
two, on a line that contains one of those constructs.

### 4.2 The bridge rule

A printed line with no runs (the blank spacer between two blocks, a preserved blank dialogue line)
and a synthetic line (`(MORE)`, `NAME (CONT'D)`) have no source range of their own. A range is a
contiguous source span and printed lines are in source order, so the rule is simply: **a line with
no source range is inside a range when the nearest anchored line above it and the nearest anchored
line below it both are.** That is what makes a bar run continuously across the blank line between
two paragraphs, and across a page break, as the reference does.

### 4.3 Why this belongs in `fountain_kit` and not in the app

The mapping is a property of how the paginator laid the screenplay out; only the paginator knows
it. Recomputing it in the app would mean re-implementing the wrap, and any future divergence
between the two would show up as bars silently drawn one line off. `fountain_kit` stays
Flutter-free throughout — nothing here needs anything but `dart:core`.

## 5. Colours

Benoit's constraint: **within one sequence no two shots may share a colour, and every colour must
be legible on white.** No meaning is attached to a particular colour.

- A `const` ordered palette of 16 colours chosen for contrast against white paper and for mutual
  distinguishability, in `lib/constants/ocpt_coverage_palette.dart` as ARGB ints (no `pdf` and no
  Flutter import — the palette will be wanted on screen later too), converted to `PdfColor` at
  render time.
- A shot's colour is the palette entry at its rank within its sequence. Deterministic, so the same
  project exported twice produces the same document — which matters the moment two printed copies
  are compared.
- A sequence with more than 16 shots takes the palette again with a hue rotation, so the
  repetition is at least visibly different rather than identical. The 17th shot of one sequence is
  where the constraint stops being satisfiable exactly; a comment says so at the call site.
- The colours are **per sequence**, so scene 5's third shot and scene 7's third shot share a
  colour. Two bars of the same colour are never adjacent, which is what the constraint is actually
  about.

## 6. The shot abbreviation field (schema v4)

- `shots` gains `abbreviation TEXT NOT NULL DEFAULT ''`. Schema version 4, one `from3To4` step in
  the existing `MigrationStrategy`, following `docs/adr/0007-schema-migration-policy.md`. The
  column is synchronised, so it takes part in `row_field_versions` exactly like its siblings
  (ADR 0010) — no tombstone concern, it is a column not a table.
- `OcptShot.abbreviation`, `OcptShotListService.updateShot`, and a new
  `OcptShotListEditableField.abbreviation`.
- Shown in `OcptShotInspectorPanel` immediately under the shot size, a short single-line field
  (3-4 characters of Courier width), with the shot size's own suggestion behaviour left alone.
- **Pre-filled by deduction**: when a shot's `shotSize` is committed and its `abbreviation` is
  still empty, the abbreviation is written as the initials of the shot size's words
  (`Plan moyen` → `PM`, `Gros plan` → `GP`, `Close-up` → `C`). Deduced once, at that moment only —
  editing the shot size afterwards never overwrites an abbreviation the user has set, and clearing
  the field leaves it empty.
- A bar's label is `<abbreviation><code>` when the abbreviation is set (`PM1/1`), `<code>` alone
  otherwise (`1/1`).
- `OcptShotListXlsxColumn` gains the column too, so the two exports agree on what a shot is.

## 7. The layout model

Pure Dart, no `pdf` and no Flutter, in `lib/models/ocpt_scenario_coverage_layout.dart` — the same
shape as the existing `OcptShotCoverageLayout`, which is already a model with a computing factory.
This is where every rule of §2, §4.2 and §7.3 lives, and where the tests are.

`OcptScenarioCoverageLayout.of({required FountainScriptLayout script, required
OcptShotListSnapshot snapshot, required String screenplayText})` produces:

### 7.1 Bar segments

One `OcptCoverageBarSegment` per (coverage range × page it appears on):

```
pageIndex, firstRow, lastRow, lane, side (left|right),
colorIndex, label, isStale,
startTick: (row, column)?  endTick: (row, column)?
```

- The rows come from resolving the range's absolute source offsets (`scene.charStart +
  range.startOffset`) against every line's `sourceRange`, with §4.2's bridge rule.
- A tick is emitted only when the boundary falls **inside** a line rather than on its first or last
  column — which is what the reference draws.
- `isStale` carries the range's existing staleness (`OcptShotCoverageRange.isStale`): the coverage
  no longer agrees with the screenplay's text. Rendered as a hollow bar (outline, no fill) so it is
  visible as "recorded, needs re-checking" without being mistaken for solid coverage. Also counted
  separately on the summary page.

### 7.2 Lanes

Assigned per page by a greedy interval colouring over the segments sorted by `firstRow`: each
segment takes the innermost lane no overlapping segment already holds. Lanes fill the left margin
first — outside the scene-number column, which keeps its place — then the right one. Capacity is
derived from the page setup's actual margins at a fixed lane pitch; **a page needing more lanes
than fit shrinks its pitch down to a floor, and past that floor the excess segments share the
outermost lane with a combined label**. That last case only happens with a dozen shots covering
the very same lines, and the summary page reports it when it does.

### 7.3 Uncovered passages

The complement of the union of every range, per scene, restricted to printed lines that carry
actual words. Emitted as `OcptCoverageGap(pageIndex, row, startColumn, endColumn)` runs.

Rendered as a **light grey wash behind the uncovered text** — chosen over a margin rule because in
a mostly-covered screenplay only the gaps get washed, so they are what the eye lands on, and
because it survives black-and-white printing. Everything not part of a scene at all (text before
the first heading) and every scene with no shots at all is uncovered by definition.

### 7.4 Legend and summary

- Legend: one row per shot, in sequence then rank order — colour swatch, label, shot size, framing,
  camera move.
- Summary: one row per sequence — scene number and heading, shot count, covered word share
  (`OcptShotCoverageLayout.countCoveredWords` already computes the numerator), stale range count,
  and the uncovered extracts quoted short. Plus the orphan group, listed separately: its shots'
  scenes no longer exist, so they cover nothing and are worth naming.

## 8. The renderer

`lib/managers/export/services/ocpt_scenario_coverage_pdf_service.dart`, a fourth service owned by
`OcptExportManager` (RFL18), exposed as a public final field like its three siblings.

- It composes the screenplay through the very same `FountainScriptComposer` call
  `OcptPdfExportService` makes, from the same `OcptPageSetup`, then draws the same absolutely
  positioned lines, then draws the bars, ticks, washes and margin annotations on top.
- `_CourierPrimeFonts` is currently private to `OcptPdfExportService`. It moves out to
  `lib/managers/export/services/ocpt_courier_prime_fonts.dart` unchanged, so both services share
  one loader and one cache rather than embedding the fonts twice.
- The line-drawing code itself (`_buildScriptPage`'s positioning, `_spansFor`, `_lineBoxWidthPt`,
  `_elementLayoutFor`, `_textAlignFor`) is the same work in both services. It moves to a shared
  `OcptScriptPagePainter` in the same directory, which `OcptPdfExportService` then uses too —
  a refactor with no behaviour change, guarded by that service's existing tests.
- `OcptExportManager.exportScenarioCoverage(...)` mirrors `exportPdf`: generate, then
  `_writeToPickedLocation` with a suggested `<project> - couverture.pdf` file name (localized).

## 9. UI wiring

- `OcptShotListMode`'s `⋮` menu gains "Export the scenario coverage…", beside the existing XLSX
  entry, disabled while the shot list is empty exactly as that one is.
- It opens `OcptScenarioCoverageExportDialog`
  (`lib/ui/pages/workspace/modes/shot_list/widgets/`), modelled directly on the existing
  `OcptEditorExportPdfOptionsDialog`: page format pre-filled from the project, include title page,
  include scene numbers, plus include legend page and include summary page. Opened through
  `OcptRouterManager`, never `Navigator`.
- A new `OcptScenarioCoverageExportRequestedEvent` on the shot list bloc, handled exactly like
  `OcptShotListXlsxExportRequestedEvent`: flush pending edits, parse
  `OcptShotListState.screenplayText` into a `FountainDocument`, hand it and the snapshot to the
  manager, report through the existing `OcptShotListIoNoticeKind` pair (succeeded / failed).
- The bloc needs the page setup, which it does not hold today: `project_info.pageFormat` through
  `OcptProjectsManager` and the margins through `OcptPropertiesManager.pageMargins`, combined by
  `OcptPageSetup` as every other call site does.
- Every user-visible string into both ARB files. The legend and summary pages' own headings are
  localized too and passed into the service as a labels object, exactly as
  `OcptShotListXlsxLabels` already does for the workbook — the manager and its services have no
  `Tr`.

## 10. Milestones

Each is one logical commit (or a small series), verified against the full gate list in `CLAUDE.md`
before it is handed back, with a user checkpoint between milestones.

| # | Content | Depends on |
| --- | --- | --- |
| M1 | `fountain_kit` source provenance: run/line `sourceRange`, `isSynthetic`, the composer's anchor threading, tests over wrapped, upper-cased, emphasised, escaped and page-split lines | — |
| M2 | Schema v4 + the `abbreviation` field: migration, model, service, inspector, deduction rule, XLSX column, l10n | — |
| M3 | `OcptScenarioCoverageLayout`: bars, bridge rule, ticks, lanes, gaps, legend and summary data — pure, and where most of the tests are | M1, M2 |
| M4 | The renderer: `OcptCourierPrimeFonts` and `OcptScriptPagePainter` extracted, the coverage PDF service, the manager entry point | M3 |
| M5 | UI: `⋮` entry, options dialog, bloc event, notices, page setup plumbing, l10n | M4 |
| M6 | Docs: an ADR for §4's decision to put source provenance in the paginator, README and `CLAUDE.md` updates, this plan deleted | M5 |

M1 and M2 are independent and can run in parallel in two worktrees under `worktrees/`.

Note for M6: the macOS branch (issue #40) already claims ADR **0011**, so this one takes the next
free number once that branch has merged.

## 11. Open points for review

Flagged rather than decided — each changes what the document looks like, and none blocks M1 or M2.

1. **The uncovered marking (§7.3).** A light grey wash behind the text is what this plan builds. A
   thin rule in the outermost margin lane is the quieter alternative; a screenplay that is 80%
   uncovered early in prep will look heavily washed.
2. **Lane overflow (§7.2).** The shrink-then-share rule is a guess at what a dense découpage does
   to the margins. Worth looking at against a real project before it is settled.
3. **Stale ranges (§7.1).** Drawn hollow. The alternative is drawing them solid and only counting
   them on the summary page, which keeps the page cleaner at the cost of hiding a real warning.
4. **Where a covered passage crosses a scene boundary.** A range is scene-scoped by construction,
   so this cannot happen today; it is only worth a note in the ADR.
