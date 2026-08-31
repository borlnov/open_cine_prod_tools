// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — `sharing_bloc_test.dart`'s own mock,
/// which this file's [OcptPairingService] needs the exact same wiring for.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

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

/// An in-memory [OcptRemoteStorage] carrying no network at all — `sharing_bloc_test.dart`'s own
/// `_FakeRemoteStorage`.
class _FakeRemoteStorage implements OcptRemoteStorage {
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
  void sendPresence(String opaquePayload) {}

  @override
  Stream<String> get presenceStream => const Stream.empty();
}

/// An [OcptSyncManager] whose [openRelayRemoteStorage] hands back a fixed fake transport instead of
/// a real relay connection over the network, and whose [pairProjectToRelay]/[repointProjectToRelay]
/// are stubbed to skip the real orchestration (push, snapshot upload, session start) — exactly
/// `sharing_bloc_test.dart`'s own `_FakeTransportSyncManager`, and for the very same reason: the
/// real [OcptSyncManager.publishSnapshot] does real `dart:io` file I/O
/// (`OcptProjectPackageService.writePackage`'s own `VACUUM INTO`), which this bloc's own tests have
/// no need to exercise — only that the pairing moved and a live session started is what the bloc
/// reacts to.
class _FakeTransportSyncManager extends OcptSyncManager {
  _FakeTransportSyncManager({
    required OcptPairingService pairingService,
    this.shouldFailToOpenTransport = false,
  }) : _pairing = pairingService,
       super(pairingService: pairingService, changesetService: const OcptChangesetService());

  final OcptPairingService _pairing;

  final bool shouldFailToOpenTransport;

