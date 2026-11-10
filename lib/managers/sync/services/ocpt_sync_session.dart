// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_dart_value_keeper/act_dart_value_keeper.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_changeset_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_merge_failure.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_transport_failure.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_remote_storage_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_session_status.dart';

/// How often [OcptSyncSession] runs [OcptChangesetService.syncOnce] on its own timer, with no
/// [OcptRemoteStorage.newWorkStream] ping and no [OcptSyncSession.syncNow] call from the user — the
/// long-interval fallback that gets this replica's own edits to the relay even on a day nobody
/// else's write ever pings it, now that the `newWorkStream` ping itself is the real driver of an
/// ordinary sync rather than this timer.
const ocptDefaultSyncPushInterval = Duration(seconds: 60);

/// Keep one project's replica converging against one relay for as long as it runs — the driver
/// `OcptSyncManager.startSyncSession` hands back so a paired project keeps itself in sync for as
/// long as it is open, with no further attention from anything above it. This class does not decide
/// *when* a project should be syncing — the workspace does that explicitly, once it opens or closes
/// a paired project.
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
/// reads an old version, as the sync design requires (`docs/architecture/sync.md`). This class
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
/// — the one conflict a user is ever asked to resolve, for a screenplay conflict view to read. This
/// class only collects them; it builds no UI of its own.
class OcptSyncSession extends AbsOcptService {
  /// The project this session keeps in sync.
  final String projectId;

  /// The project's own writable file — see this class's own doc comment for why this may never be
  /// a preview.
  final OcptProjectDatabase database;

  /// This replica's own id, the same one every changeset it pushes is stamped with.
  final String deviceId;

  /// The id [OcptChangesetService] keys this session's own delivery cursor by
  /// (`sync_relay_cursors.relayId`) — stable for as long as [storage] points at the same relay, and
  /// different from any other relay's own id, since a device keeps one delivery cursor per relay
  /// and the same project can live behind two relays in one day (the prep relay and the set relay).
  /// `OcptSyncManager.relayIdFor` is how a caller derives this for a real pairing.
  final String relayId;

  /// The transport this session pushes to and pulls from.
  final OcptRemoteStorage storage;

  /// The engine actually doing the push and the pull; `OcptSyncManager` hands this session its own
  /// instance, already wired to a real screenplay merge service and device id getter.
  final OcptChangesetService changesetService;

  /// How often this session runs [OcptChangesetService.syncOnce] on its own timer.
  final Duration pushInterval;

  /// The current status, exposed through [status] and [statusStream].
  ///
  /// It emits every value it is given, even one equal to the previous: a run reporting the same
  /// status again is still reported.
  final ValueKeeperWithStream<OcptSyncStatus> _status;

  /// Whether [_status] has been disposed by [stop], after which it must not be written to.
  bool _isStatusClosed;

  /// The merge conflicts met so far, exposed through [conflicts].
  final List<OcptScreenplayMergeConflict> _conflicts;

  /// The subscription to the new work the storage announces, or null while the session is stopped.
  StreamSubscription<void>? _newWorkSubscription;

  /// The timer of the periodic sync, or null while the session is stopped.
  Timer? _pushTimer;

  /// Whether the session is started.
  bool _isRunning;

  /// Whether the last run that settled left this session offline, and no run has since settled
  /// in sync or on a relay error.
  ///
  /// It is a flag of its own because every run starts by moving [_status] to syncing, so by the
  /// time a failure is told the status no longer says whether the session was offline before it.
  bool _wasOffline;

  /// Get this session's current status. [statusStream] never replays it to a new listener — read
  /// this
  /// first to seed a fresh subscriber, exactly as this class's own doc comment says.
  OcptSyncStatus get status => _status.value;

  /// Emit every status this session moves through from the moment a listener subscribes onward —
  /// never its current value at subscription time (see [status] and this class's own doc comment).
  Stream<OcptSyncStatus> get statusStream => _status.valueStream;

  /// Get every [OcptScreenplayMergeConflict] raised by any run since this session started, oldest
  /// first.
  List<OcptScreenplayMergeConflict> get conflicts => List.unmodifiable(_conflicts);

