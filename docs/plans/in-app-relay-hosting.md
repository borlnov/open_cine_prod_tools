<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# In-app relay hosting

Let the desktop app **be** the relay, so a small team never needs a separate server. Today the only
way to run a relay is the CLI (`dart run bin/ocpt_sync_relay.dart`) or the Docker image — an
operator surface, fine for a permanent instance behind a reverse proxy, wrong for a film person on
set with a laptop. This adds a "Héberger sur ce poste" mode to the Partager screen (desktop only)
that starts the relay in-process, advertises it on the LAN by an enrolment QR, and — when asked —
keeps hosting the same project across app restarts. **Read the repository `CLAUDE.md`,
[`../architecture/sync.md`](../architecture/sync.md) and
[`on-set-server.md`](on-set-server.md) first** — this plan assumes the engine, the relay package,
the pairing/re-point machinery and presence they record, and does not repeat them. When this plan
and an ADR (0009, 0010) disagree, the ADR wins. This file is deleted once the work ships and its
outcome is folded into `sync.md`.

## The three topologies, and which one this is for

- **Permanent remote relay** — always-on, headless, behind a TLS reverse proxy, public address. Its
  surface stays the CLI + Docker of `ocpt_sync_relay`. **Unchanged by this plan**; a server that
  outlives a desktop session should not depend on one.
- **On-set relay** — a laptop on a shoot, LAN only, one day. Hosted from the app, ephemeral.
- **The producer/director hub** — one durable machine is always the rendez-vous that keeps and
  (through its own replica) converges the project; no remote server ever. Hosted from the app,
  persistent.

The last two are **the same "host on this machine" feature**; they differ only by one persisted
flag ("réhéberger au démarrage"). Both are LAN / rendez-vous models: reaching a hosted relay from
across the internet (NAT traversal, dynamic DNS, exposing a personal machine) is **out of scope** —
that is what the permanent Docker relay is for.

## What is already true (do not re-derive)

- `packages/ocpt_sync_relay` is **pure Dart** (no Flutter): `OcptRelayServer` (a `shelf` handler
  over five routes) and `OcptRelayStore` (a `sqlite3` file) run anywhere `dart:io` and `sqlite3`
  do, which includes the desktop targets this feature ships on.
- The app depends today **only on `ocpt_sync_protocol`** (the wire types), *not* on
  `ocpt_sync_relay`. Adding hosting introduces a new dependency `lib -> ocpt_sync_relay`. It stays
  one-way (the relay never learns about the app; it remains domain-blind, ADR 0009) and its *use*
  is desktop-gated at runtime.
- `OcptSyncManager.repointProjectToRelay` already does "point this project at an arbitrary relay
  base URI + enrolment secret, push my local edits, publish a snapshot to bootstrap a joiner, and
  restart the sync session". Hosting reuses it verbatim, with the base URI being this machine's own
  relay.
- `OcptRelayEnrolment` (`lib/models/sync/ocpt_relay_enrolment.dart`) already models
  `ocpt://relay?r=<baseUri>&e=<secret>` and round-trips it; `OcptRepointingQrView` already renders
  that enrolment QR. The hosting panel reuses both.
- Presence (M5) is domain-blind and rides the sync transport. The host machine's app is itself a
  replica, so the peers connected to the hosted relay are exactly
  `OcptSyncManager.presenceRoster` / `presenceRosterStream` — the same roster the workspace toolbar
  already shows. The peer list reuses them; no host-side, relay-level presence is invented.
- The relay package already carries `OcptRelayReconciler` and `OcptRelayUpstreamClient` (the
  evening push-then-pull, deduped by `changesetId`). The in-app reconcile reuses them against the
  **live in-process store**, never by opening the `relay.sqlite` file a second time while the
  server holds it.
- Secure storage is `OcptSecretsManager` (`AbstractSecretsManager`); local, never-synchronised
  per-project preferences have a home in `OcptPropertiesManager`.

