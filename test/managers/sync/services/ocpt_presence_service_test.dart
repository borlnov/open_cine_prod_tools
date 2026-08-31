// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_presence_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

/// A minimal [OcptRemoteStorage] a test can push a peer's own opaque frame through via
/// [emitPeerFrame] and inspect every payload [OcptPresenceService] sent via [sentPayloads].
/// `append`/`readSince`/the snapshot ops and [newWorkStream] are never exercised by
/// [OcptPresenceService] itself, so they are stubbed to inert values.
class _FakeRemoteStorage implements OcptRemoteStorage {
  final StreamController<String> _presenceController = StreamController<String>.broadcast();

  /// Every payload [sendPresence] was called with, in order.
  final List<String> sentPayloads = [];

  @override
  Future<OcptSequenceNumber> append(OcptChangesetEnvelope envelope) async => OcptSequenceNumber.zero;

  @override
  Future<List<OcptStoredChangeset>> readSince(OcptSequenceNumber cursor) async => const [];

  @override
  Future<void> uploadSnapshot(OcptSnapshotDescriptor descriptor, Uint8List bytes) async {}

  @override
  Future<(OcptSnapshotDescriptor, Uint8List)?> fetchLatestSnapshot() async => null;

  @override
  Stream<void> get newWorkStream => const Stream.empty();

  @override
  void sendPresence(String opaquePayload) => sentPayloads.add(opaquePayload);

  @override
  Stream<String> get presenceStream => _presenceController.stream;

  /// Simulates a peer's own frame arriving over the wire.
  void emitPeerFrame(OcptPresenceFrame frame) => _presenceController.add(jsonEncode(frame.toJson()));

  /// Simulates a malformed frame arriving over the wire — never a valid [OcptPresenceFrame.toJson].
  void emitRawFrame(String raw) => _presenceController.add(raw);

  Future<void> dispose() => _presenceController.close();
}

