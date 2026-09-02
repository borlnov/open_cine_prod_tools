// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_folder_remote_storage.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_merge_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_presence_service.dart';
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

  /// The service turning a project into snapshot bytes and back — what [publishSnapshot] and
  /// [joinFromRelay] build on (`docs/plans/relay.md`, Phase C, commit 1).
  final OcptSnapshotService snapshotService;

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
  OcptPairingService get pairingService =>
      _pairingService ??= OcptPairingService(secretsManager: globalGetIt().get<OcptSecretsManager>());
  OcptPairingService? _pairingService;

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
  }) : changesetService =
           changesetService ??
           OcptChangesetService(
             mergeService: OcptMergeService(
               screenplayMergeService: OcptScreenplayMergeService(
                 screenplayService: (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
                 deviceId: (propertiesManager ?? globalGetIt().get<OcptPropertiesManager>()).loadOrCreateDeviceId,
               ),
             ),
           ),
       snapshotService = snapshotService ?? const OcptSnapshotService(),
       _pairingService = pairingService;

  /// This project's current sync session, or null when none is running — see [startSyncSession].
  OcptSyncSession? get syncSession => _syncSession;
  OcptSyncSession? _syncSession;

  /// This project's current presence service, or null when none is running — see
  /// [startSyncSession] and `docs/plans/presence.md` (M5, Phase B).
  OcptPresenceService? _presenceService;

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

  /// Pairs [projectId] to the relay at [relayBaseUri], pushes this replica's own edits to create
  /// it there, publishes a first snapshot so a joiner can bootstrap, and starts the ongoing sync
  /// session — the create-and-share orchestration the Partager screen's "pair and create on the
  /// relay" action calls (`docs/plans/relay.md`, Phase C, commit 3), returning the invite that
  /// screen renders as a QR code.
  ///
  /// In order:
  ///
  /// 1. Mints a fresh project token — full-entropy machine output (a plain `Uuid().v4()`), never
  ///    typed by a human, exactly as `docs/plans/collaboration-and-sync.md` §5.2 requires of a
  ///    project token (as opposed to [enrolmentSecret], the instance-wide secret handed to this
  ///    call, never minted by it).
  /// 2. Saves [projectId]'s pairing to [relayBaseUri] with that token through [pairingService],
  ///    before the relay has even heard of the project — so a failure past this point still leaves
  ///    the pairing recorded, exactly as a real pairing that a later retry (or a manual re-pair)
  ///    can reuse rather than minting a second token.
  /// 3. Opens the relay transport with [openRelayRemoteStorage], carrying [enrolmentSecret] so the
  ///    very first append below is allowed to create [projectId] on that relay
  ///    (`docs/plans/collaboration-and-sync.md` §5.2).
  /// 4. Pushes [database]'s own un-pushed local edits to that transport
  ///    ([OcptChangesetService.pushLocalEdits]) — the append that actually creates the project on
  ///    the relay.
  /// 5. Reads how far that push just advanced this replica's own delivery cursor
  ///    ([OcptChangesetService.highestAppendedSequence]) and [publishSnapshot]s the project as of
  ///    that position, so a joiner fetching the relay's latest snapshot lands exactly there
  ///    (`docs/plans/collaboration-and-sync.md` §5.3: "the first device to append uploads a
  ///    snapshot").
  /// 6. [startSyncSession]s against the same transport for the ongoing sync — [enrolmentSecret]
  ///    being sent again on whatever it appends from here on is harmless, per
  ///    [openRelayRemoteStorage]'s own doc comment.
  ///
  /// A failure at any step (the transport throwing, most likely) propagates to the caller rather
  /// than being swallowed, and leaves no sync session dangling: [startSyncSession] is the last
  /// step, so a failure anywhere before it never starts one at all.
  Future<OcptRelayInvite> pairProjectToRelay({
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

    await changesetService.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );

    final sequenceUpTo = await changesetService.highestAppendedSequence(
      database: database,
      relayId: relayId,
    );
    await publishSnapshot(
      storage: storage,
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      sequenceUpTo: sequenceUpTo,
    );

    await startSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
    );

    return OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: token);
  }

  /// Re-points [projectId] at a new relay (typically the on-set relay), reusing its **existing**
  /// project token, pushes this replica's own edits to create it there, publishes a fresh snapshot
  /// so the next joiner bootstraps against [relayBaseUri], and restarts the ongoing sync session —
  /// the "Changer de relais" flow's own orchestration (`docs/plans/on-set-server.md`, Phase D).
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
  ///    this throws a [StateError] rather than silently minting one (that is what
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
  /// A failure at any step (the transport throwing, most likely) propagates to the caller rather
  /// than being swallowed, and leaves no sync session dangling: [startSyncSession] is the last
  /// step, so a failure anywhere before it never starts one at all.
  Future<void> repointProjectToRelay({
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
      throw StateError(
        'Cannot re-point project "$projectId" to a new relay: it has no existing pairing to '
        'reuse a token from. Re-pointing only ever moves an already-paired project to a new '
        'relay; pair it first through pairProjectToRelay.',
      );
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

    await changesetService.pushLocalEdits(
      database: database,
      storage: storage,
      relayId: relayId,
      deviceId: deviceId,
    );

    final sequenceUpTo = await changesetService.highestAppendedSequence(
      database: database,
      relayId: relayId,
    );
    await publishSnapshot(
      storage: storage,
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      sequenceUpTo: sequenceUpTo,
    );

    await startSyncSession(
      projectId: projectId,
      database: database,
      deviceId: deviceId,
      relayId: relayId,
      storage: storage,
    );
  }

  /// Packages the project at [projectFilePath] as a snapshot and uploads it to [storage].
  ///
  /// This is what lets a joiner bootstrap against an otherwise-empty relay
  /// (`docs/plans/collaboration-and-sync.md` §5.3: "the first device to append uploads a
  /// snapshot") and what a restore publishes through instead of a changeset (§3.4) — the Partager
  /// screen and the restore flow are later commits that call this rather than talking to
  /// [snapshotService] or [storage] themselves.
  ///
  /// [sequenceUpTo] is the caller's own delivery cursor at the moment it decides to publish: the
  /// position in [storage]'s changeset log this snapshot already reflects, exactly as
  /// [OcptSnapshotDescriptor.sequenceUpTo]'s own doc comment describes.
  Future<void> publishSnapshot({
    required OcptRemoteStorage storage,
    required String projectFilePath,
    required String projectName,
    required String appVersion,
    required OcptSequenceNumber sequenceUpTo,
  }) async {
    final (descriptor, bytes) = await snapshotService.buildSnapshot(
      projectFilePath: projectFilePath,
      projectName: projectName,
      appVersion: appVersion,
      sequenceUpTo: sequenceUpTo,
    );

    await storage.uploadSnapshot(descriptor, bytes);
  }

  /// Fetches [storage]'s latest snapshot and materialises it as a new project under
  /// [parentDirectoryPath], pairing that new project with the relay [storage] talks to before
  /// handing back the `.ocpt` path it landed at.
  ///
  /// Throws [StateError] when [storage] holds no snapshot yet — an empty relay is not something to
  /// join, only to create (the Partager flow does that, by publishing the first one through
  /// [publishSnapshot]).
  ///
  /// **How the project id, the relay address and the token are obtained**, since the newly
  /// materialised project has never been opened and so cannot be asked: the relay address and the
  /// token are exactly what the caller already used to build [storage] in the first place (the
  /// invite `{relayBaseUri, projectId, token}` a later commit's QR/manual-entry Rejoindre screen
  /// reads), so they are taken as plain parameters here rather than guessed back out of [storage],
  /// which — typed only as [OcptRemoteStorage] — carries neither. The **project id**, on the other
  /// hand, does not need to be carried by the invite at all: a snapshot is a package built off the
  /// sharer's own project file (`docs/plans/relay.md`, Phase C, commit 1), and by the time anyone
  /// can publish one, the sharer's project already carries its own `sync_pairings` row — written by
  /// the very act of pairing that let them publish to this relay to begin with. That row travels
  /// inside the snapshot precisely as every other row does, so it is read back off the freshly
  /// materialised project itself, and the same value is written into this replica's own pairing,
  /// keeping every replica of the same project keyed by the same relay-side id.
  Future<String> joinFromRelay({
    required OcptRemoteStorage storage,
    required String parentDirectoryPath,
    required OcptPairingService pairingService,
    required Uri relayBaseUri,
    required String token,
  }) async {
    final fetched = await storage.fetchLatestSnapshot();
    if (fetched == null) {
      throw StateError(
        'This relay holds no snapshot yet: there is nothing to join. Ask whoever shared the '
        'project to open it once so a first snapshot can be published.',
      );
    }
    final (descriptor, bytes) = fetched;

    final projectFilePath = await snapshotService.applySnapshot(
      bytes: bytes,
      parentDirectoryPath: parentDirectoryPath,
      descriptor: descriptor,
    );

    final database = OcptProjectDatabase(File(projectFilePath));
    try {
      final projectId = await _readSnapshottedProjectId(database);
      await pairingService.savePairing(
        database: database,
        projectId: projectId,
        relayBaseUri: relayBaseUri,
        token: token,
      );
    } finally {
      await database.close();
    }

    return projectFilePath;
  }

  /// The relay-side project id a freshly materialised snapshot already carries in its own
  /// `sync_pairings` row — see [joinFromRelay]'s own doc comment for why that row is there at all.
  ///
  /// Read directly off the table rather than through [OcptPairingService.loadPairing]: that method
  /// also requires the project's token to already sit in secure storage, which a joiner's fresh
  /// install never has yet — the whole reason [joinFromRelay] is the one saving that pairing, not
  /// reading an existing one.
  Future<String> _readSnapshottedProjectId(OcptProjectDatabase database) async {
    final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();
    if (row == null) {
      throw StateError(
        'The joined snapshot carries no relay pairing of its own: it cannot be identified on '
        'the relay it was fetched from.',
      );
    }

    return row.projectId;
  }

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
  ///
  /// Also starts an [OcptPresenceService] over the very same [storage] and [deviceId] — see
  /// [presenceRoster]/[presenceRosterStream]/[updatePresenceMode] and
  /// `docs/plans/presence.md` (M5, Phase B). [presenceHeartbeatInterval] and [presencePeerTimeout]
  /// default exactly as [pushInterval] does, for the same reason: a test hands in much shorter ones
  /// so its own timer-driven assertions do not have to wait out the real defaults.
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

    final presenceService = OcptPresenceService(
      storage: storage,
      deviceId: deviceId,
      heartbeatInterval: presenceHeartbeatInterval,
      peerTimeout: presencePeerTimeout,
    );
    _presenceService = presenceService;

    await presenceService.start();
  }

  /// Unpairs [projectId] from whatever relay it was synced through — the Partager screen's own
  /// "stop sharing" action, once the page's own `OcptConfirmDialog` has confirmed it
  /// (`docs/plans/relay.md`, Phase C, commit 3).
  ///
  /// [stopSyncSession] first, since a session kept running against a pairing whose token has just
  /// been deleted from secure storage would only fail on its very next push; then
  /// [pairingService].`clearPairing` removes [database]'s own `sync_pairings` row and the project
  /// token it named, leaving [projectId] exactly as unpaired as a project that never talked to a
  /// relay at all.
  Future<void> unpairProject({required OcptProjectDatabase database, required String projectId}) async {
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
  /// subscription and closes its status stream — and the current presence service alongside it,
  /// if any. Safe to call with no session (or presence service) running.
  Future<void> stopSyncSession() async {
    final session = _syncSession;
    _syncSession = null;
    await session?.stop();

    final presenceService = _presenceService;
    _presenceService = null;
    await presenceService?.stop();
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

  /// The running presence service's current roster, or null when none is running.
  /// [presenceRosterStream] never replays this to a new listener — read this first to seed a fresh
  /// subscriber, exactly as [syncStatus]'s own doc comment says.
  OcptPresenceRoster? get presenceRoster => _presenceService?.roster;

  /// The running presence service's own roster stream, or null when none is running.
  Stream<OcptPresenceRoster>? get presenceRosterStream => _presenceService?.rosterStream;

  /// Tells the running presence service this replica's own [mode] just changed, so it reaches
  /// every peer on the very next heartbeat rather than waiting for the current one to age. Does
  /// nothing when no presence service is running.
  void updatePresenceMode(OcptWorkspaceMode mode) => _presenceService?.updateMode(mode);

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await stopSyncSession();

    return super.disposeLifeCycle();
  }
}
