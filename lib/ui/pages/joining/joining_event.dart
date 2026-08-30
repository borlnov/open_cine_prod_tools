// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `OcptJoiningBloc`.
sealed class OcptJoiningEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptJoiningEvent();
}

/// Reports that the manual entry form's "Rejoindre" button was pressed, with its three raw fields
/// as typed — none of them validated yet, since that needs no `Tr` and the bloc does it itself
/// (see `OcptJoiningBloc._onManualSubmitted`'s own doc comment for why).
class OcptJoiningManualSubmittedEvent extends OcptJoiningEvent {
  /// The relay address the user typed, as free text.
  final String relayAddressText;

  /// The project id the user typed, as free text.
  final String projectIdText;

  /// The project token the user typed, as free text.
  final String tokenText;

  /// Class constructor
  const OcptJoiningManualSubmittedEvent({
    required this.relayAddressText,
    required this.projectIdText,
    required this.tokenText,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, relayAddressText, projectIdText, tokenText];
}

/// Reports that the camera scanner found a QR code, carrying its raw decoded text — not
/// necessarily a valid invite, which the bloc is the one to decide
/// (`OcptRelayInvite.tryParse`).
class OcptJoiningInviteScannedEvent extends OcptJoiningEvent {
  /// The raw text the camera decoded from the scanned code.
  final String scannedText;

  /// Class constructor
  const OcptJoiningInviteScannedEvent(this.scannedText);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, scannedText];
}

/// Reports that the page has shown `OcptJoiningState.joinFailed`'s own snack bar, so the bloc
/// clears the flag and a later rebuild doesn't show it again — the same one-shot-notice shape
/// `OcptSharingBloc`'s own `pairingFailed` already follows.
class OcptJoiningErrorDismissedEvent extends OcptJoiningEvent {
  /// Class constructor
  const OcptJoiningErrorDismissedEvent();
}
