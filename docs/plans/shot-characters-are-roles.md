<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Shot characters are roles

Unify the character stores so a shot's characters are the production's `roles`, closing
[issue #88](https://github.com/borlnov/open_cine_prod_tools/issues/88). Today `shot_characters`
holds free normalised name strings unrelated to the `roles` table the resources and breakdown modes
share; this work makes it reference `roles.id`, so a rename is repaired by a merge that keeps the
casting, a character invented while shot-listing is a real castable role, and the three modes can no
longer disagree about who exists.

**Read first**, and reading them is part of the job, not background:
[`../adr/0030-a-shots-characters-are-the-productions-roles.md`](../adr/0030-a-shots-characters-are-the-productions-roles.md)
(the decision this plan carries out, and its seven settled points),
[`../adr/0007-schema-migration-policy.md`](../adr/0007-schema-migration-policy.md) and
[`../adr/0029-schema-versions-frozen-at-stable-releases.md`](../adr/0029-schema-versions-frozen-at-stable-releases.md)
(why the reshape needs its own ADR and how the schema number is claimed),
[`../architecture/resources.md`](../architecture/resources.md),
[`../architecture/breakdown.md`](../architecture/breakdown.md),
[`../architecture/schedule.md`](../architecture/schedule.md) (the shot list lives under it) and
[`../architecture/sync.md`](../architecture/sync.md) (why the backfill needs deterministic identity).

This file is deleted once the work ships and its outcome is folded into `docs/architecture/`.

## The shape

`shot_characters` loses `characterName` and gains `roleId` (a `references(OcptRolesTable, #id)`),
keyed by `{shotId, roleId}`. `OcptShot.characters` becomes a list of role ids resolved against the
loaded cast rather than a list of names. The découpage picks or creates a role instead of typing a
name; a single shared banner resolves an orphaned or name-collided role from either the resources
mode or the shot list; one `mergeRole` operation is what every "merge" affordance calls; and
`deleteRole` cascades into the shot list and the dépouillement.

The work is delegated to Sonnet 5 agents, one milestone at a time, reviewed by the main session,
with a checkpoint with Benoit between milestones. The order is deliberate: the store and its
migration first (the risk), the services and rules next, the UI last.

## M1 — The store and its migration

The foundation and the highest risk. **Behaviour-preserving**: after M1 the app compiles, every
existing test is green, and the exports, the schedule mode and the shot list UI look and act exactly
as before — the store is roleId-keyed underneath, but nothing above it is asked to speak roles yet.
The one deliberate behaviour that lands early is decision 1: attaching a character now finds or
creates a real role, because that is what a roleId-keyed row requires and it is the end-state
anyway, not throwaway. The new UI, the merge, the collision alert and the delete cascade are M2/M3.

The tactic that keeps the blast radius small:

- **The loader resolves `roleId` back to a name.** `OcptShotListService.loadShotList` joins
  `shot_characters.roleId` onto `roles.name`, so `OcptShot.characters` stays a `List<String>` of
  names in display order and every read site — the four exports, the schedule snapshot, the shot
  inspector — is untouched. `OcptShot` also carries the aligned role ids (a parallel
  `characterRoleIds`, or a small `{roleId, name}` ref list) so the write side has the id it needs;
  pick the shape that changes the fewest read sites and document it.
- **The service keeps its name-based API, roleId-backed underneath.**
  `attachCharacter(name)` resolves the normalised name to a live role, or **creates** a hand-added
  silent role linked to the shot's episode (decision 1), then inserts `{shotId, roleId}`.
  `detachCharacter` / `replaceCharacterEverywhere` / `removeCharacterFromEveryShot` resolve their
  name arguments to role ids the same way. The shot list bloc and widgets call them exactly as
  today, so no UI moves in M1. `OcptShotRemovedCharacterAlert` keeps working unchanged: it compares
  `OcptShot.characters` (names) against the screenplay cast as it always has. Turning the name-based
  API into a roleId-native one, and retiring that alert in favour of the roles-orphan flow, is M2.

- **Schema.** Add `roleId` to `OcptShotCharactersTable`, make `{shotId, roleId}` its primary key,
  remove `characterName`. Bump `currentSchemaVersion` and write the `onUpgrade` step (see below).
  Regenerate drift code (`dart run build_runner build`). Update the composite-key doc comments in
  `lib/utils/ocpt_row_stamp_key.dart` and `OcptRowFieldVersionsTable`, which name `shot_characters`'
  key as `{shotId, characterName}`, and any sync code that enumerates that key's columns
  (`OcptChangesetService`, `ocpt_field_stamp.dart`).
- **The migration.** Recreate `shot_characters` under the new key (drift's `TableMigration` /
  create-new-copy-drop, since SQLite cannot alter a primary key in place) and copy every **live**
  row across, mapping `characterName` to a role:
  - to the live role whose `name` equals the normalised name, when one exists;
  - otherwise to a **hand-added silent role** minted in the same step, its id a **deterministic UUID
    v5** of a fixed namespace constant and the normalised name, so every replica mints the same id;
    linked to the episode of the shot's screenplay via a `role_episodes` row minted the same
    deterministic way.
  Tombstoned `shot_characters` rows are carried across too (sync history), rekeyed the same way. The
  row-stamp key moves from `ocptCompositeRowStampKey([shotId, characterName])` to
  `[shotId, roleId]`; the `row_field_versions` / stamp rows must be rekeyed so a migrated file still
  merges, and the rekey must be a pure function of the old key and the deterministic role id.
- **Version codec.** `OcptProjectVersionCodec` serialises `shot_characters`: add `roleId`, drop
  `characterName`, and update `contentDigest`'s canonical rows and `_applyPayload`. Format 2 is
  frozen (0.2.0), so bump `currentPayloadFormat` to 3 and add a `decode` upgrade step for a pre-3
  payload. That step does **not** remap names to roles: a version captured before the reshape
  restores **without its shot characters** — the plans come back empty of characters, everything
  else (screenplay, cast, breakdown…) restores as before. Every version captured after the reshape
  carries `roleId` and restores fully. Pin the retired format-2 shape as a fixture, as the codec's
  own doc comment requires, and assert a format-2 payload decodes with its shot characters dropped.
- **Tests.** The migration is the centre of gravity: upgrade a 0.2.0-schema fixture whose shot names
  variously match a live role, match an orphaned role and match no role at all, and assert every
  attachment survives on the right role. Add a **convergence** test: two replicas migrating the same
  file independently produce the same rows (same minted role ids, same stamp keys). Cover the codec
  round-trip and the digest.

**Checkpoint with Benoit before M2.**

## M2 — Services and rules

The unified operations land, **without touching the UI** — every service here is reachable without
a UI change, so the shot list keeps M1's name-based API (roleId-backed) untouched and the modes keep
compiling and behaving as they do. Turning that API roleId-native, retiring the old shot-list alert,
and every banner belong to M3, where the picker that feeds a roleId arrives with them.

- **`OcptRoleIndexService.mergeRole`.** The one merge operation (decision 3): re-point every row
  that names source — `shot_characters`, `breakdown_tags` and `shooting_slot_cast` (so a
  convocation is not dropped) — onto target, deduping where target already has the same
  `{shotId, roleId}` / `{slotId, roleId}` / tag; carry source's `personId`, `castingNotes`,
  `role_elements`, `role_candidates` and `role_episodes` onto target where target lacks them;
  tombstone source. When one role is a reconciled speaking role it is the survivor. Guarded
  (`refusesUserWrite`), one transaction, sync-stamped. Investigate whether any other table names a
  role and report it rather than silently widening the operation.
- **`OcptRoleIndexService.deleteRole`.** Add the two missing cascades (decision 5): tombstone the
  `shot_characters` rows and the `breakdown_tags` rows naming the role, beside the links it already
  carries off. `OcptBreakdownService` owns the breakdown-tag tombstone; `deleteRole` holds it the
  way it already holds `elementsService` and `roleCandidatesService`.
- **Name-collision detection (decision 2).** A pure rule over the loaded cast — a live hand-added
  role and a live reconciled role sharing a normalised name — surfaced as an alert model beside
  `OcptRemovedRoleAlert`. `reconcile` is not changed; the collision is read, not reconciled.
- **Tests.** `mergeRole` in each direction and each carried field; the collision rule; the delete
  cascade reaching shots and tags.

**Checkpoint with Benoit before M3.**

## M3 — The UI

- **The roleId-native switch.** Turn the shot list service's name-based API (kept through M1–M2)
  into a roleId-native one — `attachCharacter` / `detachCharacter` / `replaceCharacterEverywhere` /
  `removeCharacterFromEveryShot` take a `roleId` — the name-to-role resolution moving into the
  picker below, and retire `OcptShotRemovedCharacterAlert` and its banner, a shot now pointing at a
  role that always exists. This lands with the picker and the shared banner, since they are what
  feed a roleId and surface orphans instead.
- **The shot list character affordance.** Keep today's `OcptShotCharacterChips` (one toggleable
  `FilterChip` per role — the whole cast — attach/detach on toggle, now roleId-backed) and fill the
  "future version" gap its own doc names: a trailing **`＋ Ajouter`** affordance opening a small
  inline field that **resolves or creates** — a typed name that matches a live role attaches it, one
  that matches none creates a hand-added silent role (decision 1) and attaches it. Design validated
  with Benoit (chips as today + one add field); ask him again before deviating.
