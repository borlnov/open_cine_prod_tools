// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
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

  /// The open project's episodes, in `OcptScreenplayService.loadEpisodes`'s own order (the
  /// episodes' `sortKey` order), or empty while none has been loaded yet or the open project holds
  /// none.
  final List<OcptEpisode> episodes;

  /// The id of the episode currently selected, or null while [episodes] is empty (nothing to
  /// select) or hasn't loaded yet.
  ///
  /// **Deliberately not persisted**: opening a project always lands on the first episode. A
  /// reading preference like this one costs nothing to lose, and a per-project key to store it
  /// under would have to live somewhere — either `OcptPropertiesManager`, keyed by a path that
  /// moves, or `project_info`, which project versions capture and hash. Nobody should add one
  /// later without weighing that cost again.
  final String? selectedEpisodeId;

  /// Class constructor
  const OcptWorkspaceState({
    required this.isLoading,
    required this.mode,
    this.revealRequest,
    this.episodes = const [],
    this.selectedEpisodeId,
  });

  /// Init class constructor
  const OcptWorkspaceState.init()
    : isLoading = true,
      mode = OcptWorkspaceMode.screenplay,
      revealRequest = null,
      episodes = const [],
      selectedEpisodeId = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [clearRevealRequest] is how [revealRequest] goes back to null, a null [revealRequest] meaning
  /// "leave it alone" like every other nullable field of a state in this app. [selectedEpisodeId]
  /// follows the same idiom through [clearSelectedEpisodeId], for the case (an episode-less
  /// project, in principle unreachable today) where it has to go back to null too.
  @override
  OcptWorkspaceState copyWith({
    bool? isLoading,
    OcptWorkspaceMode? mode,
    OcptWorkspaceRevealRequest? revealRequest,
    bool clearRevealRequest = false,
    List<OcptEpisode>? episodes,
    String? selectedEpisodeId,
    bool clearSelectedEpisodeId = false,
  }) => OcptWorkspaceState(
    isLoading: isLoading ?? this.isLoading,
    mode: mode ?? this.mode,
    revealRequest: clearRevealRequest ? null : revealRequest ?? this.revealRequest,
    episodes: episodes ?? this.episodes,
    selectedEpisodeId: clearSelectedEpisodeId
        ? null
        : selectedEpisodeId ?? this.selectedEpisodeId,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    mode,
    revealRequest,
    episodes,
    selectedEpisodeId,
  ];
}
