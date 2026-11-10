// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_foundation/act_foundation.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_merge_failure.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_transport_failure.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_session_status.dart';

/// A minimal [OcptRemoteStorage] a test can ping through [pingNewWork] to simulate another
/// replica's own push. `append`/`readSince`/the snapshot ops are never exercised by
/// [OcptSyncSession] itself (only [_FakeChangesetService] would call them, and it doesn't), so they
/// are stubbed to inert values.
class _FakeRemoteStorage implements OcptRemoteStorage {
  /// The controller behind [newWorkStream].
  final StreamController<void> _newWorkController = StreamController<void>.broadcast();

  /// Emit the pings the test adds to the controller.
  @override
  Stream<void> get newWorkStream => _newWorkController.stream;

  /// Emit nothing.
  @override
  Stream<String> get presenceStream => const Stream.empty();

  /// Accept the envelope, answering with sequence zero.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, OcptSequenceNumber>> append(
    OcptChangesetEnvelope envelope,
  ) async =>
      const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: OcptSequenceNumber.zero);

  /// Answer with an empty log.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptStoredChangeset>>> readSince(
    OcptSequenceNumber cursor,
  ) async => const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);

  /// Accept the snapshot without keeping it.
  @override
  Future<StatusWithExtraInfo<OcptRemoteStorageStatus>> uploadSnapshot(
    OcptSnapshotDescriptor descriptor,
    Uint8List bytes,
  ) async => const StatusWithExtraInfo(status: OcptRemoteStorageStatus.ok);

  /// Answer that no snapshot was ever uploaded.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, (OcptSnapshotDescriptor, Uint8List)>>
  fetchLatestSnapshot() async => const ResultWithStatus(status: OcptRemoteStorageStatus.ok);

  /// Simulates the relay announcing another replica's own push.
  void pingNewWork() => _newWorkController.add(null);

  /// Drop the payload.
  @override
  void sendPresence(String opaquePayload) {}

  /// Close the controller behind [newWorkStream].
  Future<void> dispose() => _newWorkController.close();
}

/// An [OcptChangesetService] whose `syncOnce`/`pullAndApply`/`countUnpushedEdits` never touch a
/// real database or transport: each call counts itself and pops its own queued outcome (a list of
/// conflicts to return, an [OcptSyncError] the relay refused with, an exception the transport hit,
/// or a [_DatabaseFailure] to throw), defaulting to "succeeded with no conflicts" once
/// its queue runs dry. This is what lets this file test [OcptSyncSession]'s own scheduling and
/// status logic without a real merge to drive.
class _FakeChangesetService extends OcptChangesetService {
  /// How many times a sync was run.
  int syncOnceCalls = 0;

  /// How many times a pull was run.
  int pullAndApplyCalls = 0;

  /// How many times the unpushed edits were counted.
  int countUnpushedEditsCalls = 0;

  /// The number of unpushed edits to answer with.
  int unpushedEditCount = 0;

  /// Whether [countUnpushedEdits] throws instead of answering.
  bool isCountFailing = false;

  /// The outcomes the next syncs answer with, one per call. A status answers that status alone.
  final List<Object> syncOnceOutcomes = [];

  /// The outcomes the next pulls answer with, one per call.
  final List<Object> pullAndApplyOutcomes = [];

  /// Class constructor
  _FakeChangesetService()
    : super(
        logger: const SilentLogger(),
        mergeService: const OcptMergeService(logger: SilentLogger()),
      );

