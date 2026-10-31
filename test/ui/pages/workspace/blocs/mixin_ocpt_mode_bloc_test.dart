// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_pending_writes_flusher.dart';

/// The parts of the double mode's data a reload can name.
enum _Scope {
  /// The first part.
  first,

  /// The second part.
  second,
}

/// The state of the double mode: its epochs and the log of what its hooks did.
class _State extends BlocStateForMixin<_State> with MixinOcptModeState<_State> {
  @override
  final int reloadEpoch;

  @override
  final int selectionEpoch;

  /// The scopes each reload that ran so far read, in order.
  final List<Set<Enum>> reads;

  /// Class constructor
  const _State({this.reloadEpoch = 0, this.selectionEpoch = 0, this.reads = const []});

  @override
  _State copyWith({int? reloadEpoch, int? selectionEpoch, List<Set<Enum>>? reads}) => _State(
    reloadEpoch: reloadEpoch ?? this.reloadEpoch,
    selectionEpoch: selectionEpoch ?? this.selectionEpoch,
    reads: reads ?? this.reads,
  );

  @override
  List<Object?> get props => [...super.props, reloadEpoch, selectionEpoch, reads];
}

/// A flusher that records how it was asked, answering that it wrote when it has something.
class _Flusher implements OcptPendingWritesFlusher {
  /// Whether this has something to write.
  bool hasPending;

  /// How many times it was asked to write with state.
  int flushCount = 0;

  /// How many times it was asked to write without state.
  int flushWithoutStateCount = 0;

  /// Class constructor
  _Flusher({this.hasPending = true});

  @override
  Future<bool> flushPendingWrites() async {
    flushCount++;
    return hasPending;
  }

  @override
  Future<void> flushPendingWritesWithoutState() async {
    flushWithoutStateCount++;
  }
}

/// A mode bloc whose reads wait on [readGates] in order, so a test decides when each one ends.
class _ModeBloc extends BlocForMixin<_State> with MixinOcptModeBloc<_State> {
  /// One gate per read, in the order the reads start; a read with no gate left runs at once.
  final List<Completer<void>> readGates = [];

  /// The order in which reads started and finished, as "start N" and "end N".
  final List<String> trace = [];

  /// Whether the first read fails instead of emitting.
  bool failsFirstRead = false;

  /// How many reads started so far.
  int _readCount = 0;

  /// What the mode's own flush hook did last: whether any flusher had written.
  bool? lastFlushHadWritten;

  /// Class constructor
  _ModeBloc() : super(const _State());

  /// Exposes the protected runner of the flushers that write without state.
  Future<void> runPendingWritesFlushersWithoutStateForTest() =>
      runPendingWritesFlushersWithoutState();

  @override
  Future<void> flushAllPendingWritesIn(Emitter<_State> emitter) async {
    lastFlushHadWritten = await runPendingWritesFlushers();
    if (lastFlushHadWritten!) {
      await reloadSerially({_Scope.first}, emitter);
    }
  }

  @override
  Future<void> reloadScopesIn(Set<Enum> scopes, Emitter<_State> emitter) async {
    final index = _readCount++;
    trace.add("start $index");
    if (index < readGates.length) {
      await readGates[index].future;
    }
    if (index == 0 && failsFirstRead) {
      throw StateError("boom");
    }
    emitter(state.copyWith(reloadEpoch: state.reloadEpoch + 1, reads: [...state.reads, scopes]));
    trace.add("end $index");
  }
}

