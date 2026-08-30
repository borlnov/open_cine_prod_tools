// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The state of `OcptJoiningBloc`.
///
/// The page has nothing of its own to load on entry — unlike `OcptSharingState`, there is no
/// project open yet to read a pairing off — so this state carries only what a join in progress
/// needs: whether one is running, and whether the last one failed.
class OcptJoiningState extends BlocStateForMixin<OcptJoiningState> {
  /// Whether a join is currently in flight — the "Récupération du projet…" busy state.
  final bool isJoining;

  /// Whether the last join attempt failed — cleared the moment a new one starts.
  ///
  /// A bare flag rather than the raised exception's own message: this bloc has no `Tr` to word
  /// one with (`docs/architecture/foundations.md`), so the page reads this and shows its own
  /// generic, localized wording — exactly `OcptSharingState.pairingFailed`'s own reasoning.
  final bool joinFailed;

  /// Class constructor
  const OcptJoiningState({required this.isJoining, required this.joinFailed});

  /// The initial state, shown before the user has submitted anything.
  const OcptJoiningState.init() : isJoining = false, joinFailed = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptJoiningState copyWith({bool? isJoining, bool? joinFailed}) => OcptJoiningState(
    isJoining: isJoining ?? this.isJoining,
    joinFailed: joinFailed ?? this.joinFailed,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, isJoining, joinFailed];
}
