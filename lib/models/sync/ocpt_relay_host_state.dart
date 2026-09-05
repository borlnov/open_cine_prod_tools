// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What `OcptRelayHostManager` reports of itself, at every moment it runs — the lifecycle of the
/// one in-process relay it can host for a project at a time: stopped, starting, online (carrying
/// what a peer needs to enrol), or failed.
///
/// This is a status report only: nothing here writes anything, and a caller reads it purely to
/// render or to log — see `OcptRelayHostManager`'s own doc comment for what actually drives it
/// from one state to the next.
sealed class OcptRelayHostState extends Equatable {
  /// Class constructor
  const OcptRelayHostState();
}

/// Nothing is hosting right now. The state a manager starts in before hosting is ever started, and
/// the state it returns to once hosting is stopped.
final class OcptRelayHostStopped extends OcptRelayHostState {
  /// Class constructor
  const OcptRelayHostStopped();

  /// Object properties
  @override
  List<Object?> get props => const [];
}

/// Bring-up is in progress: the socket is being bound and the store opened, but nothing is being
/// served yet.
final class OcptRelayHostStarting extends OcptRelayHostState {
  /// Class constructor
  const OcptRelayHostStarting();

  /// Object properties
  @override
  List<Object?> get props => const [];
}

/// The in-process relay is up and serving. [lanBaseUri] is the advertised LAN base URI a peer
/// scans to reach it (e.g. `http://192.168.1.42:53187/`), and [enrolmentSecret] the stable
/// per-project secret that lets a peer's enrolment create the project on this relay — both are
/// exactly what the "Héberger sur ce poste" panel's enrolment QR carries.
final class OcptRelayHostOnline extends OcptRelayHostState {
  /// Class constructor
  const OcptRelayHostOnline({required this.lanBaseUri, required this.enrolmentSecret});

  /// The advertised LAN base URI a peer scans to reach this hosted relay.
  final Uri lanBaseUri;

  /// The stable per-project secret that grants project creation on this hosted relay.
  final String enrolmentSecret;

  /// Object properties
  @override
  List<Object?> get props => [lanBaseUri, enrolmentSecret];
}

/// Bring-up failed — the socket could not be bound, the store could not be opened, or anything
/// else went wrong before the relay ever started serving.
final class OcptRelayHostFailed extends OcptRelayHostState {
  /// Class constructor
  const OcptRelayHostFailed(this.message);

  /// A human-readable detail of what went wrong, meant for a log or a panel — never parsed.
  final String message;

  /// Object properties
  @override
  List<Object?> get props => [message];
}
