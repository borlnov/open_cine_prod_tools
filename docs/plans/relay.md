<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# M4 — The relay: the changeset engine over the network

This is the implementation plan for M4 of `docs/plans/collaboration-and-sync.md`: giving the
changeset engine M3 built over a folder its network transport. It is written for the Sonnet 5
agents that will build it, orchestrated and reviewed by the main session. **Read the repository
`CLAUDE.md` and `docs/plans/collaboration-and-sync.md` first** — this plan assumes their
architecture, ways of working, coding standards, licensing rules and verification gates, and does
not repeat them. When this plan and an ADR disagree, the ADR wins
([0009](../adr/0009-offline-first-sync-through-a-domain-blind-relay.md),
[0010](../adr/0010-sync-ready-data-model-prerequisites.md)).

M4 folds into `docs/architecture/` and this file is deleted once it ships. M5 (live push and
presence) and M6 (the portable on-set server) stay in `collaboration-and-sync.md`.

## What already exists

M3 shipped the engine and its only transport:

- `packages/ocpt_sync_protocol` — the wire types the relay and the client both speak:
  `OcptChangesetEnvelope`, `OcptStoredChangeset`, `OcptSequenceNumber`, `OcptSnapshotDescriptor`,
  `OcptLamportStamp`, `OcptSyncError`, and their JSON codecs. It carries no table name and no domain
  type, and M4 adds nothing domain-shaped to it.
- `OcptRemoteStorage` (`lib/managers/sync/services/ocpt_remote_storage.dart`) — the five-operation
  transport seam: `append`, `readSince`, `uploadSnapshot`, `fetchLatestSnapshot`, `newWorkStream`.
- `OcptFolderRemoteStorage` — the directory implementation, which stays as the desktop fallback.
- `OcptSyncManager` / `OcptChangesetService` / `OcptMergeService` / `OcptScreenplayMergeService` —
  the client engine, driven today against a folder.
- `sync_relay_cursors` — a local (non-synchronised) table holding one delivery cursor per relay, so
  the same project behind two relays keeps two independent read positions.

M4 provides the second `OcptRemoteStorage` implementation and the server behind it. **Nothing in the
engine changes**: the seam is the contract, and if a merge service has to learn the relay exists,
the seam was drawn wrong.

## The decomposition

Logical commits across three phases, numbered from 1 within each phase. The server package
(Phase A) and the client transport (Phase B) carry no new UI. Phase C's design is validated — a
mockup in the "OpenCineProdTools design shell" Claude Design project
(`Pairing and Sync Design.dc.html`) — so it builds against a settled layout rather than waiting on
one.

### Phase A — `packages/ocpt_sync_relay` (the server)

A plain-Dart package beside `ocpt_sync_protocol`, depending on it, on `shelf` + `shelf_router`, on
`sqlite3` (not drift — the store holds opaque blobs, and drift is a Flutter-adjacent weight the
server does not need), and on `crypto` for the token hash. It depends on the app in no direction.
Its gate is `dart analyze` + `dart test`; it joins the `flutter_lint.yml` matrix as
`{ name: ocpt_sync_relay, path: packages/ocpt_sync_relay }`, the same way `ocpt_sync_protocol` did.

1. **Package scaffold.** `pubspec.yaml`, `analysis_options.yaml` matching the other packages, the
   REUSE/SPDX headers, the CI matrix row, and an `OcptRelayStore` façade over an empty SQLite schema
   (`projects`, `changesets`, `snapshots`), every payload a `BLOB`. No route yet — just the store
   and its tests: a changeset appended and read back, a sequence number that only ever increases.
2. **The store, complete.** `append` assigning the next per-project sequence, `readSince` returning
   the tail of the log oldest-first, `uploadSnapshot` storing bytes + descriptor and marking it
   latest, `fetchLatestSnapshot`, and project creation. Sequence assignment is serialised per
   project so two concurrent appends never collide on a number.
3. **Snapshot pruning.** A snapshot at sequence *N* is a complete self-consistent state, so every
   changeset at or below *N* becomes redundant: a replica behind *N* catches up by fetching the
   snapshot and then reading changesets above *N*, never the pruned ones. `uploadSnapshot` prunes
   `changesets` at or below the snapshot's sequence in the same transaction. The test the plan names
   — "pruning not losing a changeset a replica has not yet read" — is that a replica at cursor
   *C < N* still converges: it must receive the snapshot (jumping it to *N*) and every changeset
   above *N*, and lose nothing, precisely because what was pruned is below the snapshot it now holds.
4. **The five routes.** A `shelf_router` handler: `POST /projects/<id>/changesets` (append, returns
   the assigned sequence), `GET /projects/<id>/changesets?since=<seq>` (read since), `POST
   /projects/<id>/snapshot` (upload), `GET /projects/<id>/snapshot` (fetch latest), `GET
   /projects/<id>/events` (the WebSocket). Bodies are `ocpt_sync_protocol`'s own JSON; the router
   never looks inside a changeset payload.
5. **Authentication.** A middleware checking the `Authorization: Bearer <token>` against the stored
   token hash for `<id>`. An append for an unknown `<id>` creates the project **only** when the
   request also carries the instance enrolment secret (a second header), and is rejected otherwise;
   the client picks the id and the token. The store keeps only a fast hash of each token (full-entropy
   machine output, no dictionary to defend). Failed authentications are rate-limited per source, which
   doubles as the cheapest DoS guard.
6. **The WebSocket route.** `GET /projects/<id>/events` upgrades to a socket that emits one opaque
   "new work" ping whenever any replica appends a changeset or a snapshot to `<id>`. It carries no
   payload — a client reacts by calling `readSince`/`fetchLatestSnapshot`, exactly as
   `OcptRemoteStorage.newWorkStream`'s contract says. Same bearer check as the HTTP routes.
