// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';

/// The parts of the double mode's data that can be read again.
enum _Scope {
  /// The only part.
  data,
}

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

  /// A gate the handler waits on before it moves anything, or null.
  final Completer<void>? gate;

  /// Class constructor
  const _ModeEvent({required this.isSelection}) : gate = null;

  /// An event whose handler waits for [gate], keeping the mode busy.
  const _ModeEvent.waiting(Completer<void> this.gate) : isSelection = false;

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
class _ModeBloc extends BlocForMixin<_ModeState> with MixinOcptModeBloc<_ModeState, _Scope> {
  /// Class constructor
  _ModeBloc() : super(const _ModeState());

  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<_ModeSetEpochsEvent>(
      (event, emitter) =>
          emitter(_ModeState(reloadEpoch: event.reloadEpoch, selectionEpoch: event.selectionEpoch)),
    );
    onAwaited<_ModeEvent>((event, emitter) async {
      await event.gate?.future;
      emitter(
        event.isSelection
            ? state.copyWith(selectionEpoch: state.selectionEpoch + 1)
            : state.copyWith(reloadEpoch: state.reloadEpoch + 1),
      );
    });
  }

  @override
  Future<bool> flushAllPendingWritesIn(Emitter<_ModeState> emitter) async {
    final run = await runPendingWritesFlushers();
    return !run.hasFailed;
  }

  @override
  Future<bool> reloadScopesIn(Set<_Scope> scopes, Emitter<_ModeState> emitter) async {
    emitter(state.copyWith(reloadEpoch: state.reloadEpoch + 1));
    return true;
  }

  /// Exposes the protected runner of the flushers that write without state.
  Future<void> flushViewsWithoutState() => runPendingWritesFlushersWithoutState();
}

/// What the double view bloc shows: how it reacted and what it still has to write.
class _ViewState extends BlocStateForMixin<_ViewState> {
  /// The reactions to the mode so far, as "reload", "selection" or "both".
  final List<String> reactions;

  /// How many times the debounce fired.
  final int debounceCount;

  /// What the view selected, cleared whenever the mode's selection moves.
  final String selected;

  /// The text typed and not written yet, or empty.
  final String pending;

  /// Class constructor
  const _ViewState({
    this.reactions = const [],
    this.pending = "",
    this.debounceCount = 0,
    this.selected = "",
  });

  @override
  _ViewState copyWith({
    List<String>? reactions,
    String? pending,
    int? debounceCount,
    String? selected,
  }) => _ViewState(
    reactions: reactions ?? this.reactions,
    pending: pending ?? this.pending,
    debounceCount: debounceCount ?? this.debounceCount,
    selected: selected ?? this.selected,
  );

  @override
  List<Object?> get props => [...super.props, reactions, pending, debounceCount, selected];
}

/// Types text into the double view and starts its debounce.
class _TypeAndDebounceEvent extends BlocEventForMixin {
  /// The text typed.
  final String text;

  /// Class constructor
  const _TypeAndDebounceEvent(this.text);

  @override
  List<Object?> get props => [...super.props, text];
}

/// Fired by the double view's debounce.
class _DebounceFiredEvent extends BlocEventForMixin {
  /// Class constructor
  const _DebounceFiredEvent();
}

/// Has the double view select [name] in the same gesture as it moves the mode's selection, either
/// waiting for the mode ([isAwaited]) or not.
class _SelectEvent extends BlocEventForMixin {
  /// What to select.
  final String name;

  /// Whether to wait for the mode before selecting.
  final bool isAwaited;

  /// Class constructor
  const _SelectEvent(this.name, {required this.isAwaited});

  @override
  List<Object?> get props => [...super.props, name, isAwaited];
}

/// Asks the double view to ask its mode for an event.
class _AskModeEvent extends BlocEventForMixin {
  /// Class constructor
  const _AskModeEvent();
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

  /// Whether writing the typed text fails, as a full disk would.
  bool failsToWrite = false;

