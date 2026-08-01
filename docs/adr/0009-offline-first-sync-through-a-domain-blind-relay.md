<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0009 - Offline-first sync through a domain-blind relay

## Status

Proposed

## Context

The roadmap has so far assumed local-only storage, with Google Drive sync as the next step and a
dedicated server last. The use case that forces the choice is a shoot: the director reads the shot
list and adds a shot from a tablet — more practical than a laptop on an exterior location — while
the assistant directors change the shooting schedule at the same time, and every document stays
readable by everyone. Locations often have no usable connectivity.

The stated constraint was no paid dedicated server and no server application to maintain against
security holes.

Facts in the code that bear on the choice:

- A project is one SQLite file (ADR 0001). That file is the unit any file-sync client would carry,
  and such clients replace whole files without understanding SQLite's journal.
- `shots.shootingDay` is a column of the `shots` table, editable from the shot list. The shooting
  schedule mode is still an empty state, so that column *is* the schedule today: the director and
  the assistant director write the same rows.
- `scenes` is an index derived from the screenplay text, and `screenplay_snapshots` already stores
  whole screenplay revisions.
- `android/` and `ios/` are scaffolded by `flutter create`, but nothing has ever run there, and
  `file_selector`'s `getSaveLocation` has no Android or iOS implementation.

Avoiding a server does not remove work, it multiplies it: it costs three transports — a
synchronised folder for desktops, a peer-to-peer LAN engine for the set, a cloud API for tablets —
where a server costs one. The original objection also targets a multi-tenant hosted service, which
is not the only shape a server can take.

## Decision

Sync goes through a **relay server that knows nothing about the domain**: single-tenant,
self-hostable, one instance per person or per production, written in Dart (`shelf` plus a SQLite
file) and shipped as one binary behind a TLS-terminating reverse proxy.

Its whole API is five routes: append an opaque changeset and get its sequence number, read
changesets since a sequence number, upload a snapshot and let everything below it be pruned, fetch
the latest snapshot, and a WebSocket announcing that new changesets exist. Authentication is one
bearer token per project — no accounts, no passwords, no personal data.

A project comes into existence without a sixth route: an append for an unknown project identifier
creates it when the request carries the instance's **enrolment secret**, and is rejected otherwise.
The client picks the identifier and the token itself, so whoever holds that secret creates projects
from the app alone, with nothing for the operator to provision by hand.

Refusing accounts leaves the instance as the only trust boundary the design has: one instance is
one person or one production, and hosting a second person means a second instance beside the first
— same image, its own secret, its own database file — never a second tenant inside one.

The server never parses a changeset, never learns a table or column name, and holds no domain
logic. The domain model can therefore evolve without redeploying anything and without breaking an
instance running an older build.

Every device keeps a full local replica. The app stays completely usable offline and queues its
changes; merging happens **client-side and per column** on reconnect, against server-assigned
sequence numbers rather than distributed clocks.

The server is portable: on set it runs on a laptop at the video village or on a Raspberry Pi, with
tablets reaching it over a travel router. Same binary, same client code path, different address —
so a production with no internet is still fully collaborative, and no peer-to-peer merge is ever
needed. On the client the relay sits behind an `OcptRemoteStorage` abstraction, leaving a folder or
cloud backend possible later without touching the merge engine.

## Consequences

There is server code to write, ship and keep patched, and that is an obligation towards anyone who
self-hosts it, even with an attack surface of one token check and blob storage. It costs a few
euros a month on a small VPS, or nothing on a Pi. Film crews will not deploy anything, so in
practice Benoit hosts for his own productions and publishes a Docker image for others.

Hosting for someone else therefore costs a second service in the same compose file rather than a
multi-tenant rewrite, and their data stays one volume: the day they want their own machine, that
volume and that service move with them.

A server does not remove offline-first: a local replica, a pending queue and a merge are still
required, they simply resolve against an authority instead of against arbitrary peers.

Running both a set laptop and a VPS reintroduces two masters once a day. That is resolved by the
set server acting as a client of the upstream relay, reusing the client merge rather than a second
implementation.

Full replication means there is no per-document access control: whoever holds a project token
holds everything, including the budget once it exists. Keeping a document away from the crew means
a separate project file, not permissions inside this one.

The data model changes this depends on are deliberately not decided here; they are ADR 0010, and
they are required whichever transport wins.

## Alternatives considered

- **Google Drive**, the original idea: the `drive.file` scope does not cover opening a folder
  shared by someone else, the broader `drive` scope is restricted and carries a paid annual
  security assessment, and the Picker workaround plus token refreshes make it the most expensive
  transport to maintain of everything considered.
- **A synchronised folder** (Drive Desktop, Dropbox, Nextcloud, Syncthing): no API and no OAuth at
  all, but no such folder exists on Android or iOS, which is exactly where the director works on
  set. Kept as a cheap reference transport for exercising the merge without network code.
- **Check-out / check-in with a lock file**: a project is a single SQLite file, so locking it for
  the shot list also locks the shooting schedule — the parallel work being asked for.
- **Peer-to-peer LAN sync over mDNS**: no accounts and no internet, but it costs discovery,
  pairing, per-platform local-network permissions and N-way convergence with hybrid logical
  clocks. A portable relay reaches the same result on set for far less.
- **PowerSync**: mature offline-first sync with Flutter and drift integrations and no sync code to
  write, but it needs Postgres as the source of truth and gives up the domain-blind property that
  keeps the relay free of redeployment.
- **Firestore, Supabase or a multi-tenant hosted service**: still a server, with the security
  burden moved into access rules that are just as easy to get wrong, plus a recurring bill.
