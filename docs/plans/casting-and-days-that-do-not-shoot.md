<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Casting candidates, and the days that do not shoot

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

The schedule mode has the same hole one step further: it can only describe a day that **shoots**.
The weeks of auditions and rehearsals a production runs before the first shooting day are planned
exactly like shooting days — a date, a place, people convoked, a running order — and the mode
already has every one of those pieces. What it lacks is a way to say a day is *not* a shooting day,
and to put something other than a shot in a block.

The outcome: a role carries its candidates and the one retained writes the cast column; a day
carries a **kind**, and a casting or rehearsal day is planned, convoked, alerted on and printed
like the shooting days beside it.

## 2. Decisions taken before writing this

Eight, all settled with Benoit before a line of this plan was written:

1. A candidate is convoked by a **fourth slot link table**, `shooting_slot_candidates`, beside
   crew, cast and guests. ADR 0018 is untouched: you are convoked because you are **linked to a
   slot**, never because a block names you.
2. **One retained candidate at a time.** Retaining writes `roles.personId` and demotes the previous
   retained one to `seen`; dropping the retained one clears the column back to null. The role
   header's own cast picker **stays editable** and writes `roles.personId` alone — a production
   that ran no auditions casts directly, and touches no candidate row doing it.
3. **Separate numbering series**: `J3` keeps counting shooting days only; a casting day is `C1`, a
   rehearsal `R1`, each ranked in its own series in date order, each rendered through `Tr`
   (`D`/`C`/`R` in English) exactly as `ocptScheduleDayTagLabel` already renders the first.
4. The **call sheet learns a casting variant**: same header, same time bands, same crew note, same
   directories; the `SEQ / PLANS / EFFET / DÉCORS / RÔLES` table becomes
   `HORAIRE / RÔLE / CANDIDAT / CONTACT`, and the cast table becomes the day's convoked candidates.
5. The candidates live in a **`Candidates` card on the role sheet**, under the casting card: one
   row per candidate (avatar, name, status pill, audition date, a foldable note), the retained one
   pinned on top, a person picker at the bottom to add one.
6. The **roles tab wears a per-row pill** — cast, candidates in progress, nothing yet — and its
   header counts `12 roles · 5 cast`.
7. A day's kind is picked **in the day inspector, right under the date and above the status**, the
   twin of the status picker already there.
8. The audition table prints the candidate's **contact**, the sheet being what an assistant
   director phones down.

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

### 3.2 `shooting_slot_candidates` (new, #57)

The fourth link kind, modelled column for column on `shooting_slot_cast`, which names a role rather
than a person for the same reason this one names a **candidate row** rather than a person: the
convocation is about somebody being seen *for a part*, and two candidacies of one person are two
convocations.

| Column | Type | Says |
| --- | --- | --- |
| `id` | text | UUID |
| `slotId` | text → `shooting_slots` | which slot convokes them |
| `roleCandidateId` | text → `role_candidates` | who, for which part |
| `isDeleted` | bool | ADR 0010 |

### 3.3 `shooting_days.kind` (#57)

A new non-null text column with a converter, defaulting to `shoot` — the literal `'shoot'` written
out in the `Constant`, as `status` and `shots.status` already are, an enum's `.name` not being a
compile-time constant.

```dart
enum OcptShootingDayKind { shoot, casting, rehearsal }
```

Migration: every existing row is a `shoot` day, which the default answers on its own.

### 3.4 `shooting_day_blocks` (#57)

Two new nullable columns and two new kinds:

- `roleId` (→ `roles`, nullable) and `roleCandidateId` (→ `role_candidates`, nullable), non-null
  **iff** `kind` is `audition` — the discriminator idiom `shotId` and `sceneId` already follow.
- `OcptShootingBlockKind.audition`: one candidate, seen for one role, for this block's duration.
  One block per candidate: *"these four people, for that part, twenty minutes each"* is four
  blocks, which is also what makes the audition table print four rows.
- `OcptShootingBlockKind.rehearsal`: names a **sequence** through the existing `sceneId`, exactly as
  `hold` already does, and needs no column of its own.

**Both new kinds are shooting blocks** for `ocptComputeSlotTimeline` and the PAT band, joining
`shot` and `hold`: they are the working time of the day they sit on, and a candidate or an actor
owed a band on a rehearsal day is owed it for the same reason a cast member is on a shooting day.
Nothing else in `lib/utils/ocpt_shooting_day_timeline.dart` moves.

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

## 5. Issue #57 — the days that do not shoot

