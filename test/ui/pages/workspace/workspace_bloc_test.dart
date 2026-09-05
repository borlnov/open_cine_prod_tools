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
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_presence_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_state.dart';
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

/// An in-memory [OcptRemoteStorage] carrying no network at all.
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

/// An [OcptSyncManager] recording whether/how [startSyncSession] was called, instead of actually
/// running one: the real [OcptSyncSession.start] would touch the fake transport's own
/// `newWorkStream`/timers, which this file's own tests about the lifecycle hook — not the session
/// itself — have no reason to drive. `ocpt_sync_manager_pairing_test.dart` and
/// `ocpt_sync_manager_snapshot_test.dart` already cover the session's real behaviour.
class _RecordingSyncManager extends OcptSyncManager {
  _RecordingSyncManager({required OcptPairingService pairingService})
    : super(pairingService: pairingService, changesetService: const OcptChangesetService());

  bool startSyncSessionCalled = false;
  bool stopSyncSessionCalled = false;
  String? startedProjectId;

  @override
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) => _FakeRemoteStorage();

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
    startSyncSessionCalled = true;
    startedProjectId = projectId;
  }

  @override
  Future<void> stopSyncSession() async {
    stopSyncSessionCalled = true;
  }
}

/// An [OcptRelayHostManager] recording the workspace's own auto-start-on-open and stop-on-close
/// hosting calls, and reporting whichever host state a test sets, without ever binding a real
/// socket: the real `maybeAutoStartHosting`/`stopHosting` are covered by
/// `ocpt_relay_host_manager_test.dart` — this file's tests are about the workspace's own wiring to
/// them, not their behaviour.
class _RecordingHostManager extends OcptRelayHostManager {
  _RecordingHostManager({required this.stateToReport, this.stateAfterAutoStart});

  OcptRelayHostState stateToReport;

  /// The state [maybeAutoStartHosting] transitions [state] to, modelling a fresh host start coming
  /// up (`stopped` before, `online` after); null leaves [state] unchanged, modelling a project
  /// reopened while its relay was already up (`online` throughout).
  final OcptRelayHostState? stateAfterAutoStart;

  bool maybeAutoStartCalled = false;
  bool stopHostingCalled = false;

  @override
  OcptRelayHostState get state => stateToReport;

  @override
  Future<void> maybeAutoStartHosting({
    required OcptProjectDatabase database,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required String deviceId,
  }) async {
    maybeAutoStartCalled = true;
    if (stateAfterAutoStart != null) {
      stateToReport = stateAfterAutoStart!;
    }
  }

  @override
  Future<void> stopHosting() async {
    stopHostingCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late OcptPairingService pairingService;
  late Map<String, String> secureStore;
  late Directory tempDir;

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

    tempDir = await Directory.systemTemp.createTemp("ocpt_workspace_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds a bloc wired to the test properties manager and, unless the test needs no open
  /// project, the test project manager (already holding an open project by [setUp]).
  OcptWorkspaceBloc buildBloc({
    OcptProjectsManager? overrideProjectsManager,
    OcptSyncManager? syncManager,
    OcptRelayHostManager? hostManager,
  }) => OcptWorkspaceBloc(
    propertiesManager: propertiesManager,
    projectsManager: overrideProjectsManager ?? projectsManager,
    syncManager: syncManager,
    hostManager: hostManager,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptWorkspaceState> waitForState(
    OcptWorkspaceBloc bloc,
    bool Function(OcptWorkspaceState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test('always starts on the screenplay mode, freshly loaded', () async {
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptWorkspaceMode.screenplay);
    await bloc.close();
  });

  test(
    'a fresh workspace bloc starts on the screenplay mode even after an earlier one switched '
    'away from it — switching project resets the mode, nothing restores it',
    () async {
      final firstBloc = buildBloc();
      await waitForState(firstBloc, (state) => !state.isLoading);
      firstBloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.budget));
      await waitForState(firstBloc, (state) => state.mode == OcptWorkspaceMode.budget);
      await firstBloc.close();

      final secondBloc = buildBloc();
      final state = await waitForState(secondBloc, (state) => !state.isLoading);

      expect(state.mode, OcptWorkspaceMode.screenplay);
      await secondBloc.close();
    },
  );

  test('selecting a mode updates the state without persisting it anywhere', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.schedule));
    final state = await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.schedule);

