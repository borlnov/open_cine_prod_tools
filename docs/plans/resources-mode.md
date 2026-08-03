<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 26 — The resources production mode

This document is the implementation strategy for the "resources" production mode: the people, the
roles, the locations and the physical elements a production has to keep track of. It is written for
the Sonnet 5 agents that will build the feature, orchestrated and reviewed by the main session,
with a user checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this plan
assumes its architecture, ways of working, coding standards, licensing rules and verification
gates, and does not repeat them.

This plan implements [#45](https://github.com/borlnov/open_cine_prod_tools/issues/45), whose scope
is written from §2 and §3. The branch is `45-resources-mode`.

---

## 0. Prerequisite — project versions

**Project versions ([#20](https://github.com/borlnov/open_cine_prod_tools/issues/20)) has shipped**:
PR #44 merged it into `main` on 3 August 2026, at schema **v5** and payload format **1**. This step
therefore starts from a `main` that already has versions in it, and takes schema **v6** and payload
format **2**.

That ordering was not a preference. §4.8 is the reason: a version payload is a hand-written mirror
of the schema, stored inside users' `.ocpt` files, and eleven new tables that the payload does not
carry would make every restore silently wipe the resources of the working copy. The two features
have to be reconciled once, deliberately, in this step — not discovered later from a bug report.

### 0.1 The v4 collision, and how it was resolved

Worth knowing, because it is why versions is v5 rather than v4 and why this step is v6. The
versions branch and the scenario coverage export were cut from the same `main` at v3 and each took
the next free number: coverage merged first and shipped `shots.abbreviation` as **v4** in
`v0.1.0-alpha.2`, freezing that meaning into users' files, while the versions branch already meant
v4 as `project_versions` and v5 as its `contentDigest`. Merged as it stood, an alpha.2 file would
have run the 4 → 5 step alone and tried to add a column to a table that was never created — the
project would no longer have opened at all.

It was fixed inside PR #44 rather than here: the two steps were folded into a **single v5** that
creates `project_versions` with `contentDigest` already declared on it, and the payload codec
learnt `shots.abbreviation` so a restore stops degrading the coverage export's bar labels. The rule
that would have prevented it is now written into
[ADR 0007](../adr/0007-schema-migration-policy.md) — a schema number is allocated at merge time,
not at branch time, and whichever of two branches in flight merges second renumbers. **This step's
v6 is claimed under that rule**: it is provisional until M1 merges.

---

## 1. Application context

### 1.1 What the app is

Open Cine Prod Tools is an open-source (Apache-2.0) suite of film-production tools: a Fountain
screenplay editor and a shot list (découpage technique), inside a workspace shell that hosts the
production modes. Storage is local only — one SQLite file per project (`.ocpt`, via drift). There
are no accounts and no network yet, but the schema is already the sync-ready one
([ADR 0010](../adr/0010-sync-ready-data-model-prerequisites.md)): tombstones instead of deletes,
`sortKey` fractional indexes instead of renumbered positions, and a `row_field_versions` sidecar.

### 1.2 Structure that matters here

- **`OcptProjectsManager`** owns the one project open at a time as an `OcptOpenProjectModel`
  (`path`, `name`, `primaryScreenplayId`, `database`, plus `fileDatabase`, `previewedVersion` and
  `previewedPageSetup` since versions landed) and owns the per-domain services:
  `OcptScreenplayService`, `OcptSceneIndexService`, `OcptShotListService`,
  `OcptShotCoverageService`, `OcptProjectVersionsService`. This step adds four siblings to that
  list.
- **Every read and write the user drives goes through `currentProject.database`.** No bloc holds a
  connection of its own — which is what lets a version preview swap an in-memory database in behind
  every mode. That is not a figure of speech any more: `database` *is* the previewed database while
  a preview is up, and `fileDatabase` is the project file. A mode that held its own connection would
  keep showing the working copy while the rest of the app previewed a version; the resources mode
  must not become the first one to do that.
- **Read-only propagation.** While a version is previewed, `OcptOpenProjectModel.isReadOnly` — a
  getter, `previewedVersion != null` — is true and every mode must refuse edits. The resources mode
  is edit-heavy, every sheet field writes, so this is not a detail it can bolt on at the end: §4.7
  makes it a bloc-state flag every field reads, in the **withhold-don't-disable** idiom the app
  already uses.
- **`OcptWorkspaceShell`** is a stateless slot widget (title, toolbar actions, overflow entries,
  left panel, right panel, centre, status bar, dock controller). The end of its toolbar is
  shell-owned chrome; a mode only supplies what it actually has. `OcptWorkspaceMode` is the enum
  the bottom `OcptWorkspaceModeSwitcher` selects from, persisted through
  `OcptPropertiesManager.workspaceMode`.
- **The shot list mode is the template to copy.** `lib/ui/pages/workspace/modes/shot_list/` is a
  mode that owns its bloc, its docks, its inspector and its export; everything this step builds has
  a direct counterpart there, down to the `OcptShotListXlsxLabels` trick that keeps `Tr` out of the
  managers.
- **The scene index is the model for reconciliation.** `OcptSceneIndexService` reconciles the
  parsed screenplay against stored `scenes` rows in three passes and never destroys a row; the shot
  list keeps `orphanedHeading` and an `OcptShotRemovedCharacterAlert` when a scene or a character
  goes away. §4.4 does the same for roles.

### 1.3 Toolchain reminder

The host has **no usable Flutter SDK**. Every Flutter/Dart/`reuse` command runs in the
devcontainer:

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

Git commands run on the host, from the repo root.

---

## 2. Why this step exists

Today the app knows the screenplay and the shots. It knows nothing about **who** shoots them,
**where**, and **with what** — and those three questions are what a production actually spends its
days answering. The reference documents in `debug/ressources/` are the real spreadsheets of two
short films, and every one of them is a hand-maintained answer to one of those questions:

- `Listes - Intervenants, lieux, matériels…xlsx` — an address book (name, function, mail, phone,
  address, transport autonomy, accommodation, train details), a locations sheet (location, set,
  address, owner), and two equipment sheets (item, quantity, category, owner, who brings it,
  picked up?, where?, returned?, why?, scenes, photos).
- `Liste matériel.xlsx` — the same equipment tracking, grouped by department (props, HMC, lighting,
  video, sound, production), with owner / bringer / picked-up / ready / returned columns.
- `Dépouillement v2.xlsx` — the per-scene breakdown, which is where the elements above get attached
  to scenes (roles, actions, props, set elements, HMC and prosthetics, extras).
- The two `FeuilleDeService-*.docx` and `Plan de travail et planning.xlsx` — the documents that
  **consume** all of the above: every call sheet reprints the crew list with positions, phones and
  hours, the cast with roles and call times, and the location with its address and access notes.

That last point is the argument for building this before the schedule mode: a call sheet is 80%
resource data, and generating one from scratch is only reasonable once the resources exist as data.

This step ships the **catalogue and its links to the screenplay**. It deliberately stops short of
per-day scheduling (§6).

---

## 3. The design being implemented

The reference is the *OpenCineProdTools App Design* mock-up in the Claude Design project
`5bc089e5-85ae-42c2-b8c4-445abc90ecf4`, whose `ressources` mode has four tabs — **Personnes,
Rôles, Lieux, Éléments** — a list in the left dock and the selected item's sheet in the centre.
Where this plan and the mock-up differ, **this plan wins**; the differences are recorded in §3.3.

### 3.1 What each tab is

| Tab | Left dock | Centre sheet |
| --- | --------- | ------------ |
| **People** | Avatar + name + role chips + positions + day count | Photo slot, contact grid (structured postal address, §4.2.1), "functions on the film" (roles then positions, their scope read-only), meals/health/skills, logistics, HMC card (measurements, sizes, notes), image-rights card, unavailabilities, notes |
| **Roles** | Role name + cast member + other roles held | A table of the whole cast: n°, role, actor, other roles held — clicking a row opens that person's sheet |
| **Locations** | Location name, colour bar, permit badge | Address + GPS + contact, filming permit card, sets in this location, parking / power / facilities, noise and schedule constraints, scouting photos, shooting days |
| **Elements** | Grouped by category | Code, name, detail line, days — the whole catalogue as grouped cards |

The status bar reads `N people · N roles · N positions · N locations · N elements`, straight from
the mock-up.

### 3.2 The two ideas that carry the mode

**A person is one row, whatever they do on the film.** The mock-up is explicit about it and so are
the reference documents: Benoît is *réalisateur* and *régie*; Xavier is *assistant chef op* and
*ingé son au besoin*; Sofia plays a role on some days and holds the script on others; the owners of
the location are also in the address book. So `people` is the address book, and both the roles and
the crew positions are **links onto it**, never copies of a name. A person sheet therefore shows
one merged "functions on the film" list, roles first.

**An element is anything that must be present on a given day and is not a person.** Props, set
dressing, costumes, vehicles, animals, special equipment, generators, and even a block of extras —
the reference spreadsheets keep them in one table with a category column, because the tracking
columns are identical for all of them (owner, who brings it, picked up, ready, returned, where).
This plan keeps that single table (§4.2.6) rather than one table per department.

### 3.3 Where this plan differs from the mock-up

| # | Difference |
| - | ---------- |
| 1 | **Crew positions are assigned at project level; their scope belongs to the schedule mode.** The mock-up assigns positions inside the planning's `créneaux`. A `person_positions` row therefore says only *that* a person holds a function, never *when*: the scope is shown on the person sheet as a read-only column reading "defined in the schedule", and the schedule mode is what will fill it. One person may hold several functions over one slot (script supervisor *and* general assistant), which is why the scope can never live on the assignment row as a single free-text answer. |
| 2 | **Photos and documents are referenced, never embedded** (§4.3). The mock-up shows "drop a photo" and "upload the signed PDF"; this step stores a path and shows a thumbnail, and no bytes enter the `.ocpt`. |
| 3 | **No document generation.** The mock-up's "Generate the document" button for image rights is out of scope (§6): a legally meaningful release needs a template, jurisdiction-aware wording and a title-page-style editor. The status field and the reference to a signed PDF ship; the generator does not. |
| 4 | **The resources mode's right dock holds one tab, `Versions`, and no inspector.** The mock-up hides the inspector for this mode and this plan agrees — the centre sheet *is* the inspector. But the `Versions` tab is hosted by *every* mode's right dock since project versions landed, and §4.7 has this mode mixing in the very bloc mixin that feeds that panel; a mode with no right panel would be the only one from which a user cannot seal or browse a version. So the dock exists, `OcptResourcesRightDockTab` has a single entry, and the dock is closed by default. |
| 5 | **Roles are reconciled from the screenplay, not typed from nothing** (§4.4), and a role for a non-speaking part can still be added by hand. The mock-up shows a static list. |

### 3.4 Decisions

Decisions 1 to 9 were settled with Benoit before this plan was finalised; 10 to 14 came out of his
review of the People tab once M2 was built, and amend it. **None of them is an open question.**

| # | Decision |
| - | -------- |
| 1 | **This step comes after project versions**, on top of schema v5, and takes schema **v6**. See §0 and §4.8. |
| 2 | **Binary assets are references**, never bytes: an `assets` table holds a path, and nothing enters the `.ocpt`. See §4.3 and [ADR 0013](../adr/0013-binary-assets-referenced-by-path.md). |
| 3 | **A role is auto-created for every speaking character** the screenplay has, on the same reconciliation pass the scene index already runs. See §4.4. |
| 4 | **The Claude Design mock-up is the reference for the four sheets** and is followed as-is; Benoit is only asked about what the mock-up leaves unsaid. |
| 5 | **Crew positions are assigned at project level; the schedule mode owns their scope.** A `person_positions` row is `(person, position)` and nothing else — no stored scope. The reference call sheet of 13 August has *David on sound in the morning, Johan on sound in the afternoon*, and the same person may hold two functions over one slot: both are per-slot facts about a shooting day, so they are answered by the schedule mode's own tables, and the person sheet shows the scope as a read-only column until it exists. |
| 6 | **Deleting a person writes a tombstone and blanks their personal columns** — an erasure, not a hide. See §4.9, which is where this collides with versions. |
| 7 | **The mode switcher becomes `screenplay · shotList · resources · schedule · budget`**: the three implemented modes first, the two empty ones last. This reorders `budget` and `schedule`, which is safe — `OcptPropertiesManager.workspaceMode` persists the enum by **name**, not by index. |
| 8 | **One `elements` table with a category and a free sub-category**, not one table per department. Both reference spreadsheets already do this, and for the same reason: the tracking columns are identical whatever the item is. |
| 9 | **Scene ↔ element links ship with an editor on the element sheet**; the per-scene breakdown *view* does not (§6). |
| 10 | **A postal address is structured, not a single free-text line**: `addressLine1`, `addressLine2`, `postalCode`, `city`, `region`, `country`, on `people` **and** on `locations`. That is the field set every international address form settles on, and the one an XLSX column, a call-sheet line or a later geocoding can each read on its own. |
| 11 | **The email field is checked, never blocked.** Every person-sheet field autosaves as it is typed, so a validity check that refused a write would refuse half of every address as it is being entered. The value is stored exactly as typed; a malformed one is flagged under the field once it loses the focus. See §4.6. |
| 12 | **An unavailability spans a date range and a slot within it**: `startDate` → `endDate` (the same day by default), plus full day / morning / afternoon / a custom `startMinute`–`endMinute` window. Several rows may cover one date, which is how "unavailable 14:00–17:30 and again after 20:00" is said. Its reason is a multi-line field: one line was not enough to hold a real one. |
| 13 | **The costume sizes leave the meals/health/skills card for an HMC card of their own**, holding what a wardrobe sheet always carries — height, chest, waist, hips, shoe size, top and bottom sizes — plus the HMC notes that until then were a card of their own. Diet, allergies and skills have nothing to do with a fitting. |
| 14 | **All four amendments are applied to schema v6 in place, not as a v7.** v6 is provisional until M1 merges ([ADR 0007](../adr/0007-schema-migration-policy.md)) and no released build has ever written it, so there is no user file to migrate — a v7 whose only content is fixing a v6 that never shipped would be a permanent lie in the migration history. |

---

## 4. Architecture

### 4.1 Overview

```text
lib/types/                      ocpt_workspace_mode.dart              (+ resources)
                                ocpt_crew_department.dart
                                ocpt_element_category.dart
                                ocpt_element_source_kind.dart
                                ocpt_permit_status.dart
                                ocpt_image_rights_status.dart
                                ocpt_role_kind.dart
                                ocpt_half_day.dart
                                ocpt_asset_kind.dart
                                ocpt_resources_tab.dart
                                ocpt_resources_right_dock_tab.dart
lib/constants/                  ocpt_crew_positions.dart
lib/models/database/tables/     ocpt_people_table.dart
                                ocpt_person_positions_table.dart
                                ocpt_person_unavailabilities_table.dart
                                ocpt_person_skills_table.dart
                                ocpt_roles_table.dart
                                ocpt_locations_table.dart
                                ocpt_sets_table.dart
                                ocpt_scene_sets_table.dart
                                ocpt_elements_table.dart
                                ocpt_scene_elements_table.dart
                                ocpt_assets_table.dart
                                ocpt_local_erasures_table.dart        (local, never synchronised)
lib/models/database/            ocpt_project_database.dart            (schema v6 + migration)
lib/models/                     ocpt_person.dart
                                ocpt_person_position.dart
                                ocpt_role.dart
                                ocpt_location.dart
                                ocpt_set.dart
                                ocpt_element.dart
                                ocpt_asset_ref.dart
                                ocpt_resources_snapshot.dart
                                ocpt_resources_xlsx_labels.dart
                                ocpt_removed_role_alert.dart
lib/managers/projects/services/ ocpt_people_service.dart
                                ocpt_role_index_service.dart
                                ocpt_locations_service.dart
                                ocpt_elements_service.dart
lib/managers/projects/services/ ocpt_project_version_codec.dart       (payload format 2)
                                ocpt_project_versions_service.dart    (restore the new tables)
lib/managers/export/services/   ocpt_resources_xlsx_export_service.dart
lib/ui/pages/workspace/modes/resources/
                                resources_mode.dart
                                resources_bloc.dart
                                resources_event.dart
                                resources_state.dart
                                widgets/…                              (see §4.6)
lib/ui/utils/                   ocpt_resources_labels.dart
```

### 4.2 Database — schema v6

Twelve tables, **eleven of them synchronised**: each of those carries the two sync-ready columns
ADR 0010 requires — `isDeleted`, and `sortKey` where the rows are ordered — and every read filters
tombstones out. Ids are UUIDs. The twelfth, `local_erasures` (§4.2.7), is deliberately none of that.
The migration is additive: `onUpgrade` from 5 to 6 creates the twelve tables and touches nothing
that exists.

The schema number is claimed under [ADR 0007](../adr/0007-schema-migration-policy.md): **v6 is
provisional until M1 merges**, and if another branch takes 6 first, this one renumbers.

#### 4.2.1 `people`

The address book. One row per human, whatever they do on the film.

| Column | Type | Notes |
| ------ | ---- | ----- |
| `id`, `sortKey`, `isDeleted` | | |
| `firstName`, `lastName` | text | Both free; the display name and the initials are derived at read time, never stored. |
| `email`, `phone` | text | The two contact columns every reference document has. `email` is checked for shape on blur and stored as typed (decision 11). |
| `addressLine1`, `addressLine2`, `postalCode`, `city`, `region`, `country` | text | The structured postal address of decision 10. Six columns rather than one because a call sheet prints them in a country's own order, an export gives each a column, and a postal code is the one part of an address that is worth sorting or searching on. |
| `colorIndex` | int | Indexes `ocptCoveragePalette`, exactly as a shot's colour does, so a person keeps one avatar colour everywhere. |
| `birthDate` | date, nullable | Age and minor status are **derived**, never stored: a stored "15 ans" is wrong within a year. |
| `minorNotes` | text | The legal framing when a person is a minor (hours, guardian presence, DDETS authorisation). |
| `isTransportAutonomous` | bool, nullable | Tri-state: unknown until answered — the reference sheet's own third value. |
| `accommodationNotes`, `travelNotes` | text | "Chez Camille", and the birth date + loyalty card number a train booking needs. |
| `dietaryNotes`, `allergies` | text | Both reference documents track them, and a call sheet's catering line depends on them. |
| `sizeTop`, `sizeBottom`, `sizeShoes` | text | Costume sizes, free text because real lists mix `38`, `M` and `Haut 38`. |
| `measurementHeight`, `measurementChest`, `measurementWaist`, `measurementHips` | text | The body measurements a wardrobe sheet always carries (decision 13). Free text like the sizes above, and for the same reason: real sheets mix `178`, `1m78` and `5'10"`, and a numeric column would have to pick a unit the user never agreed to. |
| `hmcNotes` | text | Makeup/hair/costume continuity notes, shown on the same HMC card as the sizes and measurements. |
| `imageRightsStatus` | enum | `notApplicable`, `toGenerate`, `generated`, `signed`. |
| `imageRightsDate` | date, nullable | |
| `imageRightsAssetId` | text, nullable | → `assets` |
| `photoAssetId` | text, nullable | → `assets` |
| `notes` | text | |

#### 4.2.2 `person_positions`, `person_skills`, `person_unavailabilities`

- **`person_positions`** — `personId`, `positionId` (a stable code from `ocptCrewPositions`, or
  empty when the position is a free label), `customLabel`, `sortKey`, `isDeleted`. **No scope
  column** (decision 5): the row says that a person holds a function, and the schedule mode's own
  tables will say over which slots — including the case of one person holding two functions over
  the same slot, which a single scope string on this row could never express.
  `ocptCrewPositions` (`lib/constants/`) is a `const` catalogue of `(id, ARB key, department)`
  covering the positions the reference call sheets print — direction, image, sound, art department,
  HMC, production — so the label is localised and the id stays stable for the schedule mode.
  `OcptCrewDepartment` is the enum grouping them.
- **`person_skills`** — `personId`, `label`, `sortKey`, `isDeleted`. Driving licences, swimming,
  languages, instruments: chips on the person sheet, and the thing an AD searches on.
- **`person_unavailabilities`** — `personId`, `startDate`, `endDate`, `slot`
  (`OcptUnavailabilitySlot { fullDay, morning, afternoon, custom }`), `startMinute`/`endMinute`
  (minutes from midnight, both null unless `slot` is `custom`), `reason`, `isDeleted`. A range
  rather than a date because a week away is one answer, not seven; a slot rather than a half-day
  alone because "unavailable from 14:00 to 17:30" is what a real conflict looks like (decision 12).
  Several rows may cover one date, which is how two windows in one day are said. Read by the
  schedule mode later; already worth capturing.

#### 4.2.3 `roles`

`id`, `screenplayId`, `name`, `sortKey`, `isDeleted`, plus:

| Column | Notes |
| ------ | ----- |
| `personId` | nullable → `people`. The casting. |
| `kind` | `OcptRoleKind { speaking, silent, extra }` — a speaking role comes from the screenplay, the other two are added by hand. |
| `isFromScreenplay` | Whether §4.4 owns this row's name. |
| `orphanedName` | The name the character had when it disappeared from the screenplay; null while it is still there. Mirrors `shots.orphanedHeading`. |
| `castingNotes` | |

The role **number** shown in the UI is the rank in `sortKey` order, derived at read time — never a
stored column, for the same reason a shot code is not stored.

#### 4.2.4 `locations` and `sets`

**`locations`**: `id`, `name`, `colorIndex`, the same six structured address columns `people`
carries (`addressLine1`, `addressLine2`, `postalCode`, `city`, `region`, `country`, decision 10 —
an address is one shape wherever it appears, and a location's is the one printed on a call sheet),
`latitude`/`longitude` (real,
nullable), `contactPersonId` (nullable → `people`, because the reference address book *does* list
the location owners), `contactNotes`, `permitStatus` (`OcptPermitStatus { notNeeded, toRequest,
requested, granted, refused }`), `permitLabel`, `permitDate`, `permitAssetId`, `parkingNotes`,
`powerNotes`, `facilitiesNotes`, `constraintsNotes`, `notes`, `sortKey`, `isDeleted`.

Those five notes columns are not padding: they are exactly the five things the mock-up's location
sheet shows and the five things that decide whether a day is shootable — where the truck goes, what
amperage exists, whether there is a toilet, and what the neighbours will tolerate.

**`sets`** (décors): `id`, `locationId`, `code` (`A`, `B`), `name`, `notes`, `sortKey`,
`isDeleted` — the "La maison des Pains / Hangar, Jardin, Escalier, Cuisine" structure the reference
sheet has, and the mock-up's `decors` list.

**`scene_sets`**: `id`, `sceneId`, `setId`, `isDeleted`. Which scene is shot in which set,
many-to-one. §4.5 explains where the suggestion comes from.

#### 4.2.5 `assets`

`id`, `kind` (`OcptAssetKind { personPhoto, locationPhoto, elementPhoto, document }`), `path`,
`label`, `addedAt`, `sortKey`, `isDeleted`, plus a nullable owner column per subject
(`personId`, `locationId`, `elementId`) so a location can hold its fourteen scouting photos.

See §4.3 for why this holds a path and not bytes.

#### 4.2.6 `elements`

Everything that must be on set and is not a person.

| Column | Notes |
| ------ | ----- |
| `id`, `sortKey`, `isDeleted` | |
| `category` | `OcptElementCategory { prop, setDressing, costume, makeup, vehicle, animal, specialEquipment, camera, lighting, sound, production, catering, extras, other }` — the categories the two reference spreadsheets use, aligned with standard breakdown practice. |
| `subCategory` | Free text, for a production's own finer grouping. |
| `name`, `code` | `code` is the short label a breakdown margin has room for, like a shot's `abbreviation`. |
| `quantity` | **Text**, not an integer: the real sheets say `plein`, `×5`, `2 par jour`. |
| `sourceKind` | `OcptElementSourceKind { owned, borrowed, rented, toBuy, toMake, alreadyOnSet }`. |
| `ownerPersonId`, `ownerNotes` | The owner is a person when they are in the address book ("M. et Mme Schmit"), free text when they are an organisation ("Asso", "Rétro-Loc"). |
| `broughtByPersonId` | The reference sheets' "Qui l'apporte ?" — a different question from who owns it, and the one that actually fails on the day. |
| `storageNotes` | "Où ?" — "sous l'abri, déjà sur place". |
| `isSecured`, `isReadyForShoot`, `isReturned` | The three checkboxes both spreadsheets share, in that order: got it, it is on the truck, it went home. |
| `cost` | int (cents), nullable — read by the budget mode later, written here because this is where the information exists. |
| `purposeNotes`, `notes` | "Pourquoi ?" and everything else. |
| `photoAssetId` | nullable → `assets` |

**`scene_elements`**: `id`, `sceneId`, `elementId`, `quantity`, `notes`, `isDeleted` — the
*dépouillement* link, and what turns the catalogue into a per-day requirements list once the
schedule mode exists.

#### 4.2.7 `local_erasures`

`personId`, `erasedAt`. The one table of this step that is **local**, on the exact model of
`project_versions`: no `isDeleted`, no `sortKey`, no `row_field_versions` stamp, never
synchronised, never captured in a version payload, and its rows may be deleted for real. It is what
makes decision 6's erasure survive a version restore; §4.9 is the whole argument, and it is the
reason this list is a table rather than a key of `project_info.settingsJson`.

### 4.3 Binary assets — references, and an ADR

The mock-up drops photos and uploads signed PDFs. Three ways to store them:

1. **References** — the `assets` row holds a path; the app reads the file to show a thumbnail.
2. **Blobs** in the `.ocpt`.
3. **A bundle** — a directory beside the `.ocpt`, or the `.ocpt` becoming one.

This plan picks **1** for this step, and the decision outlives it, so it is recorded in
[ADR 0013](../adr/0013-binary-assets-referenced-by-path.md):

- Blobs would put megabytes into a file whose changeset sync (ADR 0009/0010) is designed around
  small per-column edits, and they would need excluding from it by hand.
- A bundle changes how every project is opened, saved, imported and exported — a step of its own.
- References are honest about their weakness (a `.ocpt` sent to a colleague arrives without its
  photos) and cost nothing to migrate away from later: the `assets` table already isolates the
  question behind an id, so moving to 2 or 3 is a service change and a migration, not a rewrite of
  eleven tables.

A missing file is a normal state, not an error: the UI shows the reference with a "file not found"
marker and offers to re-point it.

### 4.4 Role reconciliation

`OcptRoleIndexService` mirrors `OcptSceneIndexService` and runs on the same save path:

1. Ask `fountain_kit` for the screenplay's speaking characters — `speakingCharactersOf(
   document.blocks)`, the same source `FountainScriptStatistics` already counts.
2. Match them against stored `roles` rows where `isFromScreenplay` is true, by exact name. "Exact"
   means after the normalisation `speakingCharactersOf` itself applies, which `fountain_kit`'s own
   header already flags as the one a shot's character list must match too: a role, a shot character
   and a statistic must never disagree about whether two cues are the same person.
3. A character with no row → insert a `speaking` role, uncast, at the end.
4. A row whose character is gone → set `orphanedName`, clear nothing else. The role, its casting and
   its notes survive; the mode shows an `OcptRemovedRoleAlert` banner, built exactly like
   `OcptShotListRemovedCharacterBanner`, offering to delete the role or keep it as a `silent` one.
5. A row the user created by hand (`isFromScreenplay` false) is never touched.

Renames are not detected in v1 — a rename reads as one disappearance and one appearance, and the
banner is how the user repairs it. That is the same trade `OcptSceneIndexService` makes for a
heading with no scene number.

### 4.5 Scene ↔ set suggestion

A scene heading carries a location string (`INT. APPARTEMENT DE LÉA - NUIT`). The mode offers it as
a **suggestion** when a scene has no `scene_sets` row: normalise the heading's location part, match
it against set and location names, and pre-select the best hit. It is never applied automatically —
`INT. CUISINE` in two different houses is two sets, and only the user knows which.

### 4.6 UI

`lib/ui/pages/workspace/modes/resources/` follows the shot list mode file for file:
`resources_mode.dart` wires `OcptResourcesBloc` and `_ResourcesView` owns the dock layout
controller.

- **Left dock** — `OcptResourcesTabBar` (the four-tab segmented control),
  `OcptResourcesListPanel` dispatching to `OcptPeopleList` / `OcptRolesList` /
  `OcptLocationsList` / `OcptElementsList`. A search field filters the active list.
- **Centre** — `OcptPersonSheet`, `OcptRolesTable`, `OcptLocationSheet`, `OcptElementsBoard`. Every
  sheet edits in place with the same debounce-and-flush discipline the shot inspector uses; nothing
  opens a modal to edit a field. A field may **flag** what it holds without refusing it
  (decision 11): `ocptEmailFormatError` is the shared check, the field shows its message once it
  loses the focus, and the value is written either way — the person sheet autosaves as it is typed,
  so a field that refused an incomplete value would refuse nearly every keystroke.
  The person sheet's cards read top-down as the header, the functions, the legal-hours callout when
  the person is a minor, then a two-column grid (meals/health/skills beside logistics, then the HMC
  card beside image rights), then the unavailabilities — full width, since a date range, a slot and
  a multi-line reason do not fit half of one — and last the notes.
- **Right dock** — one tab, `OcptResourcesRightDockTab.versions`, hosting the shared
  `OcptProjectVersionsPanel` exactly as the two other modes do (§3.3, difference 4). No inspector
  tab: the centre sheet is the inspector. The dock is closed by default, and the shell's own
  right-dock toggle is what opens it.
- **Toolbar** — a contextual `+ Add` action, the search toggle, and the `⋮` menu carrying the XLSX
  export.
- **Status bar** — `OcptResourcesStatusBar`, the five counts.
- **Dialogs** — delete confirmations and the asset picker, all through `OcptRouterManager`, never
  `Navigator`.
- **Theme** — nothing declares its own radius, padding or font size: the studio component themes in
  `lib/constants/ocpt_theme.dart` already say all of it, and every clickable surface passes
  `ocptClickableCursor`.

### 4.7 Read-only preview, and joining the versions mixin

`OcptResourcesBloc` mixes in `MixinOcptProjectVersionsBloc` and `OcptResourcesState` mixes in
`MixinOcptProjectVersionsState`, exactly as `OcptShotListBloc` does. That is what gives the mode
both its `Versions` tab and its read-only flag, and it is a contract with four obligations the
milestone has to honour:

- **`flushPendingProjectWrites`** — a debounced field edit still in flight must reach the working
  copy *before* a preview swaps the database out, or it lands in the previewed version's in-memory
  one. This mode is edit-heavy, so it has more pending writes than any other.
- **`reloadFromProjectDatabase`** — entering or leaving a preview replaces
  `OcptOpenProjectModel.database`, so every list and every sheet is read again from it. The reload
  **must** emit `previewedVersionId` in the same state as the data it just read, or the mode draws
  one frame of a version's content with the working copy's editing affordances still on it.
- **`OcptProjectWorkingCopyRefreshRequestedEvent`** — dispatched on opening the `Versions` tab and
  on a save landing while it is already open, the mixin throttling that path to one capture every
  two seconds.
- The state answers the mixin's own members (`projectVersions`, `previewedVersionId`,
  `workingCopy`, the three `versionPending…Id`s, `projectVersionNotice`) and implements
  `copyProjectVersionsState`.

`isPreviewingVersion` is then the single predicate every widget of the mode is built from. Affordances
that write are **withheld, not disabled**, in the idiom the app settled on: a widget takes a
nullable callback and renders nothing when it is null, and a composite panel takes an `isReadOnly`
flag and hands its own parts the null callbacks, so a field added later cannot be gated in one
place and forgotten in the other. The `+ Add` toolbar action, the delete confirmations and every
sheet field follow that rule; the exports, the lists, the counts and the app-wide display
preferences stay.

### 4.8 Version payloads — format 2

`OcptProjectVersionCodec` is "a hand-written mirror of the schema" by its own documentation, and it
says what to do when a table arrives: add a named upgrade step to `_payloadUpgrades` (an empty
`const` map today, waiting for its first entry), bump `currentPayloadFormat` from 1 to 2, and keep
a fixture of the retired format in the tests. This step does exactly that, and it is **not
optional**:

- A version captured after this step must carry the eleven tables' rows, or restoring it would
  leave the resources of the working copy untouched while everything else rewound — a project half
  in one version and half in another.
- A version captured *before* this step carries no resources at all. Restoring it must therefore
  **tombstone** every resource row rather than leave it: the payload says "this project had no
  people", and that is a truthful statement about that moment. The format-1 → format-2 upgrade step
  materialises the eleven keys as empty lists, so the restore path needs no special case.
- `row_field_versions` stamps travel with them, for the reason `OcptProjectVersionsService`'s own
  documentation gives: a restore is an edit, so the restored columns must be stamped above what
  they held, or the next merge would undo it.
- The `assets` table travels as rows like any other; the **files it points at are not versioned**,
  and cannot be. Restoring a version restores the reference, and the reference may now be dangling.
  §4.3's "file not found" state is what makes that survivable, and it is the honest consequence of
  decision 2.

Two further places enumerate the covered tables **by hand**, and both are as mandatory as the
payload itself:

- **`OcptProjectVersionCodec.contentDigest`** lists its tables one by one, and the digest is what
  answers "has the working copy drifted from its base?" and what deduplicates a restore's safety
  version. Leave the eleven tables out of it and two states differing only in their resources hash
  identically: the working-copy card would claim no drift after an afternoon of typing people in,
  and a restore would skip the safety version it promised to keep.
- **`OcptProjectVersionsService._applyPayload`** calls `_restoreTable` once per table, in
  dependency order, each with its own `tombstonedOf`. Eleven more calls, ordered so a row lands
  after what it references — the transaction already runs under `PRAGMA defer_foreign_keys = ON`,
  which is what makes the tombstoning order survivable at all.

`local_erasures` (§4.2.7) appears in **none** of the three: it is local, so it is not captured, not
hashed, and not restored. That is the whole point of §4.9.

A migration test with a stored format-1 fixture is part of M1's definition of done, not M6's.

### 4.9 Erasing a person, and what versions do to it

Decision 6 says a deleted person is *erased*: the tombstone is written and the personal columns are
blanked, so the file stops holding a phone number, a home address and an allergy for someone who
asked to be removed.

Versions cut straight across that. A version captured before the deletion holds a full copy of
those columns inside its payload, so:

- the data survives the erasure, inside the `.ocpt`, indefinitely;
- restoring that version brings the person back, fully populated.

Three ways out, and this plan picks the third:

1. **Ignore it** — erasure is best-effort, versions are history. Cheap, and wrong: it makes the
   erasure a lie.
2. **Rewrite past payloads on erasure** — walk every version, blank that person, re-encode. It
   works, but it mutates versions, which the shipped feature treats as immutable captures — the
   codec's own doc comment says the stored text is never rewritten, so a version stays
   byte-identical. A version would stop being a faithful record of a moment.
3. **Scrub on decode, not on disk.** The erased person ids are kept locally, and the restore path
   drops or blanks those people as it hydrates. Versions stay byte-identical, the working copy
   never resurrects an erased person, and the only residue is inside a payload nothing reads back.

Option 3 is the one this plan implements, in M1, alongside the erasure itself.

**That list must live outside the payload, which is why §4.2.7 exists.** The obvious home,
`project_info.settingsJson`, is a trap: the codec captures `settingsJson` into every payload, feeds
it to `contentDigest`, and writes it back on restore. Parked there, the list of erased people would
be rewound by any restore — so restoring a version captured before an erasure would forget that the
erasure ever happened *and* resurrect the person in the same transaction, which is exactly the
failure this section was written to prevent. `local_erasures` is a table for the same reason
`project_versions` is one: what must not travel in a payload must not sit in something that does.

**This is the single subtlest interaction in the step**, and it is settled: decision 6 keeps the
erasure, so §4.9 is part of the work rather than a contingency.

### 4.10 Export

`OcptResourcesXlsxExportService`, beside `OcptShotListXlsxExportService` and owned by
`OcptExportManager` as its sixth service — the manager's own doc comment counts them, so it is
updated with it, exactly as the scenario coverage export did when it was the fifth — writes one
workbook with four sheets — Crew and cast directory, Roles,
Locations and sets, Elements — through `excel_community` ([ADR 0008](../adr/0008-excel-community-for-the-shot-list-export.md)),
saved through `OcptSaveLocationService` like every other export. Every heading arrives as an
`OcptResourcesXlsxLabels`, exactly as the shot list workbook does: the manager and its services
never see a `Tr`.

---

## 5. Milestones

Each milestone ends on the full verification gate list from `CLAUDE.md`, one commit per logical
change, and a user checkpoint.

### M0 — Prerequisites

~~What is left of §7: **ADR 0013 — binary assets by reference** (§4.3).~~ Done, and with it every
item of §7. No resources code.

### M1 — Schema v6, the services, and the payload

The twelve tables, the enums, `ocptCrewPositions`, the `onUpgrade` step, and the four services
(`OcptPeopleService`, `OcptRoleIndexService`, `OcptLocationsService`, `OcptElementsService`) with
tombstones, `sortKey` allocation through `ocptFractionalKey*`, and the erasure-on-delete of
decision 6 writing its `local_erasures` row. Then §4.8 in full: payload format 2, its named upgrade
step, the eleven tables added to `contentDigest` and to `_applyPayload`, and the restore path's
handling of a format-1 payload and of an erased person. Unit tests over
`OcptProjectDatabase.memory()`, including a stored format-1 payload fixture and a v5 → v6 case
added to the existing migration test — which now pins what `onCreate` produces against what every
upgrade path produces, so a table declared and forgotten in `onUpgrade` fails there rather than on
a user's file.

This milestone is deliberately large: splitting the payload work out of it would mean shipping a
build in which restoring a version corrupts a project.

### M2 — The mode and the People tab

`OcptWorkspaceMode.resources`, the switcher entry, the bloc/state/events, the left dock with its
tab bar, the people list and the person sheet with every field of §4.2.1 and §4.2.2, create /
edit / delete, the right dock and its single `Versions` tab, the four obligations of §4.7 —
`flushPendingProjectWrites`, `reloadFromProjectDatabase` emitting `previewedVersionId` with its
data, the working-copy refresh event, and the mixin's state members — the status bar, and the
en_GB + fr ARB entries. This is the milestone that proves the shell wiring; the other three tabs
are then additive.

Benoit's review of the built sheet added decisions 10 to 14, applied here rather than deferred:
the structured address (on `locations` too, so the two never disagree about what an address is),
the email check, the scope column dropped, the unavailability's range and slot, and the HMC card.
Every one of them touches schema v6 in place, so `contentDigest`, the payload codec and the
migration test move with them.

### M3 — Roles and casting

`OcptRoleIndexService` on the save path, the roles list and table, casting a person to a role,
hand-added silent and extra roles, and the removed-role banner.

### M4 — Locations and sets

The locations list and sheet, sets inside a location, the permit card, the `scene_sets` links with
the §4.5 suggestion, and the asset references for scouting photos.

### M5 — Elements

The elements board grouped by category, the tracking flags, owner and bringer resolved against the
address book, and the `scene_elements` chip editor.

### M6 — Export and polish

The XLSX workbook, search and filtering across the four tabs, empty states, and a documentation
pass folding the outcome into `CLAUDE.md` (after which this plan is deleted).

---

## 6. Out of scope

- **Per-day scheduling** — call times, crew per time slot, day-by-day requirement lists. That is the
  schedule mode, and it is the direct consumer of everything built here.
- **Call sheets and shooting plans** (`feuille de service`, `plan de travail`) — schedule mode too.
- **A per-scene breakdown view** (the *dépouillement* screen). The links ship (§4.2.6); the screen
  that reads them scene by scene does not.
- **Binary storage inside the project file** (§4.3) and **document generation** (§3.3, difference 3).
- **Contracts, deal memos, payroll, day rates.** `elements.cost` is the only money in this step.
- **Reworking `shot_characters`** to reference `roles`. The shot list keeps storing character names;
  showing the cast member beside a name is a read-time join, and any deeper refactor is its own
  step.
- **Sync.** M2+ of `docs/plans/collaboration-and-sync.md`.

---

## 7. Before M1 opens

Every design question this plan raised is settled in §3.4. What was left was not a question but a
sequence, and none of it was resources work. All of it is done, so M1 may open:

1. ~~**Land the versions branch.**~~ Done: PR #44, schema v5, payload format 1 (§0).
2. ~~**Write ADR 0013** — binary assets by reference (§4.3).~~ Done:
   [ADR 0013](../adr/0013-binary-assets-referenced-by-path.md).
3. ~~**Prune the stale local branches.**~~ Done.
4. ~~**Open the GitHub issue** from §2 and §3.~~ Done: [#45](https://github.com/borlnov/open_cine_prod_tools/issues/45).