  /// Tell whether [start] has run and [stop] has not been called since.
  bool get isRunning => _isRunning;

  /// Class constructor
  ///
  /// [pushInterval] defaults to [ocptDefaultSyncPushInterval]; a test hands in a much shorter one
  /// so its own timer-driven assertions do not have to wait out the real default.
  OcptSyncSession({
    required super.logger,
    required this.projectId,
    required this.database,
    required this.deviceId,
    required this.relayId,
    required this.storage,
    required this.changesetService,
    this.pushInterval = ocptDefaultSyncPushInterval,
  }) : _status = ValueKeeperWithStream<OcptSyncStatus>(
         value: const OcptSyncStatusInSync(),
         emitUnchangedValue: true,
       ),
       _isStatusClosed = false,
       _conflicts = [],
       _isRunning = false,
       _wasOffline = false;

  /// Run an initial sync, then subscribe to [storage]'s [OcptRemoteStorage.newWorkStream] and start
  /// the [pushInterval] timer.
  ///
  /// The initial sync runs and settles first, so a listener attached right after this returns
  /// never races it: [status] already reflects that first run's own outcome, subscribing and
  /// arming the timer only happen once it is done. Answers [OcptSyncSessionStatus.alreadyRunning],
  /// and does nothing, when this session is already running — call [stop] first to restart it.
  Future<OcptSyncSessionStatus> start() async {
    if (_isRunning) {
      return OcptSyncSessionStatus.alreadyRunning;
    }
    _isRunning = true;

    await _runSyncOnce();

    _newWorkSubscription = storage.newWorkStream.listen((_) => unawaited(_runPullOnly()));
    _pushTimer = Timer.periodic(pushInterval, (_) => unawaited(_runSyncOnce()));

    return OcptSyncSessionStatus.ok;
  }

  /// Cancel the [pushInterval] timer and the [OcptRemoteStorage.newWorkStream] subscription, and
  /// close [statusStream] — nothing this session holds outlives this call. Safe to call more than
  /// once, and safe to call before [start] ever ran.
  Future<void> stop() async {
    _isRunning = false;
    await _newWorkSubscription?.cancel();
    _newWorkSubscription = null;
    _pushTimer?.cancel();
    _pushTimer = null;
    if (!_isStatusClosed) {
      _isStatusClosed = true;
      await _status.disposeLifeCycle();
    }
  }

  /// Run [OcptChangesetService.syncOnce] once, on demand — what the status indicator's tap calls.
  Future<void> syncNow() => _runSyncOnce();

  /// React to a [OcptRemoteStorage.newWorkStream] ping: only [OcptChangesetService.pullAndApply]
  /// runs, since a ping means another replica pushed something, not that this one has anything new
  /// of its own to push — [pushInterval]'s own timer is what pushes this replica's own edits.
  Future<void> _runPullOnly() async {
    _setStatus(const OcptSyncStatusSyncing());
    try {
      final result = await changesetService.pullAndApply(
        database: database,
        storage: storage,
        relayId: relayId,
      );
      await _settle(result, failureLabel: 'Sync pull failed');
    } catch (error, stackTrace) {
      await _goOffline(error, stackTrace, failureLabel: 'Sync pull failed');
    }
  }

  /// Run one sync through the changeset service and settle the status on its result.
  Future<void> _runSyncOnce() async {
    _setStatus(const OcptSyncStatusSyncing());
    try {
      final result = await changesetService.syncOnce(
        database: database,
        storage: storage,
        relayId: relayId,
        deviceId: deviceId,
      );
      await _settle(result, failureLabel: 'Sync failed');
    } catch (error, stackTrace) {
      // Only [database] still throws: the transport answers a status.
      await _goOffline(error, stackTrace, failureLabel: 'Sync failed');
    }
  }

