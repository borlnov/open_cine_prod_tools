// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_awaited_event.dart';

/// The events handled by `MixinOcptModeBloc`, i.e. by every production mode's bloc.
///
/// They are dispatched by the mixin's own methods on behalf of the view blocs, never by a widget,
/// and each is waited on by its dispatcher (see [MixinOcptAwaitedEvent]).
sealed class OcptModeEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptModeEvent();
}

/// Requests writing every pending edit of the mode and of all its view blocs, and reading the
/// shared data again if any of it was written.
class OcptModeFlushRequestedEvent extends OcptModeEvent with MixinOcptAwaitedEvent<void> {
  /// Class constructor
  OcptModeFlushRequestedEvent();
}

/// Requests reading again the parts of the mode's shared data that [scopes] names, so a view that
/// just wrote a row finds it in the mode's state.
///
/// The scopes are the mode's own enum ([Scope]), which only the mode knows how to read. The
/// dispatcher is told whether the read succeeded.
class OcptModeReloadRequestedEvent<Scope extends Enum> extends OcptModeEvent
    with MixinOcptAwaitedEvent<bool> {
  /// The parts of the shared data to read again.
  final Set<Scope> scopes;

  /// Class constructor
  OcptModeReloadRequestedEvent({required this.scopes});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, scopes];
}