/// Waits for [condition] to become true, polling every 5ms, failing the test if [timeout] elapses
/// first — matches `ocpt_sync_session_test.dart`'s own helper, for the same reason: every
/// timer/stream-driven assertion below uses this instead of a fixed delay.
Future<void> _waitUntil(bool Function() condition, {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  const deviceId = 'device-self';
  const peerDeviceId = 'device-peer';

  late _FakeRemoteStorage storage;
  late OcptPresenceService service;

  setUp(() {
    storage = _FakeRemoteStorage();
    service = OcptPresenceService(
      storage: storage,
      deviceId: deviceId,
      platform: 'windows',
      // Long enough that no test below sees an unwanted extra tick from it, unless it builds its
      // own service with a shorter one.
      heartbeatInterval: const Duration(hours: 1),
    );
  });

  tearDown(() async {
    await service.stop();
    await storage.dispose();
  });

  test('the roster carries only self before anything else is known', () async {
    await service.start();

    expect(service.roster.participants, hasLength(1));
    expect(service.roster.participants.single.deviceId, deviceId);
    expect(service.roster.selfDeviceId, deviceId);
  });

  test("start sends this replica's own heartbeat immediately", () async {
    await service.start();

    expect(storage.sentPayloads, hasLength(1));
    final sent = OcptPresenceFrame.fromJson(jsonDecode(storage.sentPayloads.single) as Map<String, dynamic>);
    expect(sent.deviceId, deviceId);
    expect(sent.platform, 'windows');
    expect(sent.modeKey, isNull);
  });

  test('a peer frame in adds it to the roster, self first', () async {
    await service.start();

    const peerFrame = OcptPresenceFrame(
      deviceId: peerDeviceId,
      platform: 'android',
      modeKey: 'breakdown',
      heartbeat: 1,
    );
    storage.emitPeerFrame(peerFrame);

    await _waitUntil(() => service.roster.participants.length == 2);

    final roster = service.roster;
    expect(roster.participants.first.deviceId, deviceId);
    expect(roster.participants.last, peerFrame);
    expect(roster.isSelf(roster.participants.first), isTrue);
    expect(roster.isSelf(peerFrame), isFalse);
  });

  test('a second frame from the same peer refreshes it rather than duplicating it', () async {
    await service.start();

    storage.emitPeerFrame(
      const OcptPresenceFrame(deviceId: peerDeviceId, platform: 'android', modeKey: 'breakdown', heartbeat: 1),
    );
    await _waitUntil(() => service.roster.participants.length == 2);

    storage.emitPeerFrame(
      const OcptPresenceFrame(deviceId: peerDeviceId, platform: 'android', modeKey: 'schedule', heartbeat: 2),
    );
    await _waitUntil(
      () => service.roster.participants.any((frame) => frame.deviceId == peerDeviceId && frame.modeKey == 'schedule'),
    );

    expect(service.roster.participants, hasLength(2));
  });

  test('a malformed frame is dropped rather than thrown or crashing the listener', () async {
    await service.start();

    storage.emitRawFrame('not valid json at all {{{');
    storage.emitRawFrame(jsonEncode({'deviceId': peerDeviceId}));

    storage.emitPeerFrame(
      const OcptPresenceFrame(deviceId: peerDeviceId, platform: 'android', modeKey: null, heartbeat: 1),
    );
    await _waitUntil(() => service.roster.participants.length == 2);

    expect(service.roster.participants, hasLength(2));
  });

  test("a frame carrying this replica's own device id is ignored", () async {
    await service.start();

    storage.emitPeerFrame(
      const OcptPresenceFrame(deviceId: deviceId, platform: 'windows', modeKey: 'budget', heartbeat: 99),
    );
    // Give the stream a moment to be processed; nothing should change.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.roster.participants, hasLength(1));
  });

  test('updateMode sends a heartbeat immediately and emits a fresh roster with the new mode', () async {
    await service.start();

    final rosters = <String?>[];
    final subscription = service.rosterStream.listen((roster) => rosters.add(roster.participants.first.modeKey));

    service.updateMode(OcptWorkspaceMode.breakdown);
    await _waitUntil(() => rosters.isNotEmpty);

    expect(rosters.last, OcptWorkspaceMode.breakdown.name);
    expect(service.roster.participants.first.modeKey, OcptWorkspaceMode.breakdown.name);
    // The initial start() heartbeat plus this one.
    expect(storage.sentPayloads, hasLength(2));
    final lastSent = OcptPresenceFrame.fromJson(jsonDecode(storage.sentPayloads.last) as Map<String, dynamic>);
    expect(lastSent.modeKey, OcptWorkspaceMode.breakdown.name);

    await subscription.cancel();
  });

  test('a peer goes stale and is swept after peerTimeout, driven by an injected clock', () async {
    var currentTime = DateTime(2026);
    service = OcptPresenceService(
      storage: storage,
      deviceId: deviceId,
      // Short enough that a sweep tick happens quickly in real time...
      heartbeatInterval: const Duration(milliseconds: 20),
      // ...while the ageing decision itself is driven entirely by the injected clock, never real
      // wall-clock time.
      peerTimeout: const Duration(seconds: 10),
      clock: () => currentTime,
    );

    await service.start();

    storage.emitPeerFrame(
      const OcptPresenceFrame(deviceId: peerDeviceId, platform: 'android', modeKey: 'breakdown', heartbeat: 1),
    );
    await _waitUntil(() => service.roster.participants.length == 2);

    // Not stale yet: still well within peerTimeout.
    currentTime = currentTime.add(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(service.roster.participants, hasLength(2));

    // Now push the clock past peerTimeout since the peer's last heartbeat; the next sweep tick
    // (every 20ms of real time) must drop it.
    currentTime = currentTime.add(const Duration(seconds: 10));
    await _waitUntil(() => service.roster.participants.length == 1);

    expect(service.roster.participants.single.deviceId, deviceId);
  });

  test('starting a service twice without stopping throws', () async {
    await service.start();

    await expectLater(service.start, throwsStateError);
  });

  test('stop is safe to call twice, and safe to call before start ever ran', () async {
    await service.stop();
    await service.stop();

    await service.start();
    await service.stop();
    await service.stop();
  });

  test('stop closes rosterStream so a late listener sees it end', () async {
    await service.start();
    await service.stop();

    await expectLater(service.rosterStream, emitsDone);
  });
}
