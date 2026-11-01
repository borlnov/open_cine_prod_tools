// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_dart_value_keeper/act_dart_value_keeper.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_presence_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_project_pairing.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_relay_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_screenplay_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_snapshot_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_sync_session.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_flow_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_session_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:uuid/uuid.dart';

/// Builds the [OcptSyncManager] instance registered by the global manager.
class OcptSyncManagerBuilder extends AbsLifeCycleFactory<OcptSyncManager> {
  /// Class constructor
  const OcptSyncManagerBuilder() : super(OcptSyncManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [
    LoggerManager,
    OcptPropertiesManager,
    OcptProjectsManager,
    OcptSecretsManager,
  ];
}

/// Owns a project's own side of the changeset engine (`docs/architecture/sync.md`): turning local
/// writes into changesets and applying incoming ones, per-column merge, the screenplay's own
/// three-way text merge, and the transport those changesets and snapshots travel over.
///
/// [changesetService]'s **inbound** half sits on top of its outbound one: [OcptMergeService], the
/// per-column resolver [changesetService].`pullAndApply` hands every incoming changeset to, is what
/// actually makes two replicas pointed at the same [OcptRemoteStorage] converge — plus the
/// [OcptRemoteStorage] seam and [OcptFolderRemoteStorage], the directory transport that exercises
/// the whole engine with no network at all and stays as the desktop fallback
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
  /// The logger category linked to this manager.
  static const _loggerCategory = "sync";

  /// The service turning a replica's own un-pushed local edits into a changeset, appending it to a
  /// relay, and applying every changeset a relay holds that this replica hasn't seen yet.
  final OcptChangesetService changesetService;

  /// The service turning a project into snapshot bytes and back — what [publishSnapshot] and
  /// [joinFromRelay] build on.
  final OcptSnapshotService snapshotService;

  /// The logger this manager writes to, and the parent of every service's and session's own.
  final LogsHelper _logger;
  OcptPairingService? _pairingService;
  OcptSyncSession? _syncSession;

  /// This project's current presence service, or null when none is running — see
  /// [startSyncSession].
  OcptPresenceService? _presenceService;

  /// Emits this manager's sync status across the whole session lifecycle — see [syncStatusChanges].
  ///
  /// A session's own [OcptSyncSession.statusStream] only exists while that session does, so a
  /// caller reading it off the session sees nothing when a session starts or stops *after* it
  /// subscribed. This manager-level stream outlives any one session: [startSyncSession] pipes
  /// the new session's status onto it (seeded with the current one), and [stopSyncSession] closes
  /// it out with a null.
  ///
  /// It emits every value it is given, even one equal to the previous: a session reporting the
  /// same status again is still reported.
  final ValueKeeperWithStream<OcptSyncStatus?> _syncStatus;

  /// The subscription piping the running session's [OcptSyncSession.statusStream] onto
  /// [_syncStatus], cancelled when the session stops.
  StreamSubscription<OcptSyncStatus>? _sessionStatusForwarder;

  /// Emits this manager's presence roster across the whole session lifecycle — the presence
  /// counterpart of [_syncStatus], for the same reason.
  final ValueKeeperWithStream<OcptPresenceRoster?> _presenceRoster;

  /// The subscription piping the running presence service's [OcptPresenceService.rosterStream] onto
  /// [_presenceRoster], cancelled when the service stops.
  StreamSubscription<OcptPresenceRoster>? _presenceRosterForwarder;

  /// The service reading and writing a project's own relay pairing — what [pairProjectToRelay]
  /// saves the freshly minted pairing through before it ever talks to the relay.
  ///
  /// Built lazily, from `globalGetIt()`'s own [OcptSecretsManager], the first time it is actually
  /// read rather than in the constructor — exactly what makes that call optional: a caller with no
  /// reason to ever pair a project (most of this manager's own tests included) never needs
  /// [OcptSecretsManager] registered at all, precisely as passing [changesetService] in directly
  /// sidesteps the very same kind of `globalGetIt()` call for [OcptProjectsManager]/
  /// [OcptPropertiesManager] above. A test that does need one hands it in through the constructor
  /// instead — built over a fake secure-storage channel, exactly as
  /// `ocpt_sync_manager_snapshot_test.dart` already does for [joinFromRelay].
  OcptPairingService get pairingService => _pairingService ??= _buildPairingService();

