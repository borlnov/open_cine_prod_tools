// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_presence_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_project_pairing.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Backs the secure storage plugin with [store], so a pairing's token can be saved and read back.
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

/// A [PlatformManager] whose [isMobile] is stubbed.
class _StubPlatformManager extends PlatformManager {
  /// Whether this double stands for a mobile platform.
  @override
  final bool isMobile;

  /// Class constructor
  _StubPlatformManager({required this.isMobile});
}

/// A save-location service answering [path] without showing any native dialog.
class _FixedSaveLocationService extends OcptSaveLocationService {
  /// The path every save dialog is answered with.
  final String path;

  /// Class constructor
  _FixedSaveLocationService(this.path) : super(logger: const SilentLogger());

  /// Answer with the canned path.
  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async => path;
}

/// A sync session standing in for a running one: the bloc only checks that one exists.
class _FakeSyncSession extends Fake implements OcptSyncSession {}

/// A remote storage handed to [_FailingSyncManager.startSyncSession], which never uses it.
class _FakeRemoteStorage extends Fake implements OcptRemoteStorage {}

/// A sync manager holding a running session whose restart always fails.
class _FailingSyncManager extends OcptSyncManager {
  /// Whether [startSyncSession] was called.
  bool isStartCalled = false;

  /// Get a session that is not running.
  @override
  OcptSyncSession? get syncSession => _FakeSyncSession();

  /// Class constructor
  _FailingSyncManager({required super.pairingService})
    : super(
        changesetService: const OcptChangesetService(
          logger: SilentLogger(),
          mergeService: OcptMergeService(logger: SilentLogger()),
        ),
      );

  /// Open a storage that accepts everything and holds nothing.
  @override
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) => _FakeRemoteStorage();

  /// Do nothing: there is no session to stop.
  @override
  Future<void> stopSyncSession() async {}

  /// Record that a start was asked, then fail as an unreachable relay does.
  @override
  Future<void> startSyncSession({
    required String projectId,
    required OcptProjectDatabase database,
    required String deviceId,
    required String relayId,
    required OcptRemoteStorage storage,
    Duration pushInterval = ocptDefaultSyncPushInterval,
    Duration presenceHeartbeatInterval = ocptDefaultPresenceHeartbeatInterval,
    Duration presencePeerTimeout = ocptDefaultPresencePeerTimeout,
  }) async {
    isStartCalled = true;
    throw StateError('the relay is unreachable');
  }
}

/// Run the tests of the project settings bloc sync restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptPropertiesManager propertiesManager;
  late OcptPairingService pairingService;
  late Map<String, String> secureStore;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;

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

    pairingService = OcptPairingService(
      logger: const SilentLogger(),
      secretsManager: secretsManager,
    );
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    secureStore.clear();

    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_sync_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  test('a move still succeeds when the sync session cannot be restarted afterwards', () async {
    final project = (await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    )).value!;
    await pairingService.savePairing(
      database: project.fileDatabase,
      projectId: "project-abc",
      relayBaseUri: Uri.parse("https://relay.example.org/"),
      token: "token-1",
    );
    final movedPath = p.join(tempDir.path, "moved", "movie.ocpt");
    final syncManager = _FailingSyncManager(pairingService: pairingService);
    final bloc = OcptProjectSettingsBloc(
      projectsManager: projectsManager,
      exportManager: OcptExportManager(
        fileSelectorManager: const FileSelectorManager(),
        platformManager: _StubPlatformManager(isMobile: false),
        saveLocationService: _FixedSaveLocationService(movedPath),
      ),
      syncManager: syncManager,
      propertiesManager: propertiesManager,
    );
    addTearDown(bloc.close);

    bloc.add(const OcptProjectSettingsMoveRequestedEvent(fileTypeLabel: "Project"));
    final state = await bloc.stream
        .firstWhere((state) => state.projectFilePath == movedPath)
        .timeout(const Duration(seconds: 5));

    expect(state.moveError, isNull);
    expect(syncManager.isStartCalled, isTrue);
  });
}
