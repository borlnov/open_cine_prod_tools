// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';

/// How often [OcptSyncSession] runs [OcptChangesetService.syncOnce] on its own timer, with no
/// [OcptRemoteStorage.newWorkStream] ping and no [OcptSyncSession.syncNow] call from the user —
/// the long-interval fallback that gets this replica's own edits to the relay even on a day
/// nobody else's write ever pings it, now that the `newWorkStream` ping itself (M4/M5) is the real
/// driver of an ordinary sync rather than this timer (`docs/plans/presence.md`, M5, Phase B).
const ocptDefaultSyncPushInterval = Duration(seconds: 60);

/// Keeps one project's replica converging against one relay for as long as it runs —
/// `docs/plans/relay.md` (M4, Phase B, "wiring the transport in") and
/// `docs/plans/collaboration-and-sync.md` §3.2 and §3.5: the driver `OcptSyncManager.
/// startSyncSession` hands back so a paired project keeps itself in sync for as long as it is
/// open, with no further attention from anything above it. This class does not decide *when* a
/// project should be syncing — the workspace does that explicitly, once Phase C opens or closes a
/// paired project (`docs/plans/relay.md`).
///
/// [OcptChangesetService.syncOnce] — its existing push-then-pull, unchanged — runs three ways
/// against the very same [database], [relayId] and [deviceId]: once immediately from [start];
/// again every time [storage]'s [OcptRemoteStorage.newWorkStream] pings, since that is another
/// replica saying it just pushed something (though that path runs
/// [OcptChangesetService.pullAndApply] alone — there is nothing of this replica's own left to push
/// that the ping itself would know about); and on its own timer, every [pushInterval], so this
/// replica's own edits reach the relay without waiting for someone else's ping. [syncNow] runs a
/// fourth, on demand — what the status indicator's tap calls.
///
/// [database] is always the project's **writable** file (`OcptOpenProjectModel.fileDatabase`),
/// never a read-only preview: an incoming merge must land on the working copy even while the user
/// reads an old version, exactly as `docs/plans/collaboration-and-sync.md` §3.2 says. This class
/// never reads [database] itself beyond what [changesetService] already does — it only ever hands
/// it along.
///
/// Every run updates [status] and broadcasts it on [statusStream]: [OcptSyncStatusSyncing] while it
/// runs, then [OcptSyncStatusInSync] on success. A run never lets its exception escape this class:
/// an [OcptSyncError] — the relay itself rejecting the request, a bad token or a stale cursor —
/// becomes [OcptSyncStatusError] carrying its message; anything else (a refused connection, a
/// timeout, a dropped socket) is read as a reachability problem and becomes
/// [OcptSyncStatusOffline], carrying how many of this replica's own edits are still waiting to be
/// pushed when [OcptChangesetService.countUnpushedEdits] can say so. [statusStream] never replays
/// its current value to a late subscriber — no ACT stream does (`CLAUDE.md`'s own pitfalls list) —
/// so a caller seeds its own first render from [status] before it ever listens.
///
/// Every [OcptScreenplayMergeConflict] any run has raised so far is kept, in order, in [conflicts]
/// — the one conflict `docs/plans/collaboration-and-sync.md` §3.5 ever asks a user to resolve, for
/// whatever screenplay conflict view eventually reads it. This class only collects them; it builds
/// no UI of its own.
class OcptSyncSession {
  /// Class constructor
  ///
  /// [pushInterval] defaults to [ocptDefaultSyncPushInterval]; a test hands in a much shorter one
  /// so its own timer-driven assertions do not have to wait out the real default.
  OcptSyncSession({
    required this.projectId,
    required this.database,
    required this.deviceId,
    required this.relayId,
    required this.storage,
    required this.changesetService,
    this.pushInterval = ocptDefaultSyncPushInterval,
  });

  /// The project this session keeps in sync.
  final String projectId;

  /// The project's own writable file — see this class's own doc comment for why this may never be
  /// a preview.
  final OcptProjectDatabase database;

  /// This replica's own id, the same one every changeset it pushes is stamped with.
  final String deviceId;

  /// The id [OcptChangesetService] keys this session's own delivery cursor by
  /// (`sync_relay_cursors.relayId`) — stable for as long as [storage] points at the same relay,
  /// and different from any other relay's own id, exactly as §3.3/§5.3 of
  /// `docs/plans/collaboration-and-sync.md` require, since a device keeps one delivery cursor per
  /// relay and the same project can live behind two relays in one day (the prep relay and the set
  /// relay, M6). `OcptSyncManager.relayIdFor` is how a caller derives this for a real pairing.
  final String relayId;

  /// The transport this session pushes to and pulls from.
  final OcptRemoteStorage storage;

  /// The engine actually doing the push and the pull; `OcptSyncManager` hands this session its own
  /// instance, already wired to a real screenplay merge service and device id getter.
  final OcptChangesetService changesetService;

  /// How often this session runs [OcptChangesetService.syncOnce] on its own timer.
  final Duration pushInterval;

  OcptSyncStatus _status = const OcptSyncStatusInSync();
  final StreamController<OcptSyncStatus> _statusController = StreamController<OcptSyncStatus>.broadcast();
  final List<OcptScreenplayMergeConflict> _conflicts = [];

  StreamSubscription<void>? _newWorkSubscription;
  Timer? _pushTimer;
  bool _isRunning = false;

  /// This session's current status. [statusStream] never replays it to a new listener — read this
  /// first to seed a fresh subscriber, exactly as this class's own doc comment says.
  OcptSyncStatus get status => _status;

  /// Emits every status this session moves through from the moment a listener subscribes onward —
  /// never its current value at subscription time (see [status] and this class's own doc comment).
  Stream<OcptSyncStatus> get statusStream => _statusController.stream;

