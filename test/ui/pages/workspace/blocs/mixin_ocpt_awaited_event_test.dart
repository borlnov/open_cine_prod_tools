// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_awaited_event.dart';

/// A state with nothing in it: these tests are about events, not about what a bloc shows.
class _State extends BlocStateForMixin<_State> {
  /// Class constructor
  const _State();

  @override
  _State copyWith() => const _State();
}

/// An event that can be waited on, answering an int.
class _AwaitedEvent extends BlocEventForMixin with MixinOcptAwaitedEvent<int> {
  /// What the event asks for, the only thing that takes part in equality.
  final String name;

  /// Class constructor
  _AwaitedEvent(this.name);

  @override
  List<Object?> get props => [...super.props, name];
}

/// A bloc whose handler answers [answer] once [gate] is released, or never completes the event
/// when [forgetsToComplete] is set.
class _Bloc extends BlocForMixin<_State> {
  /// The gate the handler waits for before completing the event.
  final Completer<void> gate = Completer<void>();

  /// What the handler completes the event with.
  static const answer = 7;

  /// Whether the handler leaves the event uncompleted.
  final bool forgetsToComplete;

  /// How many times the handler ran.
  int handledCount = 0;

  /// Class constructor
  _Bloc({this.forgetsToComplete = false}) : super(const _State());

  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<_AwaitedEvent>((event, emitter) async {
      handledCount++;
      await gate.future;
      if (!forgetsToComplete) {
        event.complete(answer);
      }
    });
  }
}

void main() {
  test('waits for the handler to complete the event and returns its answer', () async {
    final bloc = _Bloc();
    var isDone = false;

    final future = _AwaitedEvent('a').addToAndWait(bloc).then((value) {
      isDone = true;
      return value;
    });
    await pumpEventQueue();
    expect(isDone, isFalse, reason: 'the handler is still gated');
    expect(bloc.handledCount, 1);

    bloc.gate.complete();
    expect(await future, 7);

    await bloc.close();
  });

  test('completing twice keeps the first answer', () async {
    final bloc = _Bloc()..gate.complete();
    final event = _AwaitedEvent('a')
      ..complete(1)
      ..complete(2);

    // The handler answers 7 as well, which is a third attempt to complete it.
    expect(await event.addToAndWait(bloc), 1);

    await bloc.close();
  });

  test('the completer is not part of the event, so two events asking the same thing are equal', () {
    final first = _AwaitedEvent('a');
    final second = _AwaitedEvent('a');

    first.complete(1);

    expect(first, second);
    expect(first, isNot(_AwaitedEvent('b')));
  });

  test('a bloc that is already closed is not waited on', () async {
    final bloc = _Bloc();
    await bloc.close();

    expect(await _AwaitedEvent('a').addToAndWait(bloc), isNull);
    expect(bloc.handledCount, 0);
  });

  test(
    'a bloc that closes while a handler never completes the event releases the waiter',
    () async {
      final bloc = _Bloc(forgetsToComplete: true);

      final future = _AwaitedEvent('a').addToAndWait(bloc);
      await pumpEventQueue();
      expect(bloc.handledCount, 1);

      // Closing waits for the handler in flight, then ends the state stream, which is what the
      // waiter stops waiting on.
      unawaited(bloc.close());
      bloc.gate.complete();

      expect(await future.timeout(const Duration(seconds: 5)), isNull);
    },
  );
}
