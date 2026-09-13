// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';

/// The state of `OcptSharingBloc`.
///
/// The page's two states (`docs/plans/relay.md`, Phase C, commit 3) are one screen reading a
/// single fact: whether [invite] is null. Null is ① Configure — the project has never been paired,
/// or was unpaired since — and non-null is ② Invite, everything the QR and the connection card
/// render coming straight off it.
class OcptSharingState extends BlocStateForMixin<OcptSharingState> {
  /// Whether the project's own pairing is still being loaded from the database and secure storage.
  final bool isLoading;

  /// The current project's display name, shown in the page's own title — `""` while [isLoading],
  /// never actually rendered then (the page shows a spinner instead, exactly as
  /// `OcptProjectSettingsState.currencyCode`'s own doc comment describes its own placeholder).
  final String projectName;

  /// The current project's relay invite, or null while it is not paired.
  final OcptRelayInvite? invite;

  /// Whether a "Pair and create on the relay" submission is in flight.
  final bool isPairing;

  /// Whether the last pairing attempt failed — cleared the moment a new one starts.
  ///
  /// A bare flag rather than the raised exception's own message: this bloc has no `Tr` to word one
  /// with (`docs/architecture/foundations.md`), so the page reads this and shows its own generic,
  /// localized wording.
  final bool pairingFailed;

  /// Class constructor
  const OcptSharingState({
    required this.isLoading,
    required this.projectName,
    required this.invite,
    required this.isPairing,
    required this.pairingFailed,
  });

  /// The initial state, shown for the brief moment before the load completes.
  const OcptSharingState.init()
    : isLoading = true,
      projectName = "",
      invite = null,
      isPairing = false,
      pairingFailed = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [invite] legitimately goes back to null once the project is unpaired, so it has its own
  /// [clearInvite] flag rather than a bare nullable parameter, which could never tell "leave it
  /// alone" apart from "clear it" — exactly the reasoning `OcptProjectSettingsState`'s own
  /// `clearScreenplayLanguage` already follows.
  @override
  OcptSharingState copyWith({
    bool? isLoading,
    String? projectName,
    OcptRelayInvite? invite,
    bool clearInvite = false,
    bool? isPairing,
    bool? pairingFailed,
  }) => OcptSharingState(
    isLoading: isLoading ?? this.isLoading,
    projectName: projectName ?? this.projectName,
    invite: clearInvite ? null : (invite ?? this.invite),
    isPairing: isPairing ?? this.isPairing,
    pairingFailed: pairingFailed ?? this.pairingFailed,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    projectName,
    invite,
    isPairing,
    pairingFailed,
  ];
}
