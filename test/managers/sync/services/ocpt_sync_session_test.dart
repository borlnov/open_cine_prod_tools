// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';

/// A minimal [OcptRemoteStorage] a test can ping through [pingNewWork] to simulate another
/// replica's own push. `append`/`readSince`/the snapshot ops are never exercised by
/// [OcptSyncSession] itself (only [_FakeChangesetService] would call them, and it doesn't), so they
/// are stubbed to inert values.
class _FakeRemoteStorage implements OcptRemoteStorage {
  final StreamController<void> _newWorkController = StreamController<void>.broadcast();

  @override
  Future<OcptSequenceNumber> append(OcptChangesetEnvelope envelope) async => OcptSequenceNumber.zero;

  @override
  Future<List<OcptStoredChangeset>> readSince(OcptSequenceNumber cursor) async => const [];

  @override
  Future<void> uploadSnapshot(OcptSnapshotDescriptor descriptor, Uint8List bytes) async {}

  @override
  Future<(OcptSnapshotDescriptor, Uint8List)?> fetchLatestSnapshot() async => null;

  @override
  Stream<void> get newWorkStream => _newWorkController.stream;

  /// Simulates the relay announcing another replica's own push.
  void pingNewWork() => _newWorkController.add(null);

  @override
  void sendPresence(String opaquePayload) {}

  @override
  Stream<String> get presenceStream => const Stream.empty();

  Future<void> dispose() => _newWorkController.close();
}

/// An [OcptChangesetService] whose `syncOnce`/`pullAndApply`/`countUnpushedEdits` never touch a
/// real database or transport: each call counts itself and pops its own queued outcome (a list of
/// conflicts to return, or an object to throw), defaulting to "succeeded with no conflicts" once
/// its queue runs dry. This is what lets this file test [OcptSyncSession]'s own scheduling and
/// status logic without a real merge to drive.
class _FakeChangesetService extends OcptChangesetService {
  _FakeChangesetService();

  int syncOnceCalls = 0;
  int pullAndApplyCalls = 0;
  int countUnpushedEditsCalls = 0;
  int unpushedEditCount = 0;

  final List<Object> syncOnceOutcomes = [];
  final List<Object> pullAndApplyOutcomes = [];

  @override
  Future<List<OcptScreenplayMergeConflict>> syncOnce({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
    required String deviceId,
  }) async {
    syncOnceCalls++;

    return _resolve(syncOnceOutcomes);
  }

  @override
  Future<List<OcptScreenplayMergeConflict>> pullAndApply({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
  }) async {
    pullAndApplyCalls++;

    return _resolve(pullAndApplyOutcomes);
  }

  @override
  Future<int> countUnpushedEdits({
    required OcptProjectDatabase database,
    required String relayId,
    required String deviceId,
  }) async {
    countUnpushedEditsCalls++;

    return unpushedEditCount;
  }

  Future<List<OcptScreenplayMergeConflict>> _resolve(List<Object> outcomes) async {
    if (outcomes.isEmpty) {
      return const [];
    }

    final outcome = outcomes.removeAt(0);
    if (outcome is List<OcptScreenplayMergeConflict>) {
      return outcome;
    }
    // The queued outcome is deliberately not always an Error/Exception: OcptSyncError itself is a
    // plain value class thrown on purpose (see its own doc comment and
    // OcptRelayRemoteStorage._throwIfFailed), and a test wants to exercise that exact shape.
    // ignore: only_throw_errors
    throw outcome;
  }
}

