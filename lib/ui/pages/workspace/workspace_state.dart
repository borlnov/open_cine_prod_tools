// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

/// The state of `OcptWorkspaceBloc`.
class OcptWorkspaceState extends BlocStateForMixin<OcptWorkspaceState> {
  /// Whether the persisted workspace mode is still being loaded.
  final bool isLoading;

  /// The currently active production mode.
  final OcptWorkspaceMode mode;

  /// Class constructor
  const OcptWorkspaceState({required this.isLoading, required this.mode});

  /// Init class constructor
  const OcptWorkspaceState.init() : isLoading = true, mode = OcptWorkspaceMode.screenplay;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptWorkspaceState copyWith({bool? isLoading, OcptWorkspaceMode? mode}) => OcptWorkspaceState(
    isLoading: isLoading ?? this.isLoading,
    mode: mode ?? this.mode,
  );

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isLoading, mode];
}
