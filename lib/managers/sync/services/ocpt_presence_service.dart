// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

/// How often [OcptPresenceService] sends this replica's own heartbeat — through
/// [OcptRemoteStorage.sendPresence] — while it runs.
const ocptDefaultPresenceHeartbeatInterval = Duration(seconds: 5);

/// How long a peer's last heartbeat is allowed to age before [OcptPresenceService] drops it from
/// the roster — roughly two missed heartbeats at [ocptDefaultPresenceHeartbeatInterval], so one
/// dropped frame alone never flickers a peer out.
const ocptDefaultPresencePeerTimeout = Duration(seconds: 12);

/// The default [OcptPresenceService.clock]: the wall clock. A test hands in its own so a peer's
/// ageing past [OcptPresenceService.peerTimeout] can be driven deterministically instead of
/// waiting on real time.
DateTime _systemClock() => DateTime.now();

/// One peer this service currently knows to be present: its last heartbeat, and when it arrived.
class _SeenPeer {
  _SeenPeer({required this.frame, required this.lastSeen});

  /// The peer's own last frame.
  OcptPresenceFrame frame;

  /// When [frame] was recorded, read from [OcptPresenceService.clock] — never a peer's own claim,
  /// so a peer with a wrong system clock still ages out on this replica's own schedule.
  DateTime lastSeen;
}

/// Keeps one project's presence roster converging against its peers for as long as it runs —
/// `docs/plans/presence.md` (M5, Phase B): the client-side half of the avatar cluster a future
/// widget renders, over the very same [OcptRemoteStorage] a project's `OcptChangesetService`
/// already pushes and pulls through.
///
/// This class heartbeats this replica's own [OcptPresenceFrame] every [heartbeatInterval] via
/// [OcptRemoteStorage.sendPresence], listens to [OcptRemoteStorage.presenceStream] for every peer
/// doing the same, and keeps a [OcptPresenceRoster] of whoever has heartbeated within the last
/// [peerTimeout] — a peer that goes silent longer than that is swept out on the next tick. Nothing
/// here is persisted, on this device or anywhere past [storage]: presence is entirely ephemeral,
/// exactly as `docs/plans/presence.md`'s own "out of scope" section says.
///
/// [start]/[stop] bound this service's lifetime, mirroring `OcptSyncSession`'s own pair exactly —
/// [roster] seeds a fresh listener the way `OcptSyncSession.status` does, since [rosterStream]
/// never replays its current value either (no ACT stream does, `CLAUDE.md`'s own pitfalls list).
class OcptPresenceService {
  /// Class constructor
  ///
  /// [platform] defaults to [Platform.operatingSystem] — not usable as a literal default value,
  /// since it is a runtime call, not a constant. [clock] defaults to the wall clock
  /// ([_systemClock]); a test hands in its own so a peer's ageing past [peerTimeout] can be driven
  /// deterministically instead of waiting on real time.
  OcptPresenceService({
    required this.storage,
    required this.deviceId,
    String? platform,
    this.heartbeatInterval = ocptDefaultPresenceHeartbeatInterval,
    this.peerTimeout = ocptDefaultPresencePeerTimeout,
    this.clock = _systemClock,
  }) : platform = platform ?? Platform.operatingSystem;

  /// The transport this service heartbeats over and listens to peers through.
  final OcptRemoteStorage storage;

  /// This replica's own id, the same one every changeset it pushes is stamped with.
  final String deviceId;

  /// This replica's own neutral platform label, e.g. `'windows'`, `'android'`.
  final String platform;

  /// How often this service sends this replica's own heartbeat.
  final Duration heartbeatInterval;

  /// How long a peer's last heartbeat may age before it is dropped from the roster.
  final Duration peerTimeout;

  /// Where "now" comes from — see this class's own constructor doc comment for why it is
  /// injectable.
  final DateTime Function() clock;

  OcptWorkspaceMode? _currentMode;
  int _heartbeatCounter = 0;
  final Map<String, _SeenPeer> _peers = {};

  StreamSubscription<String>? _presenceSubscription;
  Timer? _heartbeatTimer;
  bool _isRunning = false;

  final StreamController<OcptPresenceRoster> _rosterController = StreamController<OcptPresenceRoster>.broadcast();

  /// This replica's own current frame — [_heartbeatCounter] only actually advances when
  /// [_sendHeartbeat] runs, so this always reflects the last heartbeat this replica sent (or, before
  /// [start] has ever run, the frame it would send first).
  OcptPresenceFrame get _selfFrame => OcptPresenceFrame(
    deviceId: deviceId,
    platform: platform,
    modeKey: _currentMode?.name,
    heartbeat: _heartbeatCounter,
  );