  @override
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) {
    if (shouldFailToOpenTransport) {
      throw StateError('The relay could not be reached');
    }

    return _FakeRemoteStorage();
  }

  @override
  Future<OcptRelayInvite> pairProjectToRelay({
    required OcptProjectDatabase database,
    required String projectId,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required Uri relayBaseUri,
    required String enrolmentSecret,
    required String deviceId,
  }) async {
    if (shouldFailToOpenTransport) {
      throw StateError('The relay could not be reached');
    }

    const token = 'fake-project-token';
    await _pairing.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: token,
    );
    final pairing = OcptProjectPairing(relayBaseUri: relayBaseUri, token: token);
    await startSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: OcptSyncManager.relayIdFor(pairing),
      storage: openRelayRemoteStorage(pairing, projectId),
    );

    return OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: token);
  }

  @override
  Future<void> repointProjectToRelay({
    required OcptProjectDatabase database,
    required String projectId,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required Uri relayBaseUri,
    required String enrolmentSecret,
    required String deviceId,
  }) async {
    if (shouldFailToOpenTransport) {
      throw StateError('The relay could not be reached');
    }

    final existing = await _pairing.loadPairing(database: database, projectId: projectId);
    if (existing == null) {
      throw StateError('Cannot re-point an unpaired project.');
    }

    await _pairing.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: existing.token,
    );
    final newPairing = OcptProjectPairing(relayBaseUri: relayBaseUri, token: existing.token);
    await startSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: OcptSyncManager.relayIdFor(newPairing),
      storage: openRelayRemoteStorage(newPairing, projectId, enrolmentSecret: enrolmentSecret),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptPropertiesManager propertiesManager;
  late OcptPairingService pairingService;
  late Map<String, String> secureStore;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;

  final initialRelayBaseUri = Uri.parse('https://relay-prep.example.org/');
  final newRelayBaseUri = Uri.parse('https://relay-onset.example.org/');

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
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

    pairingService = OcptPairingService(secretsManager: secretsManager);
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    secureStore.clear();

    tempDir = await Directory.systemTemp.createTemp("ocpt_repointing_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds an [OcptRepointingBloc] reading/writing through [projectsManager] and
  /// [propertiesManager], talking through a fake relay transport [manager].
  OcptRepointingBloc buildBloc(_FakeTransportSyncManager manager) {
    addTearDown(manager.stopSyncSession);

    final bloc = OcptRepointingBloc(
      projectsManager: projectsManager,
      syncManager: manager,
      propertiesManager: propertiesManager,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  test("opens directly on ① Configure, with the project's own name", () async {
    final bloc = buildBloc(_FakeTransportSyncManager(pairingService: pairingService));

    await pumpEventQueue();

    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.enrolment, isNull);
    expect(bloc.state.projectName, "My Movie");
  });

  test(
    "a successful repoint moves the project's own pairing and shows ② QR code",
    () async {
      final manager = _FakeTransportSyncManager(pairingService: pairingService);
      await manager.pairProjectToRelay(
        database: projectsManager.currentProject!.fileDatabase,
        projectId: "project-abc",
        projectFilePath: projectsManager.currentProject!.path,
        projectName: "My Movie",
        appVersion: "0.1.0",
        relayBaseUri: initialRelayBaseUri,
        enrolmentSecret: "prep-enrolment-secret",
        deviceId: "device-1",
      );

      final bloc = buildBloc(manager);
      await pumpEventQueue();

      bloc.add(
        OcptRepointingRequestedEvent(
          relayBaseUri: newRelayBaseUri,
          enrolmentSecret: "onset-enrolment-secret",
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.isRepointing, isFalse);
      expect(bloc.state.repointFailed, isFalse);
      final enrolment = bloc.state.enrolment;
      expect(enrolment, isNotNull);
      expect(enrolment!.relayBaseUri, newRelayBaseUri);
      expect(enrolment.enrolmentSecret, "onset-enrolment-secret");

      // The pairing actually moved in the database and secure storage, keeping its own token.
      final pairing = await pairingService.loadPairing(
        database: projectsManager.currentProject!.fileDatabase,
        projectId: "project-abc",
      );
      expect(pairing, isNotNull);
      expect(pairing!.relayBaseUri, newRelayBaseUri);
      expect(pairing.token, "fake-project-token");
    },
  );

  test("re-pointing an unpaired project surfaces repointFailed", () async {
    final bloc = buildBloc(_FakeTransportSyncManager(pairingService: pairingService));
    await pumpEventQueue();

    bloc.add(
      OcptRepointingRequestedEvent(
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: "onset-enrolment-secret",
      ),
    );
    await pumpEventQueue();

    expect(bloc.state.isRepointing, isFalse);
    expect(bloc.state.repointFailed, isTrue);
    expect(bloc.state.enrolment, isNull);
  });

  test("an unreachable relay surfaces repointFailed and leaves the enrolment unset", () async {
    final workingManager = _FakeTransportSyncManager(pairingService: pairingService);
    await workingManager.pairProjectToRelay(
      database: projectsManager.currentProject!.fileDatabase,
      projectId: "project-abc",
      projectFilePath: projectsManager.currentProject!.path,
      projectName: "My Movie",
      appVersion: "0.1.0",
      relayBaseUri: initialRelayBaseUri,
      enrolmentSecret: "prep-enrolment-secret",
      deviceId: "device-1",
    );
    await workingManager.stopSyncSession();

    // A second manager instance, sharing the same pairing service and database, stands for the
    // relay becoming unreachable at the moment of the re-point itself — the existing pairing was
    // already saved by [workingManager] above.
    final bloc = buildBloc(
      _FakeTransportSyncManager(pairingService: pairingService, shouldFailToOpenTransport: true),
    );
    await pumpEventQueue();

    bloc.add(
      OcptRepointingRequestedEvent(
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: "onset-enrolment-secret",
      ),
    );
    await pumpEventQueue();

    expect(bloc.state.isRepointing, isFalse);
    expect(bloc.state.repointFailed, isTrue);
    expect(bloc.state.enrolment, isNull);
  });

  test("dismissing the error clears the flag", () async {
    final bloc = buildBloc(_FakeTransportSyncManager(pairingService: pairingService));
    await pumpEventQueue();

    bloc.add(
      OcptRepointingRequestedEvent(
        relayBaseUri: newRelayBaseUri,
        enrolmentSecret: "onset-enrolment-secret",
      ),
    );
    await pumpEventQueue();
    expect(bloc.state.repointFailed, isTrue);

    bloc.add(const OcptRepointingErrorDismissedEvent());
    await pumpEventQueue();

    expect(bloc.state.repointFailed, isFalse);
  });
}
