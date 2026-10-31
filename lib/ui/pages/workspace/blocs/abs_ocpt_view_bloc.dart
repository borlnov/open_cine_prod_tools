// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_pending_writes_flusher.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';

/// The base of a view bloc: the bloc of one view of a production mode, holding that view's own
/// selection and preferences and doing that view's own writes.
///
/// **What it owns.** The state local to its view, and the writes its view triggers. The mode's data
/// (the snapshots), the shared selection and the chrome stay with the mode bloc, which the view
/// receives at construction ([modeBloc]) and whose state it reads at the moment it needs it, never
/// copying a piece of it into its own. A view never knows a sibling view, and the mode never knows
/// a view except as the [OcptPendingWritesFlusher] it registered.
///
/// **How it writes.** Call the service, then `await modeBloc.reload(…)` for the data the write
/// changed, and only then emit the view's own selection: the mode's state already holds the row
/// the view is about to select, so no widget ever sees a selection naming a row the data does not
/// have. `reload` answers whether it read: on false the view stops, the mode already shows the
/// error.
///
/// **How it reacts.** The base class watches the mode's state and, whenever its `reloadEpoch` or
/// `selectionEpoch` moves, dispatches [OcptViewModeStateChangedEvent] to the view itself;
/// [onModeStateChanged] is where the view clears what was scoped to the previous selection and
/// prunes what the new data no longer holds. That handler must not wait on anything before it
/// emits, so the mode's change and the view's reaction to it land in the same turn of the event
/// loop and no frame is drawn between the two.
///
/// **What it holds back.** A view that holds typed edits in a debounce overrides
/// [flushPendingWrites] and [flushPendingWritesWithoutState]. The base registers it with the mode
/// when built, unregisters it first thing when it closes, and flushes without state while closing,
/// so a pending edit reaches the database whichever of the view and the mode closes first.
/// A flush whose write fails throws, keeps the edit pending, and makes the mode's
/// [OcptPendingWritesRun] say so: whether the action behind the flush then stops is the mode's call.
///
/// **Rules for whoever writes the next view bloc.**
///
/// - Never write `state.copyWith(x: await …)`. Dart evaluates the `state` receiver before the
///   `await`, so a reload that lands meanwhile is overwritten with the old state, epochs
///   included. Await into a local, then `state.copyWith(x: local)`.
/// - Write through the service, then `await modeBloc.reload(…)` for exactly the scopes the write
///   changed, then emit the view's own selection. Never copy the mode's data into the view. Stop
///   when `reload` answers false, before moving any selection or forgetting any pending edit.
/// - Keep typed edits as a pending map, start the debounce with [restartDebounce] (never a `Timer`
///   of your own), and after a write forget only what was written, read at emit time:
///   `ocptPendingEditsAfterWrite`. Emitting an empty map loses the keystroke typed during the
///   write.
/// - Ask the mode for anything through [addToMode], never `modeBloc.add`, and check [isClosing],
///   never `isClosed`, before an `add` made from a timer or after an `await`: both are safe on a
///   bloc that is closing.
/// - To move the mode's selection and emit your own in the same gesture, use
///   [addToModeAndWait] and emit afterwards; the event must be registered by the mode with
///   `onAwaited`.
/// - [onModeStateChanged] waits for nothing before it emits, and reads the cause of a selection
///   move from `event.modeState`, the data from `modeBloc.state`.
/// - Epochs only grow: a view reacts to a rise, never to a difference.
abstract class AbsOcptViewBloc<
  S extends BlocStateForMixin<S>,
  MS extends MixinOcptModeState<MS>,
  M extends MixinOcptModeBloc<MS, Enum>
