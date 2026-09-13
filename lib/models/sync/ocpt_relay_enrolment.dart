// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The two pieces of information the on-set relay's own enrolment QR carries so a device can be
/// pointed at it: the relay to talk to and the instance-wide enrolment secret that lets the very
/// first append create a project there (`docs/plans/on-set-server.md`, Phase C).
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
/// every value percent-encoded as an ordinary URI query parameter. [OcptRelayEnrolment.parse] (or
/// [tryParse]) reads that string back, rejecting anything that is not this exact shape — a QR code
/// aimed at some unrelated app, or at the sharing screen's own `ocpt://join` invite, must fail
/// cleanly rather than half-parse.
class OcptRelayEnrolment extends Equatable {
  /// Class constructor
  const OcptRelayEnrolment({required this.relayBaseUri, required this.enrolmentSecret});

  /// Parses [enrolmentString] back into an [OcptRelayEnrolment], throwing a [FormatException] when
  /// it is not an `ocpt://relay` URI carrying both `r` and `e` non-empty.
  factory OcptRelayEnrolment.parse(String enrolmentString) {
    final Uri uri;
    try {
      uri = Uri.parse(enrolmentString);
    } on FormatException {
      throw const FormatException('Not a valid enrolment: malformed URI.');
    }

    if (uri.scheme != _scheme) {
      throw FormatException('Not a valid enrolment: expected scheme "$_scheme".', enrolmentString);
    }
    if (uri.host != _host) {
      throw FormatException('Not a valid enrolment: expected host "$_host".', enrolmentString);
    }

    final relay = uri.queryParameters[_relayParam];
    final secret = uri.queryParameters[_secretParam];
    if (relay == null || relay.isEmpty) {
      throw FormatException('Not a valid enrolment: missing "$_relayParam".', enrolmentString);
    }
    if (secret == null || secret.isEmpty) {
      throw FormatException('Not a valid enrolment: missing "$_secretParam".', enrolmentString);
    }

    final Uri relayBaseUri;
    try {
      relayBaseUri = Uri.parse(relay);
    } on FormatException {
      throw FormatException('Not a valid enrolment: malformed "$_relayParam".', enrolmentString);
    }

    return OcptRelayEnrolment(relayBaseUri: relayBaseUri, enrolmentSecret: secret);
  }

  /// Same as [OcptRelayEnrolment.parse], but returns null instead of throwing when
  /// [enrolmentString] is not a valid enrolment.
  static OcptRelayEnrolment? tryParse(String enrolmentString) {
    try {
      return OcptRelayEnrolment.parse(enrolmentString);
    } on FormatException {
      return null;
    }
  }

  static const String _scheme = 'ocpt';
  static const String _host = 'relay';
  static const String _relayParam = 'r';
  static const String _secretParam = 'e';

  /// The set relay this enrolment points at, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The instance-wide secret authenticating the first append to [relayBaseUri] for whichever
  /// project a device re-points there. Never logged or displayed in full — see [toString].
  final String enrolmentSecret;

  /// Encodes this enrolment as the single string a QR code carries and
  /// [OcptRelayEnrolment.parse] reads back: `ocpt://relay?r=<relayBaseUri>&e=<enrolmentSecret>`,
  /// every value percent-encoded.
  String toEnrolmentString() => Uri(
    scheme: _scheme,
    host: _host,
    queryParameters: <String, String>{_relayParam: relayBaseUri.toString(), _secretParam: enrolmentSecret},
  ).toString();

  /// Object properties
  @override
  List<Object?> get props => [relayBaseUri, enrolmentSecret];

  /// A human-readable summary that never leaks [enrolmentSecret] in full.
  @override
  String toString() {
    final maskedSecret = enrolmentSecret.length <= 4
        ? '***'
        : '${enrolmentSecret.substring(0, 2)}***${enrolmentSecret.substring(enrolmentSecret.length - 2)}';
    return 'OcptRelayEnrolment(relayBaseUri: $relayBaseUri, enrolmentSecret: $maskedSecret)';
  }
}