- **`OcptScheduleService`** learns the day kind: `createDay` takes one (defaulting to `shoot`),
  `setDayKind` writes it, and the read-time ranking splits into **three series** — the rank of a
  day among the live days **of its own kind**, in date order, `sortKey` still the tiebreaker.
  `OcptShootingDay.dayNumber` keeps its name and its meaning within its series; `ocptScheduleDayTag`
  (`lib/ui/utils/ocpt_schedule_labels.dart`) takes the kind beside the number and picks the prefix
  through `Tr`. The workbook, having no `Tr`, takes the three prefixes as
  `OcptShotListXlsxLabels` already takes one.
- **The day inspector** gains the `Nature` picker under the date and above the status, built from
  the same `PopupMenuButton` shape the status already uses, withheld under a read-only preview.
- **The timetable's `+ Block` menu is scoped by the day's kind**: a shooting day offers what it
  offers today plus `Rehearsal`; a casting day offers `Audition`, `Rehearsal` and the milestones,
  and **not** `Shot`. It is a scoping of the menu, not a rule in the schema: a block already there
  when the kind changes is left alone and keeps working, because refusing to draw a row a file
  holds is how a plan becomes unreadable. An `Audition` block opens
  **`OcptScheduleCandidatePickerDialog`** — the role, then its candidates, the mode's to open as
  `OcptScheduleShotPickerDialog` already is.
- **The slot card** gains a fourth band under crew, cast and guests: `Candidates`, drawn on a
  casting day alone (there is nobody to audition on a shooting day), fed by
  `shooting_slot_candidates` and reading each row as the candidate's name and the part they are
  seen for.
- **`ocptComputeDayConvocations`** gains its fourth link kind. A candidate's convocation reads
  exactly like everybody else's — arrival, PAT band over the slot's shooting blocks (auditions
  included), departure — and the `Convocations` dock tab gains a **trailing candidates group**,
  after crew and cast and before the guests, on the same argument that gives guests theirs.
- **The alerts**, scoped by kind rather than rewritten:
  - `OcptScheduleRoleNotConvokedAlert` is about a role a **placed shot** plays, so it cannot fire
    on a day carrying no shot block; it needs no change and gets none.
  - Every alert **about people** — unavailable, double-booked, past their maximum, short of the
    minimum rest — fires on the new days unchanged, and that is the point: a rehearsal the day
    before a 07:00 call eats the same turnaround a shooting day does.
  - `OcptScheduleLocationUncoveredAlert` and `OcptSchedulePermitNotValidAlert` also fire unchanged
    — a casting studio is booked over a window like anywhere else.
  - **No new alert kind**, and deliberately none: "a candidate convoked on no slot" would be an
    opinion about how a production runs its auditions.
- **The agenda** tints the two new kinds: the `Colour by` control gains no third entry, the kind
  being a fact about the day rather than a colouring choice — a non-shooting day carries its own
  tint in all three presentations whatever the current `Colour by` is, with the shooting days
  keeping the existing behaviour. One fixed ARGB pair in
  `lib/constants/ocpt_schedule_effect_palette.dart`'s neighbourhood, like every other palette that
  must read the same in every project.
- **The presence grid** counts the new days as `working`, unchanged: somebody at a rehearsal is
  there. The **positions matrix** likewise needs nothing — a casting day's crew is crew.
- **The shooting plan, the day-out-of-days, the one-line schedule and the sides keep listing
  shooting days only**, and their day pickers say so. A DOOD is a document about a cast's shooting
  days; a one-line schedule is the shoot in one line. This is a **scoping**, stated in each
  service's doc comment, not a filter invented at the call site.

## 6. The call sheet's casting variant

`OcptCallSheetPdfService` keeps **one composition** and branches on the day's kind, rather than
growing a second service: the header, the per-slot time bands, the events, the crew note, the
locations, the sun block and both directories are the same paper, and a second service would drift
from them section by section.

What the casting variant replaces:

| Shooting day | Casting day |
| --- | --- |
| `SEQ / PLANS / EFFET / DÉCORS / RÔLES` | `HORAIRE / RÔLE / CANDIDAT / CONTACT` |
| the cast table (every role the day calls for) | the day's convoked candidates |

- The audition table is interleaved with the non-shooting blocks as full-width milestone rows,
  exactly as the shot table already is, and prints a block's `crewNote` under its row.
- `CONTACT` is the candidate's own phone, read off their `people` row, an em dash where there is
  none. A candidate convoked on the day but named by no audition block still gets a row in the
  **table**, with an em dash for its hour: that is the same honesty the shooting sheet's cast table
  already practises when it prints a role nobody convoked.
- A **rehearsal day** prints the shooting-day shape with its rehearsal blocks named by their
  sequence, and its cast table unchanged: a rehearsal convokes roles, not candidates.
