<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0019 - One project, several episodes

## Status

Accepted

## Context

A project has held exactly one screenplay since the first build, so a five-episode series means
five `.ocpt` files. The address book is entered five times, a location is scouted five times, an
actor is cast five times — and the shooting days, which are the whole reason a series is shot out
of order, cannot cross a file boundary at all. A mini-series and a feature shot in two parts are
the same production seen from the same angle: one crew, one address book, one set of locations,
one schedule, several screenplays.

The schema is already most of the way there. `screenplays` has always accepted several rows, and
only five tables say which screenplay a row belongs to: `scenes.screenplayId`,
`roles.screenplayId`, `shots.screenplayId`, `screenplay_snapshots.screenplayId` and
`shooting_days.screenplayId`. Everything else — the people, the locations and their sets, the
elements catalogue, the assets, the currency, the page setup — is already the production's,
because that is what those things are.

So the question this record answers is not "how is a dimension added", it is **what each of those
five columns means once a project holds more than one screenplay**. Three of them are facts about
a script and answer for themselves: a scene, a shot and a snapshot each belong to one screenplay
and to nothing else. The other two are the decision.

A role is the hard one. A speaking character is reconciled from the cue by `OcptRoleIndexService`,
per screenplay. Left as it is, a character speaking in three episodes becomes three `roles` rows:
three castings, three sets of casting notes, three role numbers, and three identities in
`shooting_slot_cast.roleId`. A production would say who plays MARIE three times, and a call sheet
for a day covering two episodes would print two different numbers for one actor standing in front
of it.

A shooting day is the other. A day regularly covers two episodes at one location — that is the
point of shooting a series out of order, and it is what the shared schedule buys.

## Decision

**A screenplay row is an episode.** `screenplays` gains `number` (an ordinary integer, printed) and
`sortKey` (the fractional index it is ordered by, as everywhere else), and that is the whole of it.
There is no `episodes` table: it would be a 1:1 indirection nothing reads, and it would give every
script-scoped row two ways to name the same fact, which is how two parts of an app come to
disagree. A project created today is one screenplay numbered 1, which is what a feature is.

`number` carries no uniqueness constraint. Two episodes numbered 4 is a state the user can reach by
hand and repair by hand, and a constraint would refuse the intermediate state of a reorder rather
than help. `sortKey` orders, `number` prints — the same split `shooting_days` already makes between
its date-ranked position and its `sortKey` tiebreaker.

**A role belongs to the production, not to a script.** `roles.screenplayId` is dropped and a new
synchronised table, `role_episodes` (`id`, `roleId`, `screenplayId`, `isDeleted`), records which
episodes name it. It carries **no `sortKey`**: a role's episodes are an unordered set of answers
rather than a list the user reorders, exactly as `scene_sets` is, and the order they read back in
is the episodes' own. `OcptRole.number` becomes the role's rank among the **project's** live roles,
where it was the rank within one screenplay — still derived at read time, still stored nowhere.

Reconciliation keeps its shape — it is handed one screenplay and that screenplay's parsed document,
on the save path `OcptSceneIndexService` already runs on — but it **only ever writes the links of
that episode**, while matching by name across every live `isFromScreenplay` role of the project. A
character cut from episode 2 but still speaking in episode 3 therefore loses one link and stays
cast; a character cut from every episode is orphaned exactly once, and the existing removed-role
banner is what offers to delete it or keep it as a silent role. A `silent` or `extra` role is named
by no cue, so it is created on the selected episode and its links are the one place in the app a
`role_episodes` row is written by a gesture.

**A shooting day belongs to no episode.** `shooting_days.screenplayId` is dropped outright, and
nothing replaces it: filing a day under one episode would make the schedule mode lie about the plan
it holds. The schedule reads across every episode of the project.

**The sequence prefix is one rule with one implementation.** A sequence's display number becomes
`<episode>.<scene>` as soon as the project holds more than one episode, through
`ocptSceneDisplayNumberOf` (`lib/utils/`, pure), which every reader imports rather than restating —
it is stated four times in the code this record ships against. A null episode number means "this
project has one episode" and returns exactly what those four call sites return today. **The printed
screenplay is never prefixed**: the Fountain text belongs to one episode and its `#N#` numbers are
the author's, so rewriting them at print time would be printing something other than the
screenplay. The episode is named beside the page instead.

