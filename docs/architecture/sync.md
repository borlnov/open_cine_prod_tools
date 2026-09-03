<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — collaboration and sync

How a project becomes shareable between people and devices. The decisions are argued in
[ADR 0009](../adr/0009-offline-first-sync-through-a-domain-blind-relay.md) (offline-first through a
domain-blind relay) and [ADR 0010](../adr/0010-sync-ready-data-model-prerequisites.md) (what the
schema needed first); this file says what the code does because of them. The changeset engine, the
relay, live push, presence, the portable on-set server and in-app relay hosting have all shipped —
see [`../on-set-server.md`](../on-set-server.md) for the operator's own "day on set" runbook.

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

`OcptRemoteStorage` is the seam the engine exchanges work through — append a changeset, read
changesets since a sequence, upload a snapshot, fetch the latest snapshot, a stream announcing new
work, and, for presence (M5), a `sendPresence`/`presenceStream` pair carrying opaque frames a replica
broadcasts to and receives from its peers — speaking only `ocpt_sync_protocol`'s wire types and
opaque bytes, never a table name. Two implementations:

- **`OcptFolderRemoteStorage`** — a plain directory (`changesets/`, `snapshots/`), no network at all.
  It exercised the whole engine before any server existed, and stays as the desktop fallback over any
  file-sync client. Its `newWorkStream` is empty (nothing to observe between launches), and it has no
  peer, so `sendPresence` is a no-op and `presenceStream` is empty too.
- **`OcptRelayRemoteStorage`** — the HTTP + WebSocket transport to the relay. The four request
  operations go over `package:http`; the `events` WebSocket carries everything live, over one
  reconnecting socket kept open while either `newWorkStream` or `presenceStream` has a listener. Its
  read loop routes each inbound frame — the `new-work` ping to `newWorkStream`, any other frame (a
  peer's opaque presence payload) to `presenceStream` — while `sendPresence` writes this replica's
  own frames back up it; a drop reconnects with a small backoff and emits nothing meanwhile (the
  engine falls back to polling `readSince`). The bearer token rides the socket's request headers —
  which works because the client is `dart:io`'s `IOWebSocketChannel`.

### The sync session and its status

`OcptSyncSession` drives a paired project: an initial `syncOnce`, a `pullAndApply` on every
`newWorkStream` ping, and a `syncOnce` on a periodic timer so this replica's own edits reach the
relay without waiting for someone else's; `syncNow()` is the manual trigger. With the ping now the
real driver, that timer is a long-interval fallback (sixty seconds), not the primary path it was
before live push. It is started and
stopped explicitly — the workspace starts it when it opens a paired project and stops it on close.
It exposes `OcptSyncStatus` (a sealed value: in sync, syncing, offline with a pending count, or an
error): the relay rejecting a request is an error, anything else — a refused connection, a dropped
socket — is offline, and a later success recovers to in sync; a transport failure never throws out of
the session. The `relayId` keying `sync_relay_cursors` is the relay's base URL, stable per relay so
the same project behind two relays keeps two independent delivery cursors.

### Presence

`OcptPresenceService` rides the same transport a paired project already syncs over. It heartbeats
this replica's own `OcptPresenceFrame` — its `deviceId`, platform and current `OcptWorkspaceMode` —
every five seconds through `sendPresence`, listens to `presenceStream` for peers doing the same, and
keeps an `OcptPresenceRoster` of whoever heartbeated within a twelve-second timeout, dropping a peer
gone silent longer on the next tick. Disconnects are handled entirely by that timeout, so the relay
never has to learn *who* left — it only ever rebroadcasts opaque frames. `OcptSyncManager` starts and
stops the service alongside the sync session, and `updatePresenceMode` reports a mode switch so it
reaches peers on the next heartbeat. Nothing about presence is persisted, on the device or the relay:
it is entirely ephemeral by construction.

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
`?since=`), `POST/GET …/snapshot` (a descriptor plus base64 bytes), and the `…/events` WebSocket,
which is bidirectional: it pings a project's subscribers whenever a replica appends, and rebroadcasts
any *other* frame a subscriber sends — a peer's opaque presence payload — to that project's other
subscribers, never to the sender. It moves opaque bytes and never decodes a payload — **if a reviewer
finds a table name or a domain type in this package, the design has drifted.**

**A snapshot lets the log below it be pruned.** A snapshot at sequence *N* is a complete,
self-consistent state, so `uploadSnapshot` deletes every changeset at or below *N* in the same
transaction: a replica behind *N* catches up by fetching the snapshot and then reading changesets
above it, losing nothing.

