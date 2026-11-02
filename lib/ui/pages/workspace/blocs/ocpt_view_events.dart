// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_awaited_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_state.dart';

/// The events handled by `AbsOcptViewBloc`, i.e. by every view bloc of a production mode.
sealed class OcptViewEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptViewEvent();
}

/// Report that the mode bloc's shared state moved in a way a view reacts to: its data was read
/// again, its selection was moved, or both.
///
/// Dispatched by the base class when it sees the mode's epochs change. It carries the mode state
/// that moved them, not only the fact: a view that was busy while the mode emitted twice still
/// reacts to each emission for what it was (the cause of a selection move lives in that state),
/// while it reads the mode's *current* state, through the bloc, for the data it prunes against.
class OcptViewModeStateChangedEvent<MS extends MixinOcptModeState<MS>> extends OcptViewEvent {
  /// The mode state that moved an epoch.
  final MS modeState;

  /// Whether the mode's `reloadEpoch` moved.
  final bool hasReloaded;

  /// Whether the mode's `selectionEpoch` moved.
  final bool hasSelectionMoved;

  /// Class constructor
  const OcptViewModeStateChangedEvent({
    required this.modeState,
    required this.hasReloaded,
    required this.hasSelectionMoved,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, modeState, hasReloaded, hasSelectionMoved];
}

/// Request writing the edits the view holds, answering what the write came to.
class OcptViewFlushRequestedEvent extends OcptViewEvent
    with MixinOcptAwaitedEvent<OcptPendingWritesStatus> {
  /// Class constructor
  OcptViewFlushRequestedEvent();
}