  /// Count the sync and answer with the next outcome.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>> syncOnce({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
    required String deviceId,
  }) async {
    syncOnceCalls++;

    return _resolve(syncOnceOutcomes);
  }

  /// Count the pull and answer with the next outcome.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>>
  pullAndApply({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
  }) async {
    pullAndApplyCalls++;

    return _resolve(pullAndApplyOutcomes);
  }

  /// Count the call, then answer with the canned count or fail when told to.
  @override
  Future<int> countUnpushedEdits({
    required OcptProjectDatabase database,
    required String relayId,
    required String deviceId,
  }) async {
    countUnpushedEditsCalls++;
    if (isCountFailing) {
      throw StateError('database is closed');
    }

    return unpushedEditCount;
  }

  /// Answer with the next of [outcomes], throwing it when it is an error and repeating a success
  /// when none is left.
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>> _resolve(
    List<Object> outcomes,
  ) async {
    if (outcomes.isEmpty) {
      return const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);
    }

    final outcome = outcomes.removeAt(0);
    if (outcome is List<OcptScreenplayMergeConflict>) {
      return ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: outcome);
    }
    if (outcome is OcptSyncError) {
      return ResultWithStatus(status: OcptRemoteStorageStatus.rejected, extraInfo: outcome);
    }
    if (outcome is _DatabaseFailure) {
      throw outcome.error;
    }
    if (outcome is OcptRemoteStorageStatus) {
      return ResultWithStatus(status: outcome);
    }
    if (outcome is OcptSyncMergeFailure) {
      return ResultWithStatus(status: OcptRemoteStorageStatus.unreachable, extraInfo: outcome);
    }

    return ResultWithStatus(
      status: OcptRemoteStorageStatus.unreachable,
      extraInfo: OcptSyncTransportFailure(error: outcome),
    );
  }
}

/// A queued outcome of [_FakeChangesetService] that makes the call throw [error], the way the
/// project database failing underneath a run does.
class _DatabaseFailure {
  /// The error to throw.
  final Error error;

  /// Class constructor
  const _DatabaseFailure(this.error);
}

