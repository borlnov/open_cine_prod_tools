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

  /// The label of the native folder picker's own confirm button, shown on desktop when picking the
  /// joined project's own destination folder.
  final String destinationConfirmButtonText;

  /// Class constructor
  const OcptJoiningManualSubmittedEvent({
    required this.inviteLinkText,
    required this.destinationConfirmButtonText,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, inviteLinkText, destinationConfirmButtonText];
}

/// Reports that the camera scanner found a QR code, carrying its raw decoded text — not
/// necessarily a valid invite, which the bloc is the one to decide
/// (`OcptRelayInvite.tryParse`).
class OcptJoiningInviteScannedEvent extends OcptJoiningEvent {
  /// The raw text the camera decoded from the scanned code.
  final String scannedText;

  /// The label of the native folder picker's own confirm button — see
  /// [OcptJoiningManualSubmittedEvent.destinationConfirmButtonText]. Scanning only ever happens on
  /// mobile, where no such dialog exists, but the field travels with every join attempt regardless,
  /// exactly as [OcptJoiningManualSubmittedEvent]'s own does.
  final String destinationConfirmButtonText;

  /// Class constructor
  const OcptJoiningInviteScannedEvent(
    this.scannedText, {
    required this.destinationConfirmButtonText,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, scannedText, destinationConfirmButtonText];
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
