// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_store.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_upstream_client.dart';

/// Reconciles one project's changeset log between a local [OcptRelayStore] (a set relay's own,
/// gathered offline over a shoot) and an upstream relay reached through [upstream] (typically the
/// production's prep relay) — the whole of `docs/plans/on-set-server.md`'s Phase B.
///
/// [reconcileProject] pushes what the local store holds that the upstream does not, then pulls
/// what the upstream holds that the local store does not — both directions deduped by
/// [OcptChangesetEnvelope.changesetId] ([OcptRelayStore.append] is idempotent on it, and so is the
/// upstream's own `append` route, per `OcptRelayServer`'s own doc comment). No domain merge
/// happens here: this class only replicates opaque changeset logs between two relays, exactly as
/// either relay replicates with any of its own replicas — the app's existing per-column merge is
/// what makes the two crews' edits converge, once each side has read the other's log.
///
/// Snapshots are never exchanged: the state a set relay's morning snapshot covers is exactly what
/// the prep relay already held when the project was handed to it, so the only new work a
/// reconciliation ever needs to move is the day's changesets, all sitting above that snapshot.
///
/// Re-running [reconcileProject] for the same project is always safe. In the common case, the
/// per-upstream cursors [OcptRelayStore.reconcileCursors] tracks mean a re-run pushes and pulls
/// nothing new. Even when a cursor is stale or absent — a fresh set relay, a store restored from
/// a backup — the `changesetId` dedup on both ends is the real safety net: a changeset already
/// known to either side is a no-op to re-send, so reconciling twice, or against a cursor reset to
/// zero, converges to the same state as reconciling once.
class OcptRelayReconciler {
  /// Creates a reconciler moving changesets between [store] (this relay's own) and [upstream].
  const OcptRelayReconciler({required this.store, required this.upstream});

  /// This relay's own storage — where a push reads from and a pull writes to.
  final OcptRelayStore store;

  /// The upstream relay this reconciler pushes to and pulls from.
  final OcptRelayUpstreamClient upstream;

  /// Reconciles [projectId]'s changeset log with [upstream]: first push, then pull, then save the
  /// cursors this run advanced. [enrolmentSecret] is forwarded to every push
  /// (`OcptRelayUpstreamClient.appendChangeset`) so the upstream can create [projectId] on its own
  /// side the first time this project is ever pushed to it; pass null once it is known to already
  /// exist there.
  ///
  /// Returns how many changesets were genuinely new on each side this run — both zero on a re-run
  /// with nothing new on either side. "Genuinely new" matters because a push and a pull in the
  /// same run see each other's own work as an echo, and neither is counted twice nor mistaken for
  /// new content:
  ///
  /// - `pushed` is exactly what was read off [store]'s own log after the push cursor and sent
  ///   upstream — never inflated by the pull step, since the pull step never writes to [upstream].
  /// - `pulled` excludes any changeset [store] already held *before this call started* — in
  ///   particular, the very changesets just pushed above, which `readChangesetsSince` on
  ///   [upstream] hands back again the moment they land in its own log, are recognised by their
  ///   `changesetId` and not counted as newly pulled, even though [OcptRelayStore.append] still
  ///   runs on them (a no-op, since they are already there).
  /// - The push cursor also absorbs whatever local sequence number the pull step assigns to a
  ///   changeset that turns out to be genuinely new: once a changeset from [upstream] lands in
  ///   [store] at some local position, that position is by definition already known to [upstream]
  ///   (it came from there), so a later run's push must not read it back off [store] and send it
  ///   upstream again. Skipping this step is harmless in principle
  ///   ([OcptRelayUpstreamClient.appendChangeset] is itself idempotent on `changesetId`) but would
  ///   otherwise report a nonzero `pushed` forever on an otherwise fully reconciled project.
  Future<({int pushed, int pulled})> reconcileProject({required String projectId, String? enrolmentSecret}) async {
    final upstreamKey = upstream.baseUri.toString();
    final cursors = store.reconcileCursors(upstream: upstreamKey, projectId: projectId);

    // Snapshot of what this store already knows, taken before either half of this run mutates
    // anything, so the pull step below can tell a genuinely new changeset apart from an echo of
    // what this run itself just pushed (see this method's own doc comment).
    final alreadyKnownIds = store
        .readSince(projectId, OcptSequenceNumber.zero)
        .map((changeset) => changeset.envelope.changesetId)
        .toSet();

    var pushCursor = cursors.push;
    final toPush = store.readSince(projectId, pushCursor);
    for (final changeset in toPush) {
      await upstream.appendChangeset(projectId, changeset.envelope, enrolmentSecret: enrolmentSecret);
      if (changeset.sequenceNumber > pushCursor) {
        pushCursor = changeset.sequenceNumber;
      }
    }

    var pullCursor = cursors.pull;
    var pulled = 0;
    final toPull = await upstream.readChangesetsSince(projectId, pullCursor);
    for (final changeset in toPull) {
      final localSequence = store.append(projectId, changeset.envelope);
      if (!alreadyKnownIds.contains(changeset.envelope.changesetId)) {
        pulled += 1;
      }
      if (localSequence > pushCursor) {
        pushCursor = localSequence;
      }
      if (changeset.sequenceNumber > pullCursor) {
        pullCursor = changeset.sequenceNumber;
      }
    }

    store.saveReconcileCursors(upstream: upstreamKey, projectId: projectId, push: pushCursor, pull: pullCursor);

    return (pushed: toPush.length, pulled: pulled);
  }
}
