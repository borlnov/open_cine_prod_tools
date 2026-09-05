// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The three pieces of information the Partager screen's QR code carries so the Rejoindre screen
/// can pair to the same project: the relay to talk to, the project it holds, and the token that
/// authenticates every request to it (`docs/plans/relay.md`, Phase C, commit 2).
///
/// [toInviteString] encodes the three as a single custom-scheme URI a QR code can hold and a
/// camera scan or manual entry can read back byte-for-byte:
///
/// ```text
/// ocpt://join?r=<relayBaseUri>&p=<projectId>&t=<token>
/// ```
///
/// every value percent-encoded as an ordinary URI query parameter. [OcptRelayInvite.parse] (or
/// [tryParse]) reads that string back, rejecting anything that is not this exact shape — a QR code
/// aimed at some unrelated app must fail cleanly rather than half-parse.
class OcptRelayInvite extends Equatable {
  /// Class constructor
  const OcptRelayInvite({
    required this.relayBaseUri,
    required this.projectId,
    required this.token,
  });

  /// Parses [inviteString] back into an [OcptRelayInvite], throwing a [FormatException] when it is
  /// not an `ocpt://join` URI carrying all three of `r`, `p` and `t` non-empty.
  factory OcptRelayInvite.parse(String inviteString) {
    final Uri uri;
    try {
      uri = Uri.parse(inviteString);
    } on FormatException {
      throw const FormatException('Not a valid invite: malformed URI.');
    }

    if (uri.scheme != _scheme) {
      throw FormatException('Not a valid invite: expected scheme "$_scheme".', inviteString);
    }
    if (uri.host != _host) {
      throw FormatException('Not a valid invite: expected host "$_host".', inviteString);
    }

    final relay = uri.queryParameters[_relayParam];
    final projectId = uri.queryParameters[_projectIdParam];
    final token = uri.queryParameters[_tokenParam];
    if (relay == null || relay.isEmpty) {
      throw FormatException('Not a valid invite: missing "$_relayParam".', inviteString);
    }
    if (projectId == null || projectId.isEmpty) {
      throw FormatException('Not a valid invite: missing "$_projectIdParam".', inviteString);
    }
    if (token == null || token.isEmpty) {
      throw FormatException('Not a valid invite: missing "$_tokenParam".', inviteString);
    }

    final Uri relayBaseUri;
    try {
      relayBaseUri = Uri.parse(relay);
    } on FormatException {
      throw FormatException('Not a valid invite: malformed "$_relayParam".', inviteString);
    }

    return OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: token);
  }

  /// Same as [OcptRelayInvite.parse], but returns null instead of throwing when [inviteString] is
  /// not a valid invite.
  static OcptRelayInvite? tryParse(String inviteString) {
    try {
      return OcptRelayInvite.parse(inviteString);
    } on FormatException {
      return null;
    }
  }

  static const String _scheme = 'ocpt';
  static const String _host = 'join';
  static const String _relayParam = 'r';
  static const String _projectIdParam = 'p';
  static const String _tokenParam = 't';

  /// The relay this invite pairs to, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The project this invite gives access to, matching `project_info.id`.
  final String projectId;

  /// The secret authenticating every request to [relayBaseUri] for [projectId]. Never logged or
  /// displayed in full — see [toString].
  final String token;

  /// Encodes this invite as the single string a QR code carries and [OcptRelayInvite.parse] reads
  /// back: `ocpt://join?r=<relayBaseUri>&p=<projectId>&t=<token>`, every value percent-encoded.
  String toInviteString() => Uri(
    scheme: _scheme,
    host: _host,
    queryParameters: <String, String>{
      _relayParam: relayBaseUri.toString(),
      _projectIdParam: projectId,
      _tokenParam: token,
    },
  ).toString();

  /// Object properties
  @override
  List<Object?> get props => [relayBaseUri, projectId, token];

  /// A human-readable summary that never leaks [token] in full.
  @override
  String toString() {
    final maskedToken = token.length <= 4
        ? '***'
        : '${token.substring(0, 2)}***${token.substring(token.length - 2)}';
    return 'OcptRelayInvite(relayBaseUri: $relayBaseUri, projectId: $projectId, '
        'token: $maskedToken)';
  }
}
