<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — collaboration and sync

How a project becomes shareable between people and devices. The decisions are argued in
[ADR 0009](../adr/0009-offline-first-sync-through-a-domain-blind-relay.md) (offline-first through a
domain-blind relay) and [ADR 0010](../adr/0010-sync-ready-data-model-prerequisites.md) (what the
schema needed first); this file says what the code does because of them. The changeset engine and
the relay have shipped; live push, presence and the portable on-set server are still ahead — see
[`../plans/collaboration-and-sync.md`](../plans/collaboration-and-sync.md).

**The shape in one breath.** Every device keeps a full local replica and is completely usable
offline; changes queue and merge on reconnect. Merge is **client-side and per column**, so the
director editing a shot's framing and the assistant director setting its shooting day both survive.
The authority everyone syncs against is a **single-tenant, domain-blind relay** — one self-hostable
Dart server per person or per production that never parses a changeset and never learns a table
name, so the domain model evolves without ever redeploying it. The all-in-one desktop build needs no
server at all: sync is opt-in per project.

## The two packages

Two pure-Dart packages beside `packages/fountain_kit`, both free of any Flutter import (dependencies
never reference their dependents), each a CI matrix row gated by `dart analyze` + `dart test`:

- **`packages/ocpt_sync_protocol`** — the wire format alone, shared by the app and the relay and by
  nothing else: `OcptChangesetEnvelope`, `OcptStoredChangeset`, `OcptSequenceNumber`,
  `OcptLamportStamp`, `OcptSnapshotDescriptor`, `OcptSyncError`, and their JSON codecs. It carries no
  table name and no domain type.
- **`packages/ocpt_sync_relay`** — the server: `shelf` + `shelf_router`, a `sqlite3` file of opaque
  blobs, the five routes, token checking, snapshot pruning. It depends on `ocpt_sync_protocol`; **the
  app never depends on it** — the client talks to it purely over HTTP and a WebSocket.

## The client — `OcptSyncManager`

`OcptSyncManager extends AbsWithLifeCycle`, registered with a builder factory (`dependsOn` the
projects, properties and secrets managers) and resolved through `globalGetIt()`. It follows the
one-service-per-responsibility split `OcptExportManager` set:

- **`OcptChangesetService`** — turns a replica's own un-pushed local edits into a changeset and
  appends it (`pushLocalEdits`), and applies every changeset a relay holds that this replica has not
  seen (`pullAndApply`); `syncOnce` is push-then-pull. Applying runs in a transaction with
  `PRAGMA defer_foreign_keys = ON`, since a changeset can violate a foreign key part way through.
- **`OcptMergeService`** — per-column resolution against `row_field_versions`, plus tombstone
  handling. The winner is the column's own `(counter, deviceId)` Lamport stamp, never a relay
  sequence number — so the same edits converge on the same value whichever relay carried them and in
  whichever order they arrived.
- **`OcptScreenplayMergeService`** — the three-way line merge for `screenplays.fountainText` against
  the nearest common `screenplay_snapshots` row, and the only place that can surface a conflict to
  the user. Merged text is written through `OcptScreenplayService.saveScreenplayText` like any edit,
  so scene reconciliation reruns after a merge exactly as after typing.
- **`OcptSnapshotService`** — turns the project into snapshot bytes and back by **reusing the
  portable package** (`OcptProjectPackageService`): the zip of the `.ocpt` and its assets *is* the
  opaque snapshot payload, so nothing new is serialised. `buildSnapshot` packages the project and
  stamps a descriptor (a fresh id, the relay sequence it reflects, the byte length, a sha256 digest);
  `applySnapshot` verifies the digest and unpacks the bytes into a fresh project.
- **`OcptPairingService`** — reads and writes a project's pairing: the relay base URL in the local
  `sync_pairings` table, the project token through `OcptSecretsManager` (secure storage), never in
  the `.ocpt`.

**Writes target the working copy, never a preview.** The database-touching services write through
`OcptOpenProjectModel.fileDatabase`, not its `database` slot: a changeset arriving while the user
reads an old version belongs to the working copy, not the read-only replica on screen. The
`isReadOnly` guards in the domain services are scoped to user edits and never swallow an incoming
merge — `OcptProjectDatabase.refusesUserWrite` asks "was this handed the preview database?", not "is
this project read-only?".

### The transport seam

`OcptRemoteStorage` is the five-operation seam the engine exchanges work through — append a
changeset, read changesets since a sequence, upload a snapshot, fetch the latest snapshot, and a
stream announcing new work — speaking only `ocpt_sync_protocol`'s wire types and opaque bytes, never
a table name. Two implementations:

- **`OcptFolderRemoteStorage`** — a plain directory (`changesets/`, `snapshots/`), no network at all.
  It exercised the whole engine before any server existed, and stays as the desktop fallback over any
  file-sync client. Its `newWorkStream` is empty (nothing to observe between launches).
- **`OcptRelayRemoteStorage`** — the HTTP + WebSocket transport to the relay. The four operations go
  over `package:http`; `newWorkStream` connects a WebSocket that pings on new work and reconnects
  with a small backoff after a drop, emitting nothing while disconnected (the engine falls back to
  polling `readSince`). The bearer token rides the socket's request headers — which works because the
  client is `dart:io`'s `IOWebSocketChannel`.

### The sync session and its status