  /// The current roster — see this class's own doc comment for why a caller reads this once before
  /// ever listening to [rosterStream].
  OcptPresenceRoster get roster => _buildRoster();

  /// Emits every roster this service moves through from the moment a listener subscribes onward —
  /// never its current value at subscription time (see [roster] and this class's own doc comment).
  Stream<OcptPresenceRoster> get rosterStream => _rosterController.stream;

  /// Subscribes to [storage]'s [OcptRemoteStorage.presenceStream], sends this replica's first
  /// heartbeat, and starts the [heartbeatInterval] timer that keeps sending it and sweeps stale
  /// peers. Throws [StateError] when this service is already running — call [stop] first to
  /// restart it.
  Future<void> start() async {
    if (_isRunning) {
      throw StateError('OcptPresenceService is already running for device $deviceId');
    }
    _isRunning = true;

    _presenceSubscription = storage.presenceStream.listen(_handleInboundFrame);
    _sendHeartbeat();

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sweepStalePeers();
      _sendHeartbeat();
    });
  }

  /// Cancels the [heartbeatInterval] timer and the [OcptRemoteStorage.presenceStream] subscription,
  /// and closes [rosterStream] — nothing this service holds outlives this call. Safe to call more
  /// than once, and safe to call before [start] ever ran.
  Future<void> stop() async {
    _isRunning = false;
    await _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (!_rosterController.isClosed) {
      await _rosterController.close();
    }
  }

  /// Sets this replica's own current mode and sends a heartbeat immediately, so a mode change
  /// shows on peers at once rather than waiting for the next [heartbeatInterval] tick, then emits a
  /// fresh [roster] — this replica's own frame just changed.
  void updateMode(OcptWorkspaceMode? mode) {
    _currentMode = mode;
    _sendHeartbeat();
    _emitRoster();
  }

  /// Parses [raw] into a [OcptPresenceFrame] and records it, unless it is malformed (dropped, never
  /// thrown) or carries this replica's own [deviceId] (the relay never echoes a sender's own frame
  /// back to it, but this is defensive rather than load-bearing).
  void _handleInboundFrame(String raw) {
    final OcptPresenceFrame frame;
    try {
      frame = OcptPresenceFrame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stackTrace) {
      _logWarning('Dropping a malformed presence frame: $error\n$stackTrace');
      return;
    }
    if (frame.deviceId == deviceId) {
      return;
    }

    _peers[frame.deviceId] = _SeenPeer(frame: frame, lastSeen: clock());
    _emitRoster();
  }

  /// Drops every peer whose [_SeenPeer.lastSeen] is older than [peerTimeout], and emits a fresh
  /// [roster] only when at least one actually was.
  void _sweepStalePeers() {
    final now = clock();
    final staleDeviceIds = [
      for (final entry in _peers.entries)
        if (now.difference(entry.value.lastSeen) > peerTimeout) entry.key,
    ];
    if (staleDeviceIds.isEmpty) {
      return;
    }

    staleDeviceIds.forEach(_peers.remove);
    _emitRoster();
  }

  /// Advances [_heartbeatCounter] and sends this replica's own current frame through
  /// [OcptRemoteStorage.sendPresence].
  void _sendHeartbeat() {
    _heartbeatCounter++;
    storage.sendPresence(jsonEncode(_selfFrame.toJson()));
  }

  /// This replica first, then every peer [_peers] still holds, sorted by device id for a stable
  /// order.
  OcptPresenceRoster _buildRoster() {
    final peerFrames = _peers.values.map((seenPeer) => seenPeer.frame).toList()
      ..sort((a, b) => a.deviceId.compareTo(b.deviceId));

    return OcptPresenceRoster(participants: [_selfFrame, ...peerFrames], selfDeviceId: deviceId);
  }

  void _emitRoster() {
    if (!_rosterController.isClosed) {
      _rosterController.add(_buildRoster());
    }
  }

  /// Logs [message] through `appLogger()` when a global manager instance actually exists, and does
  /// nothing otherwise — see `OcptSyncSession._logWarning`'s own doc comment for why a unit test
  /// with no app-wide `AbsGlobalManager` behind it must not crash over this.
  void _logWarning(String message) {
    if (AbsGlobalManager.instance != null) {
      appLogger().w(message);
    }
  }
}
