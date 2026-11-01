// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The slice of a production mode's state its view blocs react to, mixed into every mode's own
/// state.
///
/// A view bloc cannot look at what a mode bloc just did, only at the state the mode emits, and two
/// things in it are worth reacting to whichever mode it is: the shared data being read again, and
/// the shared selection moving. Both are counters rather than flags, so a view that missed an
/// emission still sees that something happened, and so an action that leaves the selection on the
/// very same row (clicking the selected row again) is still told about, since the value alone
/// would not change.
mixin MixinOcptModeState<S extends MixinOcptModeState<S>> on BlocStateForMixin<S> {
  /// {@template open_cine_prod_tools.MixinOcptModeState.reloadEpoch}
  /// Count how many times the mode has replaced data it read from the project database: on entry,
  /// after a
  /// flush, after a write a view asked it to reload for, after any write of its own that reads a
  /// snapshot back, and when a version preview is entered or left. It moves with **every** emit that
  /// replaces a snapshot a view can read, whichever handler made it, so a view prunes whatever it
  /// holds about a row that is gone when this moves — it never has to guess which writes read.
  /// {@endtemplate}
  int get reloadEpoch;

  /// {@template open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  /// Count how many times the mode has moved its shared selection, **whether or not the selection
  /// ended
  /// up elsewhere**: every emit that selects a sequence, a shot or a set, or that changes the
  /// selection as a side effect (a shot or a set created and selected, the selected one deleted),
  /// moves it, and says why through the mode's own cause. A view clears what is scoped to the
  /// previous selection when this moves, and reads the cause to know how much.
  /// {@endtemplate}
  int get selectionEpoch;
}
