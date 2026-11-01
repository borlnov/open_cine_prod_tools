// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `OcptSharingBloc`.
sealed class OcptSharingEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptSharingEvent();
}

/// Reports that the "Pair and create on the relay" action was pressed, with the relay address and
/// the enrolment secret typed into the ① Configure form.
class OcptSharingPairRequestedEvent extends OcptSharingEvent {
  /// The relay address the user typed, already parsed — the page validates it is a well-formed
  /// URI before dispatching this event, since the bloc has no `Tr` to word a validation error with.
  final Uri relayBaseUri;

  /// The instance-wide enrolment secret the user typed.
  final String enrolmentSecret;

  /// Class constructor
  const OcptSharingPairRequestedEvent({required this.relayBaseUri, required this.enrolmentSecret});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, relayBaseUri, enrolmentSecret];
}

/// Reports that the user confirmed, through `OcptConfirmDialog` (opened by the page, never by the
/// footer button itself), stopping sharing this project.
class OcptSharingUnpairConfirmedEvent extends OcptSharingEvent {
  /// Class constructor
  const OcptSharingUnpairConfirmedEvent();
}

/// Reports that the page has shown `OcptSharingState.pairingFailed`'s own snack bar, so the bloc
/// clears the flag and a later rebuild doesn't show it again — the same one-shot-notice shape
/// `OcptEditorBloc`'s own `hasSaveError`/`ioNotice` already follow.
class OcptSharingPairingErrorDismissedEvent extends OcptSharingEvent {
  /// Class constructor
  const OcptSharingPairingErrorDismissedEvent();
}
