// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `OcptJoiningBloc`.
sealed class OcptJoiningEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptJoiningEvent();
}

/// Reports that the manual entry form's "Rejoindre" button was pressed, with the pasted invite
/// link as typed — not validated yet, since that needs no `Tr` and the bloc does it itself
/// (see `OcptJoiningBloc._onManualSubmitted`'s own doc comment for why).
class OcptJoiningManualSubmittedEvent extends OcptJoiningEvent {
  /// The invite link the user pasted, as free text.
  final String inviteLinkText;

  /// Class constructor
  const OcptJoiningManualSubmittedEvent({required this.inviteLinkText});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, inviteLinkText];
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

/// Reports that the success modal's own "Ouvrir" button was pressed, once `joinSucceeded` is true:
/// the bloc navigates to the workspace only now, on the user's explicit ask, rather than the moment
/// the join itself finishes.
class OcptJoiningOpenRequestedEvent extends OcptJoiningEvent {
  /// Class constructor
  const OcptJoiningOpenRequestedEvent();
}

/// Reports that the blocking modal's own "Annuler" button was pressed while a join is in flight.
///
/// A best-effort UI abandon only: `dart:io` gives no way to actually cancel an in-flight snapshot
/// fetch or materialisation, so a join already past that point may still finish writing a `.ocpt`
/// to disk after this is dispatched — the user is simply returned to the Rejoindre screen's own
/// idle state without ever seeing it, and without being navigated to the workspace.
class OcptJoiningCancelledEvent extends OcptJoiningEvent {
  /// Class constructor
  const OcptJoiningCancelledEvent();
}
