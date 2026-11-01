// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_uri_query.dart';
import 'package:open_cine_prod_tools/types/ocpt_relay_enrolment_status.dart';

/// The two pieces of information the on-set relay's own enrolment QR carries so a device can be
/// pointed at it: the relay to talk to and the instance-wide enrolment secret that lets the very
/// first append create a project there.
///
/// This deliberately carries neither a project id nor a project token — unlike `OcptRelayInvite`,
/// which pairs one specific project to one specific relay, this QR only ever points a device at a
/// *relay*: the "Changer de relais" flow it feeds still recovers the project's own existing token
/// from the pairing already on disk (`OcptSyncManager.repointProjectToRelay`) rather than minting
/// or carrying one. Scanning it therefore never hands out a project's own credential — only where
/// to look for the set relay and the shared secret that lets a device introduce itself to it.
///
/// [toEnrolmentString] encodes the two as a single custom-scheme URI a QR code can hold and a
/// camera scan or manual entry can read back byte-for-byte:
///
/// ```text
/// ocpt://relay?r=<relayBaseUri>&e=<enrolmentSecret>
/// ```
///
/// every value percent-encoded as an ordinary URI query parameter. [OcptRelayEnrolment.parse] reads that string back, rejecting anything that is not this exact shape — a QR code
/// aimed at some unrelated app, or at the sharing screen's own `ocpt://join` invite, must fail
/// cleanly rather than half-parse.
class OcptRelayEnrolment extends Equatable {
  /// The URI scheme of an enrolment link.
  static const String _scheme = 'ocpt';

  /// The host part of an enrolment link.
  static const String _host = 'relay';

  /// The query parameter holding the relay address.
  static const String _relayParam = 'r';

  /// The query parameter holding the enrolment secret.
  static const String _secretParam = 'e';

  /// The set relay this enrolment points at, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The instance-wide secret authenticating the first append to [relayBaseUri] for whichever
  /// project a device re-points there. Never logged or displayed in full — see [toString].
  final String enrolmentSecret;

  /// Class constructor
  const OcptRelayEnrolment({required this.relayBaseUri, required this.enrolmentSecret});

  /// Encode this enrolment as the single string a QR code carries and
  /// [OcptRelayEnrolment.parse] reads back: `ocpt://relay?r=<relayBaseUri>&e=<enrolmentSecret>`,
  /// every value percent-encoded.
  String toEnrolmentString() => Uri(
    scheme: _scheme,
    host: _host,
    queryParameters: <String, String>{
      _relayParam: relayBaseUri.toString(),
      _secretParam: enrolmentSecret,
    },
  ).toString();

  /// Get a human-readable summary that never leaks [enrolmentSecret] in full.
  @override
  String toString() {
    final secretLength = enrolmentSecret.length;
    final maskedSecret = secretLength <= 4
        ? '***'
        : '${enrolmentSecret.substring(0, 2)}***${enrolmentSecret.substring(secretLength - 2)}';
    return 'OcptRelayEnrolment(relayBaseUri: $relayBaseUri, enrolmentSecret: $maskedSecret)';
  }

  /// Parse [enrolmentString] back into an [OcptRelayEnrolment], answering the matching failure
  /// status (and no value) when it is not an `ocpt://relay` URI carrying both `r` and `e`
  /// non-empty.
  ///
  /// A failure is not logged: the string is, or holds, a secret.
  static ResultWithStatus<OcptRelayEnrolmentStatus, OcptRelayEnrolment> parse(
    String enrolmentString,
  ) {
    final uri = Uri.tryParse(enrolmentString);
    if (uri == null) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.malformedUri);
    }

    if (uri.scheme != _scheme) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.wrongScheme);
    }
    if (uri.host != _host) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.wrongHost);
    }

    // A percent-escape that is not valid UTF-8 parses as a URI but throws on this read.
    final query = ocptQueryParametersOrNull(uri);
    if (query == null) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.malformedUri);
    }
    final relay = query[_relayParam];
    final secret = query[_secretParam];
    if (relay == null || relay.isEmpty) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.missingRelay);
    }
    if (secret == null || secret.isEmpty) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.missingSecret);
    }

    final relayBaseUri = Uri.tryParse(relay);
    if (relayBaseUri == null) {
      return const ResultWithStatus(status: OcptRelayEnrolmentStatus.malformedRelay);
    }

    return ResultWithStatus(
      status: OcptRelayEnrolmentStatus.ok,
      value: OcptRelayEnrolment(relayBaseUri: relayBaseUri, enrolmentSecret: secret),
    );
  }

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [relayBaseUri, enrolmentSecret];
}
