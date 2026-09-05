// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `OcptRepointingBloc`.
sealed class OcptRepointingEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptRepointingEvent();
}

/// Requests loading the current project's own display name.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptRepointingLoadRequestedEvent extends OcptRepointingEvent {
  /// Class constructor
  const OcptRepointingLoadRequestedEvent();
}

/// Reports that the "Switch relay" action was pressed, or a scanned relay enrolment QR was
/// resolved, with the relay address and the enrolment secret either typed into the ① Configure
/// form or read off the QR.
class OcptRepointingRequestedEvent extends OcptRepointingEvent {
  /// The relay address, already parsed — the page validates it is a well-formed URI before
  /// dispatching this event when it comes from the typed form, since the bloc has no `Tr` to word
  /// a validation error with. A scanned QR is always well-formed by construction
  /// (`OcptRelayEnrolment.tryParse`).
  final Uri relayBaseUri;

  /// The instance-wide enrolment secret, typed or scanned.
  final String enrolmentSecret;

  /// Class constructor
  const OcptRepointingRequestedEvent({required this.relayBaseUri, required this.enrolmentSecret});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, relayBaseUri, enrolmentSecret];
}

/// Reports that the page has shown `OcptRepointingState.repointFailed`'s own snack bar, so the
/// bloc clears the flag and a later rebuild doesn't show it again — the same one-shot-notice shape
/// `OcptSharingBloc`'s own `OcptSharingPairingErrorDismissedEvent` already follows.
class OcptRepointingErrorDismissedEvent extends OcptRepointingEvent {
  /// Class constructor
  const OcptRepointingErrorDismissedEvent();
}
