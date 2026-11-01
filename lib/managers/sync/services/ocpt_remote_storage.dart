// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';

/// The transport a project's changeset engine exchanges its work through, exposing the same five
/// operations `docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md` gives the relay:
/// append a changeset, read changesets since a sequence number, upload a snapshot, fetch the
/// latest snapshot, and a stream announcing new work has arrived.
///
/// This interface speaks only `ocpt_sync_protocol`'s own wire types and opaque bytes — never a
/// table name, a column name or a domain model — so an implementation never has to know what a
/// changeset's [OcptChangesetEnvelope.payload] actually contains. `OcptFolderRemoteStorage` is the
/// desktop fallback over a plain directory; `OcptRelayRemoteStorage` talks HTTP and a WebSocket to
/// a relay.
///
/// The four request/response operations never throw for a failure of the transport: they answer an
/// [OcptRemoteStorageStatus] — [OcptRemoteStorageStatus.rejected] when the relay answered with a
/// sync error, [OcptRemoteStorageStatus.unreachable] for everything else the transport hit — and
/// leave what to do about it (go offline, report an error) to the caller.
abstract interface class OcptRemoteStorage {
  /// Emits an event whenever new work — a changeset or a snapshot appended by another replica —
  /// becomes available.
  ///
  /// Nothing about an event is meaningful beyond its arrival: a listener reacts by calling
  /// [readSince] or [fetchLatestSnapshot] again, exactly as it would on a timer. The relay
  /// implementation drives this from its WebSocket route; a transport with no way to observe
  /// another replica's writes may emit nothing at all.
  Stream<void> get newWorkStream;

  /// Emits every opaque frame another replica sent through its own [sendPresence], in arrival
  /// order.
  ///
  /// Exactly as opaque to this interface as [sendPresence]'s own payload — this stream carries
  /// whatever a peer sent, unparsed, never a table name or a domain type. A transport with no way
  /// to receive a peer's frames (a folder, say) emits nothing at all, exactly as
  /// [newWorkStream] does in that case.
  Stream<String> get presenceStream;

  /// Appends [envelope] to the project's changeset log and returns the sequence number the
  /// transport assigned it.
  ///
  /// The assigned sequence number is a delivery cursor only — per ADR 0010, a merge never reads it
  /// to decide which of two column edits wins, since two different transports can assign the same
  /// project two independent sequences on the same day.
  Future<ResultWithStatus<OcptRemoteStorageStatus, OcptSequenceNumber>> append(
    OcptChangesetEnvelope envelope,
  );

  /// Returns every changeset appended after [cursor], oldest first.
  ///
  /// Returns an empty list, never an error, when [cursor] already names the last position in the
  /// log — a replica catching up after being offline calls this once and gets everything it
  /// missed in one page.
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptStoredChangeset>>> readSince(
    OcptSequenceNumber cursor,
  );

  /// Stores [bytes] under [descriptor], making it the transport's latest snapshot.
  ///
  /// [descriptor] and [bytes] are opaque to this interface beyond [descriptor]'s own fields: what
  /// [bytes] decodes to, and how [OcptSnapshotDescriptor.contentDigest] was computed, is entirely
  /// the caller's concern.
  Future<StatusWithExtraInfo<OcptRemoteStorageStatus>> uploadSnapshot(
    OcptSnapshotDescriptor descriptor,
    Uint8List bytes,
  );

  /// Returns the transport's latest snapshot, paired with its own descriptor, or a successful
  /// answer with no value when no snapshot has ever been uploaded.
  Future<ResultWithStatus<OcptRemoteStorageStatus, (OcptSnapshotDescriptor, Uint8List)>>
  fetchLatestSnapshot();

  /// Sends [opaquePayload] to this project's other replicas, over the same channel [newWorkStream]
  /// listens on.
  ///
  /// [opaquePayload] is exactly that to this interface — a string this transport moves without
  /// reading: today's only caller is presence, but nothing here names it, so the relay this method
  /// talks to never learns what the payload means. A transport with no peer to reach (a folder,
  /// say) drops the call silently — never throws — and the same holds while a networked transport
  /// is disconnected: the next call carries current state again, so nothing is lost that a caller
  /// needs to react to.
  void sendPresence(String opaquePayload);
}
