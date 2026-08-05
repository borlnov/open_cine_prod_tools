<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0014 - Breakdown tags as the script-to-catalogue anchor

## Status

Accepted

## Context

The breakdown pass (*dépouillement*) is the read where one person goes through the screenplay line
by line and writes down everything the shoot will have to provide. Its output is a link between a
**passage of the text** and a **row of a catalogue** the resources mode (schema v6) already holds:
an element, a role or a set.

Three constraints shaped how that link is stored.

- **The catalogues are three different tables.** A character is a `roles` row, reconciled from the
  screenplay by `OcptRoleIndexService`; a place is a `sets` row hanging off a location; everything
  else is an `elements` row. Creating parallel `elements` rows for characters would duplicate the
  cast and let the two drift apart, so a tag has to be able to point at any of the three.
- **The schema enforces referential integrity.** `PRAGMA foreign_keys` is on (schema v2), and every
  synchronised table follows the sync-ready rules of ADR 0010: tombstones instead of deletes,
  every read filtering them back out.
- **The text moves under the tag.** The screenplay is the source of truth and is edited constantly.
  A passage tagged today sits at a different offset tomorrow, because a word was added above it.

The neighbouring `shot_coverages` table answers a similar-looking question for the scenario
coverage — which passage does this shot cover — and stores only `coveredTextDigest`, with a
`needsCheck` flag when the digest stops matching.

## Decision

One table, `breakdown_tags` (schema v9), holds every tag: `sceneId`, a `targetKind` discriminator
(`OcptBreakdownTargetKind`: `element`, `role`, `set`) and **three nullable foreign keys**
(`elementId`, `roleId`, `setId`), exactly one of which is non-null — the one `targetKind` names.
`elements.ownerPersonId`/`broughtByPersonId` already use this shape.

Offsets are **scene-relative** (`startOffset`/`endOffset`, relative to the scene's `charStart`),
as `shot_coverages` are, so a scene that moves because a scene above it grew keeps every tag it
had with no rewriting at all.

A tag stores its passage **verbatim** in `taggedText`, where `shot_coverages` stores a digest.

Creating a tag also **ensures the link it implies**, in the same transaction: a `scene_elements`
row for an element target, a `scene_sets` row for a set target. A role target creates no link row —
there is no `scene_roles` table, and the tag itself is that link. Deleting a tag (a tombstone,
never a hard delete) **never removes the link row it once ensured.**

## Consequences

The verbatim text is what makes reconciliation possible rather than merely detectable.
`OcptBreakdownService.reconcileTags`, on the screenplay save path after the scene index is rebuilt,
re-slices each tag: unchanged, nothing to do; otherwise it searches the scene for `taggedText` and,
on **exactly one** match, silently re-anchors the tag. Only zero or several matches raise
`needsCheck`. A digest could only ever have raised the flag. The same stored text is what
`ocpt_breakdown_suggestions.dart` matches to offer a tag's other occurrences elsewhere in the
script. The cost is duplicated text in the file — bounded on purpose: a tag is a few words, well
under a line, unlike a coverage range that can span a page. That bound is not enforced by the
schema, and a future feature that tags long passages would have to revisit this.

The three nullable foreign keys cost a wider row and an invariant SQLite cannot state: "exactly one
of the three is non-null" is upheld by `OcptBreakdownService`, not by a constraint. In exchange,
every tag points at a row that really exists, a tombstoned target keeps its tags pointing somewhere
valid instead of at a dangling id, and reading a project's tags is one query rather than three.

Never removing the link is a deliberate asymmetry, and it is the conservative direction: the
resources mode lets a user link an element to a scene **by hand, with no tag at all**, and the
breakdown cannot tell its own link from that one. Removing it silently would destroy work the
breakdown never created. The cost is a `scene_elements` row that can outlive every tag that
justified it, so the inspector asks about the removal as a separate question when a target's last
tag in a scene goes.

Both new tables are ordinary synchronised tables — captured, hashed, restored and stamped like the
rest — so they joined `OcptProjectVersionCodec` in all three places (payload, `contentDigest`,
`_applyPayload`) as payload format 5. `_scrubErasedPeople` needed no change: a tag never names a
person.

## Alternatives considered

- **One table per target kind** (`element_tags`, `role_tags`, `set_tags`): every foreign key
  non-nullable and the invariant free. Rejected because reading, reconciling, exporting and
  recapping a project's tags would each become three queries and three code paths over rows that
  are otherwise identical, and any fourth target kind would add a fourth of everything.
- **One untyped `targetId` plus the discriminator**: the narrowest row. Rejected because it gives
  up referential integrity entirely, in a schema that switched it on deliberately.
- **A digest, as `shot_coverages` stores**: consistent with the neighbouring table. Rejected
  because it makes silent re-anchoring and occurrence suggestions impossible — the two things that
  keep a breakdown pass from becoming a re-tagging chore after every screenplay edit.
- **Document-relative offsets**: no scene indirection. Rejected for the reason `shot_coverages`
  already rejected it — every edit anywhere above a tag would rewrite every tag below it.
- **Deleting the link row with the last tag**: tidier, and wrong. It cannot distinguish a link the
  breakdown created from one the user made by hand in the resources mode.
