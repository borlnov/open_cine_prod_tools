<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# One project, several episodes

This document is the implementation strategy for issue #55: a series, a mini-series and a feature
shot in two parts are one production — one crew, one address book, one set of locations, one
schedule — and several screenplays. It is written for the Sonnet 5 agents that will build it,
orchestrated and reviewed by the main session, with a user checkpoint between each milestone.
**Read the repository `AGENTS.md` first** — this plan assumes its architecture, ways of working,
coding standards, licensing rules and verification gates, and does not repeat them.

The decisions this plan builds on are recorded in [ADR 0007](../adr/0007-schema-migration-policy.md)
(a schema number is allocated at merge time), [ADR 0010](../adr/0010-sync-ready-data-model-prerequisites.md)
(tombstones, `sortKey`, version stamps) and [ADR 0018](../adr/0018-a-convocation-is-the-slot-you-are-linked-to.md)
(a convocation is the slot you are linked to). It adds one of its own, written in M1:
**ADR 0019 — one project, several episodes**. When this plan and an ADR disagree, the ADR wins.

---

## 1. Why this step exists

Today a project holds exactly one screenplay, so a five-episode series means five `.ocpt` files and
five copies of the same people. The address book is entered five times, a location is scouted five
times, and the shooting days — which are the whole reason a series is shot out of order — cannot
cross a file boundary at all.

The surprise, when you open the schema, is how little of this is missing. `screenplays` already
accepts several rows, and five tables already say which screenplay a row belongs to:
`scenes.screenplayId`, `roles.screenplayId`, `shots.screenplayId`,
`screenplay_snapshots.screenplayId` and `shooting_days.screenplayId`. Everything else — the address
book, the locations and their sets, the elements catalogue, the assets, the currency, the page
setup — is already the production's.

So this step is not about adding a dimension. It is about **deciding what each of those five
columns becomes**, and then wiring an interface onto the answer. Three of the five stay exactly as
they are, one becomes a link table, and one is deleted.

---

## 2. The strategy in one page

- **One schema bump for the whole step** (v18, payload format 13): two added columns, one new
  table, two dropped columns. Doing it once rather than per milestone gives a single migration to
  pin against `onCreate` (ADR 0007), and every milestone after M1 is service and UI work with no
  migration of its own.
- **A screenplay *is* an episode.** `screenplays` gains `number` and `sortKey`, and that is the
  whole of it. A separate `episodes` table would be a 1:1 indirection nothing reads, and would give
  every script-scoped row two ways to name the same fact — which is how the two come to disagree.
- **A role belongs to the production, not to a script.** `roles` loses its `screenplayId` and a new
  `role_episodes` link says which episodes name it. This is the hard question of the issue, and §4
  is entirely about it.
- **A shooting day belongs to no episode.** `shooting_days.screenplayId` is dropped outright. A day
  regularly covers two episodes at one location, and that is the point of shooting a series out of
  order — filing a day under one episode would make the schedule mode lie about the plan it holds.
- **The prefix is one pure rule with one implementation.** A sequence's display number becomes
  `<episode>.<scene>` as soon as the project has more than one episode. That rule is stated **four
  times today** (`OcptSceneRef.displayNumber`, `OcptBreakdownScene.displayNumber`,
  `OcptShotListService` and `OcptSchedulePlanSnapshot.sceneNumberBySceneId`); this step is what
  reduces it to one function every reader imports.
- **The printed screenplay is never prefixed.** The Fountain text belongs to one episode and its
  `#N#` numbers are the author's; rewriting them at print time would be printing something other
  than the screenplay. The episode is named beside the page instead — the title page for the
  screenplay PDF, the running head for the sides.
- **A single-episode project stays exactly what it is today**: one screenplay row numbered 1, no
  selector, no prefix, no episode named anywhere.
- **Six milestones**, one branch, one pull request, a user checkpoint between each.

---

## 3. What changes in the data model

### 3.1 Schema v18

