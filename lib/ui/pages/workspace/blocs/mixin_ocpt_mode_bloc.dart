// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_mode_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_pending_writes_flusher.dart';

/// What a production mode's bloc offers the view blocs that live next to it: a place to register
/// the edits they hold in a debounce, a way to have all of them written, and a way to have the
/// shared data read again after a write.
///
/// A mode splits into one **mode bloc**, which owns the mode's data, its shared selection and its
/// chrome, and one **view bloc** per view (`AbsOcptViewBloc`). A view bloc depends on the mode
/// bloc, never the other way round, which is why the mode reaches its views only through the
/// [OcptPendingWritesFlusher]s they register here, and why a view reaches the mode only through
/// [flushAllPendingWrites] and [reload], both of which are plain events the mode handles in its own
/// queue and which a caller can wait on.
///
/// The mode answers two hooks:
///
/// - [flushAllPendingWritesIn] — write what the mode itself holds as well as, through
///   [runPendingWritesFlushers], what its views hold, and read the data again if any of it changed.
/// - [reloadScopesIn] — read again the parts of the shared data a view named, and move the state's
///   `reloadEpoch`.
///
/// Every read of the shared data that ends in an emit runs through [runSerially], one at a time —
/// [reloadSerially] for a view's reload, and the mode's own flush for its read-and-emit half: two
/// writers finishing at about the same time each read the data, and a slower read finishing after
/// a faster, newer one would put older data in the state. The flush as a whole is **not** queued,
/// only its read-and-emit half: a view's flush waits on a reload, so queueing the whole flush
/// behind that reload would wait on itself. Whoever writes a mode bloc's own reads must therefore
/// queue them: a read that is not in the queue can finish last and overwrite a newer one.
mixin MixinOcptModeBloc<S extends MixinOcptModeState<S>> on BlocForMixin<S> {
  /// The flushers the view blocs registered, in registration order.
  final List<OcptPendingWritesFlusher> _flushers = [];

  /// The tail of every read queued through [runSerially] so far.
  Future<void> _serialReads = Future.value();

  /// Whether [close] was called, from which point nothing new can be dispatched to this bloc.
  bool _isClosing = false;

  /// Registers [flusher] to be asked to write what it holds, and returns the function that
  /// unregisters it again.
  ///
  /// A view bloc registers itself when it is built and unregisters itself first thing when it
  /// closes, so the mode never calls a bloc that is going away.
  VoidCallback registerPendingWritesFlusher(OcptPendingWritesFlusher flusher) {
    _flushers.add(flusher);
    return () => _flushers.remove(flusher);
  }

  /// How many flushers are registered, so a test can tell that every view bloc of a mode was built
  /// without any widget having read it.
  @visibleForTesting
  int get pendingWritesFlusherCount => _flushers.length;

  /// Asks every registered flusher to write what it holds, one after the other, and answers
  /// whether any of them had something to write.
  @protected
  Future<bool> runPendingWritesFlushers() async {
    var hasWritten = false;
    for (final flusher in List.of(_flushers)) {
      if (await flusher.flushPendingWrites()) {
        hasWritten = true;
      }
    }
    return hasWritten;
  }

  /// Asks every registered flusher to write what it holds without touching any state, for the
  /// moments no handler can emit from (see [OcptPendingWritesFlusher.flushPendingWritesWithoutState]).
  @protected
  Future<void> runPendingWritesFlushersWithoutState() async {
    for (final flusher in List.of(_flushers)) {
      await flusher.flushPendingWritesWithoutState();
    }
  }

  /// Writes every pending edit of the mode and of its views, and reads the shared data again if any
  /// of it was written. Completes once that is done, or at once on a bloc that is closing.
  Future<void> flushAllPendingWrites() async {
    if (_isClosing) {
      return;
    }

    await OcptModeFlushRequestedEvent().addToAndWait(this);
  }

  /// Reads again the parts of the shared data that [scopes] names, and completes once the mode's
  /// state holds what was read — so the caller can select a row it has just written.
  ///
  /// Completes at once on a bloc that is closing: there is no state left to wait for.
  Future<void> reload(Set<Enum> scopes) async {
    if (_isClosing) {
      return;
    }

    await OcptModeReloadRequestedEvent(scopes: scopes).addToAndWait(this);
  }

  /// {@template open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  /// Writes what the mode holds and, through [runPendingWritesFlushers], what its views hold, then
  /// reads the shared data again if any of it was written. Called by [flushAllPendingWrites]'s
  /// handler, with that handler's own [emitter].
  /// {@endtemplate}
  @protected
  Future<void> flushAllPendingWritesIn(Emitter<S> emitter);

  /// {@template open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  /// Reads again the parts of the shared data that [scopes] names, emits them with the state's
  /// `reloadEpoch` moved on. Called one at a time by [reloadSerially].
  /// {@endtemplate}
  @protected
  Future<void> reloadScopesIn(Set<Enum> scopes, Emitter<S> emitter);

  /// Runs [action], a read of the shared data that ends in an emit, only once every action already
  /// queued through this has settled, and queues it in turn.
  ///
  /// [action] must read and emit, and wait for nothing that is itself queued here: it would wait
  /// on itself. A failed action must not leave the queue stuck: [_serialReads] never carries the
  /// error forward, only the future handed back to the caller does.
  @protected
  Future<T> runSerially<T>(Future<T> Function() action) {
    final result = _serialReads.then((_) => action());
    _serialReads = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Runs [reloadScopesIn] through [runSerially].
  @protected
  Future<void> reloadSerially(Set<Enum> scopes, Emitter<S> emitter) =>
      runSerially(() => reloadScopesIn(scopes, emitter));

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptModeFlushRequestedEvent>(_onFlushRequested);
    on<OcptModeReloadRequestedEvent>(_onReloadRequested);
  }

  /// Writes every pending edit, then tells the dispatcher.
  Future<void> _onFlushRequested(OcptModeFlushRequestedEvent event, Emitter<S> emitter) async {
    try {
      await flushAllPendingWritesIn(emitter);
    } finally {
      event.complete();
    }
  }

  /// Reads the requested parts of the shared data again, then tells the dispatcher.
  Future<void> _onReloadRequested(OcptModeReloadRequestedEvent event, Emitter<S> emitter) async {
    try {
      await reloadSerially(event.scopes, emitter);
    } finally {
      event.complete();
    }
  }

  /// Stops accepting [flushAllPendingWrites] and [reload] before the bloc starts closing, so a
  /// view that is still waiting on a handler this bloc will never run again cannot hold the close
  /// up: see `MixinOcptAwaitedEvent`.
  @override
  Future<void> close() {
    _isClosing = true;
    return super.close();
  }
}
