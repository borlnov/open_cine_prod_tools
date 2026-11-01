// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';

/// A project's relay pairing, the two halves [OcptPairingService] keeps in step: the relay it is
/// paired with and the token authenticating every request to it.
///
/// This never carries the enrolment secret: that is a create-time-only value used once by the
/// transport to let it create the project on the relay the first time it is pushed there, and is
/// never persisted by anything — see `OcptRelayRemoteStorage`'s own doc comment.
class OcptProjectPairing extends Equatable {
  /// The relay this project is paired with, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The bearer token authenticating every request this pairing's replica makes to
  /// [relayBaseUri] for this project.
  final String token;

  /// Class constructor
  const OcptProjectPairing({required this.relayBaseUri, required this.token});

  /// Get the class properties
  @override
  List<Object?> get props => [relayBaseUri, token];
}