| Change | Table / column | Why |
| --- | --- | --- |
| new column | `screenplays.number` | a row of this table is an episode |
| new column | `screenplays.sortKey` | the order episodes are read in, like everywhere else |
| new table | `role_episodes` | which episodes name a role |
| removed | `roles.screenplayId` | a role is a fact about the production |
| removed | `shooting_days.screenplayId` | a day regularly covers two episodes |

`role_episodes` carries `id`, `roleId`, `screenplayId` and `isDeleted`, and **no `sortKey`** — a
role's episodes are an unordered set of answers rather than a list the user reorders, exactly as
`scene_sets` is, and for the same reason: the order they read back in is the episodes' own.

`screenplays.number` is an ordinary integer with no uniqueness constraint. Two episodes numbered 4
is a state the user can reach by hand and repair by hand; a constraint would refuse the
intermediate state of a reorder rather than help. `sortKey` is what actually orders them, `number`
is what is printed — the same split `shooting_days` already makes between its date-ranked position
and its `sortKey` tiebreaker.

**The migration**, for a file that has always held one screenplay: that screenplay gets
`number = 1` and a fresh `sortKey`; every live `roles` row gets a `role_episodes` row pointing at
the screenplay it named; the two columns are dropped. Nothing is reconstructed and nothing is
guessed — in particular a shooting day is **not** given an episode on the way out, it simply stops
having one.

### 3.2 Payload format 13

The codec goes from twenty-seven captured tables to twenty-eight, and `role_episodes` joins all
three of the places a synchronised table has to be named: the payload itself, `contentDigest` and
`_applyPayload`.

The upgrade step from format 12 does **four** kinds of thing, and one of them is new:

- `screenplays.number` materialises as `1` and a `sortKey` is allocated. This is format 5's kind
  (`elements.status` filled with `toFind`): a version captured in format 12 held exactly one
  screenplay, so "this project had one episode, and it was the first" is the truthful reading of
  that moment — not a null meaning "leave a live value alone".
- `role_episodes` is **derived from the `roles.screenplayId` the same step removes**. This is a
  fourth kind, and the only lossless one in the codec: the payload already carries, on every role
  row, exactly the fact the new table records, so the upgrade rewrites it rather than inventing or
  discarding it. **Read this entry's doc comment before adding a fifth kind** — it is the only one
  that may do this, and only because the column being dropped and the table being added say the
  same thing.
- `roles.screenplayId` and `shooting_days.screenplayId` are **dropped**. This is format 8's kind:
  unlike an empty list it makes no claim about the moment of capture, and unlike the currency's
  null it leaves no live value alone. A day comes back with everything it held, simply belonging to
  no episode any more, because the project being restored into has no concept for that to mean
  anything.

Restoring a format-12 version into a multi-episode project therefore **tombstones every episode but
the first**, along with its scenes, its shots and its breakdown — which is the truthful reading of
"this project had one episode when this version was sealed". It is an edit like any other restore,
not a no-op that leaves the other episodes alone, and the restore's own safety version is what
makes it undoable.

---

## 4. The hard question: what a role is

A speaking character is reconciled from the cue, per screenplay, by `OcptRoleIndexService`. Left
alone, a character speaking in three episodes would become three `roles` rows — three castings,
three sets of casting notes, three role numbers, and three identities in
`shooting_slot_cast.roleId`. A production would then say who plays MARIE three times, and a call
sheet for a day covering two episodes would print two different numbers for one actor standing in
front of it.

**A role is therefore the production's**, and `role_episodes` records where it speaks.

### 4.1 What reconciliation becomes

`OcptRoleIndexService.reconcile` keeps its signature — it is still handed one screenplay and that
screenplay's parsed document, on the same save path `OcptSceneIndexService` already runs on — but
it **only ever writes the links of that episode**, while matching by name across **every live
`isFromScreenplay` role of the project**:

1. A speaking character matching a live role: the link to this episode is ensured, and
   `orphanedName` is cleared if the role now has at least one live link. Nothing else about the row
   changes.
