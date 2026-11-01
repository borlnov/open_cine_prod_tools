// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_project_pairing.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_flow_status.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — mirrors
/// `ocpt_sync_manager_snapshot_test.dart`'s own mock, which this file's [OcptPairingService] needs
/// the exact same wiring for.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Back the platform secure storage channel with [store], so no real keychain is needed.
void _mockSecureStorage(Map<String, String> store) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    _secureStorageChannel,
    (call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final key = arguments?['key'] as String?;

      switch (call.method) {
        case 'read':
          return store[key];
        case 'write':
          store[key!] = arguments!['value']! as String;
          return null;
        case 'delete':
          store.remove(key);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
        case 'containsKey':
          return store.containsKey(key);
        case 'readAll':
          return Map<String, String>.from(store);
        default:
          return null;
      }
    },
  );
}

/// An in-memory [OcptRemoteStorage] recording every changeset appended to it and the one snapshot
/// uploaded, and carrying no network at all — everything [OcptSyncManager.pairProjectToRelay]'s own
/// tests below need of a transport.
class _FakeRemoteStorage implements OcptRemoteStorage {
  /// The envelopes appended so far.
  final List<OcptChangesetEnvelope> appended = [];

  /// The last snapshot uploaded, or null before any.
  (OcptSnapshotDescriptor, Uint8List)? uploaded;

  /// When set, the status every request/response call answers instead of succeeding.
  OcptRemoteStorageStatus? failWith;

  /// The controller behind [newWorkStream].
  final StreamController<void> _newWorkController = StreamController<void>.broadcast();

  /// Emit the pings the test adds to the controller.
  @override
  Stream<void> get newWorkStream => _newWorkController.stream;

  /// Emit nothing.
  @override
  Stream<String> get presenceStream => const Stream.empty();

  /// Fail with the canned failure when there is one, otherwise keep the envelope and answer with
  /// the next sequence number.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, OcptSequenceNumber>> append(
    OcptChangesetEnvelope envelope,
  ) async {
    final failure = failWith;
    if (failure != null) {
      return ResultWithStatus(status: failure);
    }
    appended.add(envelope);

    return ResultWithStatus(
      status: OcptRemoteStorageStatus.ok,
      value: OcptSequenceNumber(appended.length),
    );
  }

  /// Answer with an empty log.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, List<OcptStoredChangeset>>> readSince(
    OcptSequenceNumber cursor,
  ) async => const ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: []);

  /// Fail with the canned failure when there is one, otherwise keep the snapshot as the latest.
  @override
  Future<StatusWithExtraInfo<OcptRemoteStorageStatus>> uploadSnapshot(
    OcptSnapshotDescriptor descriptor,
    Uint8List bytes,
  ) async {
    final failure = failWith;
    if (failure != null) {
      return StatusWithExtraInfo(status: failure);
    }
    uploaded = (descriptor, bytes);

    return const StatusWithExtraInfo(status: OcptRemoteStorageStatus.ok);
  }

  /// Answer with the snapshot uploaded last.
  @override
  Future<ResultWithStatus<OcptRemoteStorageStatus, (OcptSnapshotDescriptor, Uint8List)>>
  fetchLatestSnapshot() async =>
      ResultWithStatus(status: OcptRemoteStorageStatus.ok, value: uploaded);

  /// Drop the payload.
  @override
  void sendPresence(String opaquePayload) {}

  /// Close the controller behind [newWorkStream].
  Future<void> dispose() => _newWorkController.close();
}

/// An [OcptSyncManager] whose [openRelayRemoteStorage] hands back a fixed [storage] instead of a
/// real relay transport over the network, recording the enrolment secret it was asked to carry —
/// [pairProjectToRelay] itself has no seam for a transport (it always builds its own, per its own
/// doc comment), so this is how its own tests exercise it with no network at all.
class _FakeTransportSyncManager extends OcptSyncManager {
  /// The storage every transport opened by the double is.
  final OcptRemoteStorage storage;

  /// The enrolment secret the last transport was opened with.
  String? capturedEnrolmentSecret;

