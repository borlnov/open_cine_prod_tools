// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_event.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_state.dart';

/// This is the bloc class for the Partager screen's "Héberger sur ce poste" segment
/// (`docs/architecture/sync.md`).
///
/// It drives `OcptRelayHostManager` the way `OcptSharingBloc` drives `OcptSyncManager.
/// pairProjectToRelay`/`unpairProject` — start/stop hosting, toggle "réhéberger au démarrage", and
/// run an in-app reconcile against an upstream relay — while mirroring the manager's own host-state
/// stream and, only while hosting is online, the sync manager's own presence roster stream, both of
/// which (like every ACT manager stream, `CLAUDE.md`'s own pitfalls list) never replay their current
/// value to a new listener.
class OcptHostingBloc extends BlocForMixin<OcptHostingState> {
  /// The manager owning the in-process relay this bloc starts, stops and reconciles.
  final OcptRelayHostManager _hostManager;

  /// The manager used to read the project's own relay-side id and, while hosting, its live
  /// presence roster.
  final OcptSyncManager _syncManager;

  /// The manager used to read the current project and its own app version.
  final OcptProjectsManager _projectsManager;

  /// The manager used to read this replica's own device id and the "host on launch" preference.
  final OcptPropertiesManager _propertiesManager;

  /// The subscription to [_hostManager]'s own `stateStream`, cancelled in [disposeLifeCycle].
  StreamSubscription<OcptRelayHostState>? _hostStateSubscription;

  /// The subscription to [_syncManager]'s own `presenceRosterStream`, live only while hosting is
  /// online — see [_subscribeToPresence]/[_unsubscribeFromPresence].
  StreamSubscription<OcptPresenceRoster>? _presenceSubscription;

  /// Class constructor
  OcptHostingBloc({
    OcptRelayHostManager? hostManager,
    OcptSyncManager? syncManager,
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
  }) : _hostManager = hostManager ?? globalGetIt().get<OcptRelayHostManager>(),
       _syncManager = syncManager ?? globalGetIt().get<OcptSyncManager>(),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       super(const OcptHostingState.init()) {
    add(const OcptHostingLoadRequestedEvent());
  }

  /// The current project — the route reaching this bloc is guarded exactly like the sharing bloc's
  /// own, so a project is always open by the time this runs.
  OcptOpenProjectModel get _project => _projectsManager.currentProject!;

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptHostingLoadRequestedEvent>(_onLoadRequested);
    on<OcptHostingHostStateChangedEvent>(_onHostStateChanged);
    on<OcptHostingPresenceChangedEvent>(_onPresenceChanged);
    on<OcptHostingStartStopRequestedEvent>(_onStartStopRequested);
    on<OcptHostingAutoRestartChangedEvent>(_onAutoRestartChanged);
    on<OcptHostingReconcileRequestedEvent>(_onReconcileRequested);
    on<OcptHostingReconcileDismissedEvent>(_onReconcileDismissed);