7. **The binary and the deployment.** `bin/ocpt_sync_relay.dart` reading port, enrolment secret and
   database path from the environment and starting the server; a `Dockerfile`; the
   `docker-compose.yml` of §5.1 (one service, one volume, one enrolment secret, behind a
   TLS-terminating reverse proxy — documented, not bundled). A short `README.md` for a self-hoster.

Server tests are plain Dart and cover, per the plan: route behaviour, sequence monotonicity,
rejection of a bad or missing token, an unknown project refused without the enrolment secret, and
pruning not losing a changeset a replica has not yet read. **The domain-blind gate is a review
gate**: if a reviewer finds a table name or a domain type anywhere in this package, the design has
drifted and the commit does not land.

### Phase B — the client transport

1. **`OcptRelayRemoteStorage implements OcptRemoteStorage`**
   (`lib/managers/sync/services/ocpt_relay_remote_storage.dart`). `append`/`readSince`/
   `uploadSnapshot`/`fetchLatestSnapshot` over `package:http`; `newWorkStream` over
   `package:web_socket_channel`, reconnecting on drop and emitting nothing while disconnected (the
   engine falls back to its poll on `readSince`, so a dropped socket is a normal, silent state). It
   speaks only `ocpt_sync_protocol` and opaque bytes, the same boundary the folder transport keeps.
2. **Pairing storage.** A new local, non-synchronised table `sync_pairings` (one row per project:
   relay base URL — **not** the token), added additively the way `sync_relay_cursors` was: local
   tables are the two standing exceptions to the frozen-v1 rule (ADR 0029), so this is a schema bump
   with no migration of synchronised data. **The project token is a secret and never lands in the
   `.ocpt` at all** — it is stored through the ACT secure-storage manager
   (`act_local_storage_manager`'s `AbstractSecretsManager` / `SecretItem`, which wraps
   `flutter_secure_storage`), not `flutter_secure_storage` directly and not a plain column. The app
   has no concrete secrets manager yet, so this commit introduces `OcptSecretsManager extends
   AbstractSecretsManager` (registered like the other managers, `dependsOn` the properties manager),
   exposing one per-project token secret keyed by project id.
3. **Wiring the transport in.** `OcptSyncManager.openRelayRemoteStorage(...)` beside
    `openFolderRemoteStorage`, and the sync driver that, for a paired project, runs the
    push-then-pull loop and subscribes to `newWorkStream` — reusing the existing
    `changesetService` push/pull unchanged. A restore publishes through the snapshot route, not as a
    changeset (§3.4). Unpaired projects behave exactly as today.

### Phase C — the screens and the join flow

The design is validated against the mockup named above: the Home entry points, the Partager screen's
two states, the Rejoindre screen, and the sync status indicator with its panel, all in the studio
look. Build order:

1. **The snapshot engine.** M3 left `OcptRemoteStorage.uploadSnapshot`/`fetchLatestSnapshot` unused,
   but the join flow, the first append to an empty relay (§5.3) and a restore's publish (§3.4) all
   need a project turned into snapshot bytes and back. Reuse `OcptProjectPackageService`: the
   portable package — a zip of the `.ocpt` and its assets, already tested — *is* the opaque snapshot
   payload. A service produces a snapshot from the open project (`writePackage`, the descriptor's
   `sequenceUpTo` being the relay cursor at that moment) and applies fetched bytes into a new local
   project (`readPackage`). Wire the session to upload a snapshot on the first append to an empty
   relay, and add `joinFromRelay(baseUri, token)` that fetches the snapshot and materialises a new
   `.ocpt`. Fake-transport tests; the app still never depends on the relay package.
2. **QR and the invite payload.** Encode `{relayBaseUri, projectId, token}` as the invite link the
   QR carries, and generate the QR (check `actlibs/` first, else `qr_flutter`).
3. **The Partager screen.** A full-screen route reached from the Home card's ⋮ menu
   ("Partager / Synchroniser"), one screen in two states: ① Configure (relay address + enrolment
   secret → "pair and create on the relay", the token minted and stored via `OcptSecretsManager`)
   → ② Invite (the QR, the relay address, the masked token, and "stop sharing" through
   `OcptConfirmDialog`). Its own bloc.
4. **The Rejoindre screen.** A full-screen route reached from the Home toolbar ("Join a shared
   project"): a camera scan on a tablet (`mobile_scanner`, mobile only, camera permission) and manual
   entry (relay address + token) on desktop and as the fallback; on confirm it calls `joinFromRelay`,
   shows the snapshot download, and opens the new project. Its own bloc. The camera path can only be
   verified on a real device — over the devcontainer's wireless adb.
5. **The status indicator.** In the workspace status bar, reading `OcptSyncStatus`: in sync, syncing,
   offline with a pending count, or an error. It is **clickable** — the workspace's sync entry point:
   a tap opens a panel (sync now, show the invite QR, re-pair). The workspace starts the sync session
   when a paired project opens and stops it on close. It never writes, so under a read-only preview
   it stays informational and its actions are withheld.
6. **Wiring and l10n.** The Home card ⋮ action, the Home "Join" action, the status-bar slot, and
   every user-visible string through `Tr.of(context)` in both ARB files (in French a scene is
   « séquence »).

## Verification gates

Every commit passes the full `CLAUDE.md` §*Verification gates*. The relay package adds a
`dart analyze` + `dart test` pass from `packages/ocpt_sync_relay`, mirrored by the CI matrix row.
`dart run tool/check_markdown.dart` runs while this file and the architecture docs are edited. The
architecture fold (into `foundations.md`, with the relay's shape, its two secrets and the pairing
storage) and the deletion of this file are the last commit, exactly as M2's fold was.
