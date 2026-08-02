<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0012 - Source provenance in the paginator

## Status

Accepted

## Context

The shot list records, per shot, which passages of the screenplay that shot covers. A coverage
range is stored as a pair of character offsets into the raw Fountain source, relative to its
scene's `charStart`. The scenario coverage export has to print a coloured bar in the margin
alongside every passage a shot covers, and a tick inside the text where a passage starts or ends
mid-line — so it needs the answer to one question: *given source offsets `[s, e)`, which page, row
and column was that passage printed at?*

Nothing could answer it. The printed document is a `FountainScriptLayout`: pages of
`FountainScriptLine`s produced by `FountainScriptComposer`, which parses inline runs (dropping the
`**`/`_` markers), strips forcing markers, upper-cases what the print style says to upper-case, and
greedily wraps the result into Courier columns. A `FountainScriptLine` carried no trace of where
its text came from, and none of those four transformations is length-preserving.

The mapping is therefore a property of *how the paginator laid the screenplay out*. The
alternatives were to recompute it outside the paginator, to store printed positions alongside the
coverage ranges at authoring time, or to have the composer emit what it already knows.

`fountain_kit` is a Flutter-free pure-Dart package (ADR 0002) and nothing this needs goes beyond
`dart:core`, so none of the three options was ruled out by the package boundary.

## Decision

The paginator emits the provenance, as a nullable annotation threaded through three types:

- `FountainStyledRun.sourceRange` — the span of raw source a run was parsed from, emphasis markers
  included. `FountainInlineParser.parseRuns` gained the `line` / `startOffset` anchor parameters
  `parse` already had; the parser computed this range on every `FountainInlineSpan` already and
  merely threw it away when building runs.
- `FountainScriptLine.sourceRange` — the union of its runs' ranges — and
  `FountainScriptLine.isSynthetic`, true for the `(MORE)` token and the repeated `NAME (CONT'D)`
  cue, which are composed text with no source behind them at all.
- `FountainScriptComposer` resolves an anchor per printed line against `FountainDocument.sourceText`
  (`_SourceAnchors`): the block's own `FountainBlock.sourceRange` for its position, then a verbatim
  lookup of the printed text inside the source line it came from, which lands exactly right
  whenever the parser only removed characters.

Anchoring is **best effort by design**: a line whose text cannot be located verbatim, and a
document carrying no source text at all, get no `sourceRange` rather than a wrong one. Consumers
close the gaps with a bridge rule — every row between a range's first and last anchored row belongs
to it, anchored or not — which is what makes a bar run continuously across the blank line between
two paragraphs, across a `(MORE)`, and across a page break.

The app consumes it in `OcptScenarioCoverageLayout` (`lib/models/`), which turns resolved rows into
bars, lanes, ticks and gaps, and stays as free of `pdf` and Flutter as `fountain_kit` is.

## Consequences

The bars are laid out against the exact lines the PDF prints, so they cannot drift from the text
they annotate — which is the whole point: a bar one row off is worse than no bar.

The cost is that `sourceRange` is nullable everywhere and every consumer must degrade gracefully
rather than assume it. Any future change to how the composer wraps or rewrites text has to keep the
anchors threaded through it; a line that silently loses its anchor does not fail a test, it just
gets bridged over.

Two imprecisions are accepted and documented on the types themselves: a print-time `toUpperCase()`
can change a string's length for a handful of code points (`ß` → `SS`), and an escaped character
(`\*`) renders one character shorter than its source. In both cases a position *inside* a run is
interpolated proportionally rather than counted exactly. Neither can move a bar's first or last
row — only a tick's column, by a character or two, on a line containing one of those constructs.

`sourceRange` deliberately stays out of `props` on both `FountainStyledRun` and
`FountainScriptLine`, exactly as `FountainBlock.sourceRange` already did: two runs with the same
text and the same styling are equal whether or not either knows where it came from, which keeps
every existing round-trip and wrapping test comparing by content alone.

Worth noting for a future reader: a coverage range is scene-scoped by construction, so a bar never
spans two scenes. If ranges ever become document-scoped, the layout's per-scene resolution is the
piece that has to change, not this provenance.

## Alternatives considered

- **Recompute the mapping in the app**: means re-implementing the wrap, the marker stripping and
  the upper-casing outside `fountain_kit`. Two implementations of one algorithm, and any future
  divergence between them shows up as bars silently drawn one line off — the failure mode nobody
  notices until a print is annotated on set.
- **Store printed positions at authoring time**, beside the coverage ranges: every screenplay edit
  and every page-setup change (page format, margins) invalidates them wholesale, and they would
  have to be recomputed by the paginator anyway to be repaired.
- **Mark the source with sentinel characters before composing**, then find them in the output:
  needs no API change, but it composes a *different* document from the one that gets printed, so
  the sentinels themselves can change the wrap.
- **Derive coverage positions from the styled editor's own layout** (super_editor) rather than the
  paginator's: that layout is the screen's, not the page's — different widths, no pagination, no
  `(MORE)`. It cannot answer which printed page a passage lands on.
