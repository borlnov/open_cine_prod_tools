// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

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
/// [flushAllPendingWrites], [reload], [addUnlessClosing] and [addAndWait], which are plain events
/// the mode handles in its own queue and which a caller can wait on or safely drop.
///
/// [Scope] is the mode's own enum of the parts of its shared data that can be read again: a view
/// can only name a scope the mode declares, and the mode's hook switches over the enum, so a part
/// of the data nobody can ask for, or that nobody reads, does not compile.
///
/// The mode answers two hooks:
///
/// - [flushAllPendingWritesIn] — write what the mode itself holds as well as, through
///   [runPendingWritesFlushers], what its views hold, and read the data again if any of it changed.
/// - [reloadScopesIn] — read again the parts of the shared data a view named, and move the state's
///   `reloadEpoch`.
///
/// **Rules for a mode bloc.**
///
/// - Every read of the shared data that ends in an emit runs through [runSerially], one at a time:
///   [reloadSerially] for a view's reload, and the read-and-emit half of the mode's own flush. Two
///   writers finishing at about the same time each read the data, and a slower read finishing after
///   a faster, newer one would put older data in the state. A read that is not queued can finish
///   last and overwrite a newer one.
/// - Queue only the read-and-emit half of a flush, never the flush as a whole: a view's flush waits
///   on a reload, so queueing the whole flush behind it would wait on itself.
/// - Never write `state.copyWithX(y: await …)`: the `state` receiver is evaluated before the
///   `await`, and a reload landing meanwhile is rolled back. Await into a local first.
/// - Move `reloadEpoch` with every emit that replaces data a view can read, and `selectionEpoch`
///   with every emit that changes the selection, saying why through the mode's cause. A reload
///   scope is a value of the mode's enum, read by a `switch` that names every value.
/// - Events a view must be able to wait for are registered with [onAwaited].
/// - Delay nothing with a plain `Timer` that calls `add`: use [isClosing] and [addUnlessClosing].
mixin MixinOcptModeBloc<S extends MixinOcptModeState<S>, Scope extends Enum> on BlocForMixin<S> {
  /// The flushers the view blocs registered, in registration order.
  final List<OcptPendingWritesFlusher> _flushers = [];

  /// The dispatchers waiting in [addAndWait], per event instance.
  final Map<BlocEventForMixin, List<Completer<void>>> _awaited = Map.identity();

  /// The tail of every read queued through [runSerially] so far.
  Future<void> _serialReads = Future.value();

  /// Whether [close] was called, from which point nothing new can be dispatched to this bloc.
  bool _isClosing = false;

  /// Whether this bloc is closing or closed, from which point `add` throws.
  ///
  /// `isClosed` is not enough: it stays false until every handler still running has finished, a
  /// window in which the event queue is already shut and `add` already throws.
  bool get isClosing => _isClosing || isClosed;

  /// How many flushers are registered, so a test can tell that every view bloc of a mode was built
  /// without any widget having read it.
  @visibleForTesting
  int get pendingWritesFlusherCount => _flushers.length;

  /// Registers [flusher] to be asked to write what it holds, and returns the function that
  /// unregisters it again.
  ///
  /// A view bloc registers itself when it is built and unregisters itself first thing when it
  /// closes, so the mode never calls a bloc that is going away.
  VoidCallback registerPendingWritesFlusher(OcptPendingWritesFlusher flusher) {
    _flushers.add(flusher);
    return () => _flushers.remove(flusher);
  }

  /// Adds [event] to this bloc, or does nothing if it is closing ([isClosing]).
  ///
  /// What a view bloc, a timer or a continuation after an `await` uses to ask the mode for
  /// something: by the time it runs, the mode may have started to close, and a plain `add` would
  /// throw there.
  void addUnlessClosing(BlocEventForMixin event) {
    if (isClosing) {
      return;
    }

    add(event);
  }

  /// Registers [handler] for the mode's own event type [E], like `on<E>`, but so that
  /// [addAndWait] can wait for it: whoever dispatched the event is told when the handler is done.
  ///
  /// Register through this the events a view bloc has to move the mode's selection with, see
  /// [addAndWait]. The event itself needs nothing more, it stays the plain (even `const`) event it
  /// was.
  @protected
  void onAwaited<E extends BlocEventForMixin>(EventHandler<E, S> handler) {
    on<E>((event, emitter) async {
      try {
        await handler(event, emitter);
      } finally {
        _completeAwaited(event);
      }
    });
  }

  /// Adds [event], one registered through [onAwaited], and completes once its handler is done, i.e.
  /// once the mode's state holds what the handler emitted. Completes at once on a bloc that is
  /// closing, and as soon as the bloc closes without having run the handler.
  ///
  /// This is how a view moves the mode's shared selection **and then** emits its own: with a plain
  /// `add`, the view's next emit lands before the mode has even started on the event, and the view's
  /// reaction to the move (which clears what was scoped to the previous selection) then clears what
  /// the view just emitted. A view bloc uses `AbsOcptViewBloc.addToModeAndWait`, which also waits
  /// for its own reaction.
  Future<void> addAndWait(BlocEventForMixin event) async {
    if (isClosing) {
      return;
    }

    final completer = Completer<void>();
    final closed = Completer<void>();
    final subscription = stream.listen(null, onDone: closed.complete);
    _awaited.putIfAbsent(event, () => []).add(completer);

    try {
      add(event);
      await Future.any([completer.future, closed.future]);
    } finally {
      unawaited(subscription.cancel());
      final waiting = _awaited[event];
      waiting?.remove(completer);
      if (waiting != null && waiting.isEmpty) {
        _awaited.remove(event);
      }
    }
  }

  /// Asks every registered flusher to write what it holds, one after the other, and answers
  /// whether any of them had something to write and whether any of them failed.
  ///
  /// Every flusher is asked even after one failed: they hold unrelated edits, and a failure of one
  /// must not keep the others from being written. A flusher that failed has already reported it
  /// itself, so the failure is only counted here.
  @protected
  Future<OcptPendingWritesRun> runPendingWritesFlushers() async {
    var hasWritten = false;
    var hasFailed = false;
    for (final flusher in List.of(_flushers)) {
      try {
        if (await flusher.flushPendingWrites()) {
          hasWritten = true;
        }
      } catch (_) {
        hasFailed = true;
      }
    }
    return (hasWritten: hasWritten, hasFailed: hasFailed);
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
  ///
  /// Answers whether the caller may go on with the action it flushed for (a preview, a restore, an
  /// export): false when a write failed and the mode's rule is that the action must not run without
  /// it (see [flushAllPendingWritesIn]), and on a bloc that is closing, where no action is left to
  /// run. The edit that failed is still pending when this answers false.
  Future<bool> flushAllPendingWrites() async {
    if (_isClosing) {
      return false;
    }

    return await OcptModeFlushRequestedEvent().addToAndWait(this) ?? false;
  }

  /// Reads again the parts of the shared data that [scopes] names, and completes once the mode's
  /// state holds what was read — so the caller can select a row it has just written.
  ///
  /// Answers whether the data was read. A caller that gets false stops there: the read failed (the
  /// mode shows its own error), or the bloc is closing and there is no state left to wait for,
  /// which completes at once. Carrying on would select a row the state may not hold.
  Future<bool> reload(Set<Scope> scopes) async {
    if (_isClosing) {
      return false;
    }

    return await OcptModeReloadRequestedEvent<Scope>(scopes: scopes).addToAndWait(this) ?? false;
  }

  /// {@template open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  /// Writes what the mode holds and, through [runPendingWritesFlushers], what its views hold, then
  /// reads the shared data again if any of it was written. Called by [flushAllPendingWrites]'s
  /// handler, with that handler's own [emitter].
  ///
  /// Answers whether the action the flush was asked for may go on. A mode decides it from
  /// [OcptPendingWritesRun.hasFailed]: one that shows a failed write itself and carries on answers
  /// true whatever happened; one that must not act on a database missing a typed edit answers false
  /// when a flusher failed, and its callers stop.
  /// {@endtemplate}
  @protected
  Future<bool> flushAllPendingWritesIn(Emitter<S> emitter);

  /// {@template open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  /// Reads again the parts of the shared data that [scopes] names, emits them with the state's
  /// `reloadEpoch` moved on, and answers whether it did: false when the read failed or nothing
  /// could be read. Called one at a time by [reloadSerially].
  ///
  /// A mode that no view asks to reload, because none writes its shared data behind its back,
  /// declares [Never] as its [Scope] and keeps this default, which reads nothing.
  /// {@endtemplate}
  @protected
  Future<bool> reloadScopesIn(Set<Scope> scopes, Emitter<S> emitter) async => false;

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
  Future<bool> reloadSerially(Set<Scope> scopes, Emitter<S> emitter) =>
      runSerially(() => reloadScopesIn(scopes, emitter));

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptModeFlushRequestedEvent>(_onFlushRequested);
    on<OcptModeReloadRequestedEvent<Scope>>(_onReloadRequested);
  }

  /// Tells the oldest dispatcher waiting on [event] that its handler is done. Events are told
  /// apart by identity; two equal events (a `const` one dispatched twice) are interchangeable, so
  /// the oldest waiter is the one released.
  void _completeAwaited(BlocEventForMixin event) {
    final waiting = _awaited[event];
    if (waiting != null && waiting.isNotEmpty) {
      final completer = waiting.removeAt(0);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Writes every pending edit, then tells the dispatcher.
  Future<void> _onFlushRequested(OcptModeFlushRequestedEvent event, Emitter<S> emitter) async {
    try {
      event.complete(await flushAllPendingWritesIn(emitter));
    } finally {
      event.complete(false);
    }
  }

  /// Reads the requested parts of the shared data again, then tells the dispatcher.
  Future<void> _onReloadRequested(
    OcptModeReloadRequestedEvent<Scope> event,
    Emitter<S> emitter,
  ) async {
    try {
      event.complete(await reloadSerially(event.scopes, emitter));
    } finally {
      event.complete(false);
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