This lands as **one schema bump, version 18** (two added columns, one new table, two dropped
columns) and **one payload format, 13**, rather than one per milestone: a single migration to pin
against `onCreate` (ADR 0007), and no migration in any later milestone.

The migration reconstructs nothing and guesses nothing. The single screenplay a file holds is
numbered 1 and given a key; every live `roles` row gets the `role_episodes` row its own
`screenplayId` already states; a shooting day is **not** given an episode on the way out, it simply
stops having one. The payload's own upgrade from format 12 does the same, and its `role_episodes`
step is the **only lossless one in the codec**: every other step materialises a value that was
never recorded, or drops one the app has no concept for any more, whereas this one rewrites a fact
the payload already carries in full.

Both derivations mint the link's id as **the role's own id**. A role has exactly one episode at
that point, so the id is unique, and it is deterministic: two replicas migrating the same file, or
restoring the same version, produce the same rows rather than two sets of links a later merge would
have to reconcile. This is the same reasoning `_assignOrphanBlocksToFirstSlot` states for its own
tie-break, and it is why neither derivation writes a `row_field_versions` stamp.

## Consequences

ADR 0007's additive-only rule is set aside once more, for two column drops — as it already was at
schema versions 12, 13, 14 and 17, and by the same mechanism: `Migrator.alterTable` with a
`TableMigration`, drift's own documented recipe, still `@experimental`.

**Restoring a format-12 version into a multi-episode project tombstones every episode but the
first**, along with its scenes, its shots and its breakdown. That is the truthful reading of "this
project had one episode when this version was sealed" — it is an edit like any other restore, not a
no-op that leaves the other episodes alone, and the restore's own safety version is what makes it
undoable. No role loses its casting on the way through, since a role is no longer a script's.

One number per role across the series is not a preference, it is what the shared schedule forces: a
day covering episodes 2 and 5 prints one `RÔLES` column, and two roles numbered 3 in it would make
the call sheet unreadable at exactly the moment somebody is using it. The cost is that a role
cannot be numbered per episode at all, and printing `2.3` and `5.3` instead would put an episode on
a cast member, who does not belong to one.

Four things become correct with no work of their own, because a role is now what it always claimed
to be: `shooting_slot_cast` names one identity per character across the shoot, the *Day Out of
Days* draws one row per part over the whole series (which is how a cast contract is negotiated),
the contact list prints one cast row per role, and the uncast alert fires once per part rather than
once per part per episode.

A rename in a screenplay is still not detected, for the reason it never was: nothing about a cue is
a stable identifier. What changes is the blast radius — a rename in episode 2 reads as one
disappearance and one appearance within episode 2's links, and a role still speaking elsewhere
keeps its casting either way.

A single-episode project is exactly what it is today: one screenplay numbered 1, no selector, no
prefix, no episode named anywhere. That is a standing constraint on every surface this feature
touches, not a transitional state.

Deleting an episode takes its screenplay, its snapshots, its scenes, its shots and coverages, its
breakdown and its `role_episodes` links, and leaves the people, the locations, the elements and
**the shooting days**, which were never that episode's. A block that placed one of its shots goes
with the shot; the day it sat on does not.

## Alternatives considered

- **An `episodes` table** a screenplay points at: the shape a reader expects, but a 1:1 indirection
  nothing reads, and two ways to name one fact for every script-scoped row.
- **A role per screenplay, reconciled as today**: no migration, no link table — and a production
  saying who plays MARIE once per episode, with a call sheet printing two numbers for one actor.
- **Keeping `shooting_days.screenplayId`**, nullable, for a day that plays one episode: it would
  read as a fact about the day while being an accident of how it was created, and every reader
  would have to decide what a null meant.
- **Prefixing the printed screenplay**: makes the PDF agree with the shot list, at the cost of
  printing scene numbers the author did not write.
- **Seasons, as a grouping above the project**: a project is a season. A second level is a
  different issue, and nothing decided here forbids it later.
- **A schema bump per milestone**: smaller steps, but five migrations to pin against `onCreate`
  where the data model settles in one.
