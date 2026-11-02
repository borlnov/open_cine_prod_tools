// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_value_keeper/act_dart_value_keeper.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_level.dart';

/// The maximum number of entries [OcptDiagnosticsManager] keeps: appending past this cap drops
/// the oldest entry first.
const ocptDiagnosticsBufferCap = 500;

/// Build the [OcptDiagnosticsManager] instance registered by the global manager.
class OcptDiagnosticsManagerBuilder extends AbsLifeCycleFactory<OcptDiagnosticsManager> {
  /// Class constructor
  const OcptDiagnosticsManagerBuilder() : super(OcptDiagnosticsManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager];
}

/// A device-local diagnostics buffer — the last [ocptDiagnosticsBufferCap]
/// [OcptDiagnosticsEntry] records, oldest first — so Benoit can see, on each device, what the
/// relay server (when hosting) and the sync client are doing: debugging why one PC's hosting
/// stops the moment a phone joins needs to see both sides at once, and neither a hosting laptop
/// nor a joining phone on set has a real log file within reach. `OcptDiagnosticsLogList` is the
/// in-app "Journaux (diagnostic)" section reading it, placed where the hosting and joining actions
/// themselves live, so each device shows its own logs.
///
/// Every call site that records into this buffer goes through the guarded [log] convenience
/// rather than resolving this manager directly — exactly `OcptSyncSession._logWarning`'s own
/// `AbsGlobalManager.instance != null` guard — so a unit test with no manager environment (most of
/// this app's manager/bloc tests only ever touch `OcptGlobalManager.instance` to satisfy
/// `appLogger()`, never registering every manager) never trips over a diagnostics call it never
/// asked for.
///
/// [entriesStream] never replays its current value to a new listener — no ACT manager stream does
/// (`CLAUDE.md`'s own pitfalls list) — so a caller seeds its own first render from [entries]
/// before it ever listens, exactly as `OcptDiagnosticsLogList` does.
class OcptDiagnosticsManager extends AbsWithLifeCycle {
  /// The logger category linked to this manager.
  static const _loggerCategory = "diagnostics";

  /// The logger every recorded entry is forwarded to.
  final LogsHelper _logger;

  /// The buffer and its change stream. It holds an unmodifiable snapshot that is replaced on every
  /// change, and emits even when the snapshot compares equal to the previous one (lists compare by
  /// identity, so a replacement never does, but a cleared buffer cleared again must still emit).
  final ValueKeeperWithStream<List<OcptDiagnosticsEntry>> _entries;

  /// Whether [disposeLifeCycle] has closed the stream: an entry recorded afterwards still reaches
  /// the logger, but neither the buffer nor the stream.
  bool _isDisposed;

  /// Get every entry recorded so far, oldest first, capped at [ocptDiagnosticsBufferCap] — an
  /// unmodifiable view, so a caller can never mutate this manager's own buffer directly.
  List<OcptDiagnosticsEntry> get entries => _entries.value;

  /// Emit the full, oldest-first entry list every time it changes ([record]/[clear]) — never its
  /// current value at subscription time (see this class's own doc comment).
  Stream<List<OcptDiagnosticsEntry>> get entriesStream => _entries.valueStream;

  /// Build a manager with an empty buffer.
  OcptDiagnosticsManager()
    : _logger = buildOcptLogsHelper(_loggerCategory),
      _isDisposed = false,
      _entries = ValueKeeperWithStream<List<OcptDiagnosticsEntry>>(
        value: List.unmodifiable(<OcptDiagnosticsEntry>[]),
        emitUnchangedValue: true,
      );

  /// Append one entry to the buffer, dropping the oldest one once [ocptDiagnosticsBufferCap] is
  /// exceeded, and broadcast the updated list on [entriesStream].
  ///
  /// Also forwards the entry to this manager's logger, at the level [category]/[level] map to,
  /// prefixed with [category]'s own name — so the console and, when `logs.file.enabled` is true,
  /// the crash-survivable file external logger capture these hosting/sync/join/relay/presence
  /// events too, on top of this manager's own in-memory buffer.
  ///
  /// The buffer is device-local and shown to its own user, a log file is something a user may send
  /// away: a [message] carrying a detail that must not reach a log (a project's name, a network
  /// address, an error's text) passes a [logMessage] without it, which is what the logger gets
  /// instead. Left out, the logger gets [message] itself.
  ///
  /// An entry that repeats on a timer ([isRoutine], a sync session's every-minute "syncing" and "in
  /// sync") reaches the logger at debug level instead of info, so a log read for what happened is
  /// not drowned in it.
  void record({
    required OcptDiagnosticsCategory category,
    OcptDiagnosticsLevel level = OcptDiagnosticsLevel.info,
    required String message,
    String? logMessage,
    bool isRoutine = false,
  }) {
    final updated = [
      ..._entries.value,
      OcptDiagnosticsEntry(
        time: DateTime.now(),
        category: category,
        level: level,
        message: message,
      ),
    ];
    if (updated.length > ocptDiagnosticsBufferCap) {
      updated.removeAt(0);
    }
    _store(updated);

    _forwardToLogger(
      category: category,
      level: level,
      message: logMessage ?? message,
      isRoutine: isRoutine,
    );
  }

  /// Empty the buffer and broadcast the (now empty) list on [entriesStream] — what
  /// `OcptDiagnosticsLogList`'s own "clear" button calls.
  void clear() {
    _store([]);
  }

  /// Forward one entry to [_logger].
  void _forwardToLogger({
    required OcptDiagnosticsCategory category,
    required OcptDiagnosticsLevel level,
    required String message,
    required bool isRoutine,
  }) {
    final prefixedMessage = '[${category.name}] $message';
    switch (level) {
      case OcptDiagnosticsLevel.info:
        if (isRoutine) {
          _logger.d(prefixedMessage);
        } else {
          _logger.i(prefixedMessage);
        }
      case OcptDiagnosticsLevel.warning:
        _logger.w(prefixedMessage);
      case OcptDiagnosticsLevel.error:
        _logger.e(prefixedMessage);
    }
  }

  /// Replace the buffer by [updated] and broadcast it, unless this manager is disposed.
  void _store(List<OcptDiagnosticsEntry> updated) {
    if (_isDisposed) {
      // The keeper's stream is closed, and writing to it would throw.
      return;
    }

    _entries.value = List.unmodifiable(updated);
  }

  /// Record [message] against [category]/[level] through the registered [OcptDiagnosticsManager]
  /// — the guarded call site every instrumented manager/bloc uses, exactly
  /// `OcptSyncSession._logWarning`'s own reasoning: this no-ops, rather than throwing, whenever no
  /// global manager instance exists at all, or one exists but [OcptDiagnosticsManager] itself was
  /// never registered against it (most of this app's own manager/bloc tests, which only ever touch
  /// `OcptGlobalManager.instance` to satisfy `appLogger()`).
  static void log({
    required OcptDiagnosticsCategory category,
    OcptDiagnosticsLevel level = OcptDiagnosticsLevel.info,
    required String message,
    String? logMessage,
    bool isRoutine = false,
  }) {
    if (AbsGlobalManager.instance == null) {
      return;
    }

    final managers = globalGetIt();
    if (!managers.isRegistered<OcptDiagnosticsManager>()) {
      return;
    }

    managers.get<OcptDiagnosticsManager>().record(
      category: category,
      level: level,
      message: message,
      logMessage: logMessage,
      isRoutine: isRoutine,
    );
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    if (!_isDisposed) {
      _isDisposed = true;
      await _entries.disposeLifeCycle();
    }

    return super.disposeLifeCycle();
  }
}
