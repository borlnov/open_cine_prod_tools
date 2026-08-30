// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';

/// The transport a project's changeset engine exchanges its work through, exposing the same five
/// operations `docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md` gives the relay:
/// append a changeset, read changesets since a sequence number, upload a snapshot, fetch the
/// latest snapshot, and a stream announcing new work has arrived.
///
/// This interface speaks only `ocpt_sync_protocol`'s own wire types and opaque bytes — never a
/// table name, a column name or a domain model — so an implementation never has to know what a
/// changeset's [OcptChangesetEnvelope.payload] actually contains
/// (`docs/plans/collaboration-and-sync.md`, M3). `OcptFolderRemoteStorage` is the only
/// implementation this milestone ships, and the desktop fallback it stays afterwards; a relay
/// implementation talking HTTP and a WebSocket follows once the relay itself exists.
abstract interface class OcptRemoteStorage {
  /// Appends [envelope] to the project's changeset log and returns the sequence number the
  /// transport assigned it.
  ///
  /// The assigned sequence number is a delivery cursor only — per ADR 0010, a merge never reads it
  /// to decide which of two column edits wins, since two different transports can assign the same
  /// project two independent sequences on the same day.
  Future<OcptSequenceNumber> append(OcptChangesetEnvelope envelope);

  /// Returns every changeset appended after [cursor], oldest first.
  ///
  /// Returns an empty list, never an error, when [cursor] already names the last position in the
  /// log — a replica catching up after being offline calls this once and gets everything it
  /// missed in one page.
  Future<List<OcptStoredChangeset>> readSince(OcptSequenceNumber cursor);

  /// Stores [bytes] under [descriptor], making it the transport's latest snapshot.
  ///
  /// [descriptor] and [bytes] are opaque to this interface beyond [descriptor]'s own fields: what
  /// [bytes] decodes to, and how [OcptSnapshotDescriptor.contentDigest] was computed, is entirely
  /// the caller's concern.
  Future<void> uploadSnapshot(OcptSnapshotDescriptor descriptor, Uint8List bytes);

  /// Returns the transport's latest snapshot, paired with its own descriptor, or null when no
  /// snapshot has ever been uploaded.
  Future<(OcptSnapshotDescriptor, Uint8List)?> fetchLatestSnapshot();

  /// Emits an event whenever new work — a changeset or a snapshot appended by another replica —
  /// becomes available.
  ///
  /// Nothing about an event is meaningful beyond its arrival: a listener reacts by calling
  /// [readSince] or [fetchLatestSnapshot] again, exactly as it would on a timer. The relay
  /// implementation drives this from its WebSocket route; a transport with no way to observe
  /// another replica's writes may emit nothing at all.
  Stream<void> get newWorkStream;
}