  /// This project's current sync session, or null when none is running — see [startSyncSession].
  OcptSyncSession? get syncSession => _syncSession;

  /// The running session's current status, or null when no session is running. The session's own
  /// status stream never replays this to a new listener — read this first to seed a fresh
  /// subscriber, exactly as `OcptSyncSession.status`'s own doc comment says.
  OcptSyncStatus? get syncStatus => _syncSession?.status;

  /// The sync status across the whole session lifecycle: the running session's status, then null
  /// once it stops. Unlike the running session's own status stream, which is null when no session
  /// runs, it never goes null-*valued* to mean "no stream": it is one stream that outlives every
  /// session, so a widget subscribing to it once (seeded with [syncStatus]) keeps reflecting the
  /// truth as sessions start and stop underneath it. This is what the workspace's own status
  /// indicator listens to, since its session starts only *after* the workspace has already been
  /// built.
  Stream<OcptSyncStatus?> get syncStatusChanges => _syncStatus.valueStream;

  // TODO(borlnov): Read by the screen that resolves a screenplay conflict,
  // https://github.com/borlnov/open_cine_prod_tools/issues/116
  /// Every screenplay merge conflict the running session has raised so far, oldest first, or an
  /// empty list when no session is running.
  List<OcptScreenplayMergeConflict> get syncConflicts => _syncSession?.conflicts ?? const [];

  /// The running presence service's current roster, or null when none is running.
  /// [presenceRosterStream] never replays this to a new listener — read this first to seed a fresh
  /// subscriber, exactly as [syncStatus]'s own doc comment says.
  OcptPresenceRoster? get presenceRoster => _presenceService?.roster;

  /// The running presence service's own roster stream, or null when none is running.
  Stream<OcptPresenceRoster>? get presenceRosterStream => _presenceService?.rosterStream;

  /// The presence roster across the whole session lifecycle — the presence counterpart of
  /// [syncStatusChanges], and what the workspace's own presence indicator listens to for the same
  /// reason. Seed a fresh subscriber with [presenceRoster].
  Stream<OcptPresenceRoster?> get presenceRosterChanges => _presenceRoster.valueStream;

  /// Class constructor
  ///
  /// [projectsManager] and [propertiesManager] are the injectable seams over `globalGetIt()` a test
  /// hands in instead — `OcptScreenplayMergeService` needs a real, fully-wired
  /// `OcptScreenplayService` and a real device id getter, and [OcptProjectsManager]/
  /// [OcptPropertiesManager] are where those already live, exactly the pattern
  /// `OcptProjectsManager`'s own constructor already follows for the very same services. Passing
  /// [changesetService] directly (as this class's own tests do, with a bare
  /// `OcptChangesetService()`) skips that wiring entirely. [snapshotService] defaults to a bare
  /// `OcptSnapshotService()`, which needs no wiring at all — a test passes one built over its own
  /// temporary directory instead. [pairingService] is not read here at all — see [pairingService]'s
  /// own doc comment for why that matters.
  OcptSyncManager({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptChangesetService? changesetService,
    OcptSnapshotService? snapshotService,
    OcptPairingService? pairingService,
  }) : this._(
         logger: buildOcptLogsHelper(_loggerCategory),
         projectsManager: projectsManager,
         propertiesManager: propertiesManager,
         changesetService: changesetService,
         snapshotService: snapshotService,
         pairingService: pairingService,
       );

