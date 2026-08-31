// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One replica's own presence, at the moment it last sent a heartbeat — the opaque frame
/// `OcptPresenceService` sends through `OcptRemoteStorage.sendPresence` and reads back off
/// `OcptRemoteStorage.presenceStream`, per `docs/plans/presence.md` (M5, Phase B).
///
/// This is a pure model: no `dart:ui`/Flutter import and no `Color` — the avatar colour and the
/// display label a presence indicator renders are derived from [deviceId]/[platform] entirely by
/// Phase C's own UI code, never carried here. The relay this frame eventually rides through never
/// decodes it either (`docs/architecture/sync.md`'s own "domain-blind" rule) — [toJson] and
/// `OcptPresenceFrame.fromJson` exist purely for the two replicas on either end of that opaque
/// string.
class OcptPresenceFrame extends Equatable {
  static const _deviceIdKey = 'deviceId';
  static const _platformKey = 'platform';
  static const _modeKeyKey = 'modeKey';
  static const _heartbeatKey = 'heartbeat';

  /// The replica that sent this frame — the same id every changeset it pushes is stamped with.
  final String deviceId;

  /// A neutral platform label for that replica, e.g. `'windows'`, `'android'`, `'linux'` —
  /// `Platform.operatingSystem`'s own spelling, never a device name or anything a person typed.
  final String platform;

  /// The `OcptWorkspaceMode.name` that replica currently has open, or null before it has chosen
  /// one yet (a session that has just started, say). Opaque to the relay exactly as every other
  /// field here is.
  final String? modeKey;

  /// A monotonic counter this replica bumps on every heartbeat it sends — what lets a listener
  /// tell two frames from the same [deviceId] apart, though `OcptPresenceService` itself only
  /// reads a frame's arrival for its own `lastSeen`, never this counter's value.
  final int heartbeat;

  /// Class constructor
  const OcptPresenceFrame({
    required this.deviceId,
    required this.platform,
    required this.modeKey,
    required this.heartbeat,
  });

  /// Parses a presence frame from the JSON object [toJson] writes.
  ///
  /// Casts straight through, exactly as `OcptFieldStamp.fromJson` does — a malformed frame throws
  /// (a [TypeError] from a failed cast), which `OcptPresenceService` catches and drops rather than
  /// ever letting it reach a roster listener.
  factory OcptPresenceFrame.fromJson(Map<String, dynamic> json) => OcptPresenceFrame(
    deviceId: json[_deviceIdKey] as String,
    platform: json[_platformKey] as String,
    modeKey: json[_modeKeyKey] as String?,
    heartbeat: json[_heartbeatKey] as int,
  );

  /// Serialises this frame to the JSON object it is carried as.
  Map<String, dynamic> toJson() => {
    _deviceIdKey: deviceId,
    _platformKey: platform,
    _modeKeyKey: modeKey,
    _heartbeatKey: heartbeat,
  };

  @override
  List<Object?> get props => [deviceId, platform, modeKey, heartbeat];

  @override
  String toString() =>
      'OcptPresenceFrame(deviceId: $deviceId, platform: $platform, modeKey: $modeKey, '
      'heartbeat: $heartbeat)';
}
