// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_page.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/widgets/ocpt_repointing_configure_view.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/widgets/ocpt_repointing_qr_view.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — `sharing_page_test.dart`'s own mock.
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

/// An in-memory [OcptRemoteStorage] carrying no network at all — `sharing_page_test.dart`'s own
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

/// An [OcptSyncManager] whose [openRelayRemoteStorage] hands back a fixed fake transport and whose
/// [repointProjectToRelay] only moves the pairing, skipping [OcptSyncManager.startSyncSession]
/// entirely — unlike `repointing_bloc_test.dart`'s own `_FakeTransportSyncManager`: a real session
/// runs a periodic `Timer` that `AutomatedTestWidgetsFlutterBinding` (every `testWidgets` in this
/// file) asserts nothing left pending at the end of a test, so this page's own tests — which never
/// assert anything about the live sync status the repointing page doesn't even show — have no
/// reason to start one at all, and every reason not to.
class _FakeTransportSyncManager extends OcptSyncManager {
  _FakeTransportSyncManager({required OcptPairingService pairingService})
    : _pairing = pairingService,
      super(pairingService: pairingService, changesetService: const OcptChangesetService());

  final OcptPairingService _pairing;

  @override
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) => _FakeRemoteStorage();

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
    final existing = await _pairing.loadPairing(database: database, projectId: projectId);
    final token = existing?.token ?? 'fake-project-token';

    await _pairing.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: token,
    );
  }
}

/// Wraps [child] with the app theme and the localization delegates — `sharing_page_test.dart`'s own
/// `_wrapWithLocalization`.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

void main() {
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

    pairingService = OcptPairingService(secretsManager: secretsManager);
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    secureStore.clear();

    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    managers.registerSingleton<OcptRouterManager>(OcptRouterManager());

    // `OcptRepointingConfigureView` reads this directly (not through the bloc) to gate the real
    // camera scanner off desktop — registered here as a plain desktop instance, exactly as
    // `joining_page_test.dart` does: never mobile.
    if (managers.isRegistered<PlatformManager>()) {
      await managers.unregister<PlatformManager>();
    }
    managers.registerSingleton<PlatformManager>(PlatformManager());

    tempDir = await Directory.systemTemp.createTemp("ocpt_repointing_page_test_");
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

  /// Pumps [OcptRepointingView] backed by an [OcptRepointingBloc] built over [manager], on a
  /// surface wide enough that neither state's own column overflows the default 800px test surface
  /// (`compact-breakpoint-vs-default-test-surface`).
  Future<void> pumpView(WidgetTester tester, _FakeTransportSyncManager manager) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = OcptRepointingBloc(
      projectsManager: projectsManager,
      syncManager: manager,
      propertiesManager: propertiesManager,
    );
    addTearDown(bloc.close);
    addTearDown(manager.stopSyncSession);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptRepointingBloc>.value(value: bloc, child: const OcptRepointingView()),
      ),
    );
    if (bloc.state.isLoading) {
      await bloc.stream.firstWhere((state) => !state.isLoading);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets("renders ① Configure without overflow", (tester) async {
    await pumpView(tester, _FakeTransportSyncManager(pairingService: pairingService));

    expect(find.byType(OcptRepointingConfigureView), findsOneWidget);
    expect(find.byType(OcptRepointingQrView), findsNothing);
    expect(tester.takeException(), isNull);

    final tr = Tr.of(tester.element(find.byType(OcptRepointingView)));
    expect(find.text(tr.repointingPageTitle("My Movie")), findsOneWidget);
    expect(find.text(tr.repointingStepConfigureChip), findsOneWidget);
    expect(find.text(tr.repointingSubmitAction), findsOneWidget);
  });

  testWidgets(
    "submitting ① Configure with an existing pairing moves to ② QR code without overflow",
    (tester) async {
      final manager = _FakeTransportSyncManager(pairingService: pairingService);
      await pairingService.savePairing(
        database: projectsManager.currentProject!.fileDatabase,
        projectId: "project-abc",
        relayBaseUri: Uri.parse("https://relay-prep.example.org/"),
        token: "fake-project-token",
      );
      addTearDown(manager.stopSyncSession);

      await pumpView(tester, manager);

      await tester.enterText(
        find.byType(TextField).first,
        "https://relay-onset.example.org/",
      );
      await tester.enterText(find.byType(TextField).last, "onset-enrolment-secret");

      final tr = Tr.of(tester.element(find.byType(OcptRepointingView)));
      await tester.tap(find.text(tr.repointingSubmitAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(OcptRepointingQrView), findsOneWidget);
      expect(find.byType(OcptRepointingConfigureView), findsNothing);
      expect(tester.takeException(), isNull);

      expect(find.text(tr.repointingStepQrChip), findsOneWidget);
      expect(find.text("https://relay-onset.example.org/"), findsOneWidget);
      expect(find.text(tr.repointingCopyEnrolmentAction), findsOneWidget);
      expect(find.text(tr.repointingDoneAction), findsOneWidget);
    },
  );
}
