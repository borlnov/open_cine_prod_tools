// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

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

/// Builds the [OcptDiagnosticsManager] instance registered by the global manager.
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
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  final List<OcptDiagnosticsEntry> _entries = [];
  final StreamController<List<OcptDiagnosticsEntry>> _controller =
      StreamController<List<OcptDiagnosticsEntry>>.broadcast();

  /// Every entry recorded so far, oldest first, capped at [ocptDiagnosticsBufferCap] — an
  /// unmodifiable view, so a caller can never mutate this manager's own buffer directly.
  List<OcptDiagnosticsEntry> get entries => List.unmodifiable(_entries);

  /// Emits the full, oldest-first entry list every time it changes ([record]/[clear]) — never its
  /// current value at subscription time (see this class's own doc comment).
  Stream<List<OcptDiagnosticsEntry>> get entriesStream => _controller.stream;

  /// Appends one entry to the buffer, dropping the oldest one once [ocptDiagnosticsBufferCap] is
  /// exceeded, and broadcasts the updated list on [entriesStream].
  ///
  /// Also forwards the entry to this manager's logger, at the level [category]/[level] map to,
  /// prefixed with [category]'s own name — so the console and, when `logs.file.enabled` is true, the
  /// crash-survivable file external logger capture these hosting/sync/join/relay/presence events
  /// too, on top of this manager's own in-memory buffer.
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
    _entries.add(
      OcptDiagnosticsEntry(
        time: DateTime.now(),
        category: category,
        level: level,
        message: message,
      ),
    );
    if (_entries.length > ocptDiagnosticsBufferCap) {
      _entries.removeAt(0);
    }
    _emit();

    _forwardToLogger(
      category: category,
      level: level,
      message: logMessage ?? message,
      isRoutine: isRoutine,
    );
  }

  /// Forwards one entry to [_logger].
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

  /// Empties the buffer and broadcasts the (now empty) list on [entriesStream] — what
  /// `OcptDiagnosticsLogList`'s own "clear" button calls.
  void clear() {
    _entries.clear();
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(entries);
    }
  }

  /// Records [message] against [category]/[level] through the registered [OcptDiagnosticsManager]
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
    if (!_controller.isClosed) {
      await _controller.close();
    }

    return super.disposeLifeCycle();
  }
}