  /// Set by `repointProjectToRelay`'s own tests to hand back a second, distinct
  /// [_FakeRemoteStorage] for the re-point's own transport, so its own appends/uploads can be
  /// asserted apart from the first [pairProjectToRelay] call's [storage].
  OcptRemoteStorage? storageOverride;

  /// Class constructor
  _FakeTransportSyncManager({
    required this.storage,
    required OcptPairingService super.pairingService,
  }) : super(
         changesetService: const OcptChangesetService(
           logger: SilentLogger(),
           mergeService: OcptMergeService(logger: SilentLogger()),
         ),
       );

  /// Remember the enrolment secret, and answer with the storage override or the storage.
  @override
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) {
    capturedEnrolmentSecret = enrolmentSecret;

    return storageOverride ?? storage;
  }
}

/// Run the tests of the sync manager pairing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceId = 'device-1';
  const projectId = 'project-abc';
  final relayBaseUri = Uri.parse('https://relay.example.org/');

  late OcptPairingService pairingService;
  late Map<String, String> secureStore;

  setUpAll(() async {
    // OcptGlobalManager, OcptConfigManager and OcptPropertiesManager all log through appLogger(),
    // which requires a global manager instance to be set; merely accessing it creates the
    // (otherwise unused) singleton, exactly as `ocpt_sync_manager_snapshot_test.dart` does.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    final configManager = OcptConfigManager();
    await configManager.initLifeCycle();

    secureStore = {};
    _mockSecureStorage(secureStore);

    final secretsManager = OcptSecretsManager(
      propertiesGetter: () => propertiesManager,
      confGetter: () => configManager,
    );
    await secretsManager.initLifeCycle();

    pairingService = OcptPairingService(
      logger: const SilentLogger(),
      secretsManager: secretsManager,
    );
  });

  late Directory workspace;
  late String projectPath;
  late OcptProjectDatabase database;
  late _FakeRemoteStorage storage;
  late _FakeTransportSyncManager manager;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ocpt_sync_manager_pairing_test_');
    projectPath = p.join(workspace.path, 'project.ocpt');
    secureStore.clear();

    database = OcptProjectDatabase(File(projectPath));
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: 'Les Vagues',
            createdAt: DateTime.utc(2026),
            appVersionAtCreation: '0.1.0',
            pageFormat: OcptPageFormat.a4,
          ),
        );
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: 'screenplay-1',
            title: 'Draft',
            fountainText: const Value('INT. HOUSE - DAY\n\nA quiet morning.'),
            updatedAt: DateTime.utc(2026),
          ),
        );

    // A stamped local edit, so pushLocalEdits actually has something to append — an unstamped
    // project would let pairProjectToRelay run with nothing pushed at all, which is not the case
    // this suite is proving.
    await database
        .into(database.ocptLocationsTable)
        .insert(OcptLocationsTableCompanion.insert(id: 'location-1', name: 'Untitled'));
    final location = await (database.select(
      database.ocptLocationsTable,
    )..where((table) => table.id.equals('location-1'))).getSingle();
    final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptLocationsTable,
      rowId: location.id,
      current: location,
      next: location.copyWith(name: 'Exterior'),
      stamps: stamps,
    );
    await stamps.flush(database);

    storage = _FakeRemoteStorage();
    manager = _FakeTransportSyncManager(storage: storage, pairingService: pairingService);
  });

  tearDown(() async {
    await manager.stopSyncSession();
    await storage.dispose();
    await database.close();
    workspace.deleteSync(recursive: true);
  });

  group('pairProjectToRelay', () {
    test('saves the pairing with a freshly minted token', () async {
      final paired = await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );
      expect(paired.status, OcptSyncFlowStatus.ok);
      final invite = paired.value!;

      final pairing = await pairingService.loadPairing(database: database, projectId: projectId);
      expect(pairing, isNotNull);
      expect(pairing!.relayBaseUri, relayBaseUri);
      expect(pairing.token, invite.token);
      expect(pairing.token, isNotEmpty);
    });

    test('opens the transport with the given enrolment secret', () async {
      await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      expect(manager.capturedEnrolmentSecret, 'enrolment-secret-1');
    });

    test('pushes this replica local edits, creating the project on the relay', () async {
      await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      expect(storage.appended, hasLength(1));
    });

    test('publishes a snapshot whose sequenceUpTo is the highest sequence just appended', () async {
      await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      expect(storage.uploaded, isNotNull);

      final relayId = OcptSyncManager.relayIdFor(
        OcptProjectPairing(relayBaseUri: relayBaseUri, token: 't'),
      );
      final sequenceUpTo = await const OcptChangesetService(
        logger: SilentLogger(),
        mergeService: OcptMergeService(logger: SilentLogger()),
      ).highestAppendedSequence(database: database, relayId: relayId);
      expect(storage.uploaded!.$1.sequenceUpTo, sequenceUpTo);
      expect(sequenceUpTo, isNot(OcptSequenceNumber.zero));
    });

    test('starts the ongoing sync session', () async {
      await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      expect(manager.syncStatus, isNotNull);
    });

    test('answers the transport failure and starts no session when the push fails', () async {
      storage.failWith = OcptRemoteStorageStatus.unreachable;

      final paired = await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      expect(paired.status, OcptSyncFlowStatus.unreachable);
      expect(paired.value, isNull);
      expect(manager.syncStatus, isNull);
      expect(storage.uploaded, isNull);
    });

    test('returns an invite matching the relay, the project and the minted token', () async {
      final paired = await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );
      expect(paired.status, OcptSyncFlowStatus.ok);
      final invite = paired.value!;

      final pairing = await pairingService.loadPairing(database: database, projectId: projectId);
      expect(
        invite,
        OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: pairing!.token),
      );
    });
  });

  group('repointProjectToRelay', () {
    final newRelayBaseUri = Uri.parse('https://set-relay.example.org/');

    test('reuses the existing token and re-saves the pairing against the new relay', () async {
      final paired = await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );
      expect(paired.status, OcptSyncFlowStatus.ok);
      final invite = paired.value!;

      await manager.repointProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: 'set-relay-secret',
        deviceId: deviceId,
      );

      final pairing = await pairingService.loadPairing(database: database, projectId: projectId);
      expect(pairing, isNotNull);
      expect(pairing!.relayBaseUri, newRelayBaseUri);
      expect(pairing.token, invite.token);
    });

    test('opens the transport with the set relay enrolment secret', () async {
      await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      await manager.repointProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: 'set-relay-secret',
        deviceId: deviceId,
      );

      expect(manager.capturedEnrolmentSecret, 'set-relay-secret');
    });

    test('pushes edits, publishes a snapshot and starts a session against the new relay', () async {
      await manager.pairProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: relayBaseUri,
        enrolmentSecret: 'enrolment-secret-1',
        deviceId: deviceId,
      );

      final newStorage = _FakeRemoteStorage();
      manager.storageOverride = newStorage;

      await manager.repointProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: 'set-relay-secret',
        deviceId: deviceId,
      );

      expect(newStorage.appended, hasLength(1));
      expect(newStorage.uploaded, isNotNull);
      expect(manager.syncStatus, isNotNull);

      final relayId = OcptSyncManager.relayIdFor(
        OcptProjectPairing(relayBaseUri: newRelayBaseUri, token: 't'),
      );
      final sequenceUpTo = await const OcptChangesetService(
        logger: SilentLogger(),
        mergeService: OcptMergeService(logger: SilentLogger()),
      ).highestAppendedSequence(database: database, relayId: relayId);
      expect(newStorage.uploaded!.$1.sequenceUpTo, sequenceUpTo);

      await newStorage.dispose();
    });

    test('answers the not-paired status when the project has no existing pairing', () async {
      final result = await manager.repointProjectToRelay(
        database: database,
        projectId: projectId,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: 'set-relay-secret',
        deviceId: deviceId,
      );

      expect(result.status, OcptSyncFlowStatus.notPaired);
      expect(manager.syncStatus, isNull);
    });
  });
}
