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
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_event.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_state.dart';

/// This is the bloc class for the "Changer de relais" (repointing) screen.
///
/// Unlike `OcptSharingBloc`, this bloc reads no pairing on entry: the page always opens ready to
/// enter or scan a *new* relay (`docs/plans/on-set-server.md`, Phase E), even for a project already
/// paired elsewhere. [OcptSyncManager.repointProjectToRelay] is the only write this bloc ever
/// makes, and it is the only manager method this screen calls beyond reading the current project's
/// own `sync_pairings` row for the `projectId` that method needs — exactly as `OcptSharingBloc`
/// reads that same single row for the very same reason.
class OcptRepointingBloc extends BlocForMixin<OcptRepointingState> {
  /// The manager used to read the current project and its own app version.
  final OcptProjectsManager _projectsManager;

  /// The manager owning the pairing/sync engine this screen drives.
  final OcptSyncManager _syncManager;

  /// The manager used to read this replica's own device id.
  final OcptPropertiesManager _propertiesManager;

  /// Class constructor
  OcptRepointingBloc({
    OcptProjectsManager? projectsManager,
    OcptSyncManager? syncManager,
    OcptPropertiesManager? propertiesManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _syncManager = syncManager ?? globalGetIt().get<OcptSyncManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       super(const OcptRepointingState.init()) {
    add(const OcptRepointingLoadRequestedEvent());
  }

  /// The current project's writable file — a re-point moves the project **file**'s own pairing and
  /// ongoing sync session, never a read-only preview's (`OcptOpenProjectModel.fileDatabase`'s own
  /// doc comment). The route that reaches this page is guarded exactly like the sharing screen's
  /// own, so a project is always open by the time this runs.
  OcptProjectDatabase get _database => _projectsManager.currentProject!.fileDatabase;

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptRepointingLoadRequestedEvent>(_onLoadRequested);
    on<OcptRepointingRequestedEvent>(_onRepointRequested);
    on<OcptRepointingErrorDismissedEvent>(_onErrorDismissed);
  }

  /// Loads the current project's own display name — the page always opens on ① Configure, so
  /// there is nothing else to read.
  Future<void> _onLoadRequested(
    OcptRepointingLoadRequestedEvent event,
    Emitter<OcptRepointingState> emitter,
  ) async {
    emitter(
      state.copyWith(isLoading: false, projectName: _projectsManager.currentProject!.name),
    );
  }

  /// Re-points the current project to `event.relayBaseUri` with `event.enrolmentSecret`, reusing
  /// the token its existing pairing already holds, and moving the page to ② QR code on success.
  ///
  /// A failure (the relay unreachable, a bad enrolment secret, the project not paired at all yet)
  /// is surfaced as [OcptRepointingState.repointFailed] rather than propagated: exactly
  /// `OcptSharingBloc._onPairRequested`'s own reasoning, this bloc has no `Tr` to word a specific
  /// message with, and the page reads the flag to show its own, generic, localized one.
  Future<void> _onRepointRequested(
    OcptRepointingRequestedEvent event,
    Emitter<OcptRepointingState> emitter,
  ) async {
    emitter(state.copyWith(isRepointing: true, repointFailed: false));

    try {
      final project = _projectsManager.currentProject!;
      final database = _database;
      final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();
      if (row == null) {
        throw StateError(
          'Cannot switch relay for project "${project.name}": it has no existing pairing to '
          'reuse a token from.',
        );
      }

      final deviceId = await _propertiesManager.loadOrCreateDeviceId();
      await _syncManager.repointProjectToRelay(
        database: database,
        projectId: row.projectId,
        projectFilePath: project.path,
        projectName: project.name,
        appVersion: _projectsManager.appVersion,
        relayBaseUri: event.relayBaseUri,
        enrolmentSecret: event.enrolmentSecret,
        deviceId: deviceId,
      );

      emitter(
        state.copyWith(
          isRepointing: false,
          enrolment: OcptRelayEnrolment(
            relayBaseUri: event.relayBaseUri,
            enrolmentSecret: event.enrolmentSecret,
          ),
        ),
      );
    } catch (_) {
      emitter(state.copyWith(isRepointing: false, repointFailed: true));
    }
  }

  /// Clears [OcptRepointingState.repointFailed] once the page has shown its own snack bar for it.
  void _onErrorDismissed(
    OcptRepointingErrorDismissedEvent event,
    Emitter<OcptRepointingState> emitter,
  ) {
    emitter(state.copyWith(repointFailed: false));
  }
}
