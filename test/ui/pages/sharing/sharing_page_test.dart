// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
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
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_page.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_configure_view.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/widgets/ocpt_sharing_invite_view.dart';
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
/// [OcptSyncManager.pairProjectToRelay] needs of a transport for this page's own fixtures.
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
/// a real relay connection over the network — `sharing_bloc_test.dart`'s own
/// `_FakeTransportSyncManager`.
class _FakeTransportSyncManager extends OcptSyncManager {
  _FakeTransportSyncManager({required OcptPairingService super.pairingService})
    : super(changesetService: const OcptChangesetService());

  @override
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) => _FakeRemoteStorage();
}

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve in
/// tests, exactly as `home_page_test.dart` already does.
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

  final relayBaseUri = Uri.parse('https://relay.example.org/');

  setUpAll(() async {
    // OcptGlobalManager, OcptConfigManager, OcptPropertiesManager and OcptProjectsManager all log
    // through appLogger(), which requires a global manager instance to be set; merely accessing it
    // creates the (otherwise unused) singleton, exactly as `sharing_bloc_test.dart` does.
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

    tempDir = await Directory.systemTemp.createTemp("ocpt_sharing_page_test_");
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

  /// Pumps [OcptSharingView] backed by an [OcptSharingBloc] built over [manager], on a surface wide
  /// enough that neither state's own ~560/620px column overflows the default 800px test surface
  /// (`compact-breakpoint-vs-default-test-surface`).
  Future<void> pumpView(WidgetTester tester, _FakeTransportSyncManager manager) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = OcptSharingBloc(
      projectsManager: projectsManager,
      syncManager: manager,
      propertiesManager: propertiesManager,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptSharingBloc>.value(value: bloc, child: const OcptSharingView()),
      ),
    );
    // The bloc's own initial load is awaited directly, rather than through `pumpAndSettle()`
    // alone: while it is in flight (a paired project's own load reads the project token through a
    // mocked secure-storage platform channel, a real asynchronous hop) the page shows an
    // indeterminate `CircularProgressIndicator`, whose repeating animation keeps scheduling frames
    // forever and would make `pumpAndSettle()` spin until its own ten-minute timeout rather than
    // ever converge.
    if (bloc.state.isLoading) {
      await bloc.stream.firstWhere((state) => !state.isLoading);
    }
    // Bounded pumps rather than `pumpAndSettle()`: the ② Invite state runs a live sync session
    // (its own periodic push timer) whose ticking keeps scheduling frames, so `pumpAndSettle()`
    // would spin to its ten-minute timeout instead of converging. Two frames are enough to lay the
    // loaded state out for the assertions below.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets("renders ① Configure without overflow for an unpaired project", (tester) async {
    await pumpView(tester, _FakeTransportSyncManager(pairingService: pairingService));

    expect(find.byType(OcptSharingConfigureView), findsOneWidget);
    expect(find.byType(OcptSharingInviteView), findsNothing);
    expect(tester.takeException(), isNull);

    final tr = Tr.of(tester.element(find.byType(OcptSharingView)));
    expect(find.text(tr.sharingPageTitle("My Movie")), findsOneWidget);
    expect(find.text(tr.sharingStepConfigureChip), findsOneWidget);
    expect(find.text(tr.sharingStatusUnpairedChip), findsOneWidget);
    expect(find.text(tr.sharingPairAction), findsOneWidget);
  });

  testWidgets("renders ② Invite without overflow for a paired project", (tester) async {
    final manager = _FakeTransportSyncManager(pairingService: pairingService);
    // Pairing starts an ongoing sync session with its own periodic push timer: left running past
    // the test's own end, it keeps the test binary alive waiting for a `Timer` that never fires
    // again against a torn-down fixture, so it is stopped explicitly rather than left to `manager`
    // simply going out of scope.
    addTearDown(manager.stopSyncSession);
    // `pairProjectToRelay` packages the project into a snapshot — real `dart:io` file I/O that
    // never completes inside `testWidgets`' fake-async zone, so it is run through `runAsync`, which
    // is the one place real asynchronous work is allowed to progress in a widget test.
    await tester.runAsync(
      () => manager.pairProjectToRelay(
        database: projectsManager.currentProject!.fileDatabase,
        projectId: "project-abc",
        projectFilePath: projectsManager.currentProject!.path,
        projectName: "My Movie",
        appVersion: "0.1.0",
        relayBaseUri: relayBaseUri,
        enrolmentSecret: "enrolment-secret",
        deviceId: "device-1",
      ),
    );

    await pumpView(tester, manager);

    expect(find.byType(OcptSharingInviteView), findsOneWidget);
    expect(find.byType(OcptSharingConfigureView), findsNothing);
    expect(tester.takeException(), isNull);

    final tr = Tr.of(tester.element(find.byType(OcptSharingView)));
    expect(find.text(tr.sharingPageTitle("My Movie")), findsOneWidget);
    expect(find.text(tr.sharingStepInviteChip), findsOneWidget);
    // ② Invite shows the synced state in two places by design (the top-bar status chip and the
    // footer status line), so this label appears more than once.
    expect(find.text(tr.sharingStatusSyncedChip), findsWidgets);
    expect(find.text(relayBaseUri.toString()), findsOneWidget);
    expect(find.text(tr.sharingSaveQrAction), findsOneWidget);
    expect(find.text(tr.sharingCopyInviteLinkAction), findsOneWidget);
    expect(find.text(tr.sharingUnshareAction), findsOneWidget);
  });
}
