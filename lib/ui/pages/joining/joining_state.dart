// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The coarse phase of a join currently in flight, shown by the Rejoindre screen's own blocking
/// modal while `OcptJoiningState.isJoining` is true — nothing on the join path reports incremental
/// progress within a phase, so this is the whole of what the modal has to show.
enum OcptJoinStep {
  /// Resolving where the new project lands (the desktop destination picker, or the application's
  /// own documents directory on mobile) and opening the relay transport.
  connecting,

  /// Fetching and materialising the relay's latest snapshot as a new project on disk
  /// (`OcptSyncManager.joinFromRelay`).
  downloading,

  /// Opening the freshly written project (`OcptProjectsManager.openProject`).
  opening,
}

/// The state of `OcptJoiningBloc`.
///
/// The page has nothing of its own to load on entry — unlike `OcptSharingState`, there is no
/// project open yet to read a pairing off — so this state carries only what a join in progress
/// needs: whether one is running and which phase it is in, whether it just succeeded and is
/// waiting for the user to explicitly enter the project, and whether the last one failed.
class OcptJoiningState extends BlocStateForMixin<OcptJoiningState> {
  /// Whether a join is currently in flight — the blocking modal's own busy state.
  final bool isJoining;

  /// Whether the last join attempt failed — cleared the moment a new one starts.
  ///
  /// A bare flag rather than the raised exception's own message: this bloc has no `Tr` to word
  /// one with (`docs/architecture/foundations.md`), so the page reads this and shows its own
  /// generic, localized wording — exactly `OcptSharingState.pairingFailed`'s own reasoning.
  final bool joinFailed;

  /// The phase [isJoining] is currently in — null before a join starts and once it ends, whether
  /// by success, failure or cancellation.
  final OcptJoinStep? joinStep;

  /// Whether the last join succeeded and the freshly joined project already sits on disk, open and
  /// ready: the page shows a success state and waits for the user's explicit "Ouvrir" rather than
  /// navigating to the workspace on its own (`OcptJoiningOpenRequestedEvent`).
  final bool joinSucceeded;

  /// Class constructor
  const OcptJoiningState({
    required this.isJoining,
    required this.joinFailed,
    this.joinStep,
    this.joinSucceeded = false,
  });

  /// The initial state, shown before the user has submitted anything.
  const OcptJoiningState.init()
    : isJoining = false,
      joinFailed = false,
      joinStep = null,
      joinSucceeded = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [joinStep] legitimately goes back to null once a join ends, so it has its own `clearJoinStep`
  /// flag rather than a bare nullable parameter, which could never tell "leave it alone" apart from
  /// "clear it" — exactly `OcptHostingState.clearPresenceRoster`'s own reasoning.
  @override
  OcptJoiningState copyWith({
    bool? isJoining,
    bool? joinFailed,
    OcptJoinStep? joinStep,
    bool clearJoinStep = false,
    bool? joinSucceeded,
  }) => OcptJoiningState(
    isJoining: isJoining ?? this.isJoining,
    joinFailed: joinFailed ?? this.joinFailed,
    joinStep: clearJoinStep ? null : (joinStep ?? this.joinStep),
    joinSucceeded: joinSucceeded ?? this.joinSucceeded,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, isJoining, joinFailed, joinStep, joinSucceeded];
}
