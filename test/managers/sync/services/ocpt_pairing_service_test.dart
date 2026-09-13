// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — see [_mockSecureStorage]'s own doc
/// comment.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Backs [_secureStorageChannel] with a plain in-memory [store] instead of a real platform, so
/// [OcptSecretsManager] can be exercised on the plain Dart VM `flutter test` runs on. Mirrors the
/// four calls `SecretsSingleton` actually makes: `read`, `write`, `delete` and `deleteAll` (the
/// two only the secrets manager's own reinstall-cleanup path can trigger).
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const projectId = 'project-1';
  const otherProjectId = 'project-2';
  final relayBaseUri = Uri.parse('https://relay.example.org/');

  late Map<String, String> secureStore;
  late OcptPairingService service;
  late OcptProjectDatabase database;

  setUpAll(() async {
    // OcptConfigManager and OcptPropertiesManager both log through appLogger(), which requires a
    // global manager instance to be set; merely accessing it creates the (otherwise unused)
    // singleton, exactly as `ocpt_properties_manager_test.dart` does.
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

    service = OcptPairingService(secretsManager: secretsManager);
  });

  setUp(() {
    database = OcptProjectDatabase.memory();
    secureStore.clear();
  });

  tearDown(() => database.close());

  test('a project with no pairing loads as null', () async {
    expect(await service.loadPairing(database: database, projectId: projectId), isNull);
  });

  test('savePairing round-trips the relay URL and the token', () async {
    await service.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: 'token-1',
    );

    final pairing = await service.loadPairing(database: database, projectId: projectId);

    expect(pairing, isNotNull);
    expect(pairing!.relayBaseUri, relayBaseUri);
    expect(pairing.token, 'token-1');
  });

  test('the token is never written to the sync_pairings row itself', () async {
    await service.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: 'super-secret-token',
    );

    final row = await (database.select(
      database.ocptSyncPairingsTable,
    )..where((table) => table.projectId.equals(projectId))).getSingle();

    expect(row.relayBaseUrl, relayBaseUri.toString());
    expect(secureStore.values, contains('super-secret-token'));
  });

  test('savePairing again for the same project replaces the previous pairing', () async {
    await service.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: 'token-1',
    );
    final replacementUri = Uri.parse('https://relay.example.org/replacement');
    await service.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: replacementUri,
      token: 'token-2',
    );

    final pairing = await service.loadPairing(database: database, projectId: projectId);

    expect(pairing!.relayBaseUri, replacementUri);
    expect(pairing.token, 'token-2');
    expect(
      await (database.select(database.ocptSyncPairingsTable)).get(),
      hasLength(1),
    );
  });

  test('two projects keep independent pairings', () async {
    await service.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: 'token-1',
    );
    await service.savePairing(
      database: database,
      projectId: otherProjectId,
      relayBaseUri: relayBaseUri,
      token: 'token-2',
    );

    expect((await service.loadPairing(database: database, projectId: projectId))!.token, 'token-1');
    expect(
      (await service.loadPairing(database: database, projectId: otherProjectId))!.token,
      'token-2',
    );
  });

  test('clearPairing removes both the row and the token', () async {
    await service.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: 'token-1',
    );

    await service.clearPairing(database: database, projectId: projectId);

    expect(await service.loadPairing(database: database, projectId: projectId), isNull);
    expect(
      await (database.select(database.ocptSyncPairingsTable)).get(),
      isEmpty,
    );
    expect(secureStore, isEmpty);
  });

  test(
    'a sync_pairings row whose token went missing from secure storage loads as unpaired',
    () async {
      await service.savePairing(
        database: database,
        projectId: projectId,
        relayBaseUri: relayBaseUri,
        token: 'token-1',
      );
      // Simulates the token having been cleared from secure storage independently of the row
      // (a reinstall, the user clearing it) rather than through clearPairing.
      secureStore.clear();

      expect(await service.loadPairing(database: database, projectId: projectId), isNull);
    },
  );

  test('clearPairing on an unpaired project is a harmless no-op', () async {
    await service.clearPairing(database: database, projectId: projectId);

    expect(await service.loadPairing(database: database, projectId: projectId), isNull);
  });
}
