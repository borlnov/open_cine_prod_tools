// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — mirrors
/// `ocpt_sync_manager_pairing_test.dart`'s own mock, which this file's [OcptSecretsManager] needs
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

/// A [PlatformManager] whose [isMobile] is stubbed, so the manager's desktop guard can be
/// exercised on either branch without a real platform underneath it — mirrors
/// `ocpt_export_manager_test.dart`'s own stub.
class _StubPlatformManager extends PlatformManager {
  /// Class constructor
  _StubPlatformManager({required this.isMobile});

  @override
  final bool isMobile;
}

/// A spy [OcptSyncManager] recording whether `OcptRelayHostManager.startHosting`'s self-seed
/// paired or re-pointed, and standing in for a live sync session/presence service — modelled on
/// `ocpt_sync_manager_pairing_test.dart`'s own `_FakeTransportSyncManager`, but here the point is
/// not to exercise the real pairing/repointing logic (already covered by that suite) but to prove
/// [OcptRelayHostManager] calls the right one, with the right localhost URI, and tears the session
/// down again on `OcptRelayHostManager.stopHosting`.
class _SpySyncManager extends OcptSyncManager {
  _SpySyncManager() : super(changesetService: const OcptChangesetService());

  Uri? seededRelayBaseUri;
  String? seededEnrolmentSecret;
  String? seededProjectId;
  bool didPair = false;
  bool didRepoint = false;
  bool didStopSession = false;
  OcptPresenceRoster? rosterWhileSeeded;

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
    didPair = true;
    seededProjectId = projectId;
    seededRelayBaseUri = relayBaseUri;
    seededEnrolmentSecret = enrolmentSecret;
    rosterWhileSeeded = const OcptPresenceRoster(participants: [], selfDeviceId: 'device-1');
    // Mirrors OcptPairingService.savePairing's own upsert, so a real OcptRelayHostManager built
    // over this spy sees, on its very next loadPairedProjectId, exactly the row the real pairing
    // path would have left behind — which is what lets the "reused across restarts" tests below
    // find the very same project id a second time around.
    await database
        .into(database.ocptSyncPairingsTable)
        .insertOnConflictUpdate(
          OcptSyncPairingsTableCompanion.insert(projectId: projectId, relayBaseUrl: relayBaseUri.toString()),
        );