  /// Class constructor
  _ViewBloc({required super.modeBloc, required this.sink}) : super(const _ViewState());

  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<_TypeEvent>((event, emitter) => emitter(state.copyWith(pending: event.text)));
    on<_TypeAndDebounceEvent>((event, emitter) {
      emitter(state.copyWith(pending: event.text));
      restartDebounce(const Duration(milliseconds: 20), const _DebounceFiredEvent());
    });
    on<_DebounceFiredEvent>(
      (event, emitter) => emitter(state.copyWith(debounceCount: state.debounceCount + 1)),
    );
    on<_SelectEvent>((event, emitter) async {
      if (event.isAwaited) {
        await addToModeAndWait(const _ModeEvent(isSelection: true));
      } else {
        addToMode(const _ModeEvent(isSelection: true));
      }
      emitter(state.copyWith(selected: event.name));
    });
    on<_AskModeEvent>((event, emitter) => addToMode(const _ModeEvent(isSelection: false)));
  }

  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<_ModeState> event,
    Emitter<_ViewState> emitter,
  ) async {
    emitter(
      state.copyWith(
        selected: event.hasSelectionMoved ? "" : null,
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

    if (failsToWrite) {
      throw StateError("write failed");
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

    await mode.reload({_Scope.data});
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
    'a view whose write fails throws it to the flush, which keeps what the view holds',
    () async {
      final sink = <String>[];
      final mode = _ModeBloc();
      final view = _ViewBloc(modeBloc: mode, sink: sink)..failsToWrite = true;
      view.add(const _TypeEvent("hello"));
      await pumpEventQueue();

      await expectLater(view.flushPendingWrites(), throwsStateError);
      expect(await mode.flushAllPendingWrites(), isFalse);
      expect(view.state.pending, 'hello');
      expect(sink, isEmpty);

      view.failsToWrite = false;
      expect(await mode.flushAllPendingWrites(), isTrue);
      expect(sink, ['hello']);
      expect(view.state.pending, isEmpty);

      await view.close();
      await mode.close();
    },
  );

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

  test(
    'the view debounce fires once after the last call, and not at all once the view closes',
    () async {
      final mode = _ModeBloc();
      final view = _ViewBloc(modeBloc: mode, sink: []);

      view.add(const _TypeAndDebounceEvent("a"));
      view.add(const _TypeAndDebounceEvent("ab"));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(view.state.debounceCount, 1);

      view.add(const _TypeAndDebounceEvent("abc"));
      await pumpEventQueue();
      final closing = view.close();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await closing;
      expect(view.state.debounceCount, 1, reason: 'a closing view does not hear its own timer');

      await mode.close();
    },
  );

  test('asking a mode that is closing for something does nothing instead of throwing', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    view.add(const _AskModeEvent());
    await pumpEventQueue();
    expect(mode.state.reloadEpoch, 1, reason: 'an open mode is asked');

    // The mode's event queue is shut while a handler of it is still running.
    final gate = Completer<void>();
    mode.add(_ModeEvent.waiting(gate));
    await pumpEventQueue();
    final closing = mode.close();
    await pumpEventQueue();
    expect(mode.isClosing, isTrue);
    expect(() => mode.add(const _ModeEvent(isSelection: false)), throwsStateError);

    view.add(const _AskModeEvent());
    await pumpEventQueue();

    gate.complete();
    await closing;
    await view.close();
  });

  test('a view that moves the mode selection and waits keeps what it selects afterwards', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    view.add(const _SelectEvent("kept", isAwaited: true));
    await pumpEventQueue();

    expect(mode.state.selectionEpoch, 1);
    expect(view.state.reactions, ['selection'], reason: 'the view reacted before it selected');
    expect(view.state.selected, 'kept');

    await view.close();
    await mode.close();
  });

  test('a view that does not wait has what it selects cleared by its own reaction', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    view.add(const _SelectEvent("lost", isAwaited: false));
    await pumpEventQueue();

    expect(view.state.selected, isEmpty, reason: 'this is what waiting is for');

    await view.close();
    await mode.close();
  });

  test('waiting on a mode that closes, or is closing, neither hangs nor throws', () async {
    final mode = _ModeBloc();
    final view = _ViewBloc(modeBloc: mode, sink: []);

    final gate = Completer<void>();
    view.add(const _SelectEvent("never", isAwaited: true));
    mode.add(_ModeEvent.waiting(gate));
    await pumpEventQueue();
    final closing = mode.close();
    gate.complete();
    await closing;
    await pumpEventQueue();
    view.add(const _SelectEvent("after", isAwaited: true));
    await pumpEventQueue();

    expect(view.state.selected, 'after');

    await view.close();
  });
}