  /// Class constructor, taking the one logger the services built here are given sub-loggers of.
  ///
  /// A constructor initializer list cannot see `this`, so the logger is built once by the public
  /// constructor and handed down as a parameter.
  OcptSyncManager._({
    required LogsHelper logger,
    required OcptProjectsManager? projectsManager,
    required OcptPropertiesManager? propertiesManager,
    required OcptChangesetService? changesetService,
    required OcptSnapshotService? snapshotService,
    required OcptPairingService? pairingService,
  }) : _logger = logger,
       _syncStatus = ValueKeeperWithStream<OcptSyncStatus?>(value: null, emitUnchangedValue: true),
       _presenceRoster = ValueKeeperWithStream<OcptPresenceRoster?>(
         value: null,
         emitUnchangedValue: true,
       ),
       changesetService =
           changesetService ??
           OcptChangesetService(
             logger: logger.createSubLogger(subCategory: 'changeset'),
             mergeService: OcptMergeService(
               logger: logger.createSubLogger(subCategory: 'merge'),
               screenplayMergeService: OcptScreenplayMergeService(
                 logger: logger.createSubLogger(subCategory: 'screenplay_merge'),
                 screenplayService: (projectsManager ?? globalGetIt().get<OcptProjectsManager>())
                     .screenplayService,
                 deviceId: (propertiesManager ?? globalGetIt().get<OcptPropertiesManager>())
                     .loadOrCreateDeviceId,
               ),
             ),
           ),
       snapshotService =
           snapshotService ??
           OcptSnapshotService(logger: logger.createSubLogger(subCategory: 'snapshot')),
       _pairingService = pairingService;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this manager owns: the changeset service (which initialises the merge
  /// services it owns), the snapshot service, and the pairing service when one was handed in. A
  /// pairing service built lazily is initialised when it is built.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await changesetService.initLifeCycle();
    await snapshotService.initLifeCycle();
    await _pairingService?.initLifeCycle();

    _logger.i("The sync manager started");
  }

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
    logger: _logger.createSubLogger(subCategory: 'relay_storage'),
    relayBaseUri: pairing.relayBaseUri,
    projectId: projectId,
    token: pairing.token,
    enrolmentSecret: enrolmentSecret,
  );

  /// Pairs [projectId] to the relay at [relayBaseUri], pushes this replica's own edits to create it
  /// there, publishes a first snapshot so a joiner can bootstrap, and starts the ongoing sync
  /// session — the create-and-share orchestration the Partager screen's "pair and create on the
  /// relay" action calls, returning the invite that screen renders as a QR code.
  ///
  /// In order:
  ///
  /// 1. Mints a fresh project token — full-entropy machine output (a plain `Uuid().v4()`), never
  ///    typed by a human, as a project token always is (as opposed to [enrolmentSecret], the
  ///    instance-wide secret handed to this call, never minted by it).
  /// 2. Saves [projectId]'s pairing to [relayBaseUri] with that token through [pairingService],
  ///    before the relay has even heard of the project — so a failure past this point still leaves
  ///    the pairing recorded, exactly as a real pairing that a later retry (or a manual re-pair)
  ///    can reuse rather than minting a second token.
  /// 3. Opens the relay transport with [openRelayRemoteStorage], carrying [enrolmentSecret] so the
  ///    very first append below is allowed to create [projectId] on that relay.
  /// 4. Pushes [database]'s own un-pushed local edits to that transport
  ///    ([OcptChangesetService.pushLocalEdits]) — the append that actually creates the project on
  ///    the relay.
  /// 5. Reads how far that push just advanced this replica's own delivery cursor
  ///    ([OcptChangesetService.highestAppendedSequence]) and [publishSnapshot]s the project as of
  ///    that position, so a joiner fetching the relay's latest snapshot lands exactly there
  ///    (the first device to append uploads a snapshot).
  /// 6. [startSyncSession]s against the same transport for the ongoing sync — [enrolmentSecret]
  ///    being sent again on whatever it appends from here on is harmless, per
  ///    [openRelayRemoteStorage]'s own doc comment.
  ///
  /// A step the relay refuses or cannot be reached for is answered as [OcptSyncFlowStatus.rejected]
  /// or [OcptSyncFlowStatus.unreachable] (the detail in the result's `extraInfo`), and any other
  /// failure (the database, the packaging of the snapshot) still propagates to the caller. Either
  /// way no sync session is left dangling: [startSyncSession] is the last step, so a failure
  /// anywhere before it never starts one at all.
  Future<ResultWithStatus<OcptSyncFlowStatus, OcptRelayInvite>> pairProjectToRelay({
    required OcptProjectDatabase database,
    required String projectId,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required Uri relayBaseUri,
    required String enrolmentSecret,
    required String deviceId,
  }) async {
    final token = const Uuid().v4();

    await pairingService.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: token,
    );

    final pairing = OcptProjectPairing(relayBaseUri: relayBaseUri, token: token);
    final relayId = relayIdFor(pairing);
    final storage = openRelayRemoteStorage(pairing, projectId, enrolmentSecret: enrolmentSecret);

    final pushed = await changesetService.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );
    if (!pushed.status.isSuccess) {
      return ResultWithStatus(status: _flowStatusOf(pushed.status), extraInfo: pushed.extraInfo);
    }

    final sequenceUpTo = await changesetService.highestAppendedSequence(
      database: database,
      relayId: relayId,
    );
    final published = await publishSnapshot(
      storage: storage,
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      sequenceUpTo: sequenceUpTo,
    );
    if (!published.status.isSuccess) {
      return ResultWithStatus(status: published.status, extraInfo: published.extraInfo);
    }

    await startSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
    );

    _logger.i("A project was paired with a relay: $projectId");

    return ResultWithStatus(
      status: OcptSyncFlowStatus.ok,
      value: OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: token),
    );
  }

  /// Re-points [projectId] at a new relay (typically the on-set relay), reusing its **existing**
  /// project token, pushes this replica's own edits to create it there, publishes a fresh snapshot
  /// so the next joiner bootstraps against [relayBaseUri], and restarts the ongoing sync session —
  /// the "Changer de relais" flow's own orchestration.
  ///
  /// This is [pairProjectToRelay] with exactly one difference: it never mints a token. Where
  /// [pairProjectToRelay] creates a brand new pairing (a fresh [Uuid] token for a project never
  /// paired before), this recovers [projectId]'s current token from its existing pairing and
  /// carries that same token forward to [relayBaseUri] — a project keeps one project token for its
  /// whole life, whichever relay currently holds it. [enrolmentSecret] here is the *set relay's*
  /// own instance-wide secret (the one scanned off its `ocpt://relay` enrolment QR,
  /// `OcptRelayEnrolment`), not the token: it plays exactly the role [pairProjectToRelay]'s own
  /// [enrolmentSecret] plays for the very first relay.
  ///
  /// This returns nothing, unlike [pairProjectToRelay]: the caller already holds the enrolment
  /// information it needs to show the next QR (the operator typed or scanned [relayBaseUri] and
  /// [enrolmentSecret] to get here), so there is nothing new to hand back.
  ///
  /// In order:
  ///
  /// 1. Loads [projectId]'s current pairing through [pairingService]. A null pairing means
  ///    [projectId] was never paired to any relay — re-pointing has no existing token to reuse, so
  ///    this answers [OcptSyncFlowStatus.notPaired] rather than silently minting one (that is what
  ///    [pairProjectToRelay] is for).
  /// 2. Re-saves [projectId]'s pairing through [pairingService], to the new [relayBaseUri] but with
  ///    the very same token — [OcptPairingService.savePairing] upserts by [projectId], so this
  ///    overwrites the single `sync_pairings` row in place rather than adding a second one.
  /// 3. Opens the relay transport with [openRelayRemoteStorage], carrying [enrolmentSecret] so the
  ///    very first append below is allowed to create [projectId] on that relay, exactly as
  ///    [pairProjectToRelay] does for a brand new one.
  /// 4. Pushes [database]'s own un-pushed local edits to that transport
  ///    ([OcptChangesetService.pushLocalEdits]).
  /// 5. Reads how far that push just advanced this replica's own delivery cursor
  ///    ([OcptChangesetService.highestAppendedSequence]) and [publishSnapshot]s the project as of
  ///    that position, so a joiner fetching this relay's latest snapshot lands exactly there.
  /// 6. [startSyncSession]s against the same transport for the ongoing sync.
  ///
  /// [relayIdFor] keys a pairing's delivery cursor by relay base URL, so re-pointing to a
  /// different [relayBaseUri] deliberately starts a fresh cursor rather than reusing the old
  /// relay's — the same project living behind two relays (say, the prep relay and the set relay)
  /// keeps one delivery cursor per relay, per [relayIdFor]'s own doc comment, and re-pointing back
  /// to a relay this replica has talked to before simply resumes that relay's own cursor.
  ///
  /// Fails exactly as [pairProjectToRelay] does, and leaves no sync session dangling for the same
  /// reason.
  Future<StatusWithExtraInfo<OcptSyncFlowStatus>> repointProjectToRelay({
    required OcptProjectDatabase database,
    required String projectId,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required Uri relayBaseUri,
    required String enrolmentSecret,
    required String deviceId,
  }) async {
    final pairing = await pairingService.loadPairing(database: database, projectId: projectId);
    if (pairing == null) {
      // Re-pointing only ever moves an already-paired project to a new relay; pairing a new one is
      // [pairProjectToRelay]'s job.
      return const StatusWithExtraInfo(status: OcptSyncFlowStatus.notPaired);
    }
    final token = pairing.token;

    await pairingService.savePairing(
      database: database,
      projectId: projectId,
      relayBaseUri: relayBaseUri,
      token: token,
    );

    final newPairing = OcptProjectPairing(relayBaseUri: relayBaseUri, token: token);
    final relayId = relayIdFor(newPairing);
    final storage = openRelayRemoteStorage(newPairing, projectId, enrolmentSecret: enrolmentSecret);

    final pushed = await changesetService.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );
    if (!pushed.status.isSuccess) {
      return StatusWithExtraInfo(status: _flowStatusOf(pushed.status), extraInfo: pushed.extraInfo);
    }

    final sequenceUpTo = await changesetService.highestAppendedSequence(
      database: database,
      relayId: relayId,
    );
    final published = await publishSnapshot(
      storage: storage,
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      sequenceUpTo: sequenceUpTo,
    );
    if (!published.status.isSuccess) {
      return published;
    }

    await startSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
    );

    _logger.i("A project was re-pointed at another relay: $projectId");

    return const StatusWithExtraInfo(status: OcptSyncFlowStatus.ok);
  }

  /// Packages the project at [projectFilePath] as a snapshot and uploads it to [storage].
  ///
  /// This is what lets a joiner bootstrap against an otherwise-empty relay
  /// (the first device to append uploads a snapshot) and what a restore publishes through instead
  /// of a changeset — the Partager screen and the restore flow call this rather than talking to
  /// [snapshotService] or [storage] themselves.
  ///
  /// [sequenceUpTo] is the caller's own delivery cursor at the moment it decides to publish: the
  /// position in [storage]'s changeset log this snapshot already reflects, exactly as
  /// [OcptSnapshotDescriptor.sequenceUpTo]'s own doc comment describes.
  ///
  /// Answers [OcptSyncFlowStatus.rejected] or [OcptSyncFlowStatus.unreachable] when [storage]
  /// cannot take the upload, and [OcptSyncFlowStatus.snapshotFailed] when the project cannot be
  /// packaged.
  Future<StatusWithExtraInfo<OcptSyncFlowStatus>> publishSnapshot({
    required OcptRemoteStorage storage,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required OcptSequenceNumber sequenceUpTo,
  }) async {
    final built = await snapshotService.buildSnapshot(
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      sequenceUpTo: sequenceUpTo,
    );
    final snapshot = built.value;
    if (!built.status.isSuccess || snapshot == null) {
      return const StatusWithExtraInfo(status: OcptSyncFlowStatus.snapshotFailed);
    }
    final (descriptor, bytes) = snapshot;

    final uploaded = await storage.uploadSnapshot(descriptor, bytes);
    if (!uploaded.status.isSuccess) {
      return StatusWithExtraInfo(
        status: _flowStatusOf(uploaded.status),
        extraInfo: uploaded.extraInfo,
      );
    }

    _logger.i("A snapshot was published to the relay");

    return const StatusWithExtraInfo(status: OcptSyncFlowStatus.ok);
  }

  /// Fetches [storage]'s latest snapshot and materialises it as a new project under
  /// [parentDirectoryPath], pairing that new project with the relay [storage] talks to before
  /// handing back the `.ocpt` path it landed at.
  ///
  /// Answers [OcptSyncFlowStatus.emptyRelay] when [storage] holds no snapshot yet — an empty relay
  /// is not something to join, only to create (the Partager flow does that, by publishing the
  /// first one through [publishSnapshot]) — and [OcptSyncFlowStatus.rejected] or
  /// [OcptSyncFlowStatus.unreachable] when it cannot be asked at all. A snapshot that does not match
  /// its digest, cannot be unpacked or carries no pairing row of its own answers
  /// [OcptSyncFlowStatus.snapshotFailed].
  ///
  /// **How the project id, the relay address and the token are obtained**, since the newly
  /// materialised project has never been opened and so cannot be asked: the relay address and the
  /// token are exactly what the caller already used to build [storage] in the first place (the
  /// invite `{relayBaseUri, projectId, token}` the QR/manual-entry Rejoindre screen reads), so they
  /// are taken as plain parameters here rather than guessed back out of [storage], which — typed
  /// only as [OcptRemoteStorage] — carries neither. The **project id**, on the other hand, does not
  /// need to be carried by the invite at all: a snapshot is a package built off the sharer's own
  /// project file, and by the time anyone can publish one, the sharer's project already carries its
  /// own `sync_pairings` row — written by the very act of pairing that let them publish to this
  /// relay to begin with. That row travels inside the snapshot precisely as every other row does,
  /// so it is read back off the freshly materialised project itself, and the same value is written
  /// into this replica's own pairing, keeping every replica of the same project keyed by the same
  /// relay-side id.
  Future<ResultWithStatus<OcptSyncFlowStatus, String>> joinFromRelay({
    required OcptRemoteStorage storage,
    required String parentDirectoryPath,
    required OcptPairingService pairingService,
    required Uri relayBaseUri,
    required String token,
  }) async {
    final fetch = await storage.fetchLatestSnapshot();
    if (!fetch.status.isSuccess) {
      return ResultWithStatus(status: _flowStatusOf(fetch.status), extraInfo: fetch.extraInfo);
    }
    final fetched = fetch.value;
    if (fetched == null) {
      // Ask whoever shared the project to open it once so a first snapshot can be published.
      return const ResultWithStatus(status: OcptSyncFlowStatus.emptyRelay);
    }
    final (descriptor, bytes) = fetched;

    final applied = await snapshotService.applySnapshot(
      bytes: bytes,
      parentDirectoryPath: parentDirectoryPath,
      descriptor: descriptor,
    );
    final projectFilePath = applied.value;
    if (!applied.status.isSuccess || projectFilePath == null) {
      return const ResultWithStatus(status: OcptSyncFlowStatus.snapshotFailed);
    }

    final database = OcptProjectDatabase(File(projectFilePath));
    final String projectId;
    try {
      final snapshottedProjectId = await _readSnapshottedProjectId(database);
      if (snapshottedProjectId == null) {
        _logger.e("A joined snapshot carries no relay pairing of its own");
        return const ResultWithStatus(status: OcptSyncFlowStatus.snapshotFailed);
      }
      projectId = snapshottedProjectId;
      await pairingService.savePairing(
        database: database,
        projectId: projectId,
        relayBaseUri: relayBaseUri,
        token: token,
      );
    } finally {
      await database.close();
    }

    _logger.i("A project was joined from a relay: $projectId");

    return ResultWithStatus(status: OcptSyncFlowStatus.ok, value: projectFilePath);
  }

  /// Starts keeping [projectId] in sync against [storage], replacing whatever session was running
  /// before ([stopSyncSession] runs first, so calling this twice in a row is always safe).
  ///
  /// This is called **explicitly** by whoever decides a project should be syncing right now — the
  /// workspace, once it opens a paired project — never implicitly from a project-open lifecycle
  /// hook: this manager has no opinion on when a project deserves a session, only on how to run
  /// one.
  ///
  /// [database] must be [projectId]'s **writable** file
  /// (`OcptOpenProjectModel.fileDatabase`), never a read-only preview — see
  /// `OcptSyncSession`'s own doc comment. [relayId] is normally [relayIdFor] against the pairing
  /// [storage] itself came from ([openRelayRemoteStorage]'s own caller already has that pairing in
  /// hand); a caller syncing over an [OcptFolderRemoteStorage] instead picks its own stable id,
  /// since a directory has no URL to derive one from.
  ///
  /// Also starts an [OcptPresenceService] over the very same [storage] and [deviceId] — see
  /// [presenceRoster]/[presenceRosterStream]/[updatePresenceMode]. [presenceHeartbeatInterval] and
  /// [presencePeerTimeout] default exactly as [pushInterval] does, for the same reason: a test
  /// hands in much shorter ones so its own timer-driven assertions do not have to wait out the real
  /// defaults.
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
    await stopSyncSession();

    final session = OcptSyncSession(
      logger: _logger.createSubLogger(subCategory: 'session'),
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
      changesetService: changesetService,
      pushInterval: pushInterval,
    );
    _syncSession = session;

    final started = await session.start();
    if (!started.isSuccess) {
      // A session built a few lines above has never run, so this cannot happen; were it to, there
      // would be nothing more to set up around a session that is not ours to start.
      _logger.w("The sync session of project $projectId could not be started: $started");
      return;
    }
    // Pipe the new session's status onto the manager-level stream, seeded with the current one, so
    // an indicator built before this session started still learns about it — see
    // [_syncStatus].
    _sessionStatusForwarder = session.statusStream.listen((status) => _syncStatus.value = status);
    _syncStatus.value = session.status;

    final presenceService = OcptPresenceService(
      logger: _logger.createSubLogger(subCategory: 'presence'),
      storage: storage,
      deviceId: deviceId,
      heartbeatInterval: presenceHeartbeatInterval,
      peerTimeout: presencePeerTimeout,
    );
    _presenceService = presenceService;

    await presenceService.initLifeCycle();
    await presenceService.start();
    _presenceRosterForwarder = presenceService.rosterStream.listen(
      (roster) => _presenceRoster.value = roster,
    );
    _presenceRoster.value = presenceService.roster;

    _logger.i("A sync session started for project $projectId");
  }

  /// Unpairs [projectId] from whatever relay it was synced through — the Partager screen's own
  /// "stop sharing" action, once the page's own `OcptConfirmDialog` has confirmed it.
  ///
  /// [stopSyncSession] first, since a session kept running against a pairing whose token has just
  /// been deleted from secure storage would only fail on its very next push; then
  /// [pairingService].`clearPairing` removes [database]'s own `sync_pairings` row and the project
  /// token it named, leaving [projectId] exactly as unpaired as a project that never talked to a
  /// relay at all.
  Future<void> unpairProject({
    required OcptProjectDatabase database,
    required String projectId,
  }) async {
    await stopSyncSession();
    await pairingService.clearPairing(database: database, projectId: projectId);
  }

  /// The relay-side project id [database]'s own single `sync_pairings` row carries, or null when
  /// the project is not paired to any relay yet — the read `OcptRelayHostManager` uses to decide
  /// between re-pointing an already-paired project at its own hosted relay and pairing a
  /// never-paired one afresh.
  ///
  /// Read straight off the table, exactly as [_readSnapshottedProjectId] is, rather than through
  /// [OcptPairingService.loadPairing]: that also requires the project's token to already sit in
  /// secure storage and returns no project id of its own, where here only the id is wanted,
  /// whether or not the token half is present.
  Future<String?> loadPairedProjectId(OcptProjectDatabase database) async {
    final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();

    return row?.projectId;
  }

  /// Stops the current sync session, if any — cancels its timer and its `newWorkStream`
  /// subscription and closes its status stream — and disposes the current presence service
  /// alongside it, if any (which stops it). Safe to call with no session (or presence service) running.
  ///
  /// Closes the manager-level [syncStatusChanges]/[presenceRosterChanges] out with a null, so an
  /// indicator listening to them hides again when the session ends, and stops forwarding the
  /// now-dead session's own streams onto them.
  Future<void> stopSyncSession() async {
    final hadSession = _syncSession != null;

    await _sessionStatusForwarder?.cancel();
    _sessionStatusForwarder = null;
    await _presenceRosterForwarder?.cancel();
    _presenceRosterForwarder = null;

    final session = _syncSession;
    _syncSession = null;
    await session?.stop();

    final presenceService = _presenceService;
    _presenceService = null;
    await presenceService?.disposeLifeCycle();

    if (hadSession) {
      _syncStatus.value = null;
      _presenceRoster.value = null;
      _logger.i("The sync session stopped");
    }
  }

  /// Runs a sync right now against the running session, on demand — what the status indicator's
  /// tap calls. Answers [OcptSyncSessionStatus.notRunning] when no session is running.
  Future<OcptSyncSessionStatus> syncNow() async {
    final session = _syncSession;
    if (session == null) {
      return OcptSyncSessionStatus.notRunning;
    }

    await session.syncNow();

    return OcptSyncSessionStatus.ok;
  }

  /// Tells the running presence service this replica's own [mode] just changed, so it reaches
  /// every peer on the very next heartbeat rather than waiting for the current one to age. Does
  /// nothing when no presence service is running.
  void updatePresenceMode(OcptWorkspaceMode mode) => _presenceService?.updateMode(mode);

  /// Builds the lazily created [pairingService] and initialises it.
  ///
  /// The getter cannot wait, so the initialisation is not awaited: the service's own
  /// `initLifeCycle()` does nothing today, and one that ever does must be built eagerly instead.
  OcptPairingService _buildPairingService() {
    final service = OcptPairingService(
      logger: _logger.createSubLogger(subCategory: 'pairing'),
      secretsManager: globalGetIt().get<OcptSecretsManager>(),
    );
    unawaited(service.initLifeCycle());
    return service;
  }

  /// The [OcptSyncFlowStatus] a failed [OcptRemoteStorageStatus] stands for.
  OcptSyncFlowStatus _flowStatusOf(OcptRemoteStorageStatus status) => switch (status) {
    OcptRemoteStorageStatus.ok => OcptSyncFlowStatus.ok,
    OcptRemoteStorageStatus.rejected => OcptSyncFlowStatus.rejected,
    OcptRemoteStorageStatus.unreachable => OcptSyncFlowStatus.unreachable,
  };

  /// The relay-side project id a freshly materialised snapshot already carries in its own
  /// `sync_pairings` row — see [joinFromRelay]'s own doc comment for why that row is there at all.
  ///
  /// Read directly off the table rather than through [OcptPairingService.loadPairing]: that method
  /// also requires the project's token to already sit in secure storage, which a joiner's fresh
  /// install never has yet — the whole reason [joinFromRelay] is the one saving that pairing, not
  /// reading an existing one.
  ///
  /// Returns null when the snapshot carries no such row: it cannot be identified on the relay it
  /// was fetched from, and a snapshot from the network is not trusted to have one.
  Future<String?> _readSnapshottedProjectId(OcptProjectDatabase database) async {
    final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();
    return row?.projectId;
  }

  /// The stable id [changesetService] keys a pairing's own delivery cursor by
  /// (`sync_relay_cursors.relayId`): [pairing]'s relay base URL, stringified.
  ///
  /// This has to stay stable for as long as a project is paired with the same relay — restarting or
  /// re-pairing to the very same address must not reset the cursor — and differ between two
  /// different relays, since a device keeps one delivery cursor per relay and the same project can
  /// live behind two relays in one day (the prep relay and the set relay). The relay base URL
  /// already has exactly that shape, so nothing further is minted or stored for it.
  static String relayIdFor(OcptProjectPairing pairing) => pairing.relayBaseUri.toString();

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    _logger.i("The sync manager is being disposed");
    await stopSyncSession();
    await _syncStatus.disposeLifeCycle();
    await _presenceRoster.disposeLifeCycle();
    await _pairingService?.disposeLifeCycle();
    await snapshotService.disposeLifeCycle();
    await changesetService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
