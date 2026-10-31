// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';

/// The state of the double mode: its two epochs.
class _ModeState extends BlocStateForMixin<_ModeState> with MixinOcptModeState<_ModeState> {
  @override
  final int reloadEpoch;

  @override
  final int selectionEpoch;

  /// Class constructor
  const _ModeState({this.reloadEpoch = 0, this.selectionEpoch = 0});

  @override
  _ModeState copyWith({int? reloadEpoch, int? selectionEpoch}) => _ModeState(
    reloadEpoch: reloadEpoch ?? this.reloadEpoch,
    selectionEpoch: selectionEpoch ?? this.selectionEpoch,
  );

  @override
  List<Object?> get props => [...super.props, reloadEpoch, selectionEpoch];
}

/// Moves the double mode's selection to the same place again, or reads its data again.
class _ModeEvent extends BlocEventForMixin {
  /// Whether the event moves the selection epoch.
  final bool isSelection;

  /// Class constructor
  const _ModeEvent({required this.isSelection});

  @override
  List<Object?> get props => [...super.props, isSelection];
}

/// Puts the double mode's epochs at given values, whichever way that moves them.
class _ModeSetEpochsEvent extends BlocEventForMixin {
  /// The `reloadEpoch` to emit.
  final int reloadEpoch;

  /// The `selectionEpoch` to emit.
  final int selectionEpoch;

  /// Class constructor
  const _ModeSetEpochsEvent({required this.reloadEpoch, required this.selectionEpoch});

  @override
  List<Object?> get props => [...super.props, reloadEpoch, selectionEpoch];
}

/// A mode bloc moving its epochs on demand, flushing its views and doing no other work.
class _ModeBloc extends BlocForMixin<_ModeState> with MixinOcptModeBloc<_ModeState> {
  /// Class constructor
  _ModeBloc() : super(const _ModeState());

  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<_ModeSetEpochsEvent>(
      (event, emitter) =>
          emitter(_ModeState(reloadEpoch: event.reloadEpoch, selectionEpoch: event.selectionEpoch)),
    );
    on<_ModeEvent>(
      (event, emitter) => emitter(
        event.isSelection
            ? state.copyWith(selectionEpoch: state.selectionEpoch + 1)
            : state.copyWith(reloadEpoch: state.reloadEpoch + 1),
      ),
    );
  }

  @override
  Future<void> flushAllPendingWritesIn(Emitter<_ModeState> emitter) => runPendingWritesFlushers();

  @override
  Future<void> reloadScopesIn(Set<Enum> scopes, Emitter<_ModeState> emitter) async {
    emitter(state.copyWith(reloadEpoch: state.reloadEpoch + 1));
  }

  /// Exposes the protected runner of the flushers that write without state.
  Future<void> flushViewsWithoutState() => runPendingWritesFlushersWithoutState();
}

/// What the double view bloc shows: how it reacted and what it still has to write.
class _ViewState extends BlocStateForMixin<_ViewState> {
  /// The reactions to the mode so far, as "reload", "selection" or "both".
  final List<String> reactions;

  /// The text typed and not written yet, or empty.
  final String pending;

  /// Class constructor
  const _ViewState({this.reactions = const [], this.pending = ""});

  @override
  _ViewState copyWith({List<String>? reactions, String? pending}) =>
      _ViewState(reactions: reactions ?? this.reactions, pending: pending ?? this.pending);

  @override
  List<Object?> get props => [...super.props, reactions, pending];
}

/// Types text into the double view.
class _TypeEvent extends BlocEventForMixin {
  /// The text typed.
  final String text;

  /// Class constructor
  const _TypeEvent(this.text);

  @override
  List<Object?> get props => [...super.props, text];
}

/// A view bloc that records its reactions and holds typed text until it is flushed to [sink].
class _ViewBloc extends AbsOcptViewBloc<_ViewState, _ModeState, _ModeBloc> {
  /// Where the flushed text goes, in the order it was written.
  final List<String> sink;

  /// Class constructor
  _ViewBloc({required super.modeBloc, required this.sink}) : super(const _ViewState());

  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<_TypeEvent>((event, emitter) => emitter(state.copyWith(pending: event.text)));
  }

  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<_ModeState> event,
    Emitter<_ViewState> emitter,
  ) async {
    emitter(
      state.copyWith(
        reactions: [
          ...state.reactions,
          switch ((event.hasReloaded, event.hasSelectionMoved)) {
            (true, true) => "both",
            (true, false) => "reload",
            _ => "selection",
          },
        ],
      ),
    );
  }

  @override
  Future<bool> onFlushRequested(Emitter<_ViewState> emitter) async {
    if (state.pending.isEmpty) {
      return false;
    }

    sink.add(state.pending);
    emitter(state.copyWith(pending: ""));
    return true;
  }

  @override
  Future<void> flushPendingWritesWithoutState() async {
    if (state.pending.isNotEmpty) {
      sink.add("${state.pending} (without state)");
    }
  }
}