>
    extends BlocForMixin<S>
    implements OcptPendingWritesFlusher {
  /// The mode bloc this view belongs to.
  final M modeBloc;

  /// The `reloadEpoch` of the mode state this view last reacted to.
  int _lastReloadEpoch;

  /// The `selectionEpoch` of the mode state this view last reacted to.
  int _lastSelectionEpoch;

  /// The subscription to the mode's state stream.
  late final StreamSubscription<MS> _modeSubscription;

  /// Unregisters this view from the mode's flushers.
  late final VoidCallback _unregisterFlusher;

  /// Whether [close] was called.
  bool _isClosing = false;

  /// How many [OcptViewModeStateChangedEvent]s this view dispatched to itself so far.
  int _dispatchedReactions = 0;

  /// How many of them [onModeStateChanged] has returned from.
  int _handledReactions = 0;

  /// Completed, and replaced, whenever something [addToModeAndWait] waits on may have happened.
  Completer<void> _reactionSignal = Completer<void>();

  /// The running debounce timer, if any, see [restartDebounce].
  Timer? _debounceTimer;

  /// Class constructor
  ///
  /// The mode's epochs are read from its current state rather than waited for: a state stream does
  /// not replay its last value to a new listener, so a view built after the mode loaded would
  /// otherwise take the first change it sees for the baseline.
  AbsOcptViewBloc(super.initialState, {required this.modeBloc})
    : _lastReloadEpoch = modeBloc.state.reloadEpoch,
      _lastSelectionEpoch = modeBloc.state.selectionEpoch {
    _modeSubscription = modeBloc.stream.listen(_onModeState, onDone: _signalReaction);
    _unregisterFlusher = modeBloc.registerPendingWritesFlusher(this);
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptViewModeStateChangedEvent<MS>>(_onModeStateChangedEvent);
    on<OcptViewFlushRequestedEvent>(_onFlushRequested);
  }

  /// Turns an epoch moving in the mode's state into [OcptViewModeStateChangedEvent].
  void _onModeState(MS modeState) {
    // Only an epoch that grew is a move: a state older than one already seen (a handler that
    // emitted from a copy taken before it waited) carries a lower epoch, and is not news.
    final hasReloaded = modeState.reloadEpoch > _lastReloadEpoch;
    final hasSelectionMoved = modeState.selectionEpoch > _lastSelectionEpoch;
    if (!hasReloaded && !hasSelectionMoved) {
      return;
    }

    _lastReloadEpoch = modeState.reloadEpoch;
    _lastSelectionEpoch = modeState.selectionEpoch;

    if (isClosing) {
      return;
    }

    _dispatchedReactions++;
    add(
      OcptViewModeStateChangedEvent<MS>(
        modeState: modeState,
        hasReloaded: hasReloaded,
        hasSelectionMoved: hasSelectionMoved,
      ),
    );
    _signalReaction();
  }

  /// Runs [onModeStateChanged], then counts the reaction as handled.
  Future<void> _onModeStateChangedEvent(
    OcptViewModeStateChangedEvent<MS> event,
    Emitter<S> emitter,
  ) async {
    try {
      await onModeStateChanged(event, emitter);
    } finally {
      _handledReactions++;
      _signalReaction();
    }
  }

  /// Wakes whoever waits in [_untilReactedToMode].
  void _signalReaction() {
    final signal = _reactionSignal;
    _reactionSignal = Completer<void>();
    signal.complete();
  }

  /// Completes once this view has reacted to every state the mode emitted so far, or once either
  /// of them is going away.
  Future<void> _untilReactedToMode() async {
    while (!isClosing && !modeBloc.isClosed) {
      final modeState = modeBloc.state;
      final isUpToDate =
          _lastReloadEpoch >= modeState.reloadEpoch &&
          _lastSelectionEpoch >= modeState.selectionEpoch &&
          _handledReactions >= _dispatchedReactions;
      if (isUpToDate) {
        return;
      }

      await _reactionSignal.future;
    }
  }

  /// Whether this view is closing or closed, from which point `add` throws: `isClosed` stays false
  /// until every handler still running has finished, a window in which the event queue is already
  /// shut. Check this, not `isClosed`, before an `add` made from a timer or after an `await`.
  @protected
  bool get isClosing => _isClosing || isClosed;

  /// Asks the mode bloc for [event], or does nothing if the mode is closing. The only way a view
  /// should add an event to its mode: the mode may start to close while this view's handler is
  /// still waiting on it, and a plain `modeBloc.add` would throw then.
  @protected
  void addToMode(BlocEventForMixin event) => modeBloc.addUnlessClosing(event);

  /// Asks the mode for [event], one the mode registered as awaitable (`MixinOcptModeBloc.onAwaited`),
  /// and completes once the mode has handled it **and** this view has reacted to the state it
  /// emitted. Does nothing if the mode is closing.
  ///
  /// This is how a view moves the mode's shared selection and then emits its own selection in the
  /// same gesture: with `addToMode` the view's emit would land first and the reaction to the move
  /// would then clear it. Emit the view's own state only after this completes.
  @protected
  Future<void> addToModeAndWait(BlocEventForMixin event) async {
    await modeBloc.addAndWait(event);
    await _untilReactedToMode();
  }

  /// (Re)starts the view's debounce: after [delay] without another call, [event] is added to this
  /// view, unless the view started to close meanwhile. A view that holds typed edits calls this on
  /// every keystroke, and its handler for [event] writes them.
  ///
  /// The timer belongs to the base class: it is cancelled when the view closes, and never adds to a
  /// closing view, so a subclass has no timer of its own to get wrong.
  @protected
  void restartDebounce(Duration delay, BlocEventForMixin event) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (isClosing) {
      return;
    }

    _debounceTimer = Timer(delay, () {
      _debounceTimer = null;
      if (!isClosing) {
        add(event);
      }
    });
  }

  /// Cancels the debounce started by [restartDebounce], if it is running. A flush calls this first:
  /// what it writes is what the timer was waiting to write.
  @protected
  void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Reacts to the mode's shared state having moved: clears what was scoped to the previous
  /// selection when `event.hasSelectionMoved`, prunes what the new data no longer holds when
  /// `event.hasReloaded`. `event.modeState` is the state that moved the epochs; [modeBloc]'s own
  /// state is the latest data to prune against.
  ///
  /// Nothing may be awaited before the emit, see the class doc comment. Does nothing by default: a
  /// view with nothing scoped to the selection or to the data has nothing to react with.
  @protected
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<MS> event,
    Emitter<S> emitter,
  ) async {}

  /// Writes what this view holds in a debounce and emits the state without it, answering whether
  /// there was anything to write. Nothing by default: a view with no typed edits holds nothing.
  @protected
  Future<bool> onFlushRequested(Emitter<S> emitter) async => false;

  /// Asks the view's own bloc to write what it holds, and answers whether it had anything. Answers
  /// false at once on a view that is closing, and throws what the write threw: see
  /// [OcptPendingWritesFlusher.flushPendingWrites].
  @override
  Future<bool> flushPendingWrites() async {
    if (_isClosing) {
      return false;
    }

    return await OcptViewFlushRequestedEvent().addToAndWait(this) ?? false;
  }

  /// Nothing by default: a view with no typed edits holds nothing.
  @override
  Future<void> flushPendingWritesWithoutState() async {}

  /// Writes what the view holds, then tells the dispatcher what it found, or that it failed: the
  /// error goes to the dispatcher, which must not take a failed write for an empty one, and to
  /// this bloc's own error report.
  Future<void> _onFlushRequested(OcptViewFlushRequestedEvent event, Emitter<S> emitter) async {
    try {
      event.complete(await onFlushRequested(emitter));
    } catch (error, stackTrace) {
      event.completeError(error, stackTrace);
      addError(error, stackTrace);
    } finally {
      event.complete(false);
    }
  }

  /// Marks the bloc as closing before it starts to, so a flush asked for in the meantime is
  /// answered at once instead of waiting on a handler that will not run.
  @override
  Future<void> close() {
    _isClosing = true;
    cancelDebounce();
    _signalReaction();
    return super.close();
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Unregisters from the mode first, synchronously, so the mode never asks a closing view to
  /// flush; then writes what the view still holds, without state, so a pending edit is not lost
  /// whichever of the view and the mode closes first.
  @override
  Future<void> disposeLifeCycle() async {
    _unregisterFlusher();
    unawaited(_modeSubscription.cancel());
    await flushPendingWritesWithoutState();
    return super.disposeLifeCycle();
  }
}