- The **named** call sheet follows: its recipient union is the day's convocations, which now
  include candidates, and what a named sheet narrows stays the timetable and only the timetable.

## 7. Localization

Both ARB files, English and French, the French rule holding throughout — **a screenplay's scene is
« une séquence »**, and neither the audition table nor the rehearsal block may reintroduce the other
word. New keys, in families: the five candidate statuses, the candidates card's title, its picker
and its `⋮` entries, the confirm dialog's own words, the roles tab's pill labels and its
`N roles · M cast` count, the three day kinds and their tag prefixes, the `Nature` label, the two
new block kinds, the candidate picker's own words, the `Candidates` slot band and convocation group,
and the audition table's four column headings.

## 8. Documentation

- `docs/architecture/resources.md`: the candidates card, the retained rule, the service, the roles
  tab's progress reading, and `role_candidates` joining the erasure rule.
- `docs/architecture/schedule.md`: the day kind and the three numbering series, the two block kinds,
  the fourth link table and what it does **not** change about ADR 0018, the alert scoping, the
  agenda tint, and the call sheet's casting variant.
- `docs/architecture/foundations.md`: the two new synchronised tables in the schema section, and
  `role_candidates` in the erasure paragraph — the three implementations kept in step by hand.
- **`docs/adr/0024-a-day-has-a-kind.md`**: why a kind column on `shooting_days` rather than a
  second table of "other days" (a casting day is a day: it has slots, blocks, convocations, alerts
  and paperwork, and a parallel table would have to grow every one of them again), why the
  numbering splits into series rather than skipping numbers, and why a candidate is convoked by a
  link table rather than by the block that names them — ADR 0018 restated on purpose, with the
  cost that comes with it (§10). Listed in `docs/adr/README.md`.

## 9. Milestones

Each ends with the full verification gate of `CLAUDE.md`, one commit per logical change, and a user
checkpoint before the next starts. **M1 and M2 are #56 and ship on their own**; M3 to M5 are #57.

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

### M3 — A day has a kind

`shooting_days.kind`, the enum, the three numbering series, `ocptScheduleDayTag`, the inspector's
`Nature` picker, the agenda tint, and the export scoping of the four documents that stay
shoot-only. Tests: the ranking (a rehearsal inserted mid-shoot renumbers nothing), the tag, and the
day picker scoping.

### M4 — Auditions and rehearsals in a timetable

The two block kinds, the block's two new columns, `shooting_slot_candidates`, the candidate picker
dialog, the slot card's fourth band, the convocations' fourth kind and their trailing group, and the
`+ Block` menu scoping. Tests: the timeline with an audition block, a candidate's convocation, the
menu scoping, and the alerts firing (or not) per kind.

### M5 — The casting call sheet

The call sheet's branch, the audition table, the candidates replacing the cast table, and the named
sheet's recipient union. Tests: the composition over a casting day, over a rehearsal day, and the
named sheet's own union.

### M6 — The record

The documentation of §8 and ADR 0024. This plan file is deleted in the same commit.

## 10. The open point, stated rather than buried

**Convoking twelve candidates at twenty-minute intervals costs twelve slots.** That follows from
decision 1 and from ADR 0018 as it stands: a convocation *is* the slot you are linked to, so two
people arriving at different hours are two slots, and the day view draws one card per slot. It is
the same trade ADR 0018 already accepts for an actor called early for make-up, and it is honest —
the file says what is actually happening, and it prints. But a casting day is where it bites
hardest, twelve slot cards being a lot of surface for twelve twenty-minute auditions.

M4 therefore adds a **compact slot rendering on a non-shooting day**: a slot whose whole content is
one audition block draws as a row rather than a card, the day view falling back to the full card the
moment it carries more. That is a rendering, not a second model, and it is the one piece of this
plan I would most like reviewed before it is built — the alternative, letting an audition block
carry its own convocation, buys one gesture and costs the rule that makes every convocation in the
app readable the same way.

## 11. Verification

The full gates before each commit. `dart run tool/check_markdown.dart` for the documentation
commits. The two PDF milestones (M5) additionally get an eyeball pass: the composition rendered to a
file and read, a casting day and a rehearsal day, since nothing in a test says a table reads well.

End to end in the real app through `tool/screenshot-app.sh` (release bundle rebuilt first), once at
the end of M2 and once at the end of M5:

1. a role, three candidates, one retained: the cast column follows, the roles tab's pill follows,
   and dropping the retained one empties both;
2. a casting day created, its kind picked, `C1` on the agenda while the shooting days keep their
   own numbers;
3. two candidates convoked on two slots, an audition block each, and the `Convocations` tab reading
   their hours;
4. the casting call sheet exported and opened.