/// Waits for [condition] to become true, polling every 5ms, failing the test if [timeout] elapses
/// first — every timer/stream-driven assertion below uses this instead of a fixed delay, so a
/// regression fails fast rather than flaking or hanging.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Run the tests of [OcptSyncSession].
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
      logger: const SilentLogger(),
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

  test(
    'a newWorkStream ping triggers a pullAndApply, not a full syncOnce',
    () async {
      await session.start();
      changesetService.syncOnceCalls = 0;

      storage.pingNewWork();

      await _waitUntil(() => changesetService.pullAndApplyCalls == 1);
      expect(changesetService.syncOnceCalls, 0);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'the periodic timer runs a syncOnce on its own, with no ping and no manual call',
    () async {
      session = OcptSyncSession(
        logger: const SilentLogger(),
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
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('syncNow runs a syncOnce on demand', () async {
    await session.start();
    expect(changesetService.syncOnceCalls, 1);

    await session.syncNow();

    expect(changesetService.syncOnceCalls, 2);
  });

  test(
    'status goes inSync -> syncing -> inSync across a successful run',
    () async {
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
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('an unreachable transport moves the status to offline, with a pending count', () async {
    changesetService.unpushedEditCount = 3;
    changesetService.syncOnceOutcomes.add(Exception('connection refused'));

    await session.start();

    expect(session.status, const OcptSyncStatusOffline(pendingEditCount: 3));
    expect(changesetService.countUnpushedEditsCalls, 1);
  });

  test('a changeset that cannot be merged moves the status to offline too', () async {
    changesetService.unpushedEditCount = 1;
    changesetService.syncOnceOutcomes.add(OcptSyncMergeFailure(error: StateError('unknown table')));

    await session.start();

    expect(session.status, const OcptSyncStatusOffline(pendingEditCount: 1));
  });

  test('the database failing under a run moves the status to offline too', () async {
    changesetService.unpushedEditCount = 2;
    changesetService.syncOnceOutcomes.add(_DatabaseFailure(StateError('database is closed')));

    await session.start();

    expect(session.status, const OcptSyncStatusOffline(pendingEditCount: 2));
  });

  test('an offline status carries no pending count when the count itself fails', () async {
    changesetService.isCountFailing = true;
    changesetService.syncOnceOutcomes.add(Exception('connection refused'));

    await session.start();

    expect(session.status, const OcptSyncStatusOffline());
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

  test(
    'stopSyncSession cancels the timer and the subscription, with no leak afterwards',
    () async {
      session = OcptSyncSession(
        logger: const SilentLogger(),
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
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  group('a run that knocks the session offline names its cause', () {
    late OcptDiagnosticsManager diagnostics;
    late FakeLogger fakeLogger;

    setUp(() async {
      OcptGlobalManager.instance;
      diagnostics = OcptDiagnosticsManager();
      final managers = globalGetIt();
      if (managers.isRegistered<OcptDiagnosticsManager>()) {
        await managers.unregister<OcptDiagnosticsManager>();
      }
      managers.registerSingleton<OcptDiagnosticsManager>(diagnostics);

      fakeLogger = FakeLogger();
      session = OcptSyncSession(
        logger: fakeLogger,
        projectId: projectId,
        database: database,
        deviceId: deviceId,
        relayId: relayId,
        storage: storage,
        changesetService: changesetService,
        pushInterval: const Duration(hours: 1),
      );
    });

    tearDown(() async {
      final managers = globalGetIt();
      if (managers.isRegistered<OcptDiagnosticsManager>()) {
        await managers.unregister<OcptDiagnosticsManager>();
      }
      await diagnostics.disposeLifeCycle();
    });

    /// Make the next run fail with [outcome], on the path that pushes then pulls, or on the one
    /// that only pulls, and wait for the session to go offline.
    Future<void> failOn({required bool isPullOnly, required Object outcome}) async {
      if (isPullOnly) {
        await session.start();
        changesetService.pullAndApplyOutcomes.add(outcome);
        storage.pingNewWork();
        await _waitUntil(() => session.status is OcptSyncStatusOffline);
      } else {
        changesetService.syncOnceOutcomes.add(outcome);
        await session.start();
      }
    }

    /// Get the diagnostics lines that say why the session went offline.
    List<String> causes() => [
      for (final entry in diagnostics.entries)
        if (entry.message.startsWith('offline cause')) entry.message,
    ];

    final causesByOutcome = <String, (Object, String, String)>{
      'a transport failure': (
        Exception('connection refused'),
        'Exception: connection refused',
        '_Exception',
      ),
      'a database failure': (
        _DatabaseFailure(StateError('database is closed')),
        'Bad state: database is closed',
        'StateError',
      ),
      'a status with no detail': (
        OcptRemoteStorageStatus.unreachable,
        'OcptRemoteStorageStatus.unreachable',
        'OcptRemoteStorageStatus',
      ),
    };

    test(
      'two failed runs in a row tell the diagnostics once and the file log twice',
      () async {
        changesetService.syncOnceOutcomes.add(Exception('connection refused'));
        await session.start();
        changesetService.syncOnceOutcomes.add(Exception('connection refused'));
        await session.syncNow();

        expect(session.status, isA<OcptSyncStatusOffline>());
        expect(causes(), ['offline cause: project=$projectId Exception: connection refused']);
        expect(fakeLogger.recordsAtLevel(LogsLevel.warn), hasLength(2));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'a run that failed again after a success tells the diagnostics again',
      () async {
        changesetService.syncOnceOutcomes.add(Exception('connection refused'));
        await session.start();
        await session.syncNow();
        expect(session.status, isA<OcptSyncStatusInSync>());
        changesetService.syncOnceOutcomes.add(Exception('connection refused'));
        await session.syncNow();

        expect(causes(), hasLength(2));
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    for (final isPullOnly in [false, true]) {
      final label = isPullOnly ? 'Sync pull failed' : 'Sync failed';
      final path = isPullOnly ? 'pulling alone' : 'pushing then pulling';

      causesByOutcome.forEach((name, expected) {
        final (outcome, diagnosticText, typeName) = expected;

        test(
          '$name while $path is told in the diagnostics with its text and logged with its type',
          () async {
            await failOn(isPullOnly: isPullOnly, outcome: outcome);

            expect(session.status, isA<OcptSyncStatusOffline>());
            expect(causes(), ['offline cause: project=$projectId $diagnosticText']);
            final warnings = fakeLogger.recordsAtLevel(LogsLevel.warn);
            expect(warnings.first.message.toString(), '$label for project $projectId: $typeName');
            expect(
              warnings.map((record) => record.message.toString()),
              everyElement(isNot(contains('connection refused'))),
            );
          },
          timeout: const Timeout(Duration(seconds: 5)),
        );
      });
    }
  });

  test('starting a session twice without stopping answers the already-running status', () async {
    expect(await session.start(), OcptSyncSessionStatus.ok);

    expect(await session.start(), OcptSyncSessionStatus.alreadyRunning);
  });
}
