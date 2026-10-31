// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The slice of an event that lets whoever dispatched it wait until its handler is done, and read
/// what the handler answered.
///
/// A bloc's `add` returns at once, and the handler runs later, on its own: a view bloc that has
/// just written a row and asked its mode bloc to read it again cannot select that row until the
/// mode's state really holds it. The event therefore carries a [Completer] the handler completes
/// when it is finished ([complete]), and the dispatcher waits on it through [addToAndWait].
///
/// The completer is deliberately **not** part of the event's `props`: two events asking for the same
/// thing stay equal, whichever of them somebody is waiting on.
///
/// Waiting never hangs on a bloc that is going away: [addToAndWait] stops waiting the moment the
/// bloc's state stream ends, and refuses to wait at all on a bloc that is already closed. A handler
/// must still call [complete] in a `finally` so a failure does not leave its dispatcher waiting for a
/// bloc that stays alive.
mixin MixinOcptAwaitedEvent<T> on BlocEventForMixin {
  /// The completer the handler completes and [addToAndWait] waits on.
  final Completer<T?> _completer = Completer<T?>();

  /// Tells the dispatcher the handler is done, handing back [value] if the handler has an answer.
  ///
  /// Completing twice is harmless, so a handler can complete early on its normal path and again in
  /// its `finally`.
  void complete([T? value]) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  /// Adds this event to [bloc], then waits until its handler completed it and returns the answer,
  /// or returns null as soon as [bloc] closes, without waiting for a handler that will never run.
  Future<T?> addToAndWait(Bloc<BlocEventForMixin, Object?> bloc) async {
    if (bloc.isClosed) {
      return null;
    }

    final closed = Completer<T?>();
    final subscription = bloc.stream.listen(null, onDone: () => closed.complete(null));

    try {
      bloc.add(this);
      return await Future.any([_completer.future, closed.future]);
    } finally {
      // Not awaited: cancelling a state stream detaches the listener at once, and the future it
      // hands back is one a widget test's fake clock never gets to finish.
      unawaited(subscription.cancel());
    }
  }
}