  /// Move this session to the status [result] stands for: in sync with its conflicts collected,
  /// an error carrying the relay's own message when the relay refused the call, or offline when the
  /// transport could not reach it.
  Future<void> _settle(
    ResultWithStatus<OcptRemoteStorageStatus, List<OcptScreenplayMergeConflict>> result, {
    required String failureLabel,
  }) async {
    final conflicts = result.value;
    if (result.status.isSuccess && conflicts != null) {
      _conflicts.addAll(conflicts);
      _setStatus(const OcptSyncStatusInSync());
      return;
    }

    final detail = result.extraInfo;
    if (detail is OcptSyncError) {
      _setStatus(OcptSyncStatusError(detail.message));
      return;
    }

    if (detail is OcptSyncTransportFailure) {
      await _goOffline(detail.error, detail.stackTrace, failureLabel: failureLabel);
      return;
    }

    if (detail is OcptSyncMergeFailure) {
      await _goOffline(detail.error, detail.stackTrace, failureLabel: failureLabel);
      return;
    }

    await _goOffline(result.status, null, failureLabel: failureLabel);
  }

  /// Log [error] as what knocked this session offline, and move it to
  /// [OcptSyncStatusOffline] with however many edits are still waiting to be pushed.
  Future<void> _goOffline(
    Object error,
    StackTrace? stackTrace, {
    required String failureLabel,
  }) async {
    logger.w('$failureLabel for project $projectId: ${_typeOf(error)}', null, stackTrace);
    _logOfflineCause(error);
    _setStatus(OcptSyncStatusOffline(pendingEditCount: await _pendingEditCountOrNull()));
  }

  /// Get [OcptChangesetService.countUnpushedEdits] against [database], or null when even that cheap
  /// read itself failed — an [OcptSyncStatusOffline] with no count is still a valid status, per its
  /// own doc comment.
  Future<int?> _pendingEditCountOrNull() async {
    int? count;
    try {
      count = await changesetService.countUnpushedEdits(
        database: database,
        relayId: relayId,
        deviceId: deviceId,
      );
    } catch (error, stackTrace) {
      logger.w(
        'Could not compute the pending edit count for project $projectId: ${error.runtimeType}',
        null,
        stackTrace,
      );
    }

    return count;
  }

  /// Record [status], emit it on [statusStream] unless that is closed, and log it.
  void _setStatus(OcptSyncStatus status) {
    if (status is OcptSyncStatusInSync || status is OcptSyncStatusError) {
      _wasOffline = false;
    }
    if (!_isStatusClosed) {
      _status.value = status;
    }
    _logDiagnostics(status);
  }

  /// Record the [error] that has just knocked this session offline into the device-local
  /// diagnostics buffer — the message alone, since the stack trace stays in the file log
  /// ([logger]) — but **only on the way into** offline, not while it stays there. The offline
  /// status itself logs every push interval it fails on; its cause is logged once, so the
  /// diagnostics view names *why* syncing stopped (an unreachable relay, a closed database, …)
  /// without the reason scrolling past on every retry.
  void _logOfflineCause(Object error) {
    if (_wasOffline) {
      return;
    }

    _wasOffline = true;
    OcptDiagnosticsManager.log(
      category: OcptDiagnosticsCategory.sync,
      level: OcptDiagnosticsLevel.error,
      message: 'offline cause: project=$projectId $error',
      // An error's text can name a host or a path.
      logMessage: 'offline cause: project=$projectId ${_typeOf(error)}',
    );
  }

  /// Get the type [error] stands for in a log line: [error] itself when it already is a type, as
  /// the one a service that answered a failure names what failed with, else its own type.
  Type _typeOf(Object error) => error is Type ? error : error.runtimeType;

  /// Record [status]'s own transition into the device-local diagnostics buffer — one line per
  /// status this session moves through, so a "why did syncing stop" question can be answered from
  /// the very device it stopped on.
  void _logDiagnostics(OcptSyncStatus status) {
    switch (status) {
      case OcptSyncStatusSyncing():
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.sync,
          message: 'syncing: project=$projectId',
          isRoutine: true,
        );
      case OcptSyncStatusInSync():
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.sync,
          message: 'in sync: project=$projectId',
          isRoutine: true,
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
          // The message comes from the relay's answer and is not known to be free of detail.
          logMessage: 'error: project=$projectId',
        );
    }
  }
}
