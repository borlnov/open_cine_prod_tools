// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

/// The state of `OcptWorkspaceBloc`.
class OcptWorkspaceState extends BlocStateForMixin<OcptWorkspaceState> {
  /// Whether the persisted workspace mode is still being loaded.
  final bool isLoading;

  /// The currently active production mode.
  final OcptWorkspaceMode mode;

  /// What [mode] should land on, handed over by the mode that asked for the switch, or null — the
  /// ordinary case — to leave [mode] on its own default.
  ///
  /// The bloc never reads inside it: it holds the request until the opened mode reports having
  /// consumed it, which keeps this state about *which mode is active* and nothing about a mode's
  /// own content (ADR 0006). See [OcptWorkspaceRevealRequest].
  final OcptWorkspaceRevealRequest? revealRequest;

  /// Class constructor
  const OcptWorkspaceState({required this.isLoading, required this.mode, this.revealRequest});

  /// Init class constructor
  const OcptWorkspaceState.init()
    : isLoading = true,
      mode = OcptWorkspaceMode.screenplay,
      revealRequest = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [clearRevealRequest] is how [revealRequest] goes back to null, a null [revealRequest] meaning
  /// "leave it alone" like every other nullable field of a state in this app.
  @override
  OcptWorkspaceState copyWith({
    bool? isLoading,
    OcptWorkspaceMode? mode,
    OcptWorkspaceRevealRequest? revealRequest,
    bool clearRevealRequest = false,
  }) => OcptWorkspaceState(
    isLoading: isLoading ?? this.isLoading,
    mode: mode ?? this.mode,
    revealRequest: clearRevealRequest ? null : revealRequest ?? this.revealRequest,
  );

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isLoading, mode, revealRequest];
}
