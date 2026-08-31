// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The method channel `flutter_secure_storage` talks over — mirrors `sharing_bloc_test.dart`'s own
/// mock, which this file's [OcptPairingService] needs the exact same wiring for (never actually
/// exercised: every fake [OcptSyncManager] below stubs `joinFromRelay` before it would touch it).
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

/// An [OcptSyncManager] whose [joinFromRelay] is entirely stubbed: it never touches the filesystem
/// or the network, returning [joinResultPath] (a project already sitting on disk, created directly
/// through [OcptProjectsManager.createProject] rather than through the real snapshot machinery) —
/// exactly the "fake manager whose join returns a fixed path" this bloc's own tests are meant to
/// use, since the real [OcptSyncManager.joinFromRelay]'s file I/O is covered by
/// `ocpt_sync_manager_snapshot_test.dart` and is the one flaky step under the full suite's parallel
/// load.
///
/// [whileJoining] optionally runs (and is awaited) before returning, standing in for however long a
/// real relay round-trip and snapshot unpacking would take — what lets a test observe
/// `OcptJoiningState.isJoining` while a join is still in flight.
class _FakeSyncManager extends OcptSyncManager {
  _FakeSyncManager({
    required OcptPairingService pairingService,
    required this.joinResultPath,
    this.whileJoining,
  }) : super(pairingService: pairingService, changesetService: const OcptChangesetService());

  /// The path [joinFromRelay] always returns.
  final String joinResultPath;

  /// Optionally awaited before [joinFromRelay] returns.
  final Future<void> Function()? whileJoining;

  /// How many times [joinFromRelay] was actually called — zero means a submission never got past
  /// this bloc's own validation.
  int joinCallCount = 0;

  @override
  Future<String> joinFromRelay({
    required OcptRemoteStorage storage,
    required String parentDirectoryPath,
    required OcptPairingService pairingService,
    required Uri relayBaseUri,
    required String token,
  }) async {
    joinCallCount++;
    await whileJoining?.call();
    return joinResultPath;
  }
}

/// A file saver manager whose [saveFileFromBytes] is stubbed, to exercise the bloc's own desktop
/// destination-picking step without any real save dialog — `home_bloc_test.dart`'s own
/// `_FakeFileSaverManager`.
class _FakeFileSaverManager extends FileSaverManager {
  _FakeFileSaverManager({this.result});

  /// The path [saveFileFromBytes] returns, or null to simulate a cancelled save dialog.
  final String? result;

  /// How many times [saveFileFromBytes] was called.
  int callCount = 0;

  @override
  Future<String?> saveFileFromBytes({required String fileName, required Uint8List bytes}) async {
    callCount++;
    return result;
  }
}

/// A router manager whose [push] only records the route pushed — this bloc's own tests don't build
/// a real GoRouter for it to operate on, exactly `home_bloc_test.dart`'s own
/// `_RecordingRouterManager`.
class _RecordingRouterManager extends OcptRouterManager {
  /// The last route [push] was called with, or null if it never was.
  OcptRoute? pushedRoute;

  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushedRoute = route;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptPropertiesManager propertiesManager;
  late OcptPairingService pairingService;
  late Map<String, String> secureStore;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;
  late String joinedProjectPath;

  const relayBaseUri = 'https://relay.example.org/';

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