2. A role linked to this episode that the episode no longer names: **the link is tombstoned**. If
   the role has no live link left anywhere, it gains `orphanedName` and the existing removed-role
   banner offers to delete it or keep it as a silent role — unchanged, and now correct across the
   series: a character cut from episode 2 but still speaking in episode 3 is **not** orphaned, it
   simply stops being in episode 2.
3. A speaking character matching no role at all: a fresh project-scoped role, uncast, appended
   after every live role of the project, plus its link.

Renames are still not detected, for the reason they never were: nothing about a screenplay cue is a
stable identifier. What changes is the blast radius — a rename in episode 2 now reads as one
disappearance and one appearance **within episode 2's links**, and a role still speaking elsewhere
keeps its casting either way.

`reconcile` still writes nothing when nothing changed, running as it does on every save.

### 4.2 Role numbers

`OcptRole.number` becomes the role's rank among the **project's** live roles in `sortKey` order,
where it was the rank within one screenplay. It is still derived at read time and still stored
nowhere.

One number across the series is not a preference, it is what the shared schedule forces: a shooting
day covering episodes 2 and 5 prints one `RÔLES` column, and two roles numbered 3 in it would make
the call sheet unreadable at exactly the moment somebody is using it. The alternative — printing
`2.3` and `5.3` — would put an episode on a cast member, who does not belong to one.

### 4.3 A role added by hand

A `silent` or `extra` role is typed by the user and named by no cue, so nothing can decide its
episodes for it. It is **created on the selected episode** and its episode pills are
**editable on its own sheet** — the one place in the app where a `role_episodes` row is written by
a gesture rather than by reconciliation. A role that came from the screenplay reads its pills
out and offers no control: the cue decides, and offering to contradict it would only invite the two
to disagree.

### 4.4 What this buys for free

Because a role is now what it always claimed to be, four things become correct with no work of
their own: `shooting_slot_cast` names one identity per character across the shoot; the *Day Out of
Days* draws one row per part over the whole series, which is how a cast contract is actually
negotiated; the contact list prints one cast row per role; and
`OcptScheduleRoleUncastAlert` fires once per part rather than once per part per episode.

---

## 5. What changes in the app

### 5.1 The episode selector

`OcptWorkspaceShell` gains `episodes` and a nullable `onEpisodeSelected`, and builds the selector
itself — like the `Export` control, so the gesture cannot drift from one mode to the next. It sits
in the toolbar's **left group, right after the project title**: it qualifies *which content* is on
screen, which is what the title says too.

Being nullable is the whole of its conditional behaviour, and it goes null in two cases: a project
with a single episode (there is nothing to choose), and the **schedule mode** (which reads every
episode at once, so a selector there would either do nothing or lie about what the mode holds). In
both, **no control is drawn at all** rather than a disabled one — the budget mode's own missing
`Export` button is the precedent.

The menu only chooses. Its last entry, `Manage episodes…`, lands on `OcptProjectSettingsPage`,
where the episodes are actually managed (§5.4).

**The selection is not persisted.** Opening a project lands on the first episode; a reading
preference costs nothing to lose, and a per-project key would have to live somewhere — either in
`OcptPropertiesManager`, keyed by a path that moves, or in `project_info`, which versions capture
and hash.

### 5.2 Switching episode remounts the mode

The selection lives in `OcptWorkspaceBloc` beside the active mode, and `WorkspacePage` keys the
mode widget on it, so switching episode builds a fresh mode bloc that loads from scratch.

This is deliberate rather than lazy. A mode's state is full of things scoped to what it was showing
— a selected shot, an open tag anchor, a scroll position, a debounced field edit — and carrying
them across an episode change means auditing every one of them forever. A remount also reuses,
unchanged, the flush-on-leaving-the-tree path each mode already has for the version preview: a
pending write reaches the working copy before the new episode is read. The cost is honest and
stated: **the current selection is lost on every switch.**

### 5.3 The prefix rule