/// Waits for [condition] to become true, polling every 5ms, failing the test if [timeout] elapses
/// first — every timer/stream-driven assertion below uses this instead of a fixed delay, so a
/// regression fails fast rather than flaking or hanging.
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
  const projectId = 'project-1';
  const deviceId = 'device-1';
  const relayId = 'relay-1';

  late OcptProjectDatabase database;
  late _FakeRemoteStorage storage;
  late _FakeChangesetService changesetService;
  late OcptSyncSession session;

  setUp(() {
    database = OcptProjectDatabase.memory();
    storage = _FakeRemoteStorage();
    changesetService = _FakeChangesetService();
    session = OcptSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
      changesetService: changesetService,
      // Long enough that no test below sees an unwanted extra tick from it.
      pushInterval: const Duration(hours: 1),
    );
  });

  tearDown(() async {
    await session.stop();
    await storage.dispose();
    await database.close();
  });

  test('start runs an initial syncOnce and settles before returning', () async {
    await session.start();

    expect(changesetService.syncOnceCalls, 1);
    expect(changesetService.pullAndApplyCalls, 0);
    expect(session.status, const OcptSyncStatusInSync());
  });

  test('a newWorkStream ping triggers a pullAndApply, not a full syncOnce', () async {
    await session.start();
    changesetService.syncOnceCalls = 0;

    storage.pingNewWork();

    await _waitUntil(() => changesetService.pullAndApplyCalls == 1);
    expect(changesetService.syncOnceCalls, 0);
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('the periodic timer runs a syncOnce on its own, with no ping and no manual call', () async {
    session = OcptSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
      changesetService: changesetService,
      pushInterval: const Duration(milliseconds: 20),
    );

    await session.start();
    expect(changesetService.syncOnceCalls, 1);

    await _waitUntil(() => changesetService.syncOnceCalls >= 2);
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('syncNow runs a syncOnce on demand', () async {
    await session.start();
    expect(changesetService.syncOnceCalls, 1);

    await session.syncNow();

    expect(changesetService.syncOnceCalls, 2);
  });

  test('status goes inSync -> syncing -> inSync across a successful run', () async {
    final events = <OcptSyncStatus>[];
    final subscription = session.statusStream.listen(events.add);

    expect(session.status, const OcptSyncStatusInSync(), reason: 'a session starts in sync');

    await session.start();
    // The broadcast controller delivers events asynchronously, so wait for both to land rather
    // than asserting the instant start() returns.
    await _waitUntil(() => events.length >= 2);

    expect(events, [const OcptSyncStatusSyncing(), const OcptSyncStatusInSync()]);
    expect(session.status, const OcptSyncStatusInSync());

    await subscription.cancel();
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('an unreachable transport moves the status to offline, with a pending count', () async {
    changesetService.unpushedEditCount = 3;
    changesetService.syncOnceOutcomes.add(Exception('connection refused'));

    await session.start();

    expect(session.status, const OcptSyncStatusOffline(pendingEditCount: 3));
    expect(changesetService.countUnpushedEditsCalls, 1);
  });

  test('the relay rejecting a request moves the status to error, with its message', () async {
    changesetService.syncOnceOutcomes.add(
      const OcptSyncError(code: OcptSyncErrorCode.badToken, message: 'token mismatch'),
    );

    await session.start();

    expect(session.status, const OcptSyncStatusError('token mismatch'));
  });

  test('a later successful sync recovers from offline back to inSync', () async {
    changesetService.syncOnceOutcomes.add(Exception('connection refused'));
    await session.start();
    expect(session.status, isA<OcptSyncStatusOffline>());

    await session.syncNow();

    expect(session.status, const OcptSyncStatusInSync());
  });

  test('screenplay merge conflicts raised by a run are collected, in order', () async {
    const conflict = OcptScreenplayMergeConflict(
      screenplayId: 'screenplay-1',
      baseText: 'base',
      localText: 'local',
      incomingText: 'incoming',
    );
    changesetService.syncOnceOutcomes.add([conflict]);

    await session.start();

    expect(session.conflicts, [conflict]);
  });

  test('stopSyncSession cancels the timer and the subscription, with no leak afterwards', () async {
    session = OcptSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
      changesetService: changesetService,
      pushInterval: const Duration(milliseconds: 20),
    );
    await session.start();
    final callsAtStop = changesetService.syncOnceCalls;

    await session.stop();
    expect(session.isRunning, isFalse);

    // A ping and enough real time for several timer ticks must do nothing once stopped.
    storage.pingNewWork();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(changesetService.syncOnceCalls, callsAtStop);
    expect(changesetService.pullAndApplyCalls, 0);
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('starting a session twice without stopping throws', () async {
    await session.start();

    await expectLater(session.start, throwsStateError);
  });
}
