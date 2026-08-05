// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_state.dart';

/// This is the bloc class for the workspace page.
///
/// It owns exactly one thing: which production mode is active. Each mode keeps its own bloc and
/// state (including its own dock geometry); this bloc never reaches into them. The active mode is
/// loaded from, and persisted to, [OcptPropertiesManager.workspaceMode], so opening a project
/// restores the mode last used.
class OcptWorkspaceBloc extends BlocForMixin<OcptWorkspaceState> {
  /// The manager used to load and persist the active workspace mode.
  final OcptPropertiesManager _propertiesManager;

  /// Class constructor
  OcptWorkspaceBloc({OcptPropertiesManager? propertiesManager})
    : _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
      super(const OcptWorkspaceState.init()) {
    add(const OcptWorkspaceLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptWorkspaceLoadRequestedEvent>(_onLoadRequested);
    on<OcptWorkspaceModeSelectedEvent>(_onModeSelected);
    on<OcptWorkspaceRevealRequestConsumedEvent>(_onRevealRequestConsumed);
  }

  /// Loads the persisted workspace mode, defaulting to [OcptWorkspaceMode.screenplay].
  Future<void> _onLoadRequested(
    OcptWorkspaceLoadRequestedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async {
    final mode = await _propertiesManager.workspaceMode.load() ?? OcptWorkspaceMode.screenplay;
    emitter(state.copyWith(isLoading: false, mode: mode));
  }

  /// Applies and persists the mode selected from the bottom mode switcher, or by another mode
  /// sending the user there.
  ///
  /// `event.revealRequest` is carried into the state untouched and never read here: what a mode
  /// should land on is that mode's own business, and this bloc only owns which one is active
  /// (ADR 0006). A switch that names nothing — every switch the mode switcher itself makes —
  /// clears whatever an earlier one left behind, so a request can never outlive the switch it was
  /// made for.
  Future<void> _onModeSelected(
    OcptWorkspaceModeSelectedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async {
    emitter(
      state.copyWith(
        mode: event.mode,
        revealRequest: event.revealRequest,
        clearRevealRequest: event.revealRequest == null,
      ),
    );
    await _propertiesManager.workspaceMode.store(event.mode);
  }

  /// Clears the reveal request the mode that was just opened reports having taken into account.
  ///
  /// Nothing is persisted here: a reveal is a one-shot handover between two modes of one session,
  /// not a preference. Only the mode itself is ever persisted.
  Future<void> _onRevealRequestConsumed(
    OcptWorkspaceRevealRequestConsumedEvent event,
    Emitter<OcptWorkspaceState> emitter,
  ) async => emitter(state.copyWith(clearRevealRequest: true));
}