    return OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: 'spy-token');
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
    didRepoint = true;
    seededProjectId = projectId;
    seededRelayBaseUri = relayBaseUri;
    seededEnrolmentSecret = enrolmentSecret;
    rosterWhileSeeded = const OcptPresenceRoster(participants: [], selfDeviceId: 'device-1');
    await database
        .into(database.ocptSyncPairingsTable)
        .insertOnConflictUpdate(
          OcptSyncPairingsTableCompanion.insert(projectId: projectId, relayBaseUrl: relayBaseUri.toString()),
        );
  }

  @override
  Future<void> stopSyncSession() async {
    didStopSession = true;
  }

  @override
  OcptPresenceRoster? get presenceRoster => rosterWhileSeeded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptSecretsManager secretsManager;
  late Map<String, String> secureStore;

  setUpAll(() async {
    // OcptGlobalManager, OcptConfigManager and OcptPropertiesManager all log through appLogger(),
    // which requires a global manager instance to be set; merely accessing it creates the
    // (otherwise unused) singleton, exactly as `ocpt_sync_manager_pairing_test.dart` does.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    final configManager = OcptConfigManager();
    await configManager.initLifeCycle();

    secureStore = {};
    _mockSecureStorage(secureStore);

    secretsManager = OcptSecretsManager(
      propertiesGetter: () => propertiesManager,
      confGetter: () => configManager,
    );
    await secretsManager.initLifeCycle();
  });

  late Directory workspace;
  late String projectPath;
  late OcptProjectDatabase database;
  late _SpySyncManager spy;
  late OcptRelayHostManager manager;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ocpt_relay_host_manager_test_');
    projectPath = p.join(workspace.path, 'project.ocpt');
    secureStore.clear();

    database = OcptProjectDatabase(File(projectPath));
    spy = _SpySyncManager();

    manager = OcptRelayHostManager(
      secretsManager: secretsManager,
      syncManager: spy,
      platformManager: _StubPlatformManager(isMobile: false),
      bindAddress: InternetAddress.loopbackIPv4,
      lanAddressResolver: () async => InternetAddress('192.168.1.42'),
    );
  });

  tearDown(() async {
    await manager.stopHosting();
    await database.close();
    workspace.deleteSync(recursive: true);
  });

  Future<void> startHosting() => manager.startHosting(
    database: database,
    projectFilePath: projectPath,
    projectName: 'Les Vagues',
    appVersion: '0.1.0',
    deviceId: 'device-1',
  );

  test('a never-paired project pairs itself to its own hosted relay over localhost', () async {
    await startHosting();

    expect(spy.didPair, isTrue);
    expect(spy.didRepoint, isFalse);
    expect(spy.seededRelayBaseUri!.scheme, 'http');
    expect(spy.seededRelayBaseUri!.host, 'localhost');
    expect(spy.seededRelayBaseUri!.port, isNot(0));
    expect(spy.seededEnrolmentSecret, (manager.state as OcptRelayHostOnline).enrolmentSecret);
    expect(spy.seededProjectId, manager.hostedProjectId);
  });

  test('an already-paired project re-points itself to its own hosted relay, reusing its id', () async {
    await database
        .into(database.ocptSyncPairingsTable)
        .insert(
          OcptSyncPairingsTableCompanion.insert(
            projectId: 'existing-project',
            relayBaseUrl: 'https://prep.example.org/',
          ),
        );

    await startHosting();

    expect(spy.didRepoint, isTrue);
    expect(spy.didPair, isFalse);
    expect(spy.seededProjectId, 'existing-project');
    expect(spy.seededRelayBaseUri!.host, 'localhost');
  });

  test('the presence roster is reachable while hosting, once the self-seed has started a session', () async {
    await startHosting();

    // The hosting panel reads OcptSyncManager.presenceRoster directly (Phase E) — this only
    // proves the self-seed actually started a session, which is what makes presence live at all.
    expect(spy.presenceRoster, isNotNull);
  });

  test('stopHosting ends the self-seeded sync session', () async {
    await startHosting();

    await manager.stopHosting();

    expect(spy.didStopSession, isTrue);
    expect(manager.state, const OcptRelayHostStopped());
  });

  test('moves from stopped to starting to online while starting hosting', () async {
    final emitted = <OcptRelayHostState>[];
    final subscription = manager.stateStream.listen(emitted.add);

    expect(manager.state, const OcptRelayHostStopped());

    await startHosting();
    // The broadcast controller delivers events asynchronously, one microtask after add(): drain
    // the queue so every state startHosting already set has actually reached this listener.
    await pumpEventQueue();

    // startHosting stops any previous host first (harmless here, since nothing was hosting yet),
    // so the exact sequence carries a leading OcptRelayHostStopped before the starting/online pair
    // this test actually cares about.
    expect(emitted, contains(const OcptRelayHostStarting()));
    expect(emitted.last, isA<OcptRelayHostOnline>());
    expect(manager.state, isA<OcptRelayHostOnline>());
    expect(manager.hostedProjectId, isNotNull);

    await subscription.cancel();
  });

  test('advertises the LAN base URI built from the injected resolver and the bound port', () async {
    await startHosting();

    final state = manager.state;
    expect(state, isA<OcptRelayHostOnline>());
    final online = state as OcptRelayHostOnline;

    expect(online.lanBaseUri.scheme, 'http');
    expect(online.lanBaseUri.host, '192.168.1.42');
    expect(online.lanBaseUri.port, isNot(0));
  });

  test('creates the relay store file beside the project file', () async {
    await startHosting();

    final storePath = p.setExtension(projectPath, '.relay.sqlite');
    expect(File(storePath).existsSync(), isTrue);
  });

  test('mints the hosting enrolment secret once and reuses it across restarts', () async {
    await startHosting();
    final firstSecret = (manager.state as OcptRelayHostOnline).enrolmentSecret;
    final projectId = manager.hostedProjectId!;

    await manager.stopHosting();
    await startHosting();
    final secondSecret = (manager.state as OcptRelayHostOnline).enrolmentSecret;

    expect(secondSecret, firstSecret);
    expect(await secretsManager.loadHostingEnrolmentSecret(projectId), firstSecret);
  });

  test('throws a StateError when starting hosting on a mobile platform', () {
    final mobileManager = OcptRelayHostManager(
      secretsManager: secretsManager,
      syncManager: spy,
      platformManager: _StubPlatformManager(isMobile: true),
      bindAddress: InternetAddress.loopbackIPv4,
    );

    expect(
      () => mobileManager.startHosting(
        database: database,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        deviceId: 'device-1',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('reports a failed state when the LAN address resolver throws', () async {
    final failingManager = OcptRelayHostManager(
      secretsManager: secretsManager,
      syncManager: spy,
      platformManager: _StubPlatformManager(isMobile: false),
      bindAddress: InternetAddress.loopbackIPv4,
      lanAddressResolver: () async => throw Exception('no network available'),
    );

    await failingManager.startHosting(
      database: database,
      projectFilePath: projectPath,
      projectName: 'Les Vagues',
      appVersion: '0.1.0',
      deviceId: 'device-1',
    );

    expect(failingManager.state, isA<OcptRelayHostFailed>());

    await failingManager.stopHosting();
  });
}