`OcptSyncSession` drives a paired project: an initial `syncOnce`, a `pullAndApply` on every
`newWorkStream` ping, and a `syncOnce` on a periodic timer so this replica's own edits reach the
relay without waiting for someone else's; `syncNow()` is the manual trigger. It is started and
stopped explicitly — the workspace starts it when it opens a paired project and stops it on close.
It exposes `OcptSyncStatus` (a sealed value: in sync, syncing, offline with a pending count, or an
error): the relay rejecting a request is an error, anything else — a refused connection, a dropped
socket — is offline, and a later success recovers to in sync; a transport failure never throws out of
the session. The `relayId` keying `sync_relay_cursors` is the relay's base URL, stable per relay so
the same project behind two relays keeps two independent delivery cursors.

## The data model

Documented as schema in [`foundations.md`](foundations.md); its sync meaning:

- Every **synchronised** table carries `isDeleted` (ADR 0010): no service ever deletes a
  synchronised row — a "delete" is an update to it, and every read filters tombstones out.
- **Ordering is `sortKey`**, a fractional index, so a move writes exactly one row and two concurrent
  insertions at the same index coexist; the legacy `position` column is never renumbered.
- **`row_field_versions`** is the per-column stamp sidecar the merge reads. A per-replica `deviceId`
  lives in `OcptPropertiesManager`.
- Two tables are **local to a replica and never synchronised** — no `is_deleted`, so the rule in
  `lib/utils/ocpt_synchronised_tables.dart` drops them out on its own: `sync_relay_cursors` (one
  delivery cursor per relay) and `sync_pairings` (a project's relay base URL). `project_versions`
  and `local_erasures` are local too, and `scenes` is derived and recomputed, never merged.

## The relay server

One binary, one port, one SQLite file, behind a TLS-terminating reverse proxy. `OcptRelayStore`
holds three tables of nothing but opaque payloads — a project's token hash, its changesets keyed by
an assigned per-project sequence, its snapshots. `OcptRelayServer` is a `shelf` handler over it with
five routes: `POST/GET …/changesets` (append returns the assigned sequence; read is since a required
`?since=`), `POST/GET …/snapshot` (a descriptor plus base64 bytes), and the `…/events` WebSocket that
pings a project's subscribers whenever a replica appends. It moves opaque bytes and never decodes a
payload — **if a reviewer finds a table name or a domain type in this package, the design has
drifted.**

**A snapshot lets the log below it be pruned.** A snapshot at sequence *N* is a complete,
self-consistent state, so `uploadSnapshot` deletes every changeset at or below *N* in the same
transaction: a replica behind *N* catches up by fetching the snapshot and then reading changesets
above it, losing nothing.

**Two secrets, neither ever typed into the server** ([ADR 0009](../adr/0009-offline-first-sync-through-a-domain-blind-relay.md),
and the deployment topology in the plan's §5). The **instance enrolment secret** is set by the
operator at deploy time as an environment variable; an append for an unknown project creates it only
when the request carries that secret, so whoever holds it creates projects from the app alone, with
nothing to provision by hand. The **per-project token** is minted by the client at pairing time and
opens exactly that project; the relay stores only a fast hash of it (the token is full-entropy
machine output, not a password), and failed authentications are rate-limited per source, which
doubles as the cheapest denial-of-service guard. `buildRelayServerFromEnvironment` reads the port,
address, database path and the enrolment secret; `bin/ocpt_sync_relay.dart` serves it with a
clean SIGINT/SIGTERM shutdown. A multi-stage `Dockerfile` compiles the binary onto a slim runtime
carrying only `libsqlite3`; the `docker-compose.yml` runs one relay, a second person being a second
service — same image, its own secret and volume — never a second tenant inside one.

## Sharing, joining, and what the user sees

Sync is invisible when it works; the visible surface is deliberately small.

- **Pairing (the Partager screen, `lib/ui/pages/sharing/`)** — reached from a project card's `⋮`
  menu, one full-screen route in two states. ① *Configure* takes the relay address and the enrolment
  secret and calls `OcptSyncManager.pairProjectToRelay`, which mints the token, saves the pairing,
  pushes the project's changesets (creating it on the relay), publishes a snapshot so a joiner can
  bootstrap, and starts the session. ② *Invite* then shows the QR the crew scans, the relay address,
  the masked token, a **copy-the-invite-link** button, and a *stop sharing* that goes through
  `OcptConfirmDialog` into `unpairProject`.
- **Joining (the Rejoindre screen, `lib/ui/pages/joining/`)** — reached from the Home toolbar,
  carrying no open-project guard since joining is how a project comes to exist locally. A camera scan
  on a tablet (`QrCodeReader` from the ACT `act_qr_code` package, instantiated only on mobile) or a
  pasted **invite link** on desktop both resolve to one `OcptRelayInvite`
  (`ocpt://join?r=…&p=…&t=…`); `joinFromRelay` fetches the snapshot into a fresh `.ocpt` (a native
  save location on desktop, the app documents directory on mobile), saves the pairing and opens the
  project.
- **The status indicator** (`lib/ui/pages/workspace/widgets/ocpt_sync_status_indicator.dart`) sits in
  the shared workspace status bar, so every mode gets it at once. It seeds from
  `OcptSyncManager.syncStatus`, rebuilds on the status stream, and is absent for an unpaired project;
  a tap opens a panel to sync now, show the invite QR or re-pair. Under a read-only version preview
  its actions are withheld.

`act_qr_code` draws the QR (`QrCodeImage`) and reads it (`QrCodeReader`, with camera permission
handled) — an ACT package used in place of a pub.dev QR-or-scanner dependency.
