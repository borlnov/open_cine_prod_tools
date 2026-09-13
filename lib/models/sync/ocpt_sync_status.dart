// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What `OcptSyncSession` reports of itself, at every moment it runs — the four states
/// `docs/plans/collaboration-and-sync.md` §3.5 names for the workspace status bar's indicator: in
/// sync, syncing, offline with a pending count, or an error.
///
/// This is a status report only: nothing here writes anything, and a mode reads it purely to
/// render — see `OcptSyncSession`'s own doc comment for what actually drives it from one state to
/// the next.
sealed class OcptSyncStatus extends Equatable {
  /// Class constructor
  const OcptSyncStatus();
}

/// Every local edit this replica knows about has been pushed, and every changeset the relay held
/// has been pulled and applied. The steady state, and what a session starts in before its first
/// run.
final class OcptSyncStatusInSync extends OcptSyncStatus {
  /// Class constructor
  const OcptSyncStatusInSync();

  /// Object properties
  @override
  List<Object?> get props => const [];
}

/// A push-then-pull is running right now, whether it was `OcptSyncSession.start`'s own initial
/// run, a `newWorkStream` ping, the periodic push timer, or a `syncNow` call from the status
/// indicator.
final class OcptSyncStatusSyncing extends OcptSyncStatus {
  /// Class constructor
  const OcptSyncStatusSyncing();

  /// Object properties
  @override
  List<Object?> get props => const [];
}

/// The last run could not reach the relay at all — a refused connection, a timeout, a dropped
/// socket — read as a reachability problem rather than the relay itself rejecting the request
/// (that is [OcptSyncStatusError] instead).
///
/// [pendingEditCount] is how many of this replica's own edits are still waiting to be pushed, when
/// that count was cheap enough to compute alongside the failure; null when it wasn't available,
/// which an indicator reads as "at least one, count unknown" rather than "zero".
final class OcptSyncStatusOffline extends OcptSyncStatus {
  /// Class constructor
  const OcptSyncStatusOffline({this.pendingEditCount});

  /// How many of this replica's own edits are still waiting to be pushed, or null when that count
  /// was not available.
  final int? pendingEditCount;

  /// Object properties
  @override
  List<Object?> get props => [pendingEditCount];
}

/// The relay itself rejected the last run's request — a bad or expired token, a stale cursor,
/// anything `ocpt_sync_relay` reports as an `OcptSyncError` — rather than simply being unreachable
/// (that is [OcptSyncStatusOffline] instead).
final class OcptSyncStatusError extends OcptSyncStatus {
  /// Class constructor
  const OcptSyncStatusError(this.message);

  /// A human-readable detail of what the relay rejected, meant for a log or the status
  /// indicator's panel — never parsed.
  final String message;

  /// Object properties
  @override
  List<Object?> get props => [message];
}
