// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';

/// The maximum number of entries [OcptDiagnosticsManager] keeps: appending past this cap drops
/// the oldest entry first.
const ocptDiagnosticsBufferCap = 500;

/// Builds the [OcptDiagnosticsManager] instance registered by the global manager.
class OcptDiagnosticsManagerBuilder extends AbsLifeCycleFactory<OcptDiagnosticsManager> {
  /// Class constructor
  const OcptDiagnosticsManagerBuilder() : super(OcptDiagnosticsManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [];
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
  /// Also forwards the entry to `appLogger()`, at the level [category]/[level] map to, prefixed
  /// with [category]'s own name — so the console and, when `logs.file.enabled` is true, the
  /// crash-survivable file external logger capture these hosting/sync/join/relay/presence events
  /// too, on top of this manager's own in-memory buffer. Guarded exactly like the static [log]
  /// convenience below, so a test with no global manager environment stays unaffected.
  void record({
    required OcptDiagnosticsCategory category,
    OcptDiagnosticsLevel level = OcptDiagnosticsLevel.info,
    required String message,
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

    if (AbsGlobalManager.instance != null) {
      _forwardToAppLogger(category: category, level: level, message: message);
    }
  }

  /// Forwards one entry to `appLogger()`, called only once [AbsGlobalManager.instance] is known
  /// non-null by [record].
  void _forwardToAppLogger({
    required OcptDiagnosticsCategory category,
    required OcptDiagnosticsLevel level,
    required String message,
  }) {
    final prefixedMessage = '[${category.name}] $message';
    switch (level) {
      case OcptDiagnosticsLevel.info:
        appLogger().i(prefixedMessage);
      case OcptDiagnosticsLevel.warning:
        appLogger().w(prefixedMessage);
      case OcptDiagnosticsLevel.error:
        appLogger().e(prefixedMessage);
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
  }) {
    if (AbsGlobalManager.instance == null) {
      return;
    }

    final managers = globalGetIt();
    if (!managers.isRegistered<OcptDiagnosticsManager>()) {
      return;
    }

    managers.get<OcptDiagnosticsManager>().record(category: category, level: level, message: message);
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
