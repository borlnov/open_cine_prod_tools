// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_reconcile_outcome.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_event.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A fully controllable [OcptRelayHostManager]: [state]/[stateStream] are driven directly by
/// [emit], and [startHosting]/[stopHosting]/[reconcileWithUpstream] never touch a real socket or
/// store — only record what the bloc asked of them, exactly `ocpt_relay_host_manager_test.dart`'s
/// own `_SpySyncManager` reasoning, applied to the manager this bloc drives instead of the one it
/// drove.
class _FakeHostManager extends OcptRelayHostManager {
  OcptRelayHostState _state = const OcptRelayHostStopped();
  final _controller = StreamController<OcptRelayHostState>.broadcast();
  String? _hostedProjectId;

  /// What [availableLanAddresses] returns.
  List<InternetAddress> lanAddresses = [InternetAddress('192.168.1.42')];

  /// How many times [startHosting] was called.
  int startHostingCallCount = 0;

  /// The `port` argument [startHosting] was last called with, or null.
  int? lastStartHostingPort;

  /// How many times [stopHosting] was called.
  int stopHostingCallCount = 0;

  /// The invite [reconcileWithUpstream] was last called with, or null.
  OcptRelayInvite? lastReconcileInvite;

  /// How many times [reconcileWithUpstream] was called.
  int reconcileCallCount = 0;

  /// What [reconcileWithUpstream] returns.
  OcptReconcileOutcome reconcileResult = const OcptReconcileSucceeded(pushed: 0, pulled: 0);

  @override
  OcptRelayHostState get state => _state;

  @override
  Stream<OcptRelayHostState> get stateStream => _controller.stream;

  @override
  String? get hostedProjectId => _hostedProjectId;

  @override
  Future<List<InternetAddress>> availableLanAddresses() async => lanAddresses;

  /// Pushes [next] onto [stateStream], as [startHosting]/[stopHosting] would for real, and
  /// mirrors it into [hostedProjectId] when it carries one.
  void emit(OcptRelayHostState next, {String? hostedProjectId}) {
    _state = next;
    if (hostedProjectId != null) {
      _hostedProjectId = hostedProjectId;
    }
    _controller.add(next);
  }

  @override
  Future<void> startHosting({
    required OcptProjectDatabase database,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required String deviceId,
    int? port,
  }) async {
    startHostingCallCount++;
    lastStartHostingPort = port;
  }

  @override
  Future<void> stopHosting() async {
    stopHostingCallCount++;
  }

  @override
  Future<OcptReconcileOutcome> reconcileWithUpstream(OcptRelayInvite invite) async {
    reconcileCallCount++;
    lastReconcileInvite = invite;
    return reconcileResult;
  }

  Future<void> disposeStream() => _controller.close();
}

/// A fake [OcptPairingService] returning [pairing] straight from [loadPairing] — no real secure
/// storage, no real database read, exactly what the bloc's own online-extras load needs to be
/// exercised without either. [secretsManager] is never actually used (this class's own
/// [loadPairing] override never reaches it), so it is built with closures that would throw if
/// ever called.
class _FakePairingService extends OcptPairingService {
  _FakePairingService({this.pairing})
    : super(
        secretsManager: OcptSecretsManager(
          propertiesGetter: () => throw UnimplementedError(),
          confGetter: () => throw UnimplementedError(),
        ),
      );

  /// What [loadPairing] returns.
  OcptProjectPairing? pairing;

  @override
  Future<OcptProjectPairing?> loadPairing({
    required OcptProjectDatabase database,
    required String projectId,
  }) async => pairing;
}

/// A fake [OcptSyncManager] whose [loadPairedProjectId], presence roster and [pairingService] are
/// fully under this file's own control — no real pairing, no real presence service, exactly
/// `ocpt_sync_status_indicator_test.dart`'s own `_FakeSyncManager` reasoning.
class _FakeSyncManager extends OcptSyncManager {
  _FakeSyncManager({this.pairedProjectId, _FakePairingService? pairingService})
    : _fakePairingService = pairingService ?? _FakePairingService(),
      super(changesetService: const OcptChangesetService());

  /// What [loadPairedProjectId] returns.
  String? pairedProjectId;

  final _FakePairingService _fakePairingService;

  @override
  OcptPairingService get pairingService => _fakePairingService;

  OcptPresenceRoster? _roster;
  final _controller = StreamController<OcptPresenceRoster>.broadcast();

