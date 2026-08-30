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
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — mirrors
/// `ocpt_sync_manager_pairing_test.dart`'s own mock, which this file's [OcptPairingService] needs
/// the exact same wiring for.
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

/// An in-memory [OcptRemoteStorage] carrying no network at all — everything
/// [OcptSyncManager.pairProjectToRelay] needs of a transport for this bloc's own tests.
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
}

/// An [OcptSyncManager] whose [openRelayRemoteStorage] hands back a fixed fake transport instead of
/// a real relay connection over the network, or throws when [shouldFailToOpenTransport] — standing
/// for the relay being unreachable, or the enrolment secret being refused — exactly the shape
/// `ocpt_sync_manager_pairing_test.dart`'s own `_FakeTransportSyncManager` already follows.
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

  // The real orchestration (push, snapshot upload, session start) is exercised by
  // `ocpt_sync_manager_pairing_test.dart`. Here it is stubbed so the bloc's own tests never do the
  // real `OcptProjectPackageService.writePackage` file I/O, which under the full suite's parallel
  // load is the one flaky step — the pairing is saved and an invite returned, or the failure flag
  // throws, which is all the bloc reacts to.
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
    // Start a real session over the fake transport — its initial sync only touches the database,
    // never the filesystem — so callers see a live `syncStatus`, without the flaky `writePackage`.
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptPropertiesManager propertiesManager;
  late OcptPairingService pairingService;
  late Map<String, String> secureStore;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;

  final relayBaseUri = Uri.parse('https://relay.example.org/');

  setUpAll(() async {
    // OcptGlobalManager, OcptConfigManager, OcptPropertiesManager and OcptProjectsManager all log
    // through appLogger(), which requires a global manager instance to be set; merely accessing it
    // creates the (otherwise unused) singleton, exactly as the sync manager's own tests do.
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

    tempDir = await Directory.systemTemp.createTemp("ocpt_sharing_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en");
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

  /// Builds an [OcptSharingBloc] reading/writing through [projectsManager] and [propertiesManager],
  /// paired to a fake relay transport through [manager].
  ///
  /// [manager]'s own sync session, if a test's own pairing starts one, is stopped on tear-down —
  /// `ocpt_sync_manager_pairing_test.dart`'s own idiom — so its periodic push timer doesn't outlive
  /// the test.
  OcptSharingBloc buildBloc(_FakeTransportSyncManager manager) {
    addTearDown(manager.stopSyncSession);

    final bloc = OcptSharingBloc(
      projectsManager: projectsManager,
      syncManager: manager,
      propertiesManager: propertiesManager,
    );
    addTearDown(bloc.close);
    addTearDown(manager.stopSyncSession);
    return bloc;
  }

  test("an unpaired project opens on ① Configure, with the project's own name", () async {
    final bloc = buildBloc(_FakeTransportSyncManager(pairingService: pairingService));

    await pumpEventQueue();

    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.invite, isNull);
    expect(bloc.state.projectName, "My Movie");
  });

  test("submitting the ① Configure form pairs the project and moves to ② Invite", () async {
    final bloc = buildBloc(_FakeTransportSyncManager(pairingService: pairingService));
    await pumpEventQueue();

    bloc.add(
      OcptSharingPairRequestedEvent(relayBaseUri: relayBaseUri, enrolmentSecret: "enrolment-secret"),
    );
    // `pumpEventQueue()` alone occasionally races the raw, read-only sqlite3 connection
    // `OcptProjectPackageService.writePackage` opens for its own `VACUUM INTO` against the very
    // file drift's own `NativeDatabase` connection just wrote through (the pairing row), on this
    // sandbox's filesystem — a real settle delay avoids the transient `SqliteException(14)` that
    // race produces, which `pumpEventQueue()`'s microtask-only draining doesn't wait out.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await pumpEventQueue();

    expect(bloc.state.isPairing, isFalse);
    expect(bloc.state.pairingFailed, isFalse);
    final invite = bloc.state.invite;
    expect(invite, isNotNull);
    expect(invite!.relayBaseUri, relayBaseUri);
    expect(invite.token, isNotEmpty);

    // The pairing actually reached the database and secure storage, not just the bloc's own state.
    final pairing = await pairingService.loadPairing(
      database: projectsManager.currentProject!.fileDatabase,
      projectId: invite.projectId,
    );
    expect(pairing, isNotNull);
    expect(pairing!.relayBaseUri, relayBaseUri);
    expect(pairing.token, invite.token);
  });

  test("a project already paired opens directly on ② Invite", () async {
    final manager = _FakeTransportSyncManager(pairingService: pairingService);
    final invite = await manager.pairProjectToRelay(
      database: projectsManager.currentProject!.fileDatabase,
      projectId: "project-abc",
      projectFilePath: projectsManager.currentProject!.path,
      projectName: "My Movie",
      appVersion: "0.1.0",
      relayBaseUri: relayBaseUri,
      enrolmentSecret: "enrolment-secret",
      deviceId: "device-1",
    );

    final bloc = buildBloc(manager);
    await pumpEventQueue();

    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.invite, invite);
  });

  test("confirming unpair clears the invite, stops the session and returns to ① Configure", () async {
    final manager = _FakeTransportSyncManager(pairingService: pairingService);
    await manager.pairProjectToRelay(
      database: projectsManager.currentProject!.fileDatabase,
      projectId: "project-abc",
      projectFilePath: projectsManager.currentProject!.path,
      projectName: "My Movie",
      appVersion: "0.1.0",
      relayBaseUri: relayBaseUri,
      enrolmentSecret: "enrolment-secret",
      deviceId: "device-1",
    );
    expect(manager.syncStatus, isNotNull);

    final bloc = buildBloc(manager);
    await pumpEventQueue();
    expect(bloc.state.invite, isNotNull);

    bloc.add(const OcptSharingUnpairConfirmedEvent());
    await pumpEventQueue();

    expect(bloc.state.invite, isNull);
    expect(manager.syncStatus, isNull);

    final pairing = await pairingService.loadPairing(
      database: projectsManager.currentProject!.fileDatabase,
      projectId: "project-abc",
    );
    expect(pairing, isNull);
  });

  test("a pairing failure surfaces pairingFailed and leaves the project unpaired", () async {
    final bloc = buildBloc(
      _FakeTransportSyncManager(pairingService: pairingService, shouldFailToOpenTransport: true),
    );
    await pumpEventQueue();

    bloc.add(
      OcptSharingPairRequestedEvent(relayBaseUri: relayBaseUri, enrolmentSecret: "enrolment-secret"),
    );
    await pumpEventQueue();

    expect(bloc.state.isPairing, isFalse);
    expect(bloc.state.pairingFailed, isTrue);
    expect(bloc.state.invite, isNull);
  });

  test("dismissing the pairing error clears the flag", () async {
    final bloc = buildBloc(
      _FakeTransportSyncManager(pairingService: pairingService, shouldFailToOpenTransport: true),
    );
    await pumpEventQueue();

    bloc.add(
      OcptSharingPairRequestedEvent(relayBaseUri: relayBaseUri, enrolmentSecret: "enrolment-secret"),
    );
    await pumpEventQueue();
    expect(bloc.state.pairingFailed, isTrue);

    bloc.add(const OcptSharingPairingErrorDismissedEvent());
    await pumpEventQueue();

    expect(bloc.state.pairingFailed, isFalse);
  });
}
