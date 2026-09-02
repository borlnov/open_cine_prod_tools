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
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const projectId = 'project-abc';

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
  late OcptRelayHostManager manager;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ocpt_relay_host_manager_test_');
    projectPath = p.join(workspace.path, 'project.ocpt');
    secureStore.clear();

    manager = OcptRelayHostManager(
      secretsManager: secretsManager,
      platformManager: _StubPlatformManager(isMobile: false),
      bindAddress: InternetAddress.loopbackIPv4,
      lanAddressResolver: () async => InternetAddress('192.168.1.42'),
    );
  });

  tearDown(() async {
    await manager.stopHosting();
    workspace.deleteSync(recursive: true);
  });

  test('moves from stopped to starting to online while starting hosting', () async {
    final emitted = <OcptRelayHostState>[];
    final subscription = manager.stateStream.listen(emitted.add);

    expect(manager.state, const OcptRelayHostStopped());

    await manager.startHosting(projectId: projectId, projectFilePath: projectPath);
    // The broadcast controller delivers events asynchronously, one microtask after add(): drain
    // the queue so every state startHosting already set has actually reached this listener.
    await pumpEventQueue();

    // startHosting stops any previous host first (harmless here, since nothing was hosting yet),
    // so the exact sequence carries a leading OcptRelayHostStopped before the starting/online pair
    // this test actually cares about.
    expect(emitted, contains(const OcptRelayHostStarting()));
    expect(emitted.last, isA<OcptRelayHostOnline>());
    expect(manager.state, isA<OcptRelayHostOnline>());
    expect(manager.hostedProjectId, projectId);

    await subscription.cancel();
  });

  test('advertises the LAN base URI built from the injected resolver and the bound port', () async {
    await manager.startHosting(projectId: projectId, projectFilePath: projectPath);

    final state = manager.state;
    expect(state, isA<OcptRelayHostOnline>());
    final online = state as OcptRelayHostOnline;

    expect(online.lanBaseUri.scheme, 'http');
    expect(online.lanBaseUri.host, '192.168.1.42');
    expect(online.lanBaseUri.port, isNot(0));
  });

  test('stopHosting returns the state to stopped', () async {
    await manager.startHosting(projectId: projectId, projectFilePath: projectPath);
    expect(manager.state, isA<OcptRelayHostOnline>());

    await manager.stopHosting();

    expect(manager.state, const OcptRelayHostStopped());
    expect(manager.hostedProjectId, isNull);
  });

  test('creates the relay store file beside the project file', () async {
    await manager.startHosting(projectId: projectId, projectFilePath: projectPath);

    final storePath = p.setExtension(projectPath, '.relay.sqlite');
    expect(File(storePath).existsSync(), isTrue);
  });

  test('mints the hosting enrolment secret once and reuses it across restarts', () async {
    await manager.startHosting(projectId: projectId, projectFilePath: projectPath);
    final firstSecret = (manager.state as OcptRelayHostOnline).enrolmentSecret;

    await manager.stopHosting();
    await manager.startHosting(projectId: projectId, projectFilePath: projectPath);
    final secondSecret = (manager.state as OcptRelayHostOnline).enrolmentSecret;

    expect(secondSecret, firstSecret);
    expect(await secretsManager.loadHostingEnrolmentSecret(projectId), firstSecret);
  });

  test('throws a StateError when starting hosting on a mobile platform', () {
    final mobileManager = OcptRelayHostManager(
      secretsManager: secretsManager,
      platformManager: _StubPlatformManager(isMobile: true),
      bindAddress: InternetAddress.loopbackIPv4,
    );

    expect(
      () => mobileManager.startHosting(projectId: projectId, projectFilePath: projectPath),
      throwsA(isA<StateError>()),
    );
  });

  test('reports a failed state when the LAN address resolver throws', () async {
    final failingManager = OcptRelayHostManager(
      secretsManager: secretsManager,
      platformManager: _StubPlatformManager(isMobile: false),
      bindAddress: InternetAddress.loopbackIPv4,
      lanAddressResolver: () async => throw Exception('no network available'),
    );

    await failingManager.startHosting(projectId: projectId, projectFilePath: projectPath);

    expect(failingManager.state, isA<OcptRelayHostFailed>());

    await failingManager.stopHosting();
  });
}
