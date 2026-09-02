// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
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
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_page.dart';
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
/// fixture, unused by these tests beyond satisfying [OcptSyncManager]'s own constructor.
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
/// a real relay connection over the network — `sharing_page_test.dart`'s own
/// `_FakeTransportSyncManager`. Its every other method (`loadPairedProjectId`, `presenceRoster`, …)
/// is the real, unpaired-project behaviour, which is all these gating tests need of it.
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

/// A fully inert [OcptRelayHostManager]: [state]/[stateStream] never move off
/// [OcptRelayHostStopped], and [startHosting]/[stopHosting]/[reconcileWithUpstream] are never
/// exercised by these gating tests — `hosting_bloc_test.dart`'s own `_FakeHostManager`, trimmed to
/// what a page-level gating test needs.
class _FakeHostManager extends OcptRelayHostManager {
  final _controller = StreamController<OcptRelayHostState>.broadcast();

  @override
  OcptRelayHostState get state => const OcptRelayHostStopped();

  @override
  Stream<OcptRelayHostState> get stateStream => _controller.stream;

  @override
  Future<void> startHosting({
    required OcptProjectDatabase database,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required String deviceId,
  }) async {}

  @override
  Future<void> stopHosting() async {}

  @override
  Future<OcptReconcileOutcome> reconcileWithUpstream(OcptRelayInvite invite) async =>
      const OcptReconcileFailed('not exercised by this test');

  Future<void> disposeStream() => _controller.close();
}

/// A [PlatformManager] whose [isDesktop] is stubbed, so [OcptSharingView]'s own gating can be
/// exercised on either branch without a real platform underneath it — mirrors
/// `ocpt_export_manager_test.dart`'s own `_StubPlatformManager`, stubbing `isDesktop` directly
/// rather than `isMobile`/`isLinux`/etc., since that is the one flag the gating actually reads.
class _StubPlatformManager extends PlatformManager {
  /// Class constructor
  _StubPlatformManager({required this.isDesktop});

  @override
  final bool isDesktop;
}

/// Wraps [child] with the app theme and the localization delegates so `Tr.of` lookups resolve,
/// exactly `sharing_page_test.dart`'s own `_wrapWithLocalization`.
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

    tempDir = await Directory.systemTemp.createTemp("ocpt_sharing_page_hosting_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en");
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "Les Vagues",
      filePath: p.join(tempDir.path, "les-vagues.ocpt"),
    );
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Pumps [OcptSharingView] over both blocs [OcptSharingPage] itself provides, with [platformManager]
  /// and [isReadOnly] injected straight into the view — the same seam `OcptSyncStatusIndicator`'s own
  /// test already uses for the very same "no `globalGetIt()` registration needed" reason.
  Future<void> pumpView(
    WidgetTester tester, {
    required PlatformManager platformManager,
    required bool isReadOnly,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final syncManager = _FakeTransportSyncManager(pairingService: pairingService);
    addTearDown(syncManager.stopSyncSession);
    final hostManager = _FakeHostManager();
    addTearDown(hostManager.disposeStream);

    final sharingBloc = OcptSharingBloc(
      projectsManager: projectsManager,
      syncManager: syncManager,
      propertiesManager: propertiesManager,
    );
    addTearDown(sharingBloc.close);
    final hostingBloc = OcptHostingBloc(
      hostManager: hostManager,
      syncManager: syncManager,
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
    );
    addTearDown(hostingBloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        MultiBlocProvider(
          providers: [
            BlocProvider<OcptSharingBloc>.value(value: sharingBloc),
            BlocProvider<OcptHostingBloc>.value(value: hostingBloc),
          ],
          child: OcptSharingView(platformManager: platformManager, isReadOnly: isReadOnly),
        ),
      ),
    );

    if (sharingBloc.state.isLoading) {
      await sharingBloc.stream.firstWhere((state) => !state.isLoading);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets("the segmented button appears on a desktop, writable project", (tester) async {
    await pumpView(
      tester,
      platformManager: _StubPlatformManager(isDesktop: true),
      isReadOnly: false,
    );

    expect(find.byWidgetPredicate((widget) => widget is SegmentedButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the segmented button is absent for a read-only preview", (tester) async {
    await pumpView(
      tester,
      platformManager: _StubPlatformManager(isDesktop: true),
      isReadOnly: true,
    );

    expect(find.byWidgetPredicate((widget) => widget is SegmentedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the segmented button is absent on a mobile platform", (tester) async {
    await pumpView(
      tester,
      platformManager: _StubPlatformManager(isDesktop: false),
      isReadOnly: false,
    );

    expect(find.byWidgetPredicate((widget) => widget is SegmentedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
