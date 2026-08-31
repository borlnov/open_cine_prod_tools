<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# M6 — The portable on-set server

The last milestone of [`collaboration-and-sync.md`](collaboration-and-sync.md): running the relay on
a laptop or a Pi on set, letting a device re-point an already-paired project at that set relay, and
reconciling the set relay upstream to the prep relay at the end of the day. **Read the repository
`CLAUDE.md` and [`../architecture/sync.md`](../architecture/sync.md) first** — this sub-plan assumes
the engine, the relay and the pairing UI they already record, and does not repeat them. When this
plan and an ADR (0009, 0010) disagree, the ADR wins. This file is deleted once M6 ships and its
outcome is folded into `sync.md`.

## What is already true (do not re-derive)

- Every `OcptChangesetEnvelope` carries a stable `changesetId` UUID — legitimate *protocol*
  metadata, not the opaque domain payload — minted once by the origin device.
- The relay's `append` is **not** idempotent today: `OcptRelayStore.append` blindly assigns the next
  sequence, keyed `(projectId, sequence)`. Applying a changeset twice is already harmless at the
  merge level (equal Lamport stamps), but re-pushing a whole day's log every evening would duplicate
  it on the receiver without a dedup on `changesetId`.
- Relay-to-relay reconciliation needs **no domain merge**: the per-column stamps inside the payload
  are relay-independent (ADR 0010), so moving opaque changesets between two relays and letting
  *replicas* apply them later via the existing M3 merge *is* the reconciliation. The relay stays
  domain-blind.
- Re-pointing has a clean client seam: `OcptPairingService.savePairing` is an upsert by `projectId`
  taking an arbitrary `relayBaseUri` + `token`, and `OcptSyncManager.relayIdFor` keys the delivery
  cursor by the relay URL — both written anticipating "the same project behind two relays in one
  day". Nothing exercises that combination yet.
- Bootstrapping an empty set relay needs its enrolment secret: only `POST changesets` may create a
  project on a relay (the snapshot route cannot). So the *first* device to move a project onto the
  set relay presents the set relay's enrolment secret; the rest just re-point.

## Decisions taken with Benoit (2026-08-31)

1. **On-set re-point is by a relay enrolment QR**, a new URI `ocpt://relay?r=<baseUri>&e=<secret>`
   carrying the set relay's LAN address and enrolment secret, and **no project id and no token**. A
   device scans it *with a project already open* and re-points that project, reusing the token it
   already holds. One QR re-points any project; the token never travels on it.
2. **The action lives in the sync status panel** (the status-bar popover already holding *sync now*,
   *show invite QR*, *re-pair*), as a new "Changer de relais…" entry. Withheld under a read-only
   preview like the others, and absent for an unpaired project as the whole indicator already is.
3. **The evening reconciliation is a one-shot CLI subcommand** on the relay binary,
   `ocpt_sync_relay reconcile --invite '<ocpt://join…>'`, run by the operator on the set laptop. It
   pushes what the set relay gathered and pulls what it missed, deduped by `changesetId`. Re-running
   it is idempotent.

## Phases

Each phase is one or a few commits, delegated to a Sonnet 5 agent, with the full verification gate
and a review by the main session before the next. Phases A–B are the relay/protocol packages
(`dart` gates only); C–E are the app (`flutter` gates); F is the operator/architecture documentation
that closes M6; **G is the end-user guide covering the whole collaboration feature M2–M6, and runs
only after Benoit has validated all of M2 through M6** (see its own note).

### Phase A — Idempotent append (`ocpt_sync_relay`)

Make re-pushing a log safe, so Phase B can run every evening without growth.

- `OcptRelayStore`: add a `changesetId TEXT NOT NULL` column to `changesets`, read from the envelope
  (protocol metadata, not the opaque payload), with `UNIQUE(projectId, changesetId)`. Guard existing
  dev databases with an idempotent `ALTER TABLE … ADD COLUMN` when the column is absent. `append`
  becomes idempotent: when the project already holds a changeset with that `changesetId`, return its
  existing sequence and insert nothing; otherwise insert and assign the next sequence as today.
- `OcptRelayServer._postChangesets` is behaviourally unchanged — it already returns the sequence
  `append` hands back — but its doc comment now states the append is idempotent on `changesetId`.
