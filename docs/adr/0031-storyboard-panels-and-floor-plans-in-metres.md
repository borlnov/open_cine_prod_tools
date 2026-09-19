<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0031 - Storyboard panels and floor plans in metres

## Status

Proposed

## Context

Issue #85 asks for a storyboard mode. The mock-up it was validated against
(`docs/plans/storyboard.md`) makes two structural choices that shape the schema and diverge from the
issue's own wording, both expensive to reverse once shipped, so both are worth arguing here rather
than only in the plan.

The issue reads "one frame per shot." A shot, though, is a continuous action, and a board that
allows only one frame per shot cannot decompose it into key frames the way a real storyboard does
— a pan, a push-in, an actor crossing the frame each need more than one drawing to read. Each frame
also needs a light annotation layer (a movement arrow, a camera-move arrow, a short label) that two
people may mark up on the same image. ADR 0010 makes every synchronised table mergeable at row and
column granularity precisely so two edits to different things do not clobber each other; an
annotation layer packed as one JSON column on a panel would put every mark behind a single column,
so two people annotating one panel would merge as last-writer-wins over the whole layer instead of
per mark.

Floor plans are the app's only in-app drawing surface where physical distance has to mean something
after the fact: a scale bar has to be honest, a metrics overlay has to report a real distance
between two symbols, and the floor-plans PDF has to print a plan a location scout can trust. That
forces three questions before a single column is typed: what unit a symbol's position and size are
stored in, whether the user calibrates a scale before drawing, and how the view's zoom — which has
to change constantly as someone works a case — relates to what gets stored and synchronised.

## Decision

**A storyboard is ordered panels under a shot**, not one frame. `storyboard_panels`
(`shotId` → `shots.id`, `sortKey` fractional index, nullable `imageAssetId` pointing at `assets`
per ADR 0013, `comment`) holds 0..N rows per shot. `storyboard_annotations` is a second table, one
row per mark (`panelId`, `kind`, `sortKey`, `x1`/`y1`/`x2`/`y2` normalised to the frame, `text`).
Both are ordinary synchronised tables — `id`, `isDeleted`, per-row and per-column merge — per
ADR 0010, not columns on `shots` and not a blob on `storyboard_panels`.

**Floor-plan geometry is stored in metres, synchronised, against a default-character reference,
with zoom kept out of the synchronised model.** Every symbol's position and size
(`floor_plan_symbols.xM`, `yM`, `widthM`, `heightM`, `rotationDeg`, and their equivalents on
`floor_plan_cases`' underlay) is a real number of metres, an ordinary synchronised column like any
other. There is no calibration dialog and no stored scale factor: the default character footprint
(0.5 m) is the implicit ruler, drawn as an always-visible reference silhouette and scale bar
against the canvas's current zoom, from the one pure rule (`ocpt_floor_plan_geometry.dart`) the
canvas, the metrics overlay and the floor-plans PDF all read. Zoom and pan are held in a per-session
`OcptFloorPlanViewportController` the view's `State` owns; they never reach the bloc's persisted
state, the database or a project-version payload.

## Consequences

A fifth table, `storyboard_annotations`, is the price of per-mark merge: heavier than a single JSON
column on the panel, but the alternative loses concurrent edits outright. The same trade recurs at
smaller scale inside `floor_plan_symbols` and `floor_plan_arrows`, which are likewise one row per
symbol or arrow rather than a layer blob on the case.

Metres are portable and replica-independent, but nothing hands the app real-world scale for free:
without a calibration step, accuracy is only as good as the user's eye against the 0.5 m silhouette
and against an underlay they drag and resize to match it — there is no way to type a known
measurement in and have the app compute the rest. The character-as-ruler avoids forcing that step
before drawing at the cost of that honesty.

Because zoom never touches the synchronised model, two replicas viewing the same case at different
zooms never generate a conflict over it, and scrolling or pinching never churns a sync stamp — but
every renderer (the canvas, the scale bar, the PDF page) must independently derive screen or paper
coordinates from stored metres at its own zoom or DPI, which is one more place the pure geometry
rule has to be the single source both agree with, rather than one value read off a row.

Two related costs recorded in the plan (`docs/plans/storyboard.md`, §1, §2, §8) belong to this same
family of trade-offs without needing their own record: the storyboard frame's aspect ratio is
parsed from the shot's free-text `recordingFormat` with a 16:9 fallback, a guess a later structured
format field could remove; and a per-symbol size override (`widthM`/`heightM` on every layer, not
just set elements) is deferred to v2, reusing the same columns with no migration.

## Alternatives considered

- One frame per shot, as issue #85 worded it — rejected: a shot's action rarely fits one drawing,
  and the validated mock-up needed several key frames per shot.
- Annotations as a JSON column on the panel — rejected: two people marking up the same panel would
  overwrite each other's marks wholesale instead of merging per mark (ADR 0010).
- An explicit calibration/scale dialog before drawing a case — rejected: it adds a step before every
  new case, and a persisted scale factor is one more synchronised value to keep honest whenever the
  underlay changes.
- Geometry in logical pixels or normalised (0..1) coordinates — rejected: pixels are screen- and
  DPI-dependent and do not survive zoom or a different device; normalised coordinates need a fixed
  reference frame that would itself have to be calibrated.
- Persisting zoom and pan in the project — rejected: it is a per-viewer concern that would churn
  sync stamps on every scroll and have two replicas fighting over whose zoom sticks.
