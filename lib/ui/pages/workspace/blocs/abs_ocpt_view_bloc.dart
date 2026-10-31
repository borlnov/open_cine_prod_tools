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
/// have.
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
abstract class AbsOcptViewBloc<
  S extends BlocStateForMixin<S>,
  MS extends MixinOcptModeState<MS>,
  M extends MixinOcptModeBloc<MS>
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

  /// Class constructor
  ///
  /// The mode's epochs are read from its current state rather than waited for: a state stream does
  /// not replay its last value to a new listener, so a view built after the mode loaded would
  /// otherwise take the first change it sees for the baseline.
  AbsOcptViewBloc(super.initialState, {required this.modeBloc})
    : _lastReloadEpoch = modeBloc.state.reloadEpoch,
      _lastSelectionEpoch = modeBloc.state.selectionEpoch {
    _modeSubscription = modeBloc.stream.listen(_onModeState);
    _unregisterFlusher = modeBloc.registerPendingWritesFlusher(this);
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();

    on<OcptViewModeStateChangedEvent<MS>>(onModeStateChanged);
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

    if (isClosed) {
      return;
    }

    add(
      OcptViewModeStateChangedEvent<MS>(
        modeState: modeState,
        hasReloaded: hasReloaded,
        hasSelectionMoved: hasSelectionMoved,
      ),
    );
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
  /// false at once on a view that is closing.
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

  /// Writes what the view holds, then tells the dispatcher what it found.
  Future<void> _onFlushRequested(OcptViewFlushRequestedEvent event, Emitter<S> emitter) async {
    try {
      event.complete(await onFlushRequested(emitter));
    } finally {
      event.complete(false);
    }
  }

  /// Marks the bloc as closing before it starts to, so a flush asked for in the meantime is
  /// answered at once instead of waiting on a handler that will not run.
  @override
  Future<void> close() {
    _isClosing = true;
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