    expect(state.mode, OcptWorkspaceMode.schedule);
    await bloc.close();
  });

  test('selecting a mode carries the reveal request it was given', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(
          tab: OcptResourcesTab.elements,
          recordId: "element-1",
        ),
      ),
    );
    final state = await waitForState(bloc, (state) => state.revealRequest != null);

    expect(state.mode, OcptWorkspaceMode.resources);
    expect(
      state.revealRequest,
      const OcptResourcesRevealRequest(tab: OcptResourcesTab.elements, recordId: "element-1"),
    );
    await bloc.close();
  });

  test('consuming the reveal request clears it without touching the mode', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: "role-1"),
      ),
    );
    await waitForState(bloc, (state) => state.revealRequest != null);

    bloc.add(const OcptWorkspaceRevealRequestConsumedEvent());
    final state = await waitForState(bloc, (state) => state.revealRequest == null);

    expect(state.mode, OcptWorkspaceMode.resources);
    await bloc.close();
  });

  test('a plain mode switch clears a reveal request an earlier one left behind', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptWorkspaceModeSelectedEvent(
        mode: OcptWorkspaceMode.resources,
        revealRequest: OcptResourcesRevealRequest(tab: OcptResourcesTab.roles, recordId: "role-1"),
      ),
    );
    await waitForState(bloc, (state) => state.revealRequest != null);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.screenplay));
    final state = await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.screenplay);

    expect(state.revealRequest, isNull);
    await bloc.close();
  });

  test('loads the single episode a project starts with, landing the selection on it', () async {
    final bloc = buildBloc();

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.episodes, hasLength(1));
    expect(state.selectedEpisodeId, state.episodes.single.id);
    await bloc.close();
  });

  test('loads every episode in their sortKey order, still landing on the first', () async {
    final project = projectsManager.currentProject!;
    final firstEpisodeId = project.primaryScreenplayId;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    );
    expect(secondEpisodeId, isNotNull);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.episodes.map((episode) => episode.id).toList(), [
      firstEpisodeId,
      secondEpisodeId,
    ]);
    expect(state.selectedEpisodeId, firstEpisodeId);
    await bloc.close();
  });

  test('selecting an episode changes nothing else', () async {
    final project = projectsManager.currentProject!;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    );
    expect(secondEpisodeId, isNotNull);

    final bloc = buildBloc();
    final loaded = await waitForState(bloc, (state) => !state.isLoading);
    expect(loaded.mode, OcptWorkspaceMode.screenplay);

    bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
    final state = await waitForState(
      bloc,
      (state) => state.selectedEpisodeId == secondEpisodeId,
    );

    expect(state.selectedEpisodeId, secondEpisodeId);
    expect(state.mode, OcptWorkspaceMode.screenplay);
    expect(state.episodes, hasLength(2));
    await bloc.close();
  });

  test('selecting an episode leaves whichever mode was already active untouched', () async {
    final project = projectsManager.currentProject!;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    );
    expect(secondEpisodeId, isNotNull);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptWorkspaceModeSelectedEvent(mode: OcptWorkspaceMode.budget));
    await waitForState(bloc, (state) => state.mode == OcptWorkspaceMode.budget);

    bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
    final state = await waitForState(bloc, (state) => state.selectedEpisodeId == secondEpisodeId);

    expect(state.selectedEpisodeId, secondEpisodeId);
    expect(state.mode, OcptWorkspaceMode.budget);
    await bloc.close();
  });

  test(
    'a currentProjectStream reload keeps the selection when it still names a live episode',
    () async {
      final project = projectsManager.currentProject!;
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
        title: "Episode two",
      );
      expect(secondEpisodeId, isNotNull);

      final version = await projectsManager.createProjectVersion(
        name: "Both episodes",
        note: "",
      );
      expect(version, isNotNull);

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      expect(loaded.selectedEpisodeId, project.primaryScreenplayId);

      bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
      await waitForState(bloc, (state) => state.selectedEpisodeId == secondEpisodeId);

      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      final state = await waitForState(
        bloc,
        (state) => state.episodes.length == 2 && state.selectedEpisodeId == secondEpisodeId,
      );

      expect(state.selectedEpisodeId, secondEpisodeId);
      expect(state.episodes.map((episode) => episode.id).toList(), contains(secondEpisodeId));
      await bloc.close();
    },
  );

  test(
    'a currentProjectStream reload falls back to the first episode when the selection no longer '
    'names one',
    () async {
      final project = projectsManager.currentProject!;
      final firstEpisodeId = project.primaryScreenplayId;

      final version = await projectsManager.createProjectVersion(
        name: "One episode only",
        note: "",
      );
      expect(version, isNotNull);

      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
        title: "Episode two",
      );
      expect(secondEpisodeId, isNotNull);

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!));
      await waitForState(bloc, (state) => state.selectedEpisodeId == secondEpisodeId);

      final previewResult = await projectsManager.previewVersion(version!.id);
      expect(previewResult.status.isSuccess, isTrue);

      final state = await waitForState(
        bloc,
        (state) => state.episodes.length == 1 && state.selectedEpisodeId == firstEpisodeId,
      );

      expect(state.selectedEpisodeId, firstEpisodeId);
      expect(state.episodes.map((episode) => episode.id).toList(), [firstEpisodeId]);
      await bloc.close();
    },
  );

  test(
    'a paired project starts its sync session once the workspace opens',
    () async {
      final project = projectsManager.currentProject!;
      await pairingService.savePairing(
        database: project.fileDatabase,
        projectId: "project-abc",
        relayBaseUri: Uri.parse("https://relay.example.org/"),
        token: "token-1",
      );

      final syncManager = _RecordingSyncManager(pairingService: pairingService);
      final bloc = buildBloc(syncManager: syncManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await pumpEventQueue();

      expect(syncManager.startSyncSessionCalled, isTrue);
      expect(syncManager.startedProjectId, "project-abc");
      await bloc.close();
    },
  );

  test(
    'an unpaired project starts no sync session at all',
    () async {
      final syncManager = _RecordingSyncManager(pairingService: pairingService);
      final bloc = buildBloc(syncManager: syncManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await pumpEventQueue();

      expect(syncManager.startSyncSessionCalled, isFalse);
      await bloc.close();
    },
  );

  test(
    'a project re-hosted on launch comes up hosting and skips the ordinary session start',
    () async {
      final project = projectsManager.currentProject!;
      await pairingService.savePairing(
        database: project.fileDatabase,
        projectId: "project-abc",
        relayBaseUri: Uri.parse("https://relay.example.org/"),
        token: "token-1",
      );

      final syncManager = _RecordingSyncManager(pairingService: pairingService);
      // A fresh host start: stopped on entry, online after its self-seed, which starts the session
      // itself — so the workspace must not start a second one.
      final hostManager = _RecordingHostManager(
        stateToReport: const OcptRelayHostStopped(),
        stateAfterAutoStart: OcptRelayHostOnline(
          lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
          enrolmentSecret: "secret",
        ),
      );
      final bloc = buildBloc(syncManager: syncManager, hostManager: hostManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await pumpEventQueue();

      expect(hostManager.maybeAutoStartCalled, isTrue);
      expect(syncManager.startSyncSessionCalled, isFalse);
      await bloc.close();
    },
  );

  test(
    'reopening an already-hosted project starts a fresh paired session against the local relay',
    () async {
      // The relay stayed up across the trip home while the session was stopped with the closing
      // database. Hosting is already online on entry (no self-seed), so the workspace has to seed a
      // new session against the local relay the project is still paired to.
      final project = projectsManager.currentProject!;
      await pairingService.savePairing(
        database: project.fileDatabase,
        projectId: "project-abc",
        relayBaseUri: Uri.parse("http://192.168.1.42:47600/"),
        token: "token-1",
      );

      final syncManager = _RecordingSyncManager(pairingService: pairingService);
      final hostManager = _RecordingHostManager(
        stateToReport: OcptRelayHostOnline(
          lanBaseUri: Uri.parse("http://192.168.1.42:47600"),
          enrolmentSecret: "secret",
        ),
      );
      final bloc = buildBloc(syncManager: syncManager, hostManager: hostManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await pumpEventQueue();

      expect(syncManager.startSyncSessionCalled, isTrue);
      expect(syncManager.startedProjectId, "project-abc");
      await bloc.close();
    },
  );

  test(
    'a project that does not re-host still starts its ordinary paired session',
    () async {
      final project = projectsManager.currentProject!;
      await pairingService.savePairing(
        database: project.fileDatabase,
        projectId: "project-abc",
        relayBaseUri: Uri.parse("https://relay.example.org/"),
        token: "token-1",
      );

      final syncManager = _RecordingSyncManager(pairingService: pairingService);
      final hostManager = _RecordingHostManager(stateToReport: const OcptRelayHostStopped());
      final bloc = buildBloc(syncManager: syncManager, hostManager: hostManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await pumpEventQueue();

      expect(hostManager.maybeAutoStartCalled, isTrue);
      expect(syncManager.startSyncSessionCalled, isTrue);
      await bloc.close();
    },
  );

  test(
    'closing the workspace does not stop hosting (a navigation must not rebind the relay)',
    () async {
      final hostManager = _RecordingHostManager(
        stateToReport: OcptRelayHostOnline(
          lanBaseUri: Uri.parse('http://192.168.1.42:47600'),
          enrolmentSecret: 'secret',
        ),
      );
      final bloc = buildBloc(hostManager: hostManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await bloc.close();

      expect(hostManager.stopHostingCalled, isFalse);
    },
  );

  test(
    'closing the workspace stops the sync session even while hosting (its database is closing)',
    () async {
      final project = projectsManager.currentProject!;
      await pairingService.savePairing(
        database: project.fileDatabase,
        projectId: 'project-abc',
        relayBaseUri: Uri.parse('http://192.168.1.42:47600/'),
        token: 'token-1',
      );

      final syncManager = _RecordingSyncManager(pairingService: pairingService);
      final hostManager = _RecordingHostManager(
        stateToReport: OcptRelayHostOnline(
          lanBaseUri: Uri.parse('http://192.168.1.42:47600'),
          enrolmentSecret: 'secret',
        ),
      );
      final bloc = buildBloc(syncManager: syncManager, hostManager: hostManager);

      await waitForState(bloc, (state) => !state.isLoading);
      await pumpEventQueue();
      await bloc.close();

      // The relay keeps running (see the test above), but the session must not: it would only fail
      // against the database the closing project just closed.
      expect(syncManager.stopSyncSessionCalled, isTrue);
      expect(hostManager.stopHostingCalled, isFalse);
    },
  );
}