  @override
  Future<String?> loadPairedProjectId(OcptProjectDatabase database) async => pairedProjectId;

  @override
  OcptPresenceRoster? get presenceRoster => _roster;

  @override
  Stream<OcptPresenceRoster>? get presenceRosterStream => _controller.stream;

  /// Pushes [roster] onto [presenceRosterStream], as a real presence service's own heartbeat
  /// would.
  void emit(OcptPresenceRoster roster) {
    _roster = roster;
    _controller.add(roster);
  }

  Future<void> disposeStream() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OcptPropertiesManager propertiesManager;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;

  setUpAll(() async {
    // OcptGlobalManager, OcptPropertiesManager and OcptProjectsManager all log through
    // appLogger(), which requires a global manager instance to be set; merely accessing it creates
    // the (otherwise unused) singleton, exactly as `sharing_bloc_test.dart` does.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();

    tempDir = await Directory.systemTemp.createTemp("ocpt_hosting_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
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

  /// Builds an [OcptHostingBloc] over [hostManager]/[syncManager], tearing both streams down on
  /// test end.
  OcptHostingBloc buildBloc({required _FakeHostManager hostManager, required _FakeSyncManager syncManager}) {
    addTearDown(hostManager.disposeStream);
    addTearDown(syncManager.disposeStream);

    final bloc = OcptHostingBloc(
      hostManager: hostManager,
      syncManager: syncManager,
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  test("a never-paired, never-hosted project loads stopped with no auto-restart available", () async {
    final bloc = buildBloc(hostManager: _FakeHostManager(), syncManager: _FakeSyncManager());
    await pumpEventQueue();

    expect(bloc.state.isLoading, isFalse);
    expect(bloc.state.hostState, const OcptRelayHostStopped());
    expect(bloc.state.canSetAutoRestart, isFalse);
    expect(bloc.state.hostOnLaunch, isFalse);
    expect(bloc.state.presenceRoster, isNull);
  });

  test("an already-paired project loads with auto-restart available, reading the stored flag", () async {
    await propertiesManager.setHostOnLaunch(projectId: "existing-project", value: true);
    final bloc = buildBloc(
      hostManager: _FakeHostManager(),
      syncManager: _FakeSyncManager(pairedProjectId: "existing-project"),
    );
    await pumpEventQueue();

    expect(bloc.state.canSetAutoRestart, isTrue);
    expect(bloc.state.hostOnLaunch, isTrue);
  });

  test("starting hosting calls the manager and follows its state stream to online", () async {
    final hostManager = _FakeHostManager();
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    bloc.add(const OcptHostingStartStopRequestedEvent(start: true));
    await pumpEventQueue();
    expect(hostManager.startHostingCallCount, 1);
    expect(hostManager.stopHostingCallCount, 0);

    hostManager.emit(const OcptRelayHostStarting());
    await pumpEventQueue();
    expect(bloc.state.hostState, const OcptRelayHostStarting());

    hostManager.emit(
      OcptRelayHostOnline(
        lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
        enrolmentSecret: "secret",
      ),
      hostedProjectId: "hosted-project",
    );
    await pumpEventQueue();

    expect(bloc.state.hostState, isA<OcptRelayHostOnline>());
    expect(bloc.state.canSetAutoRestart, isTrue);
  });

  test("going online populates the available addresses and builds the enrolment/join invite", () async {
    final hostManager = _FakeHostManager()
      ..lanAddresses = [InternetAddress("192.168.1.42"), InternetAddress("10.0.0.5")];
    final syncManager = _FakeSyncManager(
      pairingService: _FakePairingService(
        pairing: OcptProjectPairing(
          relayBaseUri: Uri.https("prep.example.org"),
          token: "prep-token",
        ),
      ),
    );
    final bloc = buildBloc(hostManager: hostManager, syncManager: syncManager);
    await pumpEventQueue();

    hostManager.emit(
      OcptRelayHostOnline(
        lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
        enrolmentSecret: "secret",
      ),
      hostedProjectId: "hosted-project",
    );
    await pumpEventQueue();

    expect(bloc.state.availableAddresses, ["192.168.1.42", "10.0.0.5"]);
    expect(bloc.state.selectedAddress, "192.168.1.42");
    expect(bloc.state.boundPort, 53187);
    expect(bloc.state.enrolment?.relayBaseUri, Uri.parse("http://192.168.1.42:53187"));
    expect(bloc.state.enrolment?.enrolmentSecret, "secret");
    expect(bloc.state.joinInvite?.relayBaseUri, Uri.parse("http://192.168.1.42:53187"));
    expect(bloc.state.joinInvite?.projectId, "hosted-project");
    expect(bloc.state.joinInvite?.token, "prep-token");
    expect(bloc.state.qrKind, OcptHostingQrKind.join);
  });

  test("an advertised-address change rebuilds both credentials without restarting hosting", () async {
    final hostManager = _FakeHostManager()
      ..lanAddresses = [InternetAddress("192.168.1.42"), InternetAddress("10.0.0.5")];
    final syncManager = _FakeSyncManager(
      pairingService: _FakePairingService(
        pairing: OcptProjectPairing(
          relayBaseUri: Uri.https("prep.example.org"),
          token: "prep-token",
        ),
      ),
    );
    final bloc = buildBloc(hostManager: hostManager, syncManager: syncManager);
    await pumpEventQueue();

    hostManager.emit(
      OcptRelayHostOnline(
        lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
        enrolmentSecret: "secret",
      ),
      hostedProjectId: "hosted-project",
    );
    await pumpEventQueue();

    bloc.add(const OcptHostingAdvertisedAddressChangedEvent("10.0.0.5"));
    await pumpEventQueue();

    expect(bloc.state.selectedAddress, "10.0.0.5");
    expect(bloc.state.enrolment?.relayBaseUri, Uri.parse("http://10.0.0.5:53187"));
    expect(bloc.state.joinInvite?.relayBaseUri, Uri.parse("http://10.0.0.5:53187"));
    expect(bloc.state.joinInvite?.token, "prep-token");
    expect(hostManager.startHostingCallCount, 0);
  });

  test(
    "a port restart (a re-emitted online host state) keeps the previously selected address",
    () async {
      final hostManager = _FakeHostManager()
        ..lanAddresses = [InternetAddress("192.168.1.42"), InternetAddress("10.0.0.5")];
      final syncManager = _FakeSyncManager(
        pairingService: _FakePairingService(
          pairing: OcptProjectPairing(
            relayBaseUri: Uri.https("prep.example.org"),
            token: "prep-token",
          ),
        ),
      );
      final bloc = buildBloc(hostManager: hostManager, syncManager: syncManager);
      await pumpEventQueue();

      hostManager.emit(
        OcptRelayHostOnline(
          lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
          enrolmentSecret: "secret",
        ),
        hostedProjectId: "hosted-project",
      );
      await pumpEventQueue();

      bloc.add(const OcptHostingAdvertisedAddressChangedEvent("10.0.0.5"));
      await pumpEventQueue();
      expect(bloc.state.selectedAddress, "10.0.0.5");

      // Simulates a port-apply restart: the manager re-binds and re-emits online with the very
      // same default host (192.168.1.42), still carrying the address the operator had picked
      // among `lanAddresses`.
      hostManager.emit(
        OcptRelayHostOnline(
          lanBaseUri: Uri.parse("http://192.168.1.42:6001"),
          enrolmentSecret: "secret",
        ),
        hostedProjectId: "hosted-project",
      );
      await pumpEventQueue();

      expect(bloc.state.selectedAddress, "10.0.0.5");
      expect(bloc.state.boundPort, 6001);
      expect(bloc.state.enrolment?.relayBaseUri, Uri.parse("http://10.0.0.5:6001"));
    },
  );

  test("a port-change event asks the manager to re-bind that port", () async {
    final hostManager = _FakeHostManager();
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    hostManager.emit(
      OcptRelayHostOnline(
        lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
        enrolmentSecret: "secret",
      ),
      hostedProjectId: "hosted-project",
    );
    await pumpEventQueue();

    bloc.add(const OcptHostingPortChangeRequestedEvent(6001));
    await pumpEventQueue();

    expect(hostManager.startHostingCallCount, 1);
    expect(hostManager.lastStartHostingPort, 6001);
  });

  test("the QR-kind toggle updates the panel's own selection", () async {
    final bloc = buildBloc(hostManager: _FakeHostManager(), syncManager: _FakeSyncManager());
    await pumpEventQueue();
    expect(bloc.state.qrKind, OcptHostingQrKind.join);

    bloc.add(const OcptHostingQrKindChangedEvent(OcptHostingQrKind.enrolment));
    await pumpEventQueue();

    expect(bloc.state.qrKind, OcptHostingQrKind.enrolment);
  });

  test("stopping hosting calls the manager and follows its state stream back to stopped", () async {
    final hostManager = _FakeHostManager();
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    bloc.add(const OcptHostingStartStopRequestedEvent(start: false));
    await pumpEventQueue();

    expect(hostManager.stopHostingCallCount, 1);

    hostManager.emit(const OcptRelayHostStopped());
    await pumpEventQueue();
    expect(bloc.state.hostState, const OcptRelayHostStopped());
  });

  test("toggling auto-restart persists the flag and emits it, once a relay-side id is known", () async {
    final bloc = buildBloc(
      hostManager: _FakeHostManager(),
      syncManager: _FakeSyncManager(pairedProjectId: "existing-project"),
    );
    await pumpEventQueue();
    expect(bloc.state.canSetAutoRestart, isTrue);

    bloc.add(const OcptHostingAutoRestartChangedEvent(value: true));
    await pumpEventQueue();

    expect(bloc.state.hostOnLaunch, isTrue);
    expect(await propertiesManager.loadHostOnLaunch("existing-project"), isTrue);
  });

  test("presence forwards through the bloc once hosting goes online", () async {
    final hostManager = _FakeHostManager();
    final syncManager = _FakeSyncManager();
    final bloc = buildBloc(hostManager: hostManager, syncManager: syncManager);
    await pumpEventQueue();

    hostManager.emit(
      OcptRelayHostOnline(
        lanBaseUri: Uri.parse("http://192.168.1.42:53187"),
        enrolmentSecret: "secret",
      ),
      hostedProjectId: "hosted-project",
    );
    await pumpEventQueue();

    const roster = OcptPresenceRoster(participants: [], selfDeviceId: "device-1");
    syncManager.emit(roster);
    await pumpEventQueue();

    expect(bloc.state.presenceRoster, roster);
  });

  test("reconcile success emits the pushed/pulled outcome", () async {
    final hostManager = _FakeHostManager()
      ..reconcileResult = const OcptReconcileSucceeded(pushed: 3, pulled: 0);
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    const inviteText = "ocpt://join?r=https%3A%2F%2Fupstream.example.org%2F&p=hosted-project&t=tok";
    bloc.add(const OcptHostingReconcileRequestedEvent(inviteText));
    await pumpEventQueue();

    expect(hostManager.reconcileCallCount, 1);
    expect(hostManager.lastReconcileInvite!.projectId, "hosted-project");
    expect(bloc.state.isReconciling, isFalse);
    expect(bloc.state.reconcileOutcome, const OcptReconcileSucceeded(pushed: 3, pulled: 0));
    expect(bloc.state.reconcileInviteInvalid, isFalse);
  });

  test("reconcile with an unparseable invite never reaches the manager", () async {
    final hostManager = _FakeHostManager();
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    bloc.add(const OcptHostingReconcileRequestedEvent("not an invite"));
    await pumpEventQueue();

    expect(hostManager.reconcileCallCount, 0);
    expect(bloc.state.reconcileInviteInvalid, isTrue);
    expect(bloc.state.reconcileOutcome, isNull);
  });

  test("a reconcile failure value is carried through to the state", () async {
    final hostManager = _FakeHostManager()
      ..reconcileResult = const OcptReconcileFailed("upstream unreachable");
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    const inviteText = "ocpt://join?r=https%3A%2F%2Fupstream.example.org%2F&p=hosted-project&t=tok";
    bloc.add(const OcptHostingReconcileRequestedEvent(inviteText));
    await pumpEventQueue();

    expect(bloc.state.reconcileOutcome, isA<OcptReconcileFailed>());
  });

  test("dismissing a reconcile result clears it", () async {
    final hostManager = _FakeHostManager();
    final bloc = buildBloc(hostManager: hostManager, syncManager: _FakeSyncManager());
    await pumpEventQueue();

    bloc.add(const OcptHostingReconcileRequestedEvent("not an invite"));
    await pumpEventQueue();
    expect(bloc.state.reconcileInviteInvalid, isTrue);

    bloc.add(const OcptHostingReconcileDismissedEvent());
    await pumpEventQueue();

    expect(bloc.state.reconcileInviteInvalid, isFalse);
    expect(bloc.state.reconcileOutcome, isNull);
  });
}
