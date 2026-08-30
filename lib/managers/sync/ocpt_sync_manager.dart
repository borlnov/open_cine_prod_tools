// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_relay_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_screenplay_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';

/// Builds the [OcptSyncManager] instance registered by the global manager.
class OcptSyncManagerBuilder extends AbsLifeCycleFactory<OcptSyncManager> {
  /// Class constructor
  const OcptSyncManagerBuilder() : super(OcptSyncManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptPropertiesManager, OcptProjectsManager];
}

/// Owns a project's own side of `docs/plans/collaboration-and-sync.md`'s changeset engine (M3):
/// turning local writes into changesets and applying incoming ones, per-column merge, the
/// screenplay's own three-way text merge, and the transport those changesets and snapshots travel
/// over.
///
/// This step of that plan lands [changesetService]'s **inbound** half on top of the outbound one
/// that shipped before it: [OcptMergeService], the per-column resolver
/// [changesetService].`pullAndApply` hands every incoming changeset to, is what actually makes two
/// replicas pointed at the same [OcptRemoteStorage] converge — plus the [OcptRemoteStorage] seam and
/// [OcptFolderRemoteStorage], the directory transport that exercises the whole engine with no
/// network at all and stays afterwards as the desktop fallback
/// (`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`) — and
/// [OcptScreenplayMergeService], the one column [OcptMergeService] hands off instead of resolving
/// generically: the three-way line merge for `screenplays.fountainText`.
///
/// This manager depends on [OcptPropertiesManager] (the device id a changeset — and a screenplay
/// merge's own write — is stamped with) and [OcptProjectsManager] (the open project a changeset is
/// generated from and applied to, and the very [OcptProjectsManager.screenplayService] instance a
/// screenplay merge reruns its reconciliation through, so scenes/cast/coverage/breakdown stay in
/// step with whichever project is actually open) for exactly that reason, ahead of the code that
/// reads either one.
class OcptSyncManager extends AbsWithLifeCycle {
  /// The service turning a replica's own un-pushed local edits into a changeset, appending it to a
  /// relay, and applying every changeset a relay holds that this replica hasn't seen yet.
  final OcptChangesetService changesetService;

