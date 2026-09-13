// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';

/// Every replica `OcptPresenceService` currently knows to have the project open — this replica
/// itself, first, then every peer whose last heartbeat has not yet aged past the service's own
/// TTL — what a presence indicator (Phase C) renders as its avatar cluster.
///
/// This is a report only, exactly as `OcptSyncStatus` is for the sync session: nothing here
/// writes anything, and `OcptPresenceService` is what actually decides when a peer joins or ages
/// out of [participants].
class OcptPresenceRoster extends Equatable {
  /// This replica, first, then every peer this service still considers present.
  final List<OcptPresenceFrame> participants;

  /// This replica's own device id — [isSelf] reads against it, and a presence indicator uses it to
  /// pick [participants]'s own frame out for its distinct ring/badge.
  final String selfDeviceId;

  /// Class constructor
  const OcptPresenceRoster({required this.participants, required this.selfDeviceId});

  /// Whether [frame] is this replica's own, rather than a peer's.
  bool isSelf(OcptPresenceFrame frame) => frame.deviceId == selfDeviceId;

  @override
  List<Object?> get props => [participants, selfDeviceId];

  @override
  String toString() => 'OcptPresenceRoster(participants: $participants, selfDeviceId: $selfDeviceId)';
}