`ocptSceneDisplayNumberOf` (`lib/utils/ocpt_scene_display_number.dart`, pure and tested) is the one
implementation:

```text
String ocptSceneDisplayNumberOf({
  required String? sceneNumber,   // the explicit #N#, or null
  required int position,          // the 0-based index among the episode's scenes
  required int? episodeNumber,    // null on a single-episode project
})
```

A null `episodeNumber` means "this project has one episode" and returns exactly what the four call
sites return today (`sceneNumber ?? "${position + 1}"`). Otherwise it prefixes.
`OcptSceneRef.displayNumber`, `OcptBreakdownScene.displayNumber`, `OcptShotListService`'s own
`displayNumber` and `OcptSchedulePlanSnapshot.sceneNumberBySceneId` all become calls to it, and a
shot's `<sceneNumber>/<rank>` code follows without `OcptShot` changing at all.

`ocptShotSceneNumberOf` and `ocptShotRankOf` keep working untouched: they split on the last `/`, so
`2.12/3` gives `2.12` and `3`.

**The screenplay itself is never prefixed** — not in the styled editor's computed scene numbers,
not in the raw preview, not in the screenplay PDF, not in the coverage export, not in the sides.
Those five draw the script as written.

### 5.4 The four episode-scoped modes

The screenplay, breakdown, shot list and resources modes read the selected episode where they read
`primaryScreenplayId` today. `OcptOpenProjectModel.primaryScreenplayId` survives as what its name
says — the first episode's screenplay, which is what the home page's "import a screenplay" path
needs when it creates a project — and stops being what a mode reaches for.

The **resources mode** is the one with a shape change. Its roles tab shows **the whole series**,
each row carrying the episodes that name it, because the other three tabs are already the
production's and a cast list hiding half the cast in a mode of shared catalogues would read as a
bug. The role sheet gains the same pills, editable for a hand-added role only (§4.3).

The **project settings page** gains an `Episodes` card beside the currency and the minimum rest:
the list, an add action, inline rename, `▲`/`▼` reorder and a delete that goes through
`OcptConfirmDialog` like every irreversible action in this app. That dialog says what it takes —
the screenplay, its snapshots, its scenes, its shots and coverages, its breakdown, and the
`role_episodes` links naming it — and what it leaves: the people, the locations, the elements and
**the shooting days**, which were never that episode's. A block that placed one of its shots is
tombstoned with the shot; the day it sat on is not.

An episode's **title is optional**. An untitled one reads as `Episode 3` everywhere it is named —
a series is regularly numbered long before it is titled.

### 5.5 The schedule mode

`OcptScheduleService` loads across every episode instead of one, and `OcptSchedulePlanSnapshot`
joins them: its shot list, its scene headings, its scene numbers and its scene spans are the
project's, not one screenplay's. Nothing about a day, a slot, a block or a convocation changes —
they never named a screenplay to begin with, except the day, which now names none.

Two surfaces gain an episode grouping: the left dock's shots-still-to-place, and
`OcptScheduleShotPickerDialog`, which groups by **episode, then sequence** rather than by sequence
alone. Both already group; they gain a band, not a mechanism.

### 5.6 The paperwork

The six schedule documents get the prefix for free, reading their sequence numbers off
`OcptSchedulePlanSnapshot` as they already do. **No document gains an episode column**: the code
carries the episode, and a column would say the same thing twice while costing width on a landscape
grid that is already chunked for want of it.

Two documents need real work:

- **The sides** (`OcptSidesPdfService`) are a day's own pages, and a day now regularly plays two
  episodes. `OcptScriptSidesLayout` is composed **once per episode** and the booklet chains the
  results in episode order, each run under its own running head naming the episode and the
  screenplay page a reader can look it up by. The bloc's export handler, which today reads the one
  screenplay, reads every episode the day plays.
- **The *Day Out of Days*** already reads roles rather than actors, so it becomes correct rather
  than changing: one row per part over the whole series.

