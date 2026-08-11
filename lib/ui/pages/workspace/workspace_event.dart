// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
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

  /// What [mode] should land on once it is up, or null to leave it on its own default — which is
  /// what the mode switcher itself always passes, a user picking a mode from it having designated
  /// nothing but the mode.
  ///
  /// Non-null only when one mode sends the user to another *for a reason*: the breakdown's
  /// `Open in Resources` carries an [OcptResourcesRevealRequest] naming the very record whose sheet
  /// should be showing on arrival.
  final OcptWorkspaceRevealRequest? revealRequest;

  /// Class constructor
  const OcptWorkspaceModeSelectedEvent({required this.mode, this.revealRequest});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, mode, revealRequest];
}

/// Reports that the mode which was just opened has taken
/// [OcptWorkspaceModeSelectedEvent.revealRequest] into account, so it can be cleared.
///
/// Dispatched by the opened mode itself, on the one build that reads the request. Clearing it is
/// what makes a reveal one-shot: without it, coming back to that mode later would re-reveal a
/// record the user has since navigated away from.
class OcptWorkspaceRevealRequestConsumedEvent extends OcptWorkspaceEvent {
  /// Class constructor
  const OcptWorkspaceRevealRequestConsumedEvent();
}

/// Selects an episode from the toolbar's episode selector, built by `OcptWorkspaceShell` itself so
/// the gesture can't drift from one mode to the next.
///
/// Deliberately not persisted: see `OcptWorkspaceState.selectedEpisodeId`'s own doc comment for
/// why a reading preference like this one is cheaper to lose than to store.
class OcptWorkspaceEpisodeSelectedEvent extends OcptWorkspaceEvent {
  /// The id of the episode the user picked.
  final String episodeId;

  /// Class constructor
  const OcptWorkspaceEpisodeSelectedEvent({required this.episodeId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, episodeId];
}

/// Reloads the project's episodes after `OcptProjectsManager.currentProjectStream` emits.
///
/// Dispatched by the bloc's own stream subscription rather than sent by a widget — see
/// `OcptWorkspaceBloc`'s own doc comment for why entering or leaving a project version preview has
/// to be watched here.
class OcptWorkspaceEpisodesReloadRequestedEvent extends OcptWorkspaceEvent {
  /// Class constructor
  const OcptWorkspaceEpisodesReloadRequestedEvent();
}
