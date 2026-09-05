<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Running a set relay — an operator's runbook

A self-hoster's or operator's guide to running the relay for a shoot: what to start on the day, how
the crew joins it, and how the day's work gets back to the production's own prep relay in the
evening. It assumes no code-level knowledge — [`architecture/sync.md`](architecture/sync.md) is the
engineering record this runbook only summarises for the ground.

No special build exists for this: the set relay is the same `packages/ocpt_sync_relay` server every
permanent instance runs, whichever of the two ways below starts it.

## Starting the set relay

Two ways to bring a relay up on set, chosen by what is available:

- **Headless, on a laptop or a Pi with nothing else running** — the `ocpt_sync_relay` CLI or its
  Docker image, exactly as a permanent instance runs (`packages/ocpt_sync_relay/README.md`). Pick
  this for an always-on box tucked away for the day, reachable behind a travel router.
- **From the app itself, on a laptop already open on the project** — the Partager screen's
  "Héberger sur ce poste" panel (desktop only): a Marche/Arrêt switch turns the app itself into the
  relay, in-process, with no separate server to run at all. This is the natural choice when the
  video-village laptop already has the project open, and it is also what a producer or director's
  own machine uses to be the project's durable, always-there hub between shoots — the same panel,
  left switched on and "réhéberger au démarrage" checked.

Either way, the very first device to start the relay becomes its first member: starting it pushes
that device's own local edits in and publishes a snapshot, so the relay is never empty for the next
device that joins it.

## Sharing the enrolment QR

Whichever way it was started, the relay now advertises an enrolment QR — its own LAN address plus
its instance-wide enrolment secret, encoded as `ocpt://relay?r=<address>&e=<secret>` — shown either
by the CLI/Docker operator's own tooling or, for the in-app path, directly in the hosting panel next
to a copy-address button.

Every other crew member's device, with their own copy of the project already open, scans that QR
through the **"Changer de relais"** screen (reached from the sync status indicator in the workspace's
status bar) or types the address and secret in by hand. This re-points their already-open project at
the set relay — it keeps the project's own identity and credential; only where it looks for the
relay changes. One QR re-points any project, since it carries no project id or token of its own.

## The evening reconciliation

At the end of the day the set relay's own log is pushed and pulled against the prep relay it came
from, both directions deduped so running this more than once never duplicates anything:

- **Headless operator** — the CLI's `reconcile` subcommand, run once on the set laptop:

  ```sh
  dart run bin/ocpt_sync_relay.dart reconcile --invite '<ocpt://join…>'
  ```

  `<ocpt://join…>` is the prep relay's own invite link (the same one a crew member's Rejoindre
  screen would use to join that project). It prints `pushed N, pulled M` and exits.

- **In-app path** — the hosting panel's own "Réconcilier amont…" action: paste or scan the prep
  relay's `ocpt://join` invite, and the same push-then-pull runs in place, showing the same
  `pushed N, pulled M` line once it finishes.

Both paths call the very same reconciler (`OcptRelayReconciler`), so which one is used on a given
evening depends only on whether an operator's terminal or the app itself is at hand.

## The firewall note

Hosting a relay — from the CLI, Docker, or the app — opens a listening socket on the local network,
reachable by anything else on that LAN. For an on-set network or a small production's own hub
machine, that is an acceptable, deliberate posture: the crew's own devices are what is meant to
reach it. It is stated here plainly rather than left as a surprise; it is also why reaching a hosted
relay from *outside* that LAN (across the internet, through NAT traversal or a dynamic DNS setup) is
out of scope for both hosting paths — a production that genuinely needs that reaches for the
permanent, TLS-fronted Docker relay instead.

## If the laptop is dropped in the sand

The set relay is an optimisation, never a single point of failure: every device on set holds a full
replica of the project, edits included. If the laptop or Pi running the relay is lost, dropped, or
simply left behind, any tablet that was on set can pick up the set relay's own role — start hosting
from its own app, or point the CLI at its own copy of the project's database — and reconcile the
whole day upstream on its own. Nothing about that day's work depends on any one machine surviving
until evening.