**`append` is idempotent on the envelope's own `changesetId`.** `OcptRelayStore`'s `changesets`
table carries a `changesetId TEXT` column (a legacy database gets it through an idempotent
`ALTER TABLE … ADD COLUMN`, run on every startup) under `UNIQUE(projectId, changesetId)`; `append`
checks for an existing row with that `(projectId, changesetId)` first and, when one is already
there, returns its sequence without inserting a second row — only a first sighting of a
`changesetId` consumes a new sequence number. `OcptRelayServer`'s `POST …/changesets` is
behaviourally unchanged by this (it already returned whatever sequence `append` handed back), but a
duplicate `POST` now answers with the same `{"sequence"}` rather than storing the changeset twice.
This is what lets a set relay re-push a whole day's log to a prep relay every evening with no
growth on a re-run — see reconciliation below.

**Two secrets, neither ever typed into the server** ([ADR 0009](../adr/0009-offline-first-sync-through-a-domain-blind-relay.md),
and `packages/ocpt_sync_relay/README.md`'s own deployment topology). The **instance enrolment
secret** is set by the
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

## Relay-to-relay reconciliation

A set relay on location gathers a day's changesets with no internet at all; at the end of the day it
reconciles them against the prep relay — as a **client** of it, reusing the same wire protocol every
replica already speaks, so no second merge implementation exists. The relay stays domain-blind
throughout: relay-to-relay reconciliation needs no domain merge at all, since the per-column stamps
inside a changeset's payload are relay-independent (ADR 0010) — moving opaque changesets between two
relays and letting *replicas* apply them later through the ordinary per-column merge **is** the
reconciliation.

- **`OcptRelayUpstreamClient`** (`packages/ocpt_sync_relay`) — a slim, pure-Dart client speaking two
  of `OcptRelayServer`'s own routes against an upstream: `readChangesetsSince` and `appendChangeset`
  (carrying an optional `X-Ocpt-Enrolment-Secret` so the very first push can create the project on
  the upstream, exactly as a fresh pairing does). Snapshot routes are deliberately not spoken here —
  reconciliation never exchanges snapshots: the state a set relay's own morning snapshot covers is
  exactly what the prep relay already held when the project was handed to it, so the only new work a
  reconciliation ever moves is the day's changesets, all sitting above that snapshot.
- **`OcptRelayReconciler.reconcileProject`** — push then pull against one `OcptRelayStore` and one
  upstream, both directions deduped by `changesetId`. Per-upstream cursors
  (`reconcile_cursors(upstream, projectId, pushCursor, pullCursor)`, a relay-local table, never
  synchronised) mean a re-run pushes and pulls nothing new in the common case; the `changesetId`
  dedup on both ends is the real safety net when a cursor is stale or absent, so reconciling twice,
  or against a cursor reset to zero, converges to the same state as reconciling once. It returns how
  many changesets were genuinely new on each side this run, careful not to double-count a changeset
  this same run both pushed and then read back as an echo of its own push.
- **The CLI** — `bin/ocpt_sync_relay.dart` gains a `reconcile` subcommand
  (`runReconcileCommand`/`parseReconcileInvite`): `--invite '<ocpt://join…>'` (the same invite string
  the sharing screen's QR carries, parsed locally since the app's own `OcptRelayInvite` is not
  reachable from this pure-Dart package) or the trio `--upstream/--project/--token`, plus `--db-path`
  (defaulting as `serve` does) and an optional `--enrolment-secret` for a project the upstream has
  never seen. It opens the local store, runs the reconciler once, and prints `pushed N, pulled M`.

## Re-pointing to another relay

A device already syncing a project can be pointed at a different relay — the set relay taking over
from the prep relay for the day, or back again — without losing its token or its history.

- **`OcptRelayEnrolment`** (`lib/models/sync/ocpt_relay_enrolment.dart`) encodes
  `ocpt://relay?r=<baseUri>&e=<secret>`: a relay's own address and its instance-wide enrolment
  secret, deliberately carrying neither a project id nor a project token — unlike `OcptRelayInvite`,
  which pairs one specific project to one specific relay, this URI only ever points a device at a
  *relay*. Scanning it therefore never hands out a project's own credential.
- **`OcptSyncManager.repointProjectToRelay`** loads the project's existing pairing to recover its
  current token (a `StateError` on an unpaired project — re-pointing has no token to reuse),
  re-saves the pairing against the new relay with that same token, pushes this replica's own local
  edits (creating the project there when the relay has never seen it, idempotent when it has),
  publishes a snapshot so a joiner can bootstrap, and restarts the sync session against the new
  relay. `relayIdFor` keys the delivery cursor by the relay's own base URL, so re-pointing to a
  different relay starts a fresh cursor there while re-pointing back to one already talked to simply
  resumes its own.
- **The "Changer de relais" screen** (`lib/ui/pages/repointing/`, `OcptRepointingBloc` +
  `OcptRepointingQrView`) is a two-state route mirroring the Partager screen's own Configure→shape:
  ① scan an `ocpt://relay` QR or type the relay address and enrolment secret, which calls
  `repointProjectToRelay`; ② show the same enrolment QR so the next crew member scans it in turn.
  Reached from the sync status panel's own `Changer de relais…` entry, withheld under a read-only
  preview and absent for an unpaired project, exactly like the panel's other actions.

## In-app relay hosting

Three topologies share the same relay binary: the permanent remote relay (always-on, headless,
behind a TLS reverse proxy — unchanged, still only the CLI + Docker of `packages/ocpt_sync_relay`),
the on-set relay (a laptop on a shoot, LAN only, one day), and the producer/director hub (one
durable machine that is always the rendez-vous, converging the project through its own replica, no
remote server ever). The last two are **the same "host on this machine" feature**, differing only by
one persisted flag; reaching a hosted relay from across the internet (NAT traversal, dynamic DNS,
exposing a personal machine) is out of scope — that is what the permanent Docker relay is for.

**`OcptRelayHostManager`** (`lib/managers/sync/ocpt_relay_host_manager.dart`, an `AbsWithLifeCycle`
owned by `OcptGlobalManager`) owns the lifecycle of **one** in-process `OcptRelayServer` over one
`OcptRelayStore` at a time, desktop-only in use — `startHosting` throws on
`PlatformManager.isMobile`, a programmer error the UI must never trigger. It exposes a host-state
stream seeded like `OcptSyncSession.status` (`stopped` / `starting` /
`online(lanBaseUri, enrolmentSecret)` / `failed`). `startHosting`, in order:

1. Reads the project's existing relay-side id through `OcptSyncManager.loadPairedProjectId` (an
   already-paired project keeps it; a never-paired one — the hub topology, with no remote relay ever
   involved — gets a freshly minted one).