void main() {
  test('a registered flusher is asked to write, an unregistered one no longer is', () async {
    final mode = _ModeBloc();
    final flusher = _Flusher();
    final unregister = mode.registerPendingWritesFlusher(flusher);

    await mode.flushAllPendingWrites();
    expect(flusher.flushCount, 1);
    expect(mode.lastFlushHadWritten, isTrue);

    unregister();
    await mode.flushAllPendingWrites();
    expect(flusher.flushCount, 1);
    expect(mode.lastFlushHadWritten, isFalse);

    await mode.close();
  });

  test('the flush reads the data again only if a flusher wrote', () async {
    final mode = _ModeBloc();
    final flusher = _Flusher(hasPending: false);
    mode.registerPendingWritesFlusher(flusher);

    await mode.flushAllPendingWrites();
    expect(mode.state.reloadEpoch, 0);

    flusher.hasPending = true;
    await mode.flushAllPendingWrites();
    expect(mode.state.reloadEpoch, 1);
    expect(mode.state.reads.single, {_Scope.first});

    await mode.close();
  });

  test('every flusher is asked, one after the other, and the without-state variant too', () async {
    final mode = _ModeBloc();
    final first = _Flusher(hasPending: false);
    final second = _Flusher();
    mode.registerPendingWritesFlusher(first);
    mode.registerPendingWritesFlusher(second);

    await mode.flushAllPendingWrites();
    expect([first.flushCount, second.flushCount], [1, 1]);

    await mode.runPendingWritesFlushersWithoutStateForTest();
    expect([first.flushWithoutStateCount, second.flushWithoutStateCount], [1, 1]);

    await mode.close();
  });

  test('reload completes once the state holds what was read, and names its scopes', () async {
    final mode = _ModeBloc();
    final gate = Completer<void>();
    mode.readGates.add(gate);

    var isDone = false;
    final future = mode.reload({_Scope.second}).then((_) => isDone = true);
    await pumpEventQueue();
    expect(isDone, isFalse);
    expect(mode.state.reloadEpoch, 0);

    gate.complete();
    await future;
    expect(mode.state.reloadEpoch, 1);
    expect(mode.state.reads.single, {_Scope.second});

    await mode.close();
  });

  test('reloads run one at a time, in the order they were asked', () async {
    final mode = _ModeBloc();
    final firstGate = Completer<void>();
    mode.readGates.add(firstGate);

    final first = mode.reload({_Scope.first});
    final second = mode.reload({_Scope.second});
    await pumpEventQueue();
    expect(mode.trace, ['start 0'], reason: 'the second read waits for the first');

    firstGate.complete();
    await Future.wait([first, second]);

    expect(mode.trace, ['start 0', 'end 0', 'start 1', 'end 1']);
    expect(mode.state.reads, [
      {_Scope.first},
      {_Scope.second},
    ]);

    await mode.close();
  });

  test('a flush that arrives while a reload is in flight waits for it, then reads again', () async {
    final mode = _ModeBloc();
    final gate = Completer<void>();
    mode.readGates.add(gate);
    mode.registerPendingWritesFlusher(_Flusher());

    final reload = mode.reload({_Scope.second});
    await pumpEventQueue();
    final flush = mode.flushAllPendingWrites();
    await pumpEventQueue();
    expect(mode.trace, ['start 0']);

    gate.complete();
    await Future.wait([reload, flush]);

    expect(mode.trace, ['start 0', 'end 0', 'start 1', 'end 1']);
    expect(mode.state.reloadEpoch, 2);

    await mode.close();
  });

  test('a failed reload does not stop the next one', () async {
    final errors = <Object>[];

    // The failure is the first read's own: it reaches the bloc's error handling, which a test
    // would otherwise report as uncaught, and the second read still runs.
    await runZonedGuarded(() async {
      final mode = _ModeBloc()..failsFirstRead = true;

      await Future.wait([
        mode.reload({_Scope.first}),
        mode.reload({_Scope.second}),
      ]);

      expect(mode.state.reads, [
        {_Scope.second},
      ]);

      await mode.close();
    }, (error, _) => errors.add(error));

    expect(errors, hasLength(1));
  });

  test('flush and reload answer at once on a bloc that is closing', () async {
    final mode = _ModeBloc();
    final flusher = _Flusher();
    mode.registerPendingWritesFlusher(flusher);

    final closing = mode.close();
    await mode.flushAllPendingWrites().timeout(const Duration(seconds: 5));
    await mode.reload({_Scope.first}).timeout(const Duration(seconds: 5));
    await closing;

    expect(flusher.flushCount, 0);
    expect(mode.state.reloadEpoch, 0);
  });
}