- **The shared banner.** Modelled on the shot list's existing removed-character banner (error
  container, `person_off` icon, a message line, a text action, then a `Wrap` of `ActionChip`s), with
  two variants, shown in **both** the resources mode (in the role sheet, where `OcptRemovedRoleBanner`
  lives) and the shot list (above the table, where the removed-character banner lives) — decision 4:
  - **orphaned**: *delete the role* / *keep as a silent role*, then a `Fusionner avec :` row of
    `ActionChip`s over the roles the screenplay still names (the merge target), reusing the old
    banner's `Remplacer par :` chip pattern;
  - **collision** (decision 2): advisory and persistent — the message counsels merging or renaming
    one of the two, with a single `Fusionner` action that merges the hand-added role **into** the
    screenplay one (the anchor). No dismissal; it clears when the collision does.
  `OcptRemovedRoleBanner` and the shot list's `OcptShotListRemovedCharacterBanner` are folded into
  the one widget. `isReadOnly` withholds the actions under a project-version preview, as today.
- **Confirming a merge.** The target chip (orphaned) or the single `Fusionner` (collision) is the
  choice; the irreversible merge itself is then confirmed through `OcptConfirmDialog`, opened by the
  page or mode, never inline (CLAUDE.md's confirmation rule) — as the banner's *delete* already is.
- **l10n.** New keys in `intl_en_GB.arb` and `intl_fr.arb`, regenerated with
  `dart run intl_utils:generate`; French keeps « séquence » for a scene and never reintroduces
  « scène » (CLAUDE.md). No manager or service sees a `Tr`.
- **Tests.** Widget tests for the banner's variants and the picker; bloc tests for the wiring in
  both modes; set an explicit surface width past the 800px compact breakpoint.

## Out of scope

The voice-over / off-screen presence qualifier on the shot↔role attachment (ADR 0030, decision 7).
It is a clean additive follow-up and is deliberately left to a later change.

## Verification

The eight gates in CLAUDE.md before each commit (`flutter pub get`, `intl_utils:generate`,
`build_runner build`, `flutter analyze`, `flutter test`, `flutter build linux --debug`,
`reuse lint`, the `allcircuits.com` grep), plus `dart run tool/check_markdown.dart` for this file and
the ADR. Wait for CI before opening the PR — the local gates do not run everything CI does, and this
change touches the migration path CI exercises across released schema versions.

## Folding back

On ship: set ADR 0030 to Accepted, add its migration step to `OcptProjectDatabase`'s documented
history, fold the unified store into `docs/architecture/resources.md`, `breakdown.md` and
`schedule.md` (the shot list), and delete this plan.