void main() {
  test(
    'a view reacts to the mode reading again, to its selection moving, and says which',
    () async {
      final mode = _ModeBloc();
      final view = _ViewBloc(modeBloc: mode, sink: []);

      mode.add(const _ModeEvent(isSelection: false));
      await pumpEventQueue();
      mode.add(const _ModeEvent(isSelection: true));
      await pumpEventQueue();

      expect(view.state.reactions, ['reload', 'selection']);

      await view.close();
      await mode.close();
    },
  );

  test('moving the selection to the place it already was still reaches the view', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    // Two identical events: the state they produce differs only by its epoch, which is exactly
    // what lets a view clear what the second one invalidates.
    mode.add(const _ModeEvent(isSelection: true));
    await pumpEventQueue();
    mode.add(const _ModeEvent(isSelection: true));
    await pumpEventQueue();

    expect(view.state.reactions, ['selection', 'selection']);

    await view.close();
    await mode.close();
  });

  test(
    'an epoch that goes down is not a move, and the next rise is measured from the top',
    () async {
      final mode = _ModeBloc();
      final view = _ViewBloc(modeBloc: mode, sink: []);

      mode.add(const _ModeSetEpochsEvent(reloadEpoch: 3, selectionEpoch: 3));
      await pumpEventQueue();
      mode.add(const _ModeSetEpochsEvent(reloadEpoch: 2, selectionEpoch: 2));
      await pumpEventQueue();
      mode.add(const _ModeSetEpochsEvent(reloadEpoch: 3, selectionEpoch: 4));
      await pumpEventQueue();

      expect(view.state.reactions, ['both', 'selection']);

      await view.close();
      await mode.close();
    },
  );

  test('a view built after the mode changed takes its epochs as the baseline', () async {
    final mode = _ModeBloc();
    mode.add(const _ModeEvent(isSelection: false));
    mode.add(const _ModeEvent(isSelection: true));
    await pumpEventQueue();

    final view = _ViewBloc(modeBloc: mode, sink: []);
    await pumpEventQueue();
    expect(view.state.reactions, isEmpty, reason: 'nothing happened since the view existed');

    mode.add(const _ModeEvent(isSelection: false));
    await pumpEventQueue();
    expect(view.state.reactions, ['reload']);

    await view.close();
    await mode.close();
  });

  test('a reload the view asked the mode for reaches it exactly once', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    await mode.reload({});
    await pumpEventQueue();

    expect(view.state.reactions, [
      'reload',
    ], reason: 'one reload, one reaction, nothing in between');

    await view.close();
    await mode.close();
  });

  test('the mode flushes a view, which writes what it holds and forgets it', () async {
    final sink = <String>[];
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: sink);
    view.add(const _TypeEvent("hello"));
    await pumpEventQueue();

    await mode.flushAllPendingWrites();

    expect(sink, ['hello']);
    expect(view.state.pending, isEmpty);

    // Nothing left: a second flush writes nothing.
    await mode.flushAllPendingWrites();
    expect(sink, ['hello']);

    await view.close();
    await mode.close();
  });

  test(
    'a view that closes is no longer asked to flush, and writes what it holds on its way out',
    () async {
      final sink = <String>[];
      final mode = _ModeBloc();
      final view = _ViewBloc(modeBloc: mode, sink: sink);
      view.add(const _TypeEvent("hello"));
      await pumpEventQueue();

      await view.close();
      expect(sink, ['hello (without state)']);

      await mode.flushAllPendingWrites();
      await mode.flushViewsWithoutState();
      expect(sink, ['hello (without state)'], reason: 'the closed view is not called again');

      await mode.close();
    },
  );

  test(
    'closing the mode first leaves the view able to write what it holds when it closes',
    () async {
      final sink = <String>[];
      final mode = _ModeBloc();
      final view = _ViewBloc(modeBloc: mode, sink: sink);
      view.add(const _TypeEvent("hello"));
      await pumpEventQueue();

      await mode.close();
      await view.close();

      expect(sink, ['hello (without state)']);
    },
  );

  test('a view that closes while the mode flushes does not hang the flush', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    final closing = view.close();
    await mode.flushAllPendingWrites().timeout(const Duration(seconds: 5));
    await closing;

    await mode.close();
  });

  test('a view stops reacting once closed, and the mode keeps working', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);
    await view.close();

    mode.add(const _ModeEvent(isSelection: false));
    await pumpEventQueue();

    expect(mode.state.reloadEpoch, 1);
    expect(view.state.reactions, isEmpty);

    await mode.close();
  });

  test('a view with nothing to hold answers a flush with nothing written', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    expect(await view.flushPendingWrites(), isFalse);

    await view.close();
    await mode.close();
  });
}