  /// Every [OcptScreenplayMergeConflict] raised by any run since this session started, oldest
  /// first.
  List<OcptScreenplayMergeConflict> get conflicts => List.unmodifiable(_conflicts);

  /// True once [start] has run and [stop] has not been called since.
  bool get isRunning => _isRunning;

  /// Runs an initial sync, then subscribes to [storage]'s [OcptRemoteStorage.newWorkStream] and
  /// starts the [pushInterval] timer.
  ///
  /// The initial sync runs and settles first, so a listener attached right after this returns
  /// never races it: [status] already reflects that first run's own outcome, subscribing and
  /// arming the timer only happen once it is done. Throws [StateError] when this session is
  /// already running — call [stop] first to restart it.
  Future<void> start() async {
    if (_isRunning) {
      throw StateError('OcptSyncSession is already running for project $projectId');
    }
    _isRunning = true;

    await _runSyncOnce();

    _newWorkSubscription = storage.newWorkStream.listen((_) => unawaited(_runPullOnly()));
    _pushTimer = Timer.periodic(pushInterval, (_) => unawaited(_runSyncOnce()));
  }

  /// Cancels the [pushInterval] timer and the [OcptRemoteStorage.newWorkStream] subscription, and
  /// closes [statusStream] — nothing this session holds outlives this call. Safe to call more than
  /// once, and safe to call before [start] ever ran.
  Future<void> stop() async {
    _isRunning = false;
    await _newWorkSubscription?.cancel();
    _newWorkSubscription = null;
    _pushTimer?.cancel();
    _pushTimer = null;
    if (!_statusController.isClosed) {
      await _statusController.close();
    }
  }

  /// Runs [OcptChangesetService.syncOnce] once, on demand — what the status indicator's tap calls.
  Future<void> syncNow() => _runSyncOnce();

  /// Reacts to a [OcptRemoteStorage.newWorkStream] ping: only [OcptChangesetService.pullAndApply]
  /// runs, since a ping means another replica pushed something, not that this one has anything new
  /// of its own to push — [pushInterval]'s own timer is what pushes this replica's own edits.
  Future<void> _runPullOnly() async {
    _setStatus(const OcptSyncStatusSyncing());
    try {
      final conflicts = await changesetService.pullAndApply(
        database: database,
        storage: storage,
        relayId: relayId,
      );
      _conflicts.addAll(conflicts);
      _setStatus(const OcptSyncStatusInSync());
    } on OcptSyncError catch (error) {
      _setStatus(OcptSyncStatusError(error.message));
    } catch (error, stackTrace) {
      _logWarning('Sync pull failed for project $projectId: $error\n$stackTrace');
      _setStatus(OcptSyncStatusOffline(pendingEditCount: await _pendingEditCountOrNull()));
    }
  }

  Future<void> _runSyncOnce() async {
    _setStatus(const OcptSyncStatusSyncing());
    try {
      final conflicts = await changesetService.syncOnce(
        database: database,
        storage: storage,
        relayId: relayId,
        deviceId: deviceId,
      );
      _conflicts.addAll(conflicts);
      _setStatus(const OcptSyncStatusInSync());
    } on OcptSyncError catch (error) {
      _setStatus(OcptSyncStatusError(error.message));
    } catch (error, stackTrace) {
      _logWarning('Sync failed for project $projectId: $error\n$stackTrace');
      _setStatus(OcptSyncStatusOffline(pendingEditCount: await _pendingEditCountOrNull()));
    }
  }

  /// [OcptChangesetService.countUnpushedEdits] against [database], or null when even that cheap
  /// read itself failed — an [OcptSyncStatusOffline] with no count is still a valid status, per its
  /// own doc comment.
  Future<int?> _pendingEditCountOrNull() async {
    try {
      return await changesetService.countUnpushedEdits(
        database: database,
        relayId: relayId,
        deviceId: deviceId,
      );
    } catch (error, stackTrace) {
      _logWarning('Could not compute the pending edit count for project $projectId: $error\n$stackTrace');

      return null;
    }
  }

  void _setStatus(OcptSyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
    _logDiagnostics(status);
  }

  /// Records [status]'s own transition into the device-local diagnostics buffer — one line per
  /// status this session moves through, so a "why did syncing stop" question can be answered from
  /// the very device it stopped on.
  void _logDiagnostics(OcptSyncStatus status) {
    switch (status) {
      case OcptSyncStatusSyncing():
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.sync,
          message: 'syncing: project=$projectId',
        );
      case OcptSyncStatusInSync():
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.sync,
          message: 'in sync: project=$projectId',
        );
      case OcptSyncStatusOffline(pendingEditCount: final pendingEditCount):
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.sync,
          level: OcptDiagnosticsLevel.warning,
          message: 'offline: project=$projectId pendingEdits=${pendingEditCount ?? "?"}',
        );
      case OcptSyncStatusError(message: final message):
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.sync,
          level: OcptDiagnosticsLevel.error,
          message: 'error: project=$projectId $message',
        );
    }
  }

  /// Logs [message] through `appLogger()` when a global manager instance actually exists, and
  /// does nothing otherwise.
  ///
  /// A unit test builds an [OcptSyncSession] directly, with no app-wide `AbsGlobalManager` behind
  /// it at all (see this file's own tests) — this class is instantiated straight from
  /// `OcptSyncManager`, never resolved through `globalGetIt()` itself, so nothing else already
  /// guarantees one is there. A failed sync is expected, ordinary behaviour this class already
  /// reports through [status]; the warning is a bonus for a real app's log file, never something
  /// worth crashing a test — or a session — over its own absence.
  void _logWarning(String message) {
    if (AbsGlobalManager.instance != null) {
      appLogger().w(message);
    }
  }
}
