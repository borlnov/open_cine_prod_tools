# Projects and episodes

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## One project, one file

An Open Cine Prod Tools project fits in a **single `.ocpt` file** on your disk. It holds
everything: the screenplay, the breakdown, the shot list, the resources, the schedule and the
budget. To back up or share a project, you just copy that file — or export it as a portable
package (see [Exporting, in short](exporting-overview.md)).

## One project, several episodes

A series, a mini-series or a film shot in parts all live in a **single file**. A project holds
**one screenplay per episode**, but **one** crew, one address book, one set of locations and one
schedule. That is what lets a series be shot out of order: a single shooting day routinely covers
scenes from two episodes at one location.

Each mode that depends on an episode shows the one the toolbar's **episode selector** points at.
Two modes read every episode instead: the **Schedule** and the **Budget** — so they have no
selector.

## Scene numbering

As soon as a project holds more than one episode, scene numbers read `episode.scene` — for
example `2.12` for the twelfth scene of the second episode. A single-episode project shows plain
numbers. The screenplay text is never renumbered: the episode is named beside the page instead.

## Managing episodes

- **Adding a first extra episode**: in a single-episode project, the Screenplay toolbar shows an
  **Add an episode…** button. This is the gesture that turns a project into a series.
- **After that**: everything is managed from **project settings → Episodes card** — add, rename
  in place, reorder with `▲` / `▼`, delete. Deletion is confirmed and lists exactly what it
  removes. The selector's **Manage episodes…** entry goes straight there.