- Tests: `ocpt_relay_store_test.dart` (a second append of the same `changesetId` returns the first
  sequence and leaves the log length unchanged; a different id still appends), and a server-level
  duplicate `POST` returning the same `{"sequence"}`.

### Phase B — The reconcile client and CLI (`ocpt_sync_relay`)

The set relay acting as a client of an upstream relay, purely over the wire protocol.

- `OcptRelayUpstreamClient` (new, depends on `package:http` + `ocpt_sync_protocol`): a small pure-Dart
  transport speaking the same routes the app's `OcptRelayRemoteStorage` speaks — `readChangesetsSince`
  (`GET …/changesets?since=`), `appendChangeset` (`POST …/changesets`, `Authorization: Bearer`, and
  an optional `X-Ocpt-Enrolment-Secret` for the create-on-upstream case). Snapshot routes are not
  needed for reconciliation (see below). Injectable `http.Client` for tests.
- `OcptRelayReconciler` (new): given the local `OcptRelayStore`, an `OcptRelayUpstreamClient`, a
  `projectId` and its token, runs **push then pull**, both directions deduped by `changesetId`
  (Phase A):
  - *push*: read the set relay's own changesets after the per-upstream **push cursor** and
    `appendChangeset` each to the upstream; advance the cursor past the highest pushed.
  - *pull*: `readChangesetsSince` the upstream after the per-upstream **pull cursor** and
    `store.append` each locally (idempotent); advance the cursor.
  - Cursors live in a new local `reconcile_cursors(upstream, projectId, pushCursor, pullCursor)`
    table in `OcptRelayStore` (relay-local bookkeeping, never synchronised), so a re-run does not
    re-push the same day. Idempotency remains the safety net when the cursor is stale.
  - Snapshots are **not** exchanged: the base state a set relay's morning snapshot covers is exactly
    what the prep relay already holds (the project came from prep), and the only new work is the
    day's changesets, all above that snapshot. Reconciling the changeset logs converges without
    touching either relay's snapshots.
- CLI: `bin/ocpt_sync_relay.dart` gains a `reconcile` subcommand. It parses `--invite '<ocpt://join…>'`
  (a few lines of `Uri` parsing local to the bin — the app's `OcptRelayInvite` is not reachable from
  this package) into upstream base URI + projectId + token, `--db-path` (defaulting as the serve path
  does), and an optional `--enrolment-secret` for a project the upstream has never seen. It opens the
  local store, runs the reconciler, prints a one-line summary (`pushed N, pulled M`), and exits.
- Tests: `OcptRelayReconciler` against two in-memory stores fronted by two `OcptRelayServer`s over a
  loopback `http` client (push+pull, a second run pushing nothing, a mid-day divergence converging);
  CLI arg/invite parsing.

### Phase C — The `ocpt://relay` enrolment model (app)

- `OcptRelayEnrolment` (new, `lib/models/sync/ocpt_relay_enrolment.dart`): fields `relayBaseUri: Uri`,
  `enrolmentSecret: String`; `toEnrolmentString()` → `ocpt://relay?r=<baseUri>&e=<secret>`;
  `parse`/`tryParse` mirroring `OcptRelayInvite` (reject wrong scheme/host or empty `r`/`e`);
  `toString()` masks the secret. Equatable.
- Tests: `test/models/sync/ocpt_relay_enrolment_test.dart` — round-trip, and parse rejecting a bad
  scheme, a bad host and an empty field.

### Phase D — `repointProjectToRelay` (app manager)

- `OcptSyncManager.repointProjectToRelay({database, projectId, projectFilePath, projectName,
  appVersion, relayBaseUri, enrolmentSecret, deviceId})`: loads the existing pairing to recover the
  **current token** (a `StateError` when the project is not paired — re-pointing an unpaired project
  is meaningless), `savePairing`s the same token against the new `relayBaseUri`, opens the relay
  transport with `enrolmentSecret`, `pushLocalEdits` (creating the project on the set relay when
  absent, idempotent when present), publishes a snapshot to bootstrap a joiner, and restarts the sync
  session against the new `relayId`. It mirrors `pairProjectToRelay` exactly, minus the token minting.
