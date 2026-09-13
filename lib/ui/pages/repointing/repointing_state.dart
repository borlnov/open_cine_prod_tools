// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';

/// The state of `OcptRepointingBloc`.
///
/// The page's two states (`docs/plans/on-set-server.md`, Phase E) are one screen reading a single
/// fact: whether [enrolment] is null. Null is ① Configure — the relay address and enrolment secret
/// form, shown every time the page opens, even for a project already paired elsewhere — and
/// non-null is ② QR code, the enrolment QR the next crew member scans, drawn straight off it.
class OcptRepointingState extends BlocStateForMixin<OcptRepointingState> {
  /// Whether the current project's own name is still being loaded from the projects manager.
  final bool isLoading;

  /// The current project's display name, shown in the page's own title — `""` while [isLoading],
  /// never actually rendered then (the page shows a spinner instead, exactly as
  /// `OcptSharingState.projectName`'s own doc comment describes its own placeholder).
  final String projectName;

  /// Whether a "Switch relay" submission is in flight.
  final bool isRepointing;

  /// Whether the last re-point attempt failed — cleared the moment a new one starts.
  ///
  /// A bare flag rather than the raised exception's own message: this bloc has no `Tr` to word one
  /// with (`docs/architecture/foundations.md`), so the page reads this and shows its own generic,
  /// localized wording.
  final bool repointFailed;

  /// The enrolment this project was just re-pointed to, or null while ① Configure is still shown.
  final OcptRelayEnrolment? enrolment;

  /// Class constructor
  const OcptRepointingState({
    required this.isLoading,
    required this.projectName,
    required this.isRepointing,
    required this.repointFailed,
    required this.enrolment,
  });

  /// The initial state, shown for the brief moment before the load completes.
  const OcptRepointingState.init()
    : isLoading = true,
      projectName = "",
      isRepointing = false,
      repointFailed = false,
      enrolment = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [enrolment] legitimately goes back to null every time the page is re-entered, so it has its
  /// own [clearEnrolment] flag rather than a bare nullable parameter, which could never tell "leave
  /// it alone" apart from "clear it" — exactly `OcptSharingState.clearInvite`'s own reasoning.
  @override
  OcptRepointingState copyWith({
    bool? isLoading,
    String? projectName,
    bool? isRepointing,
    bool? repointFailed,
    OcptRelayEnrolment? enrolment,
    bool clearEnrolment = false,
  }) => OcptRepointingState(
    isLoading: isLoading ?? this.isLoading,
    projectName: projectName ?? this.projectName,
    isRepointing: isRepointing ?? this.isRepointing,
    repointFailed: repointFailed ?? this.repointFailed,
    enrolment: clearEnrolment ? null : (enrolment ?? this.enrolment),
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    projectName,
    isRepointing,
    repointFailed,
    enrolment,
  ];
}