    _hostStateSubscription = _hostManager.stateStream.listen(
      (hostState) => add(OcptHostingHostStateChangedEvent(hostState)),
    );
  }

  /// Seeds every field of [OcptHostingState] off the managers' own getters, exactly as
  /// `OcptSharingBloc._onLoadRequested`/`OcptWorkspaceBloc._onLoadRequested` do for the very same
  /// "streams don't replay" reason.
  Future<void> _onLoadRequested(
    OcptHostingLoadRequestedEvent event,
    Emitter<OcptHostingState> emitter,
  ) async {
    final hostState = _hostManager.state;
    if (hostState is OcptRelayHostOnline) {
      _subscribeToPresence();
    }

    final projectId = await _syncManager.loadPairedProjectId(_project.fileDatabase);
    final hostOnLaunch =
        projectId != null && await _propertiesManager.loadHostOnLaunch(projectId);
    final presenceRoster = _syncManager.presenceRoster;

    emitter(
      state.copyWith(
        isLoading: false,
        hostState: hostState,
        presenceRoster: presenceRoster,
        clearPresenceRoster: presenceRoster == null,
        canSetAutoRestart: projectId != null,
        hostOnLaunch: hostOnLaunch,
      ),
    );
  }

  /// Applies [event]'s own host state, and — since presence only ever lives while hosting is
  /// online — subscribes to (or unsubscribes from) [_syncManager]'s own presence roster stream to
  /// match: a transition to [OcptRelayHostOnline] means a session just started, so this both starts
  /// the presence subscription and re-reads whether "réhéberger au démarrage" can now be set (a
  /// never-paired project that just started hosting for the first time has a relay-side id from this
  /// moment on, through `OcptRelayHostManager.hostedProjectId`); any other state means hosting is no
  /// longer live, so the subscription is torn down and the roster cleared.
  Future<void> _onHostStateChanged(
    OcptHostingHostStateChangedEvent event,
    Emitter<OcptHostingState> emitter,
  ) async {
    final hostState = event.hostState;

    if (hostState is OcptRelayHostOnline) {
      _subscribeToPresence();

      final hostedId = _hostManager.hostedProjectId;
      final hostOnLaunch = hostedId == null
          ? state.hostOnLaunch
          : await _propertiesManager.loadHostOnLaunch(hostedId);
      final presenceRoster = _syncManager.presenceRoster;

      emitter(
        state.copyWith(
          hostState: hostState,
          canSetAutoRestart: true,
          hostOnLaunch: hostOnLaunch,
          presenceRoster: presenceRoster,
          clearPresenceRoster: presenceRoster == null,
        ),
      );
    } else {
      await _unsubscribeFromPresence();
      emitter(state.copyWith(hostState: hostState, clearPresenceRoster: true));
    }
  }

  /// Applies [event]'s own roster straight to [OcptHostingState.presenceRoster].
  void _onPresenceChanged(
    OcptHostingPresenceChangedEvent event,
    Emitter<OcptHostingState> emitter,
  ) {
    final roster = event.presenceRoster;
    emitter(state.copyWith(presenceRoster: roster, clearPresenceRoster: roster == null));
  }

  /// Starts or stops hosting the current project — [OcptHostingHostStateChangedEvent] is what
  /// actually moves [OcptHostingState.hostState] on, off [_hostManager]'s own stream, so this never
  /// emits a state of its own.
  Future<void> _onStartStopRequested(
    OcptHostingStartStopRequestedEvent event,
    Emitter<OcptHostingState> emitter,
  ) async {
    if (event.start) {
      final project = _project;
      await _hostManager.startHosting(
        database: project.fileDatabase,
        projectFilePath: project.path,
        projectName: project.name,
        appVersion: _projectsManager.appVersion,
        deviceId: await _propertiesManager.loadOrCreateDeviceId(),
      );
    } else {
      await _hostManager.stopHosting();
    }
  }

  /// Persists [event]'s own value against the project's relay-side id — [_hostManager.
  /// hostedProjectId] while hosting is live, or [OcptSyncManager.loadPairedProjectId] otherwise —
  /// and does nothing when neither is known yet: the checkbox stays disabled in that case
  /// ([OcptHostingState.canSetAutoRestart]), so this should never actually be reached without an id.
  Future<void> _onAutoRestartChanged(
    OcptHostingAutoRestartChangedEvent event,
    Emitter<OcptHostingState> emitter,
  ) async {
    final id = _hostManager.hostedProjectId ?? await _syncManager.loadPairedProjectId(_project.fileDatabase);
    if (id == null) {
      return;
    }

    await _propertiesManager.setHostOnLaunch(projectId: id, value: event.value);
    emitter(state.copyWith(hostOnLaunch: event.value));
  }

  /// Parses [event]'s own invite text and, when it is a well-formed `ocpt://join` link, runs
  /// `OcptRelayHostManager.reconcileWithUpstream` against it — an unparseable text never reaches
  /// the manager at all, surfacing instead as [OcptHostingState.reconcileInviteInvalid], since the
  /// bloc has no `Tr` to word a specific message with (`OcptSharingBloc`'s own reasoning for
  /// `pairingFailed`).
  Future<void> _onReconcileRequested(
    OcptHostingReconcileRequestedEvent event,
    Emitter<OcptHostingState> emitter,
  ) async {
    final invite = OcptRelayInvite.tryParse(event.inviteText.trim());
    if (invite == null) {
      emitter(
        state.copyWith(
          reconcileInviteInvalid: true,
          isReconciling: false,
          clearReconcileOutcome: true,
        ),
      );
      return;
    }

    emitter(state.copyWith(isReconciling: true, reconcileInviteInvalid: false, clearReconcileOutcome: true));
    final outcome = await _hostManager.reconcileWithUpstream(invite);
    emitter(state.copyWith(isReconciling: false, reconcileOutcome: outcome));
  }

  /// Clears [OcptHostingState.reconcileOutcome] and [OcptHostingState.reconcileInviteInvalid] once
  /// the panel has shown either — the same one-shot-notice shape `OcptSharingBloc`'s own
  /// `_onPairingErrorDismissed` already follows.
  void _onReconcileDismissed(
    OcptHostingReconcileDismissedEvent event,
    Emitter<OcptHostingState> emitter,
  ) {
    emitter(state.copyWith(clearReconcileOutcome: true, reconcileInviteInvalid: false));
  }

  /// Subscribes to [_syncManager]'s own presence roster stream, when it is actually live (hosting
  /// online) and not already subscribed to — a no-op otherwise, since
  /// `OcptSyncManager.presenceRosterStream` is null whenever no session is running.
  void _subscribeToPresence() {
    if (_presenceSubscription != null) {
      return;
    }

    final stream = _syncManager.presenceRosterStream;
    if (stream == null) {
      return;
    }

    _presenceSubscription = stream.listen(
      (roster) => add(OcptHostingPresenceChangedEvent(roster)),
    );
  }

  /// Cancels [_presenceSubscription], if any — called both on a transition away from
  /// [OcptRelayHostOnline] and from [disposeLifeCycle].
  Future<void> _unsubscribeFromPresence() async {
    await _presenceSubscription?.cancel();
    _presenceSubscription = null;
  }

  /// {@macro act_foundation.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await _hostStateSubscription?.cancel();
    await _unsubscribeFromPresence();

    return super.disposeLifeCycle();
  }
}
