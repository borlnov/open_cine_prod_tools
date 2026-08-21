<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Casting candidates, and the days that do not only shoot

This document is the implementation strategy for [issue #56][i56] and [issue #57][i57], which are
companions: #57 plans the sessions where the candidates of #56 are actually seen, so **#56 ships
first and #57 is written on top of it**. **Read the repository `CLAUDE.md` first** — this plan
assumes its architecture, ways of working, coding standards, licensing rules and verification
gates, and does not repeat them. It also assumes `docs/architecture/resources.md` and
`docs/architecture/schedule.md`, whose rules it extends rather than restates.

[i56]: https://github.com/borlnov/open_cine_prod_tools/issues/56
[i57]: https://github.com/borlnov/open_cine_prod_tools/issues/57

---

## 1. Why this step exists

`roles.personId` is a single column: a role has an actor or it has none. Casting is the whole
period before that column can be filled — several people are seen for one part, notes are kept on
each, one is eventually retained — and the app has nowhere to put any of it. A production using it
today either keeps its casting in a spreadsheet, or types the retained name in and loses every
trace of who else was seen.

The schedule mode has the same hole one step further: it can only put a **shot** in a block. The
weeks of auditions and rehearsals a production runs before the first shooting day are planned
exactly like shooting days — a date, a place, people convoked, a running order — and the mode
already has every one of those pieces. What it lacks is something other than a shot to put in the
running order.

**A day is never given a kind.** A real day auditions in the morning and rehearses in the
afternoon; a rehearsal regularly falls on the morning of the day it is shot. What a day is for is
therefore said by the **blocks it holds**, and by nothing else — a day that carries an audition is a
day that auditions, and the paperwork adapts to what it finds rather than to a label somebody
picked.

The outcome: a role carries its candidates and the one retained writes the cast column; an audition
and a rehearsal are block kinds like any other, and a day made of them is planned, convoked, alerted
on and printed like every day beside it.

## 2. Decisions taken before writing this

Eight, all settled with Benoit before a line of this plan was written:

1. A candidate is convoked by a **link table**, never by a free-typed name, and every clock about
   them is read off what that link points at — ADR 0018's own rule, applied to the casting side.
   *(Amended after M5: the link hangs on the **audition block**, `shooting_block_candidates`
   replacing the slot-wide `shooting_slot_candidates` M4 built. What a candidate is linked to is
   the twenty minutes they are seen in, so that is what convokes them — see §5 and ADR 0024.)*
2. **One retained candidate at a time.** Retaining writes `roles.personId` and demotes the previous
   retained one to `seen`; dropping the retained one clears the column back to null. The role
   header's own cast picker **stays editable** and writes `roles.personId` alone — a production
   that ran no auditions casts directly, and touches no candidate row doing it.
3. **One kind of day and one numbering series**: every day of the schedule is a day, `J1..Jn` in
   date order, and every block kind is offered on every one of them. *(Amended after M4: the day
   kind M3 introduced, and the three series that came with it, are gone.)*
4. The **call sheet adapts to the blocks it finds**: same header, same time bands, same crew note,
   same directories; a day carrying auditions prints an `HORAIRE / RÔLE / CANDIDAT / CONTACT` table
   beside — not instead of — the `SEQ / PLANS / EFFET / DÉCORS / RÔLES` one it prints for its shots,
   and the candidates convoked on the day are listed under the cast table rather than replacing
   it.
5. The candidates live in a **`Candidates` card on the role sheet**, under the casting card: one
   row per candidate (avatar, name, status pill, audition date, a foldable note), the retained one
   pinned on top, a person picker at the bottom to add one.
6. The **roles tab wears a per-row pill** — cast, candidates in progress, nothing yet — and its
   header counts `12 roles · 5 cast`.
7. An audition block names **the candidacies it sees** — somebody, for a part — and may name
   several: two actors of two different parts are regularly read together to see what they do to
   each other. *(Amended after M5: this decision first said an audition named the part and nothing
   else, the people being convoked slot-wide. That could give nobody an hour of their own and could
   not read two parts together. The block names the people now, and its `roleId` goes with the
   change — a candidacy already carries its part.)*
8. The candidates convoked on a day are printed with their **contact**, the sheet being what an
   assistant director phones down. *(Amended after M5: the contact stays in the day's candidates
   directory, under the cast table, and the audition table — a reading of the timetable, not a
   directory — prints the hour, the part and the name.)*

## 3. The data model

Four tables touched, two of them new. The schema number is allocated **at merge time, not now**
(ADR 0007); `currentSchemaVersion` is 19 as this is written. Every new table is **synchronised**,
so each carries `isDeleted`, is read through a tombstone filter, and has to reach
`OcptProjectVersionCodec`'s payload, its `contentDigest` and its `_applyPayload` **together**.

### 3.1 `role_candidates` (new, #56)

`role_elements`' sibling on the casting side: a link between `roles` and `people` carrying what a
casting decision is made on.

| Column | Type | Says |
| --- | --- | --- |
| `id` | text | UUID |
| `roleId` | text → `roles` | the part |
| `personId` | text → `people` | who was seen — a `people` row like everybody else |
| `status` | text (converter) | `seen`, `shortlisted`, `retained`, `declined`, `unavailable` |
| `auditionedOn` | dateTime, nullable | when they were seen, null while nobody has said |
| `notes` | text | the impressions kept on **this** candidate for **this** part |
| `sortKey` | text | the casting director's own order, `role_elements` having none but this being a list a user ranks |
| `isDeleted` | bool | ADR 0010 |

- **A person is one row, whatever they do on the film**, so an actor seen for two parts is one
  `people` row and two `role_candidates` rows, and their photo, self-tape and contact are read off
  their own sheet rather than copied here. That is what the issue means by "the references the
  person's own sheet already holds": **no reference column here at all**, `assets` already answering
  through `personId`.
- `notes` is **personal data about a person** and `role_candidates` therefore joins the erasure
  rule: erasing a person must blank it and tombstone the row, in **all three** implementations that
  already have to be kept in step by hand (`OcptPeopleService.deletePerson`,
  `OcptProjectVersionsService._scrubErasedPeople`, `ocptScrubErasedPeopleFromPayload`). This is the
  first table added since that rule was written, and the test walking every key the codec writes
  for a person is what will catch a miss.
- `auditionedOn` is typed by hand and stays typed even once #57 exists: a candidate seen before the
  app was opened, or seen over a self-tape, has a date and no session. **Nothing derives it from a
  block** — a derived date would go empty the day the session is deleted.

### 3.2 `shooting_block_candidates` (new, #57)

Who is seen at this hour, and for which part: the link an **audition block** carries, and the one
convocation in the app read off a block rather than off a slot.

| Column | Type | Says |
| --- | --- | --- |
| `id` | text | UUID |
| `blockId` | text → `shooting_day_blocks` | the audition being planned |
| `roleCandidateId` | text → `role_candidates` | who, for which part |
| `sortKey` | text | the order the block reads them in |
| `notes` | text | what this convocation says beside the hour |
| `isDeleted` | bool | ADR 0010 |

- **A candidacy is named, not a person**, for the reason `shooting_slot_cast` names a role rather
  than an actor: somebody is seen *for a part*, and one person read for two parts on one day is two
  convocations, each about a different twenty minutes.
- **Several rows on one block is the point.** Two actors of two different parts read together are
  one block carrying two rows; four people seen twenty minutes each are four blocks carrying one
  row apiece — and each of the four has an hour of their own, which is the other half of why this
  table exists.
- A row whose candidacy has since been removed is **read defensively and drops out**, no cascade
  written for it — the treatment `shooting_slot_cast` already gets for a role deleted under it, and
  what an erased person's tombstoned candidacies get for free. The link carries no `personId`, so
  it joins no erasure implementation; `role_candidates` stays the row the erasure blanks.
- **`shooting_slot_candidates` is gone.** M4 built it and M6 takes it back out: a slot-wide
  convocation says "some time today", which is exactly the hour this table exists to stop printing.
  Nothing carries its rows over — no released build ever wrote one (§3.4).

### 3.3 `shooting_day_blocks` (#57)

Two new kinds, and **no new column**:

- `OcptShootingBlockKind.audition`: the candidacies being seen, for this block's duration, named
  through `shooting_block_candidates`. A block naming nobody yet is an ordinary state, exactly as a
  `hold` with no sequence is.
- **The block carries no `roleId`.** M4 gave it one, M6 drops it: a candidacy already says which
  part it is for, and a block reading two parts at once could never have named a single one — two
  columns saying the part is one column too many, and the one that can be wrong.
- `OcptShootingBlockKind.rehearsal`: names a **sequence** through the existing `sceneId`, exactly as
  `hold` already does, and needs no column of its own.

**Both new kinds are shooting blocks** for `ocptComputeSlotTimeline` and the PAT band, joining
`shot` and `hold`: they are the working time of the day they sit on, and a candidate or an actor
owed a band on a day of rehearsals is owed it for the same reason a cast member is on a day of
shots. Nothing else in `lib/utils/ocpt_shooting_day_timeline.dart` moves.

### 3.4 The migration, and what a branch may still take back

Version 23 already carries the idiom this needs: `shooting_days.kind` and
`shooting_day_blocks.roleCandidateId` were written by intermediate versions of **this very branch**
and dropped defensively (`_dropColumnIfPresent`) rather than migrated, no released build having ever
written either. `shooting_slot_candidates` and `shooting_day_blocks.roleId` are in exactly that
position, so they are handled exactly that way: the steps that create them stop creating them, a
`_dropTableIfPresent` sibling drops the table on the development files that already carry it, and
`roleId` joins the column list beside it. The version number is settled **at merge time** like every
other (ADR 0007).

## 4. Issue #56 — the casting side

- **`OcptRoleCandidatesService`** (new, owned by `OcptProjectsManager` beside
  `OcptRoleIndexService`): create, update status, update notes and date, reorder, tombstone. It is
  the one place the **retained rule** lives — `retain(candidateId)` demotes the role's previous
  retained row to `seen`, sets this one to `retained` and writes `roles.personId`, all in one
  transaction; `unretain` is its mirror and clears the column. A service, not a bloc, because the
  rule is about two tables agreeing and every caller must get the same answer.
- `OcptRoleIndexService.deleteRole` gains its second cascade (`tombstoneCandidatesOfRole`) beside
  `tombstoneRoleLinksOfRole`. **Deleting a candidate never touches the `people` row** — a person
  outlives a candidacy exactly as a coat outlives the character who wore it.
- **`OcptRoleCandidate`** (`lib/models/`) joins the row with its `OcptPerson`, as `OcptElement`
  carries its `roleLinks`; `OcptResourcesSnapshot` gains it as a fifth read and
  `OcptResourcesBloc` joins it in.
- **`OcptRoleSheetCandidatesCard`** (`…/resources/widgets/`), under the casting card and above the
  episodes card — who plays them, who was seen, where they appear, what they wear. One row per
  candidate: `OcptPersonAvatar`, the name, a status pill, the audition date, and a foldable note
  field riding the sheets' existing 2 s debounce through a sixth `pending…FieldEdits` map. The
  retained row is **pinned on top** and wears the accent; the rest keep their `sortKey` order. Its
  `⋮` offers the status change, `Retain` / `Drop` and `Remove this candidate` — the last one
  **only asking**, the mode opening `OcptConfirmDialog` as every irreversible action does. Adding
  one is the shared `OcptResourcesPersonPicker` at the bottom, over the whole address book,
  **excluding the people already candidates for this role**.
- **The roles tab**: `OcptRolesList` rows gain a leading pill — cast / candidates in progress /
  nothing — and the header count becomes `N roles · M cast`, `OcptRoleCastingProgress`
  (`lib/utils/`, pure and tested) being the one place that reading is written, so the list and any
  later reader cannot disagree.
- **`OcptScheduleRoleUncastAlert` is not touched**: the issue is explicit that a role with
  candidates but none retained is that same alert, and the alerts file keeps knowing nothing about
  candidates.

## 5. Issue #57 — auditions and rehearsals in a timetable

- **The `+ Block` menu offers every kind on every day.** Nothing is scoped: a day auditions,
  rehearses and shoots as its blocks say, and a menu that narrowed itself would be guessing which
  of those a user is about to plan.
- **An audition row carries its candidates** (M6): a wrapped strip of candidacy chips — the
  person's name and the part they are seen for — each with its own remove control, and a `+` picker
  offering every candidacy of the project grouped by role, minus the ones this block already names.
  It **picks an existing candidacy and never creates one**: a candidate is recorded on the role
  sheet, where the casting is decided, and a timetable that could invent one would be a second
  place saying who is seen for a part. A rehearsal row carries the sequence picker. *(M4 gave the
  audition row a role picker writing `shooting_day_blocks.roleId`; M6 replaces it with the chips,
  the part being read off each candidacy.)*
- **The slot card's `Candidats` band goes** (M6), and its second row is the guests alone again, as
  it was before M4: a candidate is expected at an hour, not at a unit, and one band saying otherwise
  beside the block that says it precisely is one band too many.
- **`ocptComputeDayConvocations`** keeps its fourth kind and changes where it reads it. A candidate
  is convoked by the **audition blocks that name them**: arrival at the first such block of the day,
  the PAT band over that block's own span, departure at the last one's end — the same three figures
  as everybody else, read off what they are actually linked to. The file stays free of drift and of
  the timeline types: the caller hands it, beside its slots, the day's auditions already resolved to
  a slot id, a start, an end and their candidacies. The `Convocations` dock tab keeps its
  **candidates group**, after crew and cast and before the guests.
- **The alerts are untouched**, and that is the point: nothing there reads what a day is for. Every
  rule about people fires as it always did — a rehearsal the day before a 07:00 call eats the same
  turnaround — the location and permit rules likewise, and `OcptScheduleRoleNotConvokedAlert` finds
  nothing on a day carrying no shot without needing to be told. **No new alert kind**, and
  deliberately none: "a candidate nobody has given an hour to" would be an opinion about how a
  production runs its auditions.
- **The presence grid** counts such days as `working`, unchanged: somebody at a rehearsal is there.
  The **positions matrix** likewise needs nothing.
- **Every export keeps listing every day**: with no kind to filter on, the shooting plan, the day
  out of days, the one-line schedule and the sides read the days they are given, and a day carrying
  no shot simply gives them nothing to print.

## 6. The call sheet, adapting to what a day holds

`OcptCallSheetPdfService` keeps **one composition** and reads the day's own blocks, rather than
growing a second service or branching on a label: the header, the per-slot time bands, the events,
the crew note, the locations, the sun block and both directories are the same paper whatever the day
does.

What a day carrying **audition blocks** adds:

| Always | Added by an audition block |
| --- | --- |
| the `SEQ / PLANS / EFFET / DÉCORS / RÔLES` table, for the shots the day holds | an `HORAIRE / RÔLE / CANDIDAT` table |
| the cast table (every role the day calls for) | the day's convoked candidates, under it |

- A day holding both prints both, in that order: this is one sheet for one day, and a production
  that auditions in the morning and shoots in the afternoon gets one piece of paper.
- The audition table prints **one row per candidacy an audition block names** — the block's hour,
  the part, the person — in running order, two people read together making two rows sharing an hour,
  and a block naming nobody yet making one row carrying its hour alone. *(M5 printed `HORAIRES /
  RÔLE` and could print no name, a block naming none; M6 gives it the third column.)* The
  candidates convoked on the day stay listed under the cast table with their **contact**: the
  audition table is a reading of the timetable, and a phone number belongs in the directory beside
  everybody else's.
- A table that has nothing to print is **skipped entirely** rather than drawn over an em dash, the
  rule the events, guest and crew-note sections already follow.
- The **named** call sheet follows: its recipient union is the day's convocations, which now include
  candidates, and what a named sheet narrows stays the timetable and only the timetable.
- **A named sheet addressed to a candidate is narrowed to that candidate** (M6): its audition table
  prints the auditions naming them and no other, and the candidates directory under the cast table
  prints their line alone. It is the one place a block-level link narrows something a slot-level one
  could not, and the reason is not tidiness — who else is being seen for a part, and on what phone
  number, is the production's business and not another candidate's. Every other directory stays
  day-wide, a candidate reading the crew and cast lists exactly as any other recipient does.

## 7. Localization

Both ARB files, English and French, the French rule holding throughout — **a screenplay's scene is
« une séquence »**, and neither the audition table nor the rehearsal block may reintroduce the other
word. New keys, in families: the five candidate statuses, the candidates card's title, its picker
and its `⋮` entries, the confirm dialog's own words, the roles tab's pill labels and its
`N roles · M cast` count, the two new block kinds, the audition row's own candidate picker and its
chips, the `Candidates` convocation group, and the audition table's three column headings. M6 takes
back the keys M4's slot band and role picker owned, the ARB files holding no word the UI no longer
says.

## 8. Documentation

- `docs/architecture/resources.md`: the candidates card, the retained rule, the service, the roles
  tab's progress reading, and `role_candidates` joining the erasure rule.
- `docs/architecture/schedule.md`: the two block kinds, the audition block's own candidacies, the
  convocation they produce and the hours it carries, why the alerts needed no change at all, and how
  the call sheet reads the blocks a day holds rather than a label on the day.
- `docs/architecture/foundations.md`: the two new synchronised tables in the schema section, and
  `role_candidates` in the erasure paragraph — the three implementations kept in step by hand.
- **`docs/adr/0024-what-a-day-is-for-is-what-it-holds.md`**: why an audition and a rehearsal are
  **block kinds** rather than a kind on the day (a real day mixes them, and a day carrying both a
  casting session and an afternoon of shots could never be labelled once); why an audition block
  names **candidacies** — a person for a part, several at once when two actors are read together —
  rather than one part with the people convoked beside it; and why that link is the **one
  convocation read off a block** while every other is read off a slot: a candidate is expected at
  twenty past ten, not "on the unit today", and ADR 0018's rule — you are convoked by what you are
  linked to, and your clocks come from it — is what says so. It records, with its reasons, that a
  day kind, a slot-wide candidates band and a role-naming audition block were each built and taken
  back out. Listed in `docs/adr/README.md`, and ADR 0018 gains the pointer to it.

## 9. Milestones

Each ends with the full verification gate of `CLAUDE.md`, one commit per logical change, and a user
checkpoint before the next starts. **M1 and M2 are #56 and ship on their own**; M3 to M7 are #57.

### M1 — The candidates, in the data

`role_candidates`, its converter, its model, `OcptRoleCandidatesService` with the retained rule, the
`deleteRole` cascade, the codec's three touch points, and the erasure rule in all three
implementations. Tests: the retained transaction (retaining demotes, dropping clears, a role cast by
hand keeps its candidates untouched), the cascade, the codec round trip, and the erasure walk.

No UI at all: at the end of M1 a candidate exists and nothing shows it.

### M2 — The candidates, on screen

The candidates card, the person picker, the status `⋮`, the confirm dialog, the roles tab's pill and
count, `OcptRoleCastingProgress`, and the localization of everything above. Tests: the card's
widget test, the progress function, and the bloc's own events.

**#56 is complete and mergeable here.**

### M3 — A day has a kind — **built, then taken back out**

Shipped a `shooting_days.kind` column, three numbering series, a `Nature` picker, an agenda tint and
a shoot-only scoping of four exports. All of it was removed during M4: a day mixes casting,
rehearsal and shooting, so what a day is for is said by its blocks. Nothing of it remains but two
dropped columns in the migration and one payload-format step.

### M4 — Auditions and rehearsals in a timetable — ✅ done

The two block kinds, the block's `roleId`, `shooting_slot_candidates`, the audition row's role
picker, the slot card's fourth band beside the guests, the convocations' fourth kind and their
group. Tests: the timeline with an audition block, a candidate's convocation, the menu, the role
picker and the alerts firing (or not). **M6 takes the `roleId`, the slot table and the two controls
that fed them back out** — what a candidate is convoked by moves to the block.

### M5 — The call sheet, adapting to what a day holds — ✅ done

The audition table, the candidates listed under the cast table, both drawn only when the day's own
blocks call for them, and the named sheet's recipient union. Tests: the composition over a day of
auditions, over a day mixing auditions and shots, over a day of rehearsals, and the named sheet's
own union.

### M6 — The candidates, in the block that sees them

The convocation moves from the slot to the audition block, which is what gives each candidate an
hour of their own and lets one block read two actors of two different parts together.

1. **The data.** `shooting_block_candidates` (table, converterless, model, its read into
   `OcptSchedulePlanSnapshot`), `OcptScheduleService`'s add / remove / reorder over it, the codec's
   three touch points, and the migration of §3.4: `shooting_slot_candidates` and
   `shooting_day_blocks.roleId` stop being created and are dropped defensively where a development
   file already carries them.
2. **The timetable.** The audition row's candidacy chips and their picker replace its role picker;
   `OcptScheduleSlotCandidateAdded`/`Removed` become the block's own events, and
   `onAuditionRoleChanged` goes.
3. **The slot card.** The `Candidats` band is removed and the second row is the guests alone again.
4. **The convocations.** `ocptComputeDayConvocations` reads a candidate's three figures off the
   audition blocks naming them, the caller resolving those blocks' spans; the dock tab's candidates
   group prints the hours that come out.
5. **The call sheet.** The audition table gains its `CANDIDAT` column and prints one row per
   candidacy named, the day's candidates directory keeping the contacts.
6. **The words.** Both ARB files: the new picker and chips in, M4's slot band and role picker out.

Tests: a candidate named on two blocks of one day getting one convocation spanning both, a block
naming two candidacies of two parts, the codec round trip and the migration's defensive drops, the
audition row's own widget test, the call sheet over a day of auditions, and the alerts still firing
exactly as they did.

### M7 — The record

The documentation of §8 and ADR 0024. This plan file is deleted in the same commit.

## 10. The open point, settled

**Convoking twelve candidates at twenty-minute intervals need not cost twelve slots.** It looked as
though it would while a convocation could only be a slot (ADR 0018): twelve people at twelve hours
would have been twelve slots. It is not, because the twelve are named by **twelve audition blocks
inside one slot**, `Casting mardi` — one running order, twelve hours, twelve convocations, and the
day still reads as the single unit it is.

M4 answered that question the other way, naming the part on the block and the people on the slot.
It cost the thing the exercise was for: twelve candidates all convoked from 09:00 to 18:00, and no
way at all to read two actors of two different parts together. M4 also briefly carried a compact
rendering — a slot holding one audition drawn as a row rather than a card — and that stays gone:
there is one way to read a slot.

## 11. Verification

The full gates before each commit. `dart run tool/check_markdown.dart` for the documentation
commits. M5 and M6 each get an eyeball pass: the composition rendered to a file and read, over a
day of auditions and over one mixing them with shots, since nothing in a test says a table reads
well.

End to end in the real app through `tool/screenshot-app.sh` (release bundle rebuilt first), once at
the end of M2 and once at the end of M6:

1. a role, three candidates, one retained: the cast column follows, the roles tab's pill follows,
   and dropping the retained one empties both;
2. a day carrying one slot and three audition blocks — two of them naming one candidacy each, the
   third naming two candidacies of two different parts — the `Convocations` tab reading each
   candidate's own hours rather than the slot's;
3. the same day given a shot as well, and its call sheet printing both tables, the audition one
   naming who is seen at which hour.