2. Mints once, then reuses, that project's own stable hosting enrolment secret through
   `OcptSecretsManager`, so the enrolment QR stays the same across restarts.
3. Opens an `OcptRelayStore` at `<projectFilePath>.relay.sqlite` — beside the project file, kept in
   place after `stopHosting` so the hub case restarts without losing what was already relayed — and
   serves an `OcptRelayServer` on a **fixed** default port (`ocptDefaultInAppHostingPort`,
   overridable from the panel's own port field) — fixed rather than ephemeral so a restart keeps the
   same advertised address and a peer already holding an invite is not stranded on a port the OS
   picked afresh.
4. **Self-seeds**: points the project at `http://localhost:<port>` — `repointProjectToRelay` for an
   already-paired project, `pairProjectToRelay` for a never-paired one — so the host becomes the
   relay's own first replica, pushing its edits in, publishing a snapshot, and starting the sync
   session, which is also what starts presence.
5. Computes the advertised `lanBaseUri` from the first non-loopback IPv4 the interface ranking
   (`rankLanAddresses`, which pushes VPN/virtual adapters last) offers — the panel's dropdown lets a
   person pick another — falling back to loopback, with a logged warning, when none exists.

A failure at any step tears down whatever was already opened and reports `OcptRelayHostFailed`
rather than throwing — a bring-up failure is a state to render, exactly like `OcptSyncStatus`.
`reconcileWithUpstream(OcptRelayInvite)` runs `OcptRelayReconciler` and `OcptRelayUpstreamClient`
against the **live** store — never a second handle on the same `.relay.sqlite` file while the server
holds it — returning an `OcptReconcileOutcome` (`OcptReconcileSucceeded(pushed, pulled)` or
`OcptReconcileFailed(message)`), never throwing across the UI boundary.

**Auto-restart.** A local, per-device, never-synchronised "host on launch" flag
(`OcptPropertiesManager.loadHostOnLaunch`/`setHostOnLaunch`, keyed by the project's relay-side id)
drives `maybeAutoStartHosting`, which the workspace bloc runs on project open. When it brings hosting
up, its own self-seed has already started the sync session (and presence) against the freshly hosted
relay, so the workspace bloc skips the ordinary paired-session start rather than starting a second
one over the same project. `maybeAutoStartHosting` is **idempotent**: called again for a project it
is already hosting — as navigating back to it does, the workspace bloc being rebuilt each time — it
does nothing, since restarting would rebind the socket and drop connected peers. For the same
reason, hosting is owned by `OcptRelayHostManager` across every navigation and is **not** torn down
by the workspace bloc's `disposeLifeCycle` (nor is its self-seeded session): it stops through the
hosting panel's switch, a different project being hosted, or app shutdown.

**The hosting panel** (`OcptHostingPanel` over a sibling `OcptHostingBloc`,
`lib/ui/pages/sharing/widgets/ocpt_hosting_panel.dart`) is the Partager screen's "Héberger sur ce
poste" segment — desktop-only and withheld under a read-only preview, like every other write
affordance. It always shows a Marche/Arrêt switch and a "réhéberger au démarrage" checkbox; once
online it also shows an advertised-address dropdown (`OcptRelayHostManager.availableLanAddresses`,
re-detecting a network switch on a fresh screen entry, since the socket already binds every
interface) and a port field re-binding the socket through `startHosting`'s own `port` parameter, a
`SegmentedButton` choosing between the join invite (a device with no local copy of the project) and
the enrolment (a device that already has it, re-pointing here) — the one QR each currently selects
(the reusable `OcptQrCode` widget, `lib/ui/widgets/ocpt_qr_code.dart`, which the repointing screen's
own QR state also draws through, both now drawn at a larger, easier-to-scan size) — the
connected-peers list (reading `OcptSyncManager.presenceRoster`/`presenceRosterStream` — no host-side
presence code of its own, just the same roster the workspace toolbar already shows — each peer a
`ocptPresenceColor` dot and a `platform · id fragment` label, never a name), and a "Réconcilier
amont…" action: paste or scan an upstream `ocpt://join` invite, run the reconciler, show
`pushed N, pulled M`.

## Sharing, joining, and what the user sees

Sync is invisible when it works; the visible surface is deliberately small.

- **Pairing (the Partager screen, `lib/ui/pages/sharing/`)** — reached from a project card's `⋮`
  menu, one full-screen route. On desktop its body opens with a `SegmentedButton` splitting it into
  "Relais distant" and "Héberger sur ce poste" (see below); mobile stays single-mode. "Relais
  distant" is two states. ① *Configure* takes the relay address and the enrolment secret and calls
  `OcptSyncManager.pairProjectToRelay`, which mints the token, saves the pairing, pushes the
  project's changesets (creating it on the relay), publishes a snapshot so a joiner can bootstrap,
  and starts the session. ② *Invite* then shows the QR the crew scans, the relay address, the masked
  token, a **copy-the-invite-link** button, and a *stop sharing* that goes through
  `OcptConfirmDialog` into `unpairProject`.
- **Joining (the Rejoindre screen, `lib/ui/pages/joining/`)** — reached from the Home toolbar,
  carrying no open-project guard since joining is how a project comes to exist locally. A camera scan
  on a tablet (`mobile_scanner`, instantiated only on mobile) or a pasted **invite link** on desktop
  both resolve to one `OcptRelayInvite`
  (`ocpt://join?r=…&p=…&t=…`); `joinFromRelay` fetches the snapshot into a fresh `.ocpt` (a native
  save location on desktop, the app documents directory on mobile), saves the pairing and opens the
  project.
- **The status indicator** (`lib/ui/pages/workspace/widgets/ocpt_sync_status_indicator.dart`) sits in
  the shared workspace status bar, so every mode gets it at once. It seeds from
  `OcptSyncManager.syncStatus`, rebuilds on the status stream, and is absent for an unpaired project;
  a tap opens a panel to sync now, show the invite QR, re-pair, or `Changer de relais…` (opening the
  repointing screen above, `OcptRoute.repointing`). Under a read-only version preview its actions are
  withheld.
- **The presence indicator** (`lib/ui/pages/workspace/widgets/ocpt_presence_indicator.dart`) sits in
  the top toolbar instead — an overlapping avatar cluster naming every replica with the project open,
  and a `MenuAnchor` popover (the sync indicator's own mechanism) detailing each one's platform, a
  short id fragment and its current mode. Identity is automatic, since there are no accounts (ADR 0009
  §6): a colour derived from the `deviceId`, a `platform · fragment` label, self ringed in the accent
  and sorted first. It is absent for an unpaired project, exactly as the sync indicator is, and holds
  no write action, so a read-only preview withholds nothing.

`qr_flutter` draws the QR and `mobile_scanner` reads it. The ACT `act_qr_code` package covers both,
but its stale transitive plugins (`qr_code_scanner`, `permission_handler`) fail the Android and
Windows builds against this app's toolchains, so maintained pub.dev packages are used instead and the
ACT gap is left for a separate submodule fix.
