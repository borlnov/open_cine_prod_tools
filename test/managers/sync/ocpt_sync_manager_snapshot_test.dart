// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — mirrors
/// `ocpt_pairing_service_test.dart`'s own mock, which this file's [OcptPairingService] needs the
/// exact same wiring for.
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

/// An in-memory [OcptRemoteStorage] holding at most one uploaded snapshot — everything
/// `publishSnapshot`/`joinFromRelay` need of a transport, and nothing about a network.
class _FakeRemoteStorage implements OcptRemoteStorage {
  (OcptSnapshotDescriptor, Uint8List)? uploaded;

  final StreamController<void> _newWorkController = StreamController<void>.broadcast();

  @override
  Future<OcptSequenceNumber> append(OcptChangesetEnvelope envelope) async => OcptSequenceNumber.zero;

  @override
  Future<List<OcptStoredChangeset>> readSince(OcptSequenceNumber cursor) async => const [];

  @override
  Future<void> uploadSnapshot(OcptSnapshotDescriptor descriptor, Uint8List bytes) async {
    uploaded = (descriptor, bytes);
  }

  @override
  Future<(OcptSnapshotDescriptor, Uint8List)?> fetchLatestSnapshot() async => uploaded;

  @override
  Stream<void> get newWorkStream => _newWorkController.stream;

  @override
  void sendPresence(String opaquePayload) {}

  @override
  Stream<String> get presenceStream => const Stream.empty();

  Future<void> dispose() => _newWorkController.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workspace;
  late String projectPath;
  late OcptPairingService pairingService;
  late Map<String, String> secureStore;

  setUpAll(() async {
    // OcptGlobalManager, OcptConfigManager and OcptPropertiesManager all log through appLogger(),
    // which requires a global manager instance to be set; merely accessing it creates the
    // (otherwise unused) singleton, exactly as `ocpt_pairing_service_test.dart` does.
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

    pairingService = OcptPairingService(secretsManager: secretsManager);
  });

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ocpt_sync_manager_snapshot_test_');
    projectPath = p.join(workspace.path, 'project.ocpt');
    secureStore.clear();

    final database = OcptProjectDatabase(File(projectPath));
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
    // The sharer's own project already carries its own pairing row by the time it can publish a
    // snapshot at all — see `OcptSyncManager.joinFromRelay`'s own doc comment for why that row is
    // what a joiner reads its project id back off. `savePairing` is not used here on purpose: it
    // would also stash a token in secure storage under this same test's shared `secureStore`,
    // which would make "the joiner never had one" a fiction.
    await database
        .into(database.ocptSyncPairingsTable)
        .insert(
          OcptSyncPairingsTableCompanion.insert(
            projectId: 'project-abc',
            relayBaseUrl: 'https://relay.example.org/',
          ),
        );
    await database.close();
  });

  tearDown(() async {
    workspace.deleteSync(recursive: true);
  });

  group('publishSnapshot', () {
    test('uploads a snapshot built from the project file', () async {
      final manager = OcptSyncManager(changesetService: const OcptChangesetService());
      final storage = _FakeRemoteStorage();
      addTearDown(storage.dispose);

      await manager.publishSnapshot(
        storage: storage,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        sequenceUpTo: const OcptSequenceNumber(7),
      );

      expect(storage.uploaded, isNotNull);
      final (descriptor, bytes) = storage.uploaded!;
      expect(descriptor.sequenceUpTo, const OcptSequenceNumber(7));
      expect(descriptor.byteLength, bytes.length);
    });
  });

  group('joinFromRelay', () {
    test('throws when the relay holds no snapshot yet', () async {
      final manager = OcptSyncManager(changesetService: const OcptChangesetService());
      final storage = _FakeRemoteStorage();
      addTearDown(storage.dispose);
      final parentDirectory = Directory(p.join(workspace.path, 'joined'))..createSync();

      await expectLater(
        () => manager.joinFromRelay(
          storage: storage,
          parentDirectoryPath: parentDirectory.path,
          pairingService: pairingService,
          relayBaseUri: Uri.parse('https://relay.example.org/'),
          token: 'token-1',
        ),
        throwsStateError,
      );
    });

    test('materialises the shared project and saves its pairing, with no network', () async {
      final manager = OcptSyncManager(changesetService: const OcptChangesetService());
      final storage = _FakeRemoteStorage();
      addTearDown(storage.dispose);
      final relayBaseUri = Uri.parse('https://relay.example.org/');

      await manager.publishSnapshot(
        storage: storage,
        projectFilePath: projectPath,
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        sequenceUpTo: const OcptSequenceNumber(1),
      );

      final parentDirectory = Directory(p.join(workspace.path, 'joined'))..createSync();
      final joinedProjectPath = await manager.joinFromRelay(
        storage: storage,
        parentDirectoryPath: parentDirectory.path,
        pairingService: pairingService,
        relayBaseUri: relayBaseUri,
        token: 'token-1',
      );

      expect(File(joinedProjectPath).existsSync(), isTrue);
      expect(joinedProjectPath, isNot(projectPath));

      final joinedDatabase = OcptProjectDatabase(File(joinedProjectPath));
      addTearDown(joinedDatabase.close);

      final info = await joinedDatabase.select(joinedDatabase.ocptProjectInfoTable).getSingle();
      expect(info.name, 'Les Vagues');
      final screenplay = await joinedDatabase.select(joinedDatabase.ocptScreenplaysTable).getSingle();
      expect(screenplay.fountainText, 'INT. HOUSE - DAY\n\nA quiet morning.');

      final pairing = await pairingService.loadPairing(
        database: joinedDatabase,
        projectId: 'project-abc',
      );
      expect(pairing, isNotNull);
      expect(pairing!.relayBaseUri, relayBaseUri);
      expect(pairing.token, 'token-1');
    });
  });
}