A mode's own exports stay scoped to the selected episode — the shot list workbook, the breakdown
sheets and workbook, the screenplay PDF and the coverage PDF — and **name it in the suggested file
name** (`Les Falaises - découpage - ép. 2.xlsx`), so two episodes saved into one folder cannot
overwrite each other. This is the rule the sides' own day tag already follows.

---

## 6. The milestones

Each is shippable and reviewable on its own, and ends on the full verification gates.

### M1 — The whole data model in one migration

ADR 0019, schema v18 and payload format 13 (§3), the migration and its test pinned against
`onCreate` on every upgrade path, and the codec's twenty-eighth table. Nothing in the UI changes;
the app still opens on episode 1 and still shows no selector, because every project still has
exactly one episode.

### M2 — The services

`roles` read and written project-wide, `role_episodes` and its reconciliation (§4),
`OcptRoleIndexService` rewritten with its three rules, `OcptRole.number` ranked over the project,
and `OcptScreenplayService` extended with the episode CRUD (list, create, rename, reorder, delete
with its cascade). No twelfth service: a screenplay is an episode, so the service that owns
screenplays owns episodes.

### M3 — The shell and the prefix

`OcptEpisode` (`lib/models/`, pure), the selector and its nullable slot,
`OcptWorkspaceBloc`'s selection, the keyed remount (§5.2), and
`ocptSceneDisplayNumberOf` with its four call sites collapsed onto it (§5.3). At the end of this
milestone a project can hold several episodes and be navigated between them, with the four modes
still reading whatever the shell hands them.

### M4 — The four episode-scoped modes

Screenplay, breakdown, shot list and resources on the selected episode; the roles tab and the role
sheet with their pills, editable for a hand-added role; the export file names carrying the episode.

### M5 — The schedule and its paperwork

`OcptScheduleService` and `OcptSchedulePlanSnapshot` across every episode, the two grouped
surfaces, the sides composed per episode, and a pass over the six documents confirming each prints
the prefixed code and names no episode column.

### M6 — Project settings, and the edges

The `Episodes` card and its confirm dialog (§5.4), the home page's project card saying how many
episodes a project holds, the status bar's counts, and the ARB pass over both languages.

---

## 7. Out of scope, and why

| Subject | Why it is not here |
| --- | --- |
| Seasons | A project is a season. A second grouping level is a different issue, and nothing in the schema forbids it later |
| Cross-episode renumbering of sequences | Each episode numbers its own scenes; a global renumbering is an authoring decision the app does not make |
| Copying or moving content between episodes | Real, and a step of its own — it needs to decide what a copied scene does with its tags, its shots and its placements |
| Per-episode budget | The budget mode is still an empty state |
| Detecting a rename across episodes | Unchanged from today, and for the same reason: a cue carries no stable identifier |
| An episode's own page setup | The page setup is the production's, like the currency; a series does not change paper between episodes |

---

## 8. Verification

Beyond the standard gates, this step is done when:

- The migration test pins v18's `onCreate` against every upgrade path, `role_episodes` included,
  and a pre-v18 file opens with its single screenplay numbered 1 and every role linked to it.
- A format-12 payload restores into a multi-episode project leaving exactly one episode, with no
  shooting day carrying an episode and **no role losing its casting**.
- `OcptRoleIndexService` is tested on the three cases only a series can produce: a character
  speaking in two episodes staying one row, a character cut from one of them keeping its casting
  and **not** being orphaned, and a character cut from all of them being orphaned exactly once.
- `ocptSceneDisplayNumberOf` returns today's answer verbatim for a null `episodeNumber`, and every
  one of its four callers is a call rather than a copy.
- A day playing sequences from two episodes prints one call sheet whose `SEQ` column is unambiguous
  and whose `RÔLES` column names each part once.
- The sides of that same day print both episodes, each under its own running head, with the
  screenplay's own scene numbers **unprefixed** in the margin.
- A single-episode project shows no selector, prints no prefix and names no episode anywhere.