## Decisions taken with Benoit (2026-09-02)

1. **We complete the CLI, we do not replace it.** The permanent/headless relay stays CLI + Docker.
2. **Firewall posture is acceptable** (the editor opens a listening socket on the LAN) and is
   **explained in the end-user guide**, not hidden.
3. **`relay.sqlite` lives beside the project file**, kept for the durable-hub case, per project.
4. **The Partager screen gains a segmented control** (`SegmentedButton` at the top of the body, the
   AppBar unchanged): "Relais distant" (the existing pair→invite flow) and "Héberger sur ce poste".
   The hosting segment is **desktop only** — absent on mobile, where the screen stays single-mode —
   and withheld under a read-only preview like every other write affordance.
5. **The hosting segment is one panel** (not a two-state flow): a Marche/Arrêt switch and the
   "réhéberger ce projet au démarrage" checkbox (unchecked by default) at the top; when running,
   the advertised LAN address, the enrolment QR, the nominative list of connected peers, and a
   "Réconcilier amont…" action appear below; greyed when stopped.
6. **The evening reconcile is an in-app action** inside the hosting segment (paste/scan an upstream
   `ocpt://join…` invite, run push-then-pull, show `pushed N, pulled M`). The relay CLI's own
   `reconcile` subcommand stays for the headless operator.

## Architecture

- **`OcptRelayHostManager`** (new, `AbsWithLifeCycle`, owned by `OcptGlobalManager`,
  `dependsOn` the sync + secrets + properties managers). Desktop-only in use. It owns the lifecycle
  of one in-process `OcptRelayServer` + `OcptRelayStore` at a time and exposes a host-state stream
  (`stopped` / `starting` / `online(lanBaseUri, enrolmentSecret)` / `failed`). Starting it:
  1. resolves (minting once, then reusing) this project's **stable enrolment secret** from
     `OcptSecretsManager`, so the QR is stable across restarts;
  2. opens `OcptRelayStore` at `<project>.relay.sqlite` beside the project file and serves
     `OcptRelayServer` on `0.0.0.0:<port>`;
  3. computes the **advertised LAN base URI** from `NetworkInterface.list()` (first non-loopback
     IPv4), for the `ocpt://relay` enrolment QR the peers scan;
  4. **seeds and joins** by calling `repointProjectToRelay` at `http://localhost:<port>` with that
     secret — the host becomes the first replica, its edits flow into the relay, and a snapshot is
     published so a joiner converges.
  Stopping it tears the server and store down and (for the ephemeral case) leaves the file in place
  beside the project.
- **Auto-restart** — a local, never-synchronised per-project flag in `OcptPropertiesManager`
  ("host on launch"). On a project open, if set, the manager auto-starts hosting.
- **Reconcile** — `OcptRelayHostManager.reconcileWithUpstream(OcptRelayInvite)` runs
  `OcptRelayReconciler` over an `OcptRelayUpstreamClient` against the **live** store, returning the
  pushed/pulled counts.
- **Dependency / build** — add `ocpt_sync_relay` as a `path:` dependency of the app. Its transitive
  deps (`shelf`, `sqlite3`, `web_socket_channel`) must not break any shipped build; `sqlite3` is
  already pulled by drift. This app ships no web target, so `dart:ffi` is not a concern, but the
  **Android/iOS builds in the CI matrix must be verified**, not just `pub get` (a known pitfall).

## Phases

Each phase is one or a few commits, delegated to a Sonnet 5 agent, run through the full
verification gate, and reviewed by the main session before the next. A–D are the app manager layer
(`flutter` gates, no UI); E is the UI; F is the documentation fold.

### Phase A — `OcptRelayHostManager` lifecycle (no UI)

