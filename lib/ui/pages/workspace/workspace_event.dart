// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

/// The events handled by `OcptWorkspaceBloc`.
sealed class OcptWorkspaceEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptWorkspaceEvent();
}

/// Requests loading the last used workspace mode.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptWorkspaceLoadRequestedEvent extends OcptWorkspaceEvent {
  /// Class constructor
  const OcptWorkspaceLoadRequestedEvent();
}

/// Selects a production mode from the bottom mode switcher, and persists it.
class OcptWorkspaceModeSelectedEvent extends OcptWorkspaceEvent {
  /// The mode the user selected.
  final OcptWorkspaceMode mode;

  /// Class constructor
  const OcptWorkspaceModeSelectedEvent({required this.mode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, mode];
}