    tempDir = await Directory.systemTemp.createTemp("ocpt_joining_bloc_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager, appLanguageCode: () => "en");
    await projectsManager.initLifeCycle();

    // Stands in for the project a relay would hand back: written directly through the real
    // create path (never through the relay/snapshot machinery, which `_FakeSyncManager` stubs
    // out entirely), then closed so the bloc's own `OcptProjectsManager.openProject` call is the
    // one that actually opens it, exactly as it would the real joined file.
    joinedProjectPath = p.join(tempDir.path, "joined-shared-movie.ocpt");
    await projectsManager.createProject(name: "Shared Movie", filePath: joinedProjectPath);
    await projectsManager.closeCurrentProject();
  });

  tearDown(() async {
    if (projectsManager.currentProject != null) {
      await projectsManager.closeCurrentProject();
    }
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds an [OcptJoiningBloc] over [manager], recording every route [routerManager] is pushed
  /// to, and picking [fileSaverManager]'s own answer as the desktop destination.
  OcptJoiningBloc buildBloc({
    required _FakeSyncManager manager,
    required _RecordingRouterManager routerManager,
    FileSaverManager? fileSaverManager,
  }) {
    final bloc = OcptJoiningBloc(
      syncManager: manager,
      projectsManager: projectsManager,
      routerManager: routerManager,
      fileSaverManager: fileSaverManager ?? _FakeFileSaverManager(result: p.join(tempDir.path, "picked", "placeholder.ocpt")),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// A well-formed invite link, exactly what "Copy the invite link" on the Partager screen would
  /// hand over and a manual submission pastes back — built through [OcptRelayInvite.toInviteString]
  /// rather than typed out, so it stays valid if the encoding ever changes.
  final validInviteLink = OcptRelayInvite(
    relayBaseUri: Uri.parse(relayBaseUri),
    projectId: "project-abc",
    token: "token-1",
  ).toInviteString();

  test("a valid manual entry joins the project and pushes the workspace", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    bloc.add(OcptJoiningManualSubmittedEvent(inviteLinkText: validInviteLink));
    await pumpEventQueue();

    expect(manager.joinCallCount, 1);
    expect(bloc.state.isJoining, isFalse);
    expect(bloc.state.joinFailed, isFalse);
    expect(routerManager.pushedRoute, OcptRoute.workspace);
    expect(projectsManager.currentProject?.path, joinedProjectPath);
  });

  test("a valid scanned invite joins the project just like a manual submission", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    final invite = OcptRelayInvite(
      relayBaseUri: Uri.parse(relayBaseUri),
      projectId: "project-abc",
      token: "token-1",
    );
    bloc.add(OcptJoiningInviteScannedEvent(invite.toInviteString()));
    await pumpEventQueue();

    expect(manager.joinCallCount, 1);
    expect(bloc.state.joinFailed, isFalse);
    expect(routerManager.pushedRoute, OcptRoute.workspace);
  });

  test("a malformed manual entry surfaces an error without ever calling the relay", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    bloc.add(const OcptJoiningManualSubmittedEvent(inviteLinkText: "not an invite link at all"));
    await pumpEventQueue();

    expect(manager.joinCallCount, 0);
    expect(bloc.state.isJoining, isFalse);
    expect(bloc.state.joinFailed, isTrue);
    expect(routerManager.pushedRoute, isNull);
    expect(projectsManager.currentProject, isNull);
  });

  test("an empty manual field surfaces an error without ever calling the relay", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    bloc.add(const OcptJoiningManualSubmittedEvent(inviteLinkText: ""));
    await pumpEventQueue();

    expect(manager.joinCallCount, 0);
    expect(bloc.state.joinFailed, isTrue);
  });

  test("a bad scanned string surfaces an error without ever calling the relay", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    bloc.add(const OcptJoiningInviteScannedEvent("this is not a QR code this app understands"));
    await pumpEventQueue();

    expect(manager.joinCallCount, 0);
    expect(bloc.state.isJoining, isFalse);
    expect(bloc.state.joinFailed, isTrue);
    expect(routerManager.pushedRoute, isNull);
  });

  test("dismissing the error clears the flag", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    bloc.add(const OcptJoiningInviteScannedEvent("garbage"));
    await pumpEventQueue();
    expect(bloc.state.joinFailed, isTrue);

    bloc.add(const OcptJoiningErrorDismissedEvent());
    await pumpEventQueue();
    expect(bloc.state.joinFailed, isFalse);
  });

  test("the busy state is set for the whole time a join is in flight", () async {
    final joinGate = Completer<void>();
    final manager = _FakeSyncManager(
      pairingService: pairingService,
      joinResultPath: joinedProjectPath,
      whileJoining: () => joinGate.future,
    );
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager);

    bloc.add(OcptJoiningManualSubmittedEvent(inviteLinkText: validInviteLink));
    await pumpEventQueue();

    expect(bloc.state.isJoining, isTrue);
    expect(bloc.state.joinFailed, isFalse);
    expect(routerManager.pushedRoute, isNull);

    joinGate.complete();
    await pumpEventQueue();

    expect(bloc.state.isJoining, isFalse);
    expect(routerManager.pushedRoute, OcptRoute.workspace);
  });

  test("a cancelled desktop destination picker is a silent no-op", () async {
    final manager = _FakeSyncManager(pairingService: pairingService, joinResultPath: joinedProjectPath);
    final routerManager = _RecordingRouterManager();
    final fileSaverManager = _FakeFileSaverManager();
    final bloc = buildBloc(manager: manager, routerManager: routerManager, fileSaverManager: fileSaverManager);

    bloc.add(OcptJoiningManualSubmittedEvent(inviteLinkText: validInviteLink));
    await pumpEventQueue();

    expect(fileSaverManager.callCount, 1);
    expect(manager.joinCallCount, 0);
    expect(bloc.state.isJoining, isFalse);
    expect(bloc.state.joinFailed, isFalse);
    expect(routerManager.pushedRoute, isNull);
  });
}
