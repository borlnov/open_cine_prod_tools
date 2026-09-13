// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_event.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_state.dart';
import 'package:uuid/uuid.dart';

/// This is the bloc class for the Partager (sharing) screen.
///
/// It reads the currently open project's own relay pairing on entry
/// (`docs/plans/relay.md`, Phase C, commit 3) — a project holds at most one `sync_pairings` row of
/// its own, so it is found with no id in hand yet by selecting that table's single row, exactly as
/// `OcptSyncManager._readSnapshottedProjectId` already does for the very same reason. Pairing it
/// through [OcptSyncManager.pairProjectToRelay] and unpairing it through
/// [OcptSyncManager.unpairProject] are the only two writes this bloc ever makes.
class OcptSharingBloc extends BlocForMixin<OcptSharingState> {
  /// The manager used to read the current project and its own app version.
  final OcptProjectsManager _projectsManager;

  /// The manager owning the pairing/sync engine this screen drives.
  final OcptSyncManager _syncManager;

  /// The manager used to read this replica's own device id.
  final OcptPropertiesManager _propertiesManager;

  /// Class constructor
  OcptSharingBloc({
    OcptProjectsManager? projectsManager,
    OcptSyncManager? syncManager,
    OcptPropertiesManager? propertiesManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _syncManager = syncManager ?? globalGetIt().get<OcptSyncManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       super(const OcptSharingState.init()) {
    add(const OcptSharingLoadRequestedEvent());
  }

  /// The current project's writable file — a paired project's own pairing row and its ongoing sync
  /// session both belong to the project **file**, never to a read-only preview
  /// (`OcptOpenProjectModel.fileDatabase`'s own doc comment). The route that reaches this page is
  /// guarded exactly like the workspace's own, so a project is always open by the time this runs.
  OcptProjectDatabase get _database => _projectsManager.currentProject!.fileDatabase;

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptSharingLoadRequestedEvent>(_onLoadRequested);
    on<OcptSharingPairRequestedEvent>(_onPairRequested);
    on<OcptSharingUnpairConfirmedEvent>(_onUnpairConfirmed);
    on<OcptSharingPairingErrorDismissedEvent>(_onPairingErrorDismissed);
  }

  /// Loads the current project's own relay invite, if it is paired, so the page opens directly on
  /// ② Invite for a project that already is, and on ① Configure otherwise.
  Future<void> _onLoadRequested(
    OcptSharingLoadRequestedEvent event,
    Emitter<OcptSharingState> emitter,
  ) async {
    final invite = await _loadCurrentInvite();
    emitter(
      state.copyWith(
        isLoading: false,
        projectName: _projectsManager.currentProject!.name,
        invite: invite,
        clearInvite: invite == null,
      ),
    );
  }

  /// The current project's own relay invite, or null when it isn't paired — either because it has
  /// no `sync_pairings` row at all, or because [OcptSyncManager.pairingService] finds no token for
  /// it in secure storage any more (see `OcptPairingService`'s own doc comment).
  Future<OcptRelayInvite?> _loadCurrentInvite() async {
    final database = _database;
    final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final pairing = await _syncManager.pairingService.loadPairing(
      database: database,
      projectId: row.projectId,
    );
    if (pairing == null) {
      return null;
    }

    return OcptRelayInvite(
      relayBaseUri: pairing.relayBaseUri,
      projectId: row.projectId,
      token: pairing.token,
    );
  }

  /// Mints a fresh project id — the client's own to pick, per `docs/plans/relay.md`'s own Phase A
  /// doc comment — and pairs the project to `event.relayBaseUri` with `event.enrolmentSecret`,
  /// moving the page to ② Invite on success.
  ///
  /// A failure (the relay unreachable, a bad enrolment secret, …) is surfaced as
  /// [OcptSharingState.pairingFailed] rather than propagated: this bloc has no caller ready to
  /// catch it, and the page reads that flag to show its own, generic, localized message.
  Future<void> _onPairRequested(
    OcptSharingPairRequestedEvent event,
    Emitter<OcptSharingState> emitter,
  ) async {
    emitter(state.copyWith(isPairing: true, pairingFailed: false));

    final project = _projectsManager.currentProject!;
    final deviceId = await _propertiesManager.loadOrCreateDeviceId();
    final projectId = const Uuid().v4();

    try {
      final invite = await _syncManager.pairProjectToRelay(
        database: project.fileDatabase,
        projectId: projectId,
        projectFilePath: project.path,
        projectName: project.name,
        appVersion: _projectsManager.appVersion,
        relayBaseUri: event.relayBaseUri,
        enrolmentSecret: event.enrolmentSecret,
        deviceId: deviceId,
      );
      emitter(state.copyWith(isPairing: false, invite: invite));
    } catch (_) {
      emitter(state.copyWith(isPairing: false, pairingFailed: true));
    }
  }

  /// Stops sharing the current project, once the page's own `OcptConfirmDialog` confirmed it,
  /// moving the page back to ① Configure.
  Future<void> _onUnpairConfirmed(
    OcptSharingUnpairConfirmedEvent event,
    Emitter<OcptSharingState> emitter,
  ) async {
    final invite = state.invite;
    if (invite == null) {
      return;
    }

    await _syncManager.unpairProject(database: _database, projectId: invite.projectId);
    emitter(state.copyWith(clearInvite: true));
  }

  /// Clears [OcptSharingState.pairingFailed] once the page has shown its own snack bar for it.
  void _onPairingErrorDismissed(
    OcptSharingPairingErrorDismissedEvent event,
    Emitter<OcptSharingState> emitter,
  ) {
    emitter(state.copyWith(pairingFailed: false));
  }
}
