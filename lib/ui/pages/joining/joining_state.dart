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

  /// Whether the user cancelled the join in flight, set by `OcptJoiningCancelledEvent`'s handler
  /// and checked by the join after every `await` along its path, to bail out — without navigating
  /// and without reporting success — the moment the user asks to cancel. Cleared the moment a new
  /// join starts.
  ///
  /// This is a best-effort UI abandon only: `dart:io` gives no way to actually cancel an in-flight
  /// snapshot fetch or materialisation already under way, so a cancelled join may still finish
  /// writing a `.ocpt` to disk after this flag is set — that file is simply never opened or shown,
  /// which is an acceptable cost for how rarely a cancel lands mid-write.
  final bool isCancelled;

  /// Class constructor
  const OcptJoiningState({
    required this.isJoining,
    required this.joinFailed,
    this.joinStep,
    this.joinSucceeded = false,
    this.isCancelled = false,
  });

  /// The initial state, shown before the user has submitted anything.
  const OcptJoiningState.init()
    : isJoining = false,
      joinFailed = false,
      joinStep = null,
      joinSucceeded = false,
      isCancelled = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [joinStep] legitimately goes back to null once a join ends, so it has its own
  /// `forceJoinStepValue` flag rather than a bare nullable parameter, which could never tell "leave
  /// it alone" apart from "clear it" — exactly `OcptHostingState.forcePresenceRosterValue`'s own
  /// reasoning.
  @override
  OcptJoiningState copyWith({
    bool? isJoining,
    bool? joinFailed,
    OcptJoinStep? joinStep,
    bool forceJoinStepValue = false,
    bool? joinSucceeded,
    bool? isCancelled,
  }) => OcptJoiningState(
    isJoining: isJoining ?? this.isJoining,
    joinFailed: joinFailed ?? this.joinFailed,
    joinStep: joinStep ?? (forceJoinStepValue ? null : this.joinStep),
    joinSucceeded: joinSucceeded ?? this.joinSucceeded,
    isCancelled: isCancelled ?? this.isCancelled,
  );

  /// Copy this state with the scanned code flagged as not being a valid invite.
  OcptJoiningState copyWithInviteRejected() => copyWith(joinFailed: true);

  /// Copy this state with a join started, at its first step.
  OcptJoiningState copyWithJoinStarted() => copyWith(
    isJoining: true,
    joinFailed: false,
    joinSucceeded: false,
    isCancelled: false,
    joinStep: OcptJoinStep.connecting,
  );

  /// Copy this state back to idle: no join under way and no step shown.
  OcptJoiningState copyToIdle() => copyWith(isJoining: false, forceJoinStepValue: true);

  /// Copy this state back to idle with the join in flight marked as cancelled by the user.
  OcptJoiningState copyToCancelled() =>
      copyWith(isJoining: false, forceJoinStepValue: true, isCancelled: true);

  /// Copy this state with the join at its downloading step.
  OcptJoiningState copyWithDownloading() => copyWith(joinStep: OcptJoinStep.downloading);

  /// Copy this state with the join at its opening step.
  OcptJoiningState copyWithOpening() => copyWith(joinStep: OcptJoinStep.opening);

  /// Copy this state with the join ended on a failure.
  OcptJoiningState copyWithJoinFailed() =>
      copyWith(isJoining: false, joinFailed: true, forceJoinStepValue: true);

  /// Copy this state with the join ended on a success.
  OcptJoiningState copyWithJoinSucceeded() =>
      copyWith(isJoining: false, joinSucceeded: true, forceJoinStepValue: true);

  /// Copy this state with the failure dismissed.
  OcptJoiningState copyWithFailureDismissed() => copyWith(joinFailed: false);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isJoining,
    joinFailed,
    joinStep,
    joinSucceeded,
    isCancelled,
  ];
}
