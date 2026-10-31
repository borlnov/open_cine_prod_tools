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
  /// How many times the mode has read its shared data again from the project database — on entry,
  /// after a flush, after a write a view asked it to reload for, and when a version preview is
  /// entered or left. A view prunes whatever it holds about a row that is gone when this moves.
  /// {@endtemplate}
  int get reloadEpoch;

  /// {@template open_cine_prod_tools.MixinOcptModeState.selectionEpoch}
  /// How many times the mode has been told to move its shared selection, **whether or not the
  /// selection ended up elsewhere**. A view clears what is scoped to the previous selection when
  /// this moves.
  /// {@endtemplate}
  int get selectionEpoch;
}
