<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0030 - A shot's characters are the production's roles

## Status

Proposed

## Context

Characters live in **two unrelated stores** today. The resources mode's cast is the `roles` table,
reconciled from each episode's screenplay by `OcptRoleIndexService` and shared as-is by the
breakdown mode, whose tags point straight at a `roles.id`. The shot list is the outlier: it stores
a shot's characters as **free normalised name strings** in `shot_characters`, keyed by
`{shotId, characterName}`, with no foreign key to `roles`. The only thing keeping the two from
disagreeing is that both pass names through `fountain_kit`'s `normalizeCharacterName` — a name, not
an identity.

That split has three costs, and the first is the bug that opened this record
([issue #88](https://github.com/borlnov/open_cine_prod_tools/issues/88)):

- **A rename loses work.** Correcting a misspelled cue reads to `OcptRoleIndexService.reconcile` as
  one disappearance and one appearance — renames are deliberately not matched, a screenplay cue
  carrying no stable identifier (see the service's own doc comment, ADR 0019). The old role is left
  orphaned, its banner offering only *delete* or *keep as a silent role*; the corrected name is a
  fresh, empty role. The casting, the notes, the costumes and the candidates attached to the old
  role cannot follow the name to the new one. There is no *merge* on the resources side at all —
  only the shot list has one, worded as its banner's *replace with* chips, and it operates on names,
  not roles.
- **A character invented in the shot list cannot be cast.** A silhouette a shot legitimately carries
  but the screenplay names nowhere is only ever a string on that shot. The moment it matters enough
  to film, it matters enough to cast, to dress and to schedule — and none of that is reachable,
  because the string is not a role.
- **The two lists drift.** The découpage and the dépouillement answer "who is in this?" from
  different stores, so they can and do disagree — a shot name absent from the cast, an orphaned or
  hand-added role in no shot, a casing or accent variant — and nothing done on one side propagates
  to the other.

Unifying the store is a **reshape of an existing table**, not an additive change:
`shot_characters` must stop being keyed by a name and start being keyed by a role. ADR 0007's
migration policy is additive-only and says in as many words that a change of this kind "gets its own
ADR revisiting this policy rather than being folded in quietly" — which is what this record is. The
schema was frozen for 0.2.0, so real `.ocpt` files hold name-keyed `shot_characters` rows that a
migration has to carry across without losing a single attachment.

The reshape also runs headlong into sync. Every replica migrates its own file independently, on its
own upgrade schedule (`docs/architecture/sync.md`, ADR 0010). A migration that mints a `roles` row
for a shot name with no matching role would mint it with a fresh random UUID **on each replica** —
and the same character would come back as several rows once the replicas met. Backfill therefore
cannot use random identity.

## Decision

**A shot's characters are `roles`.** `shot_characters` references `roles.id` and is keyed by
`{shotId, roleId}`; its `characterName` column is gone. The découpage, the dépouillement and the
resources mode all read and write the one cast from then on, and the seven decisions below settle
how.

1. **Attaching a character in the shot list picks a role, or creates one.** The shot's character
   affordance offers the project's existing roles and a *create* path. A role created there is
   **hand-added** (`isFromScreenplay` false), born **silent** — `speaking` stays reserved to
   `reconcile`, which alone reads it off a cue — and linked to the **episode the shot belongs to**,
   exactly as `OcptRoleIndexService.addRole` already does from the resources mode. It shows up in
   Ressources at once, castable and dressable, which is the whole point.

2. **A name a hand-added role shares with a new cue is surfaced, never adopted silently.** When a
   character invented in the shot list later gets a line, `reconcile` creates the speaking role it
   always would (the screenplay stays the source of truth), so two live roles share a name. That
   state raises a **name-collision alert** — the app never guesses that two same-named roles are one
   person. The alert is **advisory and persistent**: it offers to *merge* and otherwise counsels
   renaming one of the two, and it clears only when the collision itself is gone (a merge, or a
   rename) — there is deliberately **no "keep separate" dismissal**, since acknowledging a collision
   would freeze a choice the user cannot revisit and would grow ambiguous the moment a third
   same-named role appeared. The merge is always **anchored on the screenplay role** — the
   hand-added role merges *into* it — so there is never a "merge with which?" question: several
   hand-added namesakes each resolve in turn, always onto the one reconciled role. `reconcile`'s
   matching is unchanged: it still touches only `isFromScreenplay` roles, and the collision is a
   read over the loaded cast, not a new rule inside the reconciliation.

3. **Merge is one operation, and the speaking role wins.** Merging role *source* into role *target*
   re-points every row that names *source* — `shot_characters`, `breakdown_tags` and
   `shooting_slot_cast`, the last so an actor's convocation on the schedule is not dropped by the
   merge — onto *target*, carries *source*'s casting (`personId`), notes, `role_elements`,
   `role_candidates` and `role_episodes` onto *target* where *target* lacks them, then tombstones
   *source*. When one of the two is a reconciled speaking role, **it is the one that survives**, so
   `reconcile` keeps owning it; the hand-added role's casting is what is carried over. (Deletion, by
   contrast, keeps the narrower cascade decision 5 settles — a merge preserves the convocation, a
   deletion is the user saying the part is gone.)

4. **One banner, shown wherever the role is.** A single shared banner widget states a role that
   needs attention and offers the ways out — a widget that only asks (nullable callbacks), each mode
   wiring the same service. It has two variants: an **orphaned** role (the screenplay no longer names
   it) offering *delete* / *keep as a silent role* / *merge with…*, and a **name collision**
   (decision 2) offering *merge*. The shot list's old free-name "removed character" banner is gone:
   a shot now points at a role that still exists even when orphaned, so there is no dangling name
   left to report.

   The affected role must be **visible the moment a mode is entered**, not only once its record is
   opened, so the surfacing differs by where the role can be acted on. The **shot list** carries the
   full banner at the top of the mode, as it always did. The **resources mode** keeps the full banner
   in the role's own sheet and adds, at the top of the mode, a **compact one-line-per-role** summary
   of every role needing attention; clicking a line selects that role, landing on its sheet where the
   full banner is. The **breakdown mode** shows the same compact one-line-per-role summary; having no
   role sheet of its own, a line opens the role **in the resources mode** through the cross-mode
   reveal the mode already offers. A rename also leaves the breakdown's own tag-anchor warnings
   (`breakdown_tags.needsCheck`, a passage whose text moved — unrelated to the role's identity, and
   not cleared by a merge): those stay the breakdown's existing per-scene concern, made reachable
   from the scene list's warning mark rather than only from the inspector.

5. **Deleting a role deletes it everywhere.** `OcptRoleIndexService.deleteRole` gains two cascades
   it lacks today: it tombstones the `shot_characters` rows and the `breakdown_tags` rows naming the
   role, beside the `role_elements`, `role_candidates` and `role_episodes` links it already carries
   off. A role removed in Ressources therefore leaves the plans and the dépouillement at the same
   time. The irreversible-action confirmation dialog gates it as it does every deletion.

6. **The migration reshapes `shot_characters`, and backfills with deterministic identity.** The step
   recreates the table under its new key and copies every live row across, mapping its
   `characterName` to a role: to the live role of that normalised name when one exists, otherwise to
   a **freshly minted hand-added silent role** whose id is a **deterministic UUID v5** of a fixed
   namespace and the normalised name. Every replica that runs the migration mints the *same* id for
   the same name, so the minted roles converge under per-column merge instead of multiplying; the
   row-stamp key rekey from `{shotId, characterName}` to `{shotId, roleId}` converges the same way,
   the new key being a pure function of the old one and the deterministic role id. This is the first
   non-additive migration the app ships, and the only part of it that reshapes rather than adds.

7. **The voice-over qualifier is out of scope.** A character present on a shot only as a voice-over
   or off-screen is a **property of the shot↔role attachment**, not a character of its own — the
   parser already folds `JEAN (V.O.)` into `JEAN`. Recording it (a presence qualifier on
   `shot_characters`) is a clean additive follow-up and is deliberately left to a later change, so
   this one stays about the store, not about what a link says.

## Consequences

The three costs above go away together. A rename is repaired by a merge that keeps the casting; a
character invented while shot-listing is a real role from the moment it is typed; and the découpage,
the dépouillement and Ressources can no longer disagree about who exists, because there is one cast.
The merge that issue #88 asks for is the same operation everywhere, reached from one banner.

The price is the migration. It is the first step that is not additive, it recreates a table and
rekeys its sync stamps, and its correctness rests on the deterministic-id argument above rather than
on the additive-only guarantee every prior step leaned on — so it carries the heaviest test burden
of any migration written so far: the upgrade path from the 0.2.0 frozen schema, a file whose shot
names variously match a live role, an orphaned role and no role at all, and a convergence check that
two replicas migrating the same file independently agree row for row.

A project version captured before the reshape restores **without its shot characters**. The version
codec is a migration path, but the decode step for a pre-reshape payload deliberately drops the
name-keyed `shot_characters` rows rather than re-running the name-to-role backfill on them: the
plans of a restored old version come back empty of characters, everything else restores as before,
and every version captured after the reshape carries `roleId` and restores in full. Remapping them
on restore was considered and turned down as more machinery than a pre-reshape version is worth.

Two behaviours change in ways a user will feel. Deleting a role now reaches into the shot list and
the dépouillement, where before it did not touch the shot list at all — the cascade is the point,
but it is a wider blast radius than the delete had. And a name collision shows a real, if transient,
duplicate in the cast until the user resolves it, rather than the app quietly deciding: that is the
deliberate choice of decision 2, the same "surface the state, let the user decide" the orphan banner
already makes.

`reconcile` itself is untouched in how it matches and what it writes; the unification lives in the
store, the services around it and the shared banner, not in the reconciliation. The plan that
carries this out is `docs/plans/shot-characters-are-roles.md`, deleted once the work ships and its
outcome is folded into `docs/architecture/`.
