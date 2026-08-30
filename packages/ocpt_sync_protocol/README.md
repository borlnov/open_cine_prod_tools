<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# ocpt_sync_protocol

The domain-blind sync wire format shared by Open Cine Prod Tools and its self-hostable relay
(`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`).

`ocpt_sync_protocol` has no Flutter dependency and no I/O of its own: it only defines the value
types a relay's five routes exchange, and their JSON codecs. It deliberately contains **no table
name and no domain type** — a relay built against this package never parses a changeset and never
learns what it is shipping, which is what lets the domain model evolve without ever redeploying
the relay.

## What it defines

- `OcptChangesetEnvelope` — one unit of work appended to a project's changeset log. Its `payload`
  is opaque bytes (base64 on the wire): the app's own serialisation of a set of per-column field
  stamps, never interpreted by this package.
- `OcptSequenceNumber` — a relay's own delivery cursor: monotonic, totally ordered, and never a
  merge primitive (`docs/adr/0010-sync-ready-data-model-prerequisites.md` is explicit that a
  relay's counter cannot decide which of two column edits wins).
- `OcptStoredChangeset` — an envelope paired with the sequence number a relay assigned it, what a
  "read since" call hands back.
- `OcptSnapshotDescriptor` — describes a snapshot without carrying its bytes, defined now so the
  relay's snapshot route adds no protocol churn when it ships.
- `OcptSyncError` / `OcptSyncErrorCode` — what a relay's routes report instead of a normal
  response.
- `OcptLamportStamp` — the pure `(version, deviceId)` ordering ADR 0010 defines for a per-column
  version stamp: a higher Lamport counter wins, and a tie is broken by comparing device ids
  lexicographically.

## Format-version discipline

`OcptChangesetEnvelope` and `OcptSnapshotDescriptor` each carry their own format field
(`protocolFormat`, `snapshotFormat`) and their own `currentProtocolFormat` /
`currentSnapshotFormat` constant, mirroring how `OcptProjectVersionCodec` treats the project
version payload: a value declaring a **newer** format than this build knows throws
`OcptSyncUnsupportedFormatError` rather than being half-read, while an **older** one is accepted.

## License

Licensed under the Apache-2.0 license, like the rest of Open Cine Prod Tools. See the
repository's [LICENSES](../../LICENSES/) directory for the full license text.
