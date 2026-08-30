// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_state.dart';

/// This is the bloc class for the workspace page.
///
/// It owns two things: which production mode is active, and which of the open project's episodes
/// is selected. Each mode keeps its own bloc and state (including its own dock geometry); this
/// bloc never reaches into them. The active mode is loaded from, and persisted to,
/// [OcptPropertiesManager.workspaceMode], so opening a project restores the mode last used; the
/// selected episode is not (see [OcptWorkspaceState.selectedEpisodeId]).
///
/// This bloc subscribes to [OcptProjectsManager.currentProjectStream] rather than reading
/// [OcptProjectsManager.currentProject] once, because previewing or leaving a project version
/// swaps the database every mode reads through, and the previewed version may hold a different set
/// of episodes than the working copy did — the very case
/// [OcptWorkspaceEpisodesReloadRequestedEvent] exists to re-read.
///
/// It is also where the open project's own sync session is started, once, the very first time the
/// workspace opens: [_startSyncSessionIfPaired] reads the project's own `sync_pairings` row (there
/// is at most one, exactly as `OcptSharingBloc._loadCurrentInvite` already finds it with no id in
/// hand), and — only when both halves of the pairing are still there
/// (`OcptPairingService`'s own doc comment) — hands [OcptSyncManager.startSyncSession] the transport
/// [OcptSyncManager.openRelayRemoteStorage] builds from it. [disposeLifeCycle] stops it: the
/// workspace closing is the one signal this bloc has for "nobody needs this session running any
/// more", exactly as `docs/plans/relay.md` (Phase C, commit 5) describes. An unpaired project
/// starts nothing at all, and [OcptSyncManager.startSyncSession] itself is never called again after
/// that first attempt — the workspace bloc lives exactly as long as one project stays open, so
/// there is nothing later to react to.
class OcptWorkspaceBloc extends BlocForMixin<OcptWorkspaceState> {
  /// The manager used to load and persist the active workspace mode.
  final OcptPropertiesManager _propertiesManager;

  /// The manager used to read the open project and its episodes, and to watch it change.
  final OcptProjectsManager _projectsManager;

  /// The manager owning the pairing/sync engine this bloc starts and stops a session against, when
  /// a test hands one in directly — see [_syncManager]'s own doc comment for why this is not
  /// resolved through `globalGetIt()` here the way [_propertiesManager]/[_projectsManager] are.
  final OcptSyncManager? _syncManagerOverride;

  /// The subscription to [OcptProjectsManager.currentProjectStream], cancelled in
  /// [disposeLifeCycle].
  StreamSubscription<OcptOpenProjectModel?>? _currentProjectSubscription;

  /// Class constructor
  OcptWorkspaceBloc({
    OcptPropertiesManager? propertiesManager,
    OcptProjectsManager? projectsManager,
    OcptSyncManager? syncManager,
  }) : _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _syncManagerOverride = syncManager,
       super(const OcptWorkspaceState.init()) {
    add(const OcptWorkspaceLoadRequestedEvent());
  }

  /// [_syncManagerOverride], or the one `globalGetIt()` holds when there is an app-wide manager
  /// environment that actually registered one, or null otherwise.
  ///
  /// Unlike [_propertiesManager]/[_projectsManager], this is resolved lazily, on every access,
  /// rather than eagerly in the constructor: every other mode's own widget test (and most of this
  /// bloc's own) builds a bare `OcptWorkspaceBloc()` with no reason to ever register a sync
  /// manager of their own — this feature is not what they are testing — and an eager
  /// `globalGetIt().get<OcptSyncManager>()` would make its absence their problem anyway, exactly
  /// the failure mode `OcptSyncManager.pairingService`'s own doc comment already describes for the
  /// very same reason. [_startSyncSessionIfPaired] and [disposeLifeCycle] both simply do nothing
  /// when this is null.
  OcptSyncManager? get _syncManager {
    final override = _syncManagerOverride;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();
    return managers.isRegistered<OcptSyncManager>() ? managers.get<OcptSyncManager>() : null;
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptWorkspaceLoadRequestedEvent>(_onLoadRequested);
    on<OcptWorkspaceModeSelectedEvent>(_onModeSelected);
    on<OcptWorkspaceRevealRequestConsumedEvent>(_onRevealRequestConsumed);
    on<OcptWorkspaceEpisodeSelectedEvent>(_onEpisodeSelected);
    on<OcptWorkspaceEpisodesReloadRequestedEvent>(_onEpisodesReloadRequested);

    _currentProjectSubscription = _projectsManager.currentProjectStream.listen(
      (_) => add(const OcptWorkspaceEpisodesReloadRequestedEvent()),
    );
  }

