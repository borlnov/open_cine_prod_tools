// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_relay_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_session_status.dart';

/// A minimal [OcptRemoteStorage]: [OcptSyncManager]'s own tests below only care that a session
/// starts and stops around it, never about what it actually stores.
class _FakeRemoteStorage implements OcptRemoteStorage {
  final StreamController<void> _newWorkController = StreamController<void>.broadcast();

  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, OcptSequenceNumber>> append(
    OcptChangesetEnvelope envelope,
  ) async =>
      const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: OcptSequenceNumber.zero);

  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptStoredChangeset>>> readSince(
    OcptSequenceNumber cursor,
  ) async => const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);

  @override
  Future<StatusWithExtraInfo<OcptRemoteStorageStatus>> uploadSnapshot(
    OcptSnapshotDescriptor descriptor,
    Uint8List bytes,
  ) async => const StatusWithExtraInfo(status: OcptRemoteStorageStatus.ok);

  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, (OcptSnapshotDescriptor, Uint8List)>>
  fetchLatestSnapshot() async => const ResultWithStatus(status: OcptRemoteStorageStatus.ok);

  @override
  Stream<void> get newWorkStream => _newWorkController.stream;

  @override
  void sendPresence(String opaquePayload) {}

  @override
  Stream<String> get presenceStream => const Stream.empty();

  Future<void> dispose() => _newWorkController.close();
}

/// An [OcptChangesetService] that never touches a real database or transport — see the sync
/// session's own test file for the fuller version this mirrors; this one only needs to prove
/// [OcptSyncManager] wires a session up and tears it down correctly, so it stays minimal.
class _FakeChangesetService extends OcptChangesetService {
  _FakeChangesetService()
    : super(
        logger: const SilentLogger(),
        mergeService: const OcptMergeService(logger: SilentLogger()),
      );

  int syncOnceCalls = 0;

  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>> syncOnce({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
    required String deviceId,
  }) async {
    syncOnceCalls++;

    return const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);
  }

  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>>>
  pullAndApply({
    required OcptProjectDatabase database,
    required OcptRemoteStorage storage,
    required String relayId,
  }) async => const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);
}

void main() {
  group('openRelayRemoteStorage', () {
    test('builds a relay transport from the pairing and the given project id', () {
      final manager = OcptSyncManager(
        changesetService: const OcptChangesetService(
          logger: SilentLogger(),
          mergeService: OcptMergeService(logger: SilentLogger()),
        ),
      );
      final pairing = OcptProjectPairing(
        relayBaseUri: Uri.https('relay.example.org'),
        token: 'token-1',
      );

      final storage =
          manager.openRelayRemoteStorage(pairing, 'project-1', enrolmentSecret: 'secret-1')
              as OcptRelayRemoteStorage;

      expect(storage.relayBaseUri, pairing.relayBaseUri);
      expect(storage.projectId, 'project-1');
      expect(storage.token, pairing.token);
      expect(storage.enrolmentSecret, 'secret-1');

      storage.dispose();
    });
  });

  group('relayIdFor', () {
    test('is stable for the same relay base URL', () {
      final pairing = OcptProjectPairing(relayBaseUri: Uri.https('relay.example.org'), token: 't');

      expect(OcptSyncManager.relayIdFor(pairing), OcptSyncManager.relayIdFor(pairing));
    });

    test('differs between two different relays', () {
      final first = OcptProjectPairing(relayBaseUri: Uri.https('relay-a.example.org'), token: 't');
      final second = OcptProjectPairing(relayBaseUri: Uri.https('relay-b.example.org'), token: 't');

      expect(OcptSyncManager.relayIdFor(first), isNot(OcptSyncManager.relayIdFor(second)));
    });
  });

  group('sync session lifecycle', () {
    late OcptProjectDatabase database;
    late _FakeRemoteStorage storage;
    late _FakeChangesetService changesetService;
    late OcptSyncManager manager;

    setUp(() {
      database = OcptProjectDatabase.memory();
      storage = _FakeRemoteStorage();
      changesetService = _FakeChangesetService();
      manager = OcptSyncManager(changesetService: changesetService);
    });

    tearDown(() async {
      await manager.stopSyncSession();
      await storage.dispose();
      await database.close();
    });

    test('startSyncSession runs an initial sync and exposes the running session', () async {
      await manager.startSyncSession(
        projectId: 'project-1',
        database: database,
        deviceId: 'device-1',
        relayId: 'relay-1',
        storage: storage,
      );

      expect(changesetService.syncOnceCalls, 1);
      expect(manager.syncSession, isNotNull);
      expect(manager.syncStatus, const OcptSyncStatusInSync());
    });

    test('syncNow forwards to the running session', () async {
      await manager.startSyncSession(
        projectId: 'project-1',
        database: database,
        deviceId: 'device-1',
        relayId: 'relay-1',
        storage: storage,
      );

      await manager.syncNow();

      expect(changesetService.syncOnceCalls, 2);
    });

    test('syncNow answers the not-running status when no session is running', () async {
      expect(await manager.syncNow(), OcptSyncSessionStatus.notRunning);
    });

    test('stopSyncSession clears the running session', () async {
      await manager.startSyncSession(
        projectId: 'project-1',
        database: database,
        deviceId: 'device-1',
        relayId: 'relay-1',
        storage: storage,
      );

      await manager.stopSyncSession();

      expect(manager.syncSession, isNull);
      expect(manager.syncStatus, isNull);
    });

    test(
      'syncStatusChanges reaches a subscriber that subscribed before the session started',
      () async {
        // The workspace's own status indicator subscribes when it is built — before the project it
        // then opens has started its session. The per-session stream would be null at that point,
        // so this manager-level one has to carry the session's status once it starts, and a null
        // once it stops, for the indicator to ever appear (and later hide).
        final received = <OcptSyncStatus?>[];
        final subscription = manager.syncStatusChanges.listen(received.add);
        addTearDown(subscription.cancel);

        await manager.startSyncSession(
          projectId: 'project-1',
          database: database,
          deviceId: 'device-1',
          relayId: 'relay-1',
          storage: storage,
        );
        await pumpEventQueue();

        expect(received, contains(const OcptSyncStatusInSync()));

        await manager.stopSyncSession();
        await pumpEventQueue();

        expect(
          received.last,
          isNull,
          reason: 'the session stopping closes the stream out with a null',
        );
      },
    );

    test('starting a session again replaces the one already running', () async {
      await manager.startSyncSession(
        projectId: 'project-1',
        database: database,
        deviceId: 'device-1',
        relayId: 'relay-1',
        storage: storage,
      );
      final firstSession = manager.syncSession;

      await manager.startSyncSession(
        projectId: 'project-1',
        database: database,
        deviceId: 'device-1',
        relayId: 'relay-1',
        storage: storage,
      );

      expect(manager.syncSession, isNot(same(firstSession)));
      expect(firstSession!.isRunning, isFalse);
    });
  });
}
