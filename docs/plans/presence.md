<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# M5 — Live push and presence (working sub-plan)

The implementation strategy for M5 of the collaboration work, for the Sonnet 5 agents that build
it, orchestrated and reviewed by the main session. **Read the repository `CLAUDE.md` and
[`../architecture/sync.md`](../architecture/sync.md) first** — this sub-plan assumes both and does
not repeat them. It is deleted once M5 ships and its outcome is folded into `sync.md`, exactly as
`relay.md` was for M4.

The milestone is defined in [`collaboration-and-sync.md`](collaboration-and-sync.md): the WebSocket
driving the client instead of polling, and a presence indicator showing who else has the project
open and which mode they are in.

## What already exists (M3/M4)

Live push is **most of the way there already**. The relay's `events` WebSocket pings `new-work` on
every append and snapshot (`OcptRelayServer._notifyNewWork`), and `OcptSyncSession` already reacts
to each ping with `pullAndApply`, with a periodic `syncOnce` timer only as a safety net. So M5 does
**not** rebuild live push — it adds presence over the same socket, and turns the poll down now that
push is the real driver.

The `events` socket is one-directional today: the relay only ever *sends* (`new-work`), and
**ignores everything a client sends** (`_subscribe`'s `webSocket.stream.listen((_) {})`). Presence
is what makes it bidirectional.

## Design decisions (validated with Benoit)

- **Identity is automatic, no accounts** (out of scope, ADR 0009 §6). Each replica is a stable
  colour derived from its `deviceId` plus a neutral label — the platform and a short id fragment
  (`Windows · a3f`). Nothing is typed, nothing personal is stored.
- **The indicator is an avatar cluster** in the top workspace toolbar, to the right, before the
  chrome block (export / docks / save / ⋮) — separate from the sync indicator, which stays in the
  status bar. Up to three avatars side by side, then a `+N` disc. Self carries a violet ring and a
  `Vous` badge; self sorts first.
- **The detail is a `MenuAnchor` popover**, the *same* mechanism the sync indicator already uses
  (`OcptSyncStatusIndicator`) — not a new right-dock panel, which would be more machinery, not
  less, since the right dock is mode-owned and presence is workspace chrome. Each peer's current
  mode reads on hover of its avatar and in the popover.
- **The relay stays domain-blind.** It rebroadcasts presence frames verbatim and never parses one,
  exactly as it moves changesets. Identity and mode ride inside the opaque frame.

## Phase A — Bidirectional opaque transport (relay + seam, no app domain, no UI)

The relay learns to fan out what a client sends; the transport seam grows a send path and a peer
stream. Both stay opaque — no presence *type* lives here, and none reaches the relay package.

- **`OcptRelayServer`** (`packages/ocpt_sync_relay`): in `_subscribe`, an inbound frame from a
  socket is **rebroadcast verbatim to that project's other subscribers** (never echoed to the
  sender). Keep it distinct from `_notifyNewWork` (relay-generated, to *all* subscribers). Update
  the class and route doc comments, which currently state the socket carries no meaningful inbound
  traffic. The relay never inspects a rebroadcast frame — the review gate (no table name, no domain
  type in this package) still holds.
- **`OcptRemoteStorage`** seam: add `void sendPresence(String opaquePayload)` and
  `Stream<String> get presenceStream`, both speaking opaque strings only.
  - `OcptRelayRemoteStorage`: `sendPresence` writes to the socket sink; the socket read loop routes
    each inbound frame — the literal `new-work` ping to `newWorkStream`, any other frame (a peer's
    opaque presence payload) to `presenceStream`. Reconnect/backoff already there is reused;
    `presenceStream` emits nothing while disconnected.
  - `OcptFolderRemoteStorage`: `sendPresence` is a no-op and `presenceStream` is empty — there are
    no peers over a folder.
- **Tests**: relay fan-out (two subscribers; a frame one sends reaches the other verbatim, not the
  sender; `new-work` still reaches all); transport routing (`new-work` → `newWorkStream`, a JSON
  frame → `presenceStream`).

One commit: `feat(sync): relay peer frames over the events socket`.

## Phase B — Client presence service (engine, no UI)

- **`OcptPresenceFrame`** (`lib/models/sync/ocpt_presence_frame.dart`): `deviceId`, `platform`,
  `modeKey` (the `OcptWorkspaceMode` name — opaque to the relay), and a monotonic `heartbeat`.
  `toJson`/`fromJson`. Pure model, no Flutter `Color` — colour and label derivation is Phase C's
  UI concern, from the `deviceId`/`platform` this carries.
- **`OcptPresenceRoster`** (`lib/models/sync/ocpt_presence_roster.dart`): the participants, self
  first, each with its frame and whether it is this replica.
- **`OcptPresenceService`** (`lib/managers/sync/services/`): given the transport, the `deviceId`
  and a current-mode getter, it heartbeats this replica's frame every ~5 s via
  `transport.sendPresence`, listens to `transport.presenceStream`, parses frames into a roster keyed
  by `deviceId` with a `lastSeen`, and **drops a peer after a TTL of ~2 intervals** on a periodic
  sweep. Exposes the roster as a stream plus a seed getter (seed the widget the way
  `OcptSyncStatusIndicator` seeds from `syncStatus`, per the ACT-streams pitfall). `updateMode`
  sends a frame immediately so a mode change shows at once; `start`/`stop` bound its lifetime.
- **`OcptSyncManager`**: own the presence service beside the sync session — `startSyncSession`
  starts it, `stopSyncSession` stops it. Expose `presenceRoster` + `presenceRosterStream` and
  `updatePresenceMode(OcptWorkspaceMode)`. Turn the session poll **down to ~60 s** now that push
  drives sync.
- **Tests**: a frame in on `presenceStream` adds a peer; a silent peer ages out; `updateMode`
  re-emits; the roster puts self first; start/stop are clean.

Commits, split logically: the models; the service; the manager wiring plus the poll turndown.

## Phase C — Presence indicator (UI — mockup validated)

- **`OcptPresenceIndicator`** (`lib/ui/pages/workspace/widgets/`): seeds from
  `OcptSyncManager.presenceRoster`, rebuilds on `presenceRosterStream`, renders the avatar cluster
  and the `MenuAnchor` popover. Absent when the roster is empty or the project is unpaired (the same
  "nothing to show" the sync indicator already renders when no manager is registered, so a mode's
  own widget tests never trip on it). Colour is derived deterministically from `deviceId`
  (`lib/ui/utils/`), the label is `platform · <id fragment>`, and a `modeKey` maps to its mode's own
  `Tr` label. No write actions, so nothing to withhold under a read-only preview — it simply shows.
- **`OcptWorkspaceToolbar`**: a new `presenceIndicator` slot, built by the shell and handed in like
  `episodeControl`, placed after the mode's `actions` and before the chrome block.
- **Wiring**: the workspace calls `updatePresenceMode` when the active `OcptWorkspaceMode` changes.
- **l10n**: `Vous`, the popover header and count, the avatar tooltip — both ARB files.
- **Tests**: the widget's cluster/`+N`/self-first/empty-roster cases, driven by a fake manager.

Commits, split logically: the indicator widget; its wiring into the toolbar and the mode hook.

## Out of scope for M5

Cursors or per-keystroke co-editing (§6 stands), a persistent presence dock, and anything the relay
would have to parse. Presence is ephemeral: nothing about it is persisted, on the device or the
relay.