  /// Class constructor
  ///
  /// [projectsManager] and [propertiesManager] are the injectable seams over `globalGetIt()` a test
  /// hands in instead — `OcptScreenplayMergeService` needs a real, fully-wired
  /// `OcptScreenplayService` and a real device id getter, and [OcptProjectsManager]/
  /// [OcptPropertiesManager] are where those already live, exactly the pattern
  /// `OcptProjectsManager`'s own constructor already follows for the very same services. Passing
  /// [changesetService] directly (as this class's own tests do, with a bare
  /// `OcptChangesetService()`) skips that wiring entirely.
  OcptSyncManager({OcptProjectsManager? projectsManager, OcptPropertiesManager? propertiesManager, OcptChangesetService? changesetService})
    : changesetService =
          changesetService ??
          OcptChangesetService(
            mergeService: OcptMergeService(
              screenplayMergeService: OcptScreenplayMergeService(
                screenplayService: (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
                deviceId: (propertiesManager ?? globalGetIt().get<OcptPropertiesManager>()).loadOrCreateDeviceId,
              ),
            ),
          );

  /// This project's current sync session, or null when none is running — see [startSyncSession].
  OcptSyncSession? get syncSession => _syncSession;
  OcptSyncSession? _syncSession;

  /// Opens the directory transport rooted at [directory].
  ///
  /// This is the one [OcptRemoteStorage] implementation the changeset engine has to exercise
  /// against today; [openRelayRemoteStorage] is the second, once a project is actually paired
  /// with a relay.
  OcptRemoteStorage openFolderRemoteStorage(Directory directory) => OcptFolderRemoteStorage(directory);

  /// Opens the relay transport [pairing] describes, for [projectId].
  ///
  /// [enrolmentSecret] is only ever needed the first time [projectId] is pushed to a relay that
  /// has never heard of it — see [OcptRelayRemoteStorage]'s own constructor doc comment for why a
  /// previously paired project simply does not pass one.
  OcptRemoteStorage openRelayRemoteStorage(
    OcptProjectPairing pairing,
    String projectId, {
    String? enrolmentSecret,
  }) => OcptRelayRemoteStorage(
    relayBaseUri: pairing.relayBaseUri,
    projectId: projectId,
    token: pairing.token,
    enrolmentSecret: enrolmentSecret,
  );

  /// The stable id [changesetService] keys a pairing's own delivery cursor by
  /// (`sync_relay_cursors.relayId`): [pairing]'s relay base URL, stringified.
  ///
  /// This has to stay stable for as long as a project is paired with the same relay — restarting
  /// or re-pairing to the very same address must not reset the cursor — and differ between two
  /// different relays, since a device keeps one delivery cursor per relay and the same project can
  /// live behind two relays in one day (the prep relay and the set relay, M6,
  /// `docs/plans/collaboration-and-sync.md` §3.3/§5.3). The relay base URL already has exactly
  /// that shape, so nothing further is minted or stored for it.
  static String relayIdFor(OcptProjectPairing pairing) => pairing.relayBaseUri.toString();

  /// Starts keeping [projectId] in sync against [storage], replacing whatever session was running
  /// before ([stopSyncSession] runs first, so calling this twice in a row is always safe).
  ///
  /// This is called **explicitly** by whoever decides a project should be syncing right now — the
  /// workspace, once it opens a paired project (`docs/plans/relay.md`, M4, Phase C) — never
  /// implicitly from a project-open lifecycle hook: this manager has no opinion on when a project
  /// deserves a session, only on how to run one.
  ///
  /// [database] must be [projectId]'s **writable** file
  /// (`OcptOpenProjectModel.fileDatabase`), never a read-only preview — see
  /// `OcptSyncSession`'s own doc comment. [relayId] is normally [relayIdFor] against the pairing
  /// [storage] itself came from ([openRelayRemoteStorage]'s own caller already has that pairing in
  /// hand); a caller syncing over [openFolderRemoteStorage] instead picks its own stable id, since
  /// a directory has no URL to derive one from.
  Future<void> startSyncSession({
    required String projectId,
    required OcptProjectDatabase database,
    required String deviceId,
    required String relayId,
    required OcptRemoteStorage storage,
    Duration pushInterval = ocptDefaultSyncPushInterval,
  }) async {
    await stopSyncSession();

    final session = OcptSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
      changesetService: changesetService,
      pushInterval: pushInterval,
    );
    _syncSession = session;

    await session.start();
  }

  /// Stops the current sync session, if any — cancels its timer and its `newWorkStream`
  /// subscription and closes its status stream. Safe to call with no session running.
  Future<void> stopSyncSession() async {
    final session = _syncSession;
    _syncSession = null;
    await session?.stop();
  }

  /// Runs a sync right now against the running session, on demand — what the status indicator's
  /// tap calls. Throws [StateError] when no session is running.
  Future<void> syncNow() async {
    final session = _syncSession;
    if (session == null) {
      throw StateError('No sync session is running');
    }

    await session.syncNow();
  }

  /// The running session's current status, or null when no session is running. [syncStatusStream]
  /// never replays this to a new listener — read this first to seed a fresh subscriber, exactly as
  /// `OcptSyncSession.status`'s own doc comment says.
  OcptSyncStatus? get syncStatus => _syncSession?.status;

  /// The running session's own status stream, or null when no session is running.
  Stream<OcptSyncStatus>? get syncStatusStream => _syncSession?.statusStream;

  /// Every screenplay merge conflict the running session has raised so far, oldest first, or an
  /// empty list when no session is running.
  List<OcptScreenplayMergeConflict> get syncConflicts => _syncSession?.conflicts ?? const [];

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await stopSyncSession();

    return super.disposeLifeCycle();
  }
}