- The manager above, minus reconcile and auto-restart: start → `online(lanBaseUri, secret)` → stop,
  the in-process server + store beside the project, the stable secret in `OcptSecretsManager`, the
  LAN base URI from `NetworkInterface.list()`, and the host-state stream (seeded the way
  `OcptSyncSession.status` is, since ACT streams do not replay — a known pitfall). Register it in
  `OcptGlobalManager`.
- Desktop-only: a clear guard so a mobile build never binds a socket.
- Tests: start/stop transitions and the emitted states, secret minted once then reused, the store
  file created beside the project, an injected interface list yielding the advertised URI.

### Phase B — Self-seed and the peer roster

- On start, `repointProjectToRelay` at `http://localhost:<port>` with the hosted secret, so the
  host is the first replica and a joiner gets a snapshot; on stop, end that session cleanly.
- Surface the peers: no new presence code — the panel will read `OcptSyncManager.presenceRoster` /
  `presenceRosterStream`, so this phase only wires the manager so those are live while hosting.
- Tests: starting hosting repoints to localhost and starts the session; stopping ends it; the
  roster is reachable while hosting.

### Phase C — In-app reconcile

- `reconcileWithUpstream(OcptRelayInvite)` running `OcptRelayReconciler` +
  `OcptRelayUpstreamClient` against the live store; returns `pushed N, pulled M`; surfaces a failure
  as a value, not a throw across the UI boundary.
- Tests: against two in-memory relays over a loopback `http` client (push+pull, a second run
  pushing nothing), mirroring `ocpt_sync_relay`'s own reconciler test.

### Phase D — Auto-restart persistence

- The local, never-synchronised "host on launch" flag in `OcptPropertiesManager`, toggled by the
  checkbox and read on project open to auto-start hosting.
- Tests: the flag round-trips per project; a project open with the flag set auto-starts hosting; one
  without does not; it is never written to a synchronised table.

### Phase E — The Partager segmented UI

- The `SegmentedButton` splitting the Partager body into "Relais distant" (the existing
  `OcptSharingConfigureView` / `OcptSharingInviteView`, untouched) and "Héberger sur ce poste",
  the latter **desktop-only** and **withheld under read-only**.
- The hosting panel (one panel, per decision 5): Marche/Arrêt switch, the "réhéberger au démarrage"
  checkbox, and — when online — the LAN address with a copy button, the enrolment QR (reusing
  `OcptRepointingQrView`), the nominative connected-peers list (reusing the presence roster and
  `OcptPresenceColor`), and the "Réconcilier amont…" action (paste/scan an upstream invite → run
  reconcile → show `pushed N, pulled M`).
- Wiring: a bloc following the sharing bloc's UI/bloc/state/event split (extend `OcptSharingBloc`
  or a sibling `OcptRelayHostBloc` — the reviewer picks when the code is in front of them), seeding
  its initial state from the manager's getters. Every string through `Tr.of(context)`, added to
  both ARB files.
- Tests: the segment is absent on a narrow/mobile surface and under read-only; the switch drives
  start/stop; the QR, address, peers and reconcile action render when online; bloc start/stop and
  reconcile success/failure.

### Phase F — Documentation fold

- Fold into `docs/architecture/sync.md`: in-app hosting, the segmented Partager screen, the
  self-seed-to-localhost model, and the in-app reconcile.
- Extend the operator runbook `docs/on-set-server.md` (the one `on-set-server.md` Phase F creates)
  with the GUI hosting path beside the CLI, and add the firewall note (decision 2) for the
  end-user guide (coordinated with `on-set-server.md` Phase G, the M2–M6 user guide).
- Delete this plan; update the `AGENTS.md` status table.

## Out of scope

Reaching a hosted relay from the internet (NAT traversal, dynamic DNS, exposing a personal
machine) — use the permanent Docker relay instead. A hosted relay that runs without the editor open
(a tray app or background service). Multi-project hosting from one panel (host is per open project).
Everything `on-set-server.md` and §6 of the parent collaboration plan already exclude.