  /// Loads the persisted workspace mode, defaulting to [OcptWorkspaceMode.screenplay], and the
  /// open project's episodes, landing the selection on the first one (see
  /// [OcptWorkspaceState.selectedEpisodeId]'s own doc comment for why it is never restored from
  /// anywhere instead).
  Future<void> _onLoadRequested(
    OcptWorkspaceLoadRequestedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async {
    final mode = await _propertiesManager.workspaceMode.load() ?? OcptWorkspaceMode.screenplay;
    final episodes = await _loadEpisodes();
    emitter(
      state.copyWith(
        isLoading: false,
        mode: mode,
        episodes: episodes,
        selectedEpisodeId: episodes.isEmpty ? null : episodes.first.id,
        clearSelectedEpisodeId: episodes.isEmpty,
      ),
    );

    await _startSyncSessionIfPaired();
  }

  /// Starts the open project's own sync session when it is paired to a relay, and does nothing at
  /// all otherwise — see this class's own doc comment for when this runs and why once is enough.
  ///
  /// A project counts as paired only when **both** halves of its pairing are still there (its own
  /// `sync_pairings` row, and the project token [OcptSyncManager.pairingService] can still read
  /// back for it) — `OcptPairingService.loadPairing`'s own doc comment. Any failure along the way
  /// (the relay unreachable, most likely) is swallowed rather than left to escape as an unhandled
  /// error: this bloc has nothing further to report it to, and the sync indicator itself already
  /// renders nothing while no session is running.
  Future<void> _startSyncSessionIfPaired() async {
    final syncManager = _syncManager;
    final project = _projectsManager.currentProject;
    if (syncManager == null || project == null) {
      return;
    }

    try {
      final database = project.fileDatabase;
      final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();
      if (row == null) {
        return;
      }

      final pairing = await syncManager.pairingService.loadPairing(
        database: database,
        projectId: row.projectId,
      );
      if (pairing == null) {
        return;
      }

      final deviceId = await _propertiesManager.loadOrCreateDeviceId();
      await syncManager.startSyncSession(
        projectId: row.projectId,
        database: database,
        deviceId: deviceId,
        relayId: OcptSyncManager.relayIdFor(pairing),
        storage: syncManager.openRelayRemoteStorage(pairing, row.projectId),
      );
    } catch (error) {
      appLogger().w("Could not start the sync session for the open project: $error");
    }
  }

  /// Re-reads the open project's episodes after [OcptProjectsManager.currentProjectStream] emits
  /// (entering or leaving a project version preview swaps the database every mode reads through).
  ///
  /// The current selection is kept when it still names one of the freshly read episodes, and falls
  /// back to the first one otherwise — the keyed remount (`WorkspacePage._buildActiveMode`) then
  /// takes care of the mode itself, which is exactly right for a database that just changed under
  /// it. A read failing here is swallowed rather than left to escape as an unhandled error, most
  /// likely because the project closed while this was still queued.
  Future<void> _onEpisodesReloadRequested(
    OcptWorkspaceEpisodesReloadRequestedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async {
    try {
      final episodes = await _loadEpisodes();
      final currentSelection = state.selectedEpisodeId;
      final stillLive = episodes.any((episode) => episode.id == currentSelection);
      final selectedEpisodeId = stillLive
          ? currentSelection
          : (episodes.isEmpty ? null : episodes.first.id);

      emitter(
        state.copyWith(
          episodes: episodes,
          selectedEpisodeId: selectedEpisodeId,
          clearSelectedEpisodeId: selectedEpisodeId == null,
        ),
      );
    } catch (error) {
      appLogger().w("A problem occurred when tried to reload the project's episodes, most likely "
          "because the project already closed: $error");
    }
  }

  /// Applies the episode picked from the toolbar's episode selector. Nothing else about the state
  /// changes, and nothing is persisted — see [OcptWorkspaceState.selectedEpisodeId]'s own doc
  /// comment.
  Future<void> _onEpisodeSelected(
    OcptWorkspaceEpisodeSelectedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async {
    emitter(state.copyWith(selectedEpisodeId: event.episodeId));
  }

  /// The open project's live episodes, in `sortKey` order, or empty while no project is open.
  Future<List<OcptEpisode>> _loadEpisodes() async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return const [];
    }

    return _projectsManager.screenplayService.loadEpisodes(database: project.database);
  }

  /// Applies and persists the mode selected from the bottom mode switcher, or by another mode
  /// sending the user there.
  ///
  /// `event.revealRequest` is carried into the state untouched and never read here: what a mode
  /// should land on is that mode's own business, and this bloc only owns which one is active
  /// (ADR 0006). A switch that names nothing — every switch the mode switcher itself makes —
  /// clears whatever an earlier one left behind, so a request can never outlive the switch it was
  /// made for.
  Future<void> _onModeSelected(
    OcptWorkspaceModeSelectedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async {
    emitter(
      state.copyWith(
        mode: event.mode,
        revealRequest: event.revealRequest,
        clearRevealRequest: event.revealRequest == null,
      ),
    );
    await _propertiesManager.workspaceMode.store(event.mode);
  }

  /// Clears the reveal request the mode that was just opened reports having taken into account.
  ///
  /// Nothing is persisted here: a reveal is a one-shot handover between two modes of one session,
  /// not a preference. Only the mode itself is ever persisted.
  Future<void> _onRevealRequestConsumed(
    OcptWorkspaceRevealRequestConsumedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async => emitter(state.copyWith(clearRevealRequest: true));

  /// {@macro act_foundation.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await _currentProjectSubscription?.cancel();
    await _syncManager?.stopSyncSession();

    return super.disposeLifeCycle();
  }
}