- Tests: `test/managers/sync/ocpt_sync_manager_pairing_test.dart` (or a sibling) — re-pointing keeps
  the token, overwrites the pairing URL, and restarts the session against the new URL.

### Phase E — The "Changer de relais" flow (app UI)

A two-state route mirroring the Partager (sharing) screen's Configure→Invite shape, reached from the
sync status panel:

- ① **Configure** — scan an `ocpt://relay` QR (mobile, reusing the joining scanner widget) or
  paste/type the set relay URL + enrolment secret (desktop). Calls `repointProjectToRelay`.
- ② **Show QR** — after re-pointing, display the `ocpt://relay` enrolment QR (URL + secret), the
  address and a copy button, so the next crew member scans it. The first operator types it once;
  everyone after scans.
- Wiring: a new "Changer de relais…" entry in `ocpt_sync_status_indicator.dart`'s panel, a new route,
  a bloc following the sharing bloc's split. Withheld under read-only; absent for an unpaired project.
- Tests: bloc test (configure success/failure, showing the QR), page test, indicator test for the new
  menu entry.

### Phase F — Operator guide and architecture fold

This is the **technical/operator** documentation (`docs/`, developer-facing), not the end-user guide
(that is Phase G).

- **Operator runbook**: a new `docs/on-set-server.md` (a self-hoster/operator guide, not code) — a
  "day on set" runbook: starting the set relay on a laptop or Pi, generating the enrolment QR, the
  crew re-pointing, the evening `reconcile`, and the "laptop dropped in the sand" recovery via any
  tablet's own replica. The relay `README.md` gains the `reconcile` subcommand.
- **Fold**: fold M6 into `docs/architecture/sync.md` (idempotent append, the reconcile client and
  CLI, the `ocpt://relay` enrolment QR and the re-point flow), delete this sub-plan **and**
  `collaboration-and-sync.md`, and update the `AGENTS.md` status table (the sync work is done — the
  roadmap continues with call sheets).

### Phase G — The end-user guide for collaboration (M2–M6)

**Runs last, and only after Benoit has validated all of M2 through M6** — the whole collaboration
feature is nothing in the end-user guide today, and this phase is what fills that gap in one pass
rather than piecemeal per milestone. It is the user-facing counterpart of the developer fold in
Phase F, and touches `docs-site/` (the Docusaurus filmmaker guide), never `docs/`.

- **New guide section** in `docs-site/docs/` covering the collaboration feature end to end, in the
  filmmaker's terms, not the engine's: sharing a project (the Partager screen, pairing, the invite
  QR/link), joining one (the Rejoindre screen, camera scan or pasted link), what offline-first means
  in practice (every device holds the whole project; edits queue and merge; the sync status
  indicator's states), presence (who else has the project open, in which mode), working on a tablet
  or phone (the M2 responsive layouts and the mobile share-sheet export), and the on-set server for
  a shoot (pointing at the set relay by QR via "Changer de relais", and a plain-language pointer to
  the operator runbook for whoever runs the laptop). Settle the section's user-facing name with
  Benoit when writing it — he referred to the whole feature as the "mode contributeur".
- **Both locales**: English under `docs-site/docs/`, French under
  `docs-site/i18n/fr/docusaurus-plugin-content-docs/current/`, mirroring the existing structure; the
  guide content is `CC-BY-4.0`, not `Apache-2.0` (see `docs-site/README.md`).
- **Wiring**: add the new pages to `docs-site/sidebars.ts`, and any new i18n JSON the navbar/category
  labels need.
- **Screenshots**: capture the Partager/Rejoindre screens, the sync indicator and the presence
  cluster through `tool/screenshot-app.sh`, into `docs-site/static/img/screenshots/`, as the existing
  mode pages do.
- **Verification caveat**: the Docusaurus build needs a Node toolchain the devcontainer does **not**
  carry (`docs-site/README.md`), so this phase's local gate is `dart run tool/check_markdown.dart`
  plus `reuse lint`; the site build itself is verified by its CI workflow, not locally.

## Out of scope (unchanged from the parent plan)

Continuous upstream following, snapshot exchange between relays, multi-project reconciliation in one
command (run it per project), user accounts, and everything §6 of the parent plan already excludes.
