// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_uri_query.dart';
import 'package:open_cine_prod_tools/types/ocpt_relay_invite_status.dart';

/// The three pieces of information the Partager screen's QR code carries so the Rejoindre screen
/// can pair to the same project: the relay to talk to, the project it holds, and the token that
/// authenticates every request to it.
///
/// [toInviteString] encodes the three as a single custom-scheme URI a QR code can hold and a
/// camera scan or manual entry can read back byte-for-byte:
///
/// ```text
/// ocpt://join?r=<relayBaseUri>&p=<projectId>&t=<token>
/// ```
///
/// every value percent-encoded as an ordinary URI query parameter. [OcptRelayInvite.parse] reads
/// that string back, rejecting anything that is not this exact shape — a QR code aimed at some
/// unrelated app must fail cleanly rather than half-parse.
class OcptRelayInvite extends Equatable {
  /// The URI scheme of an invite link.
  static const String _scheme = 'ocpt';

  /// The host part of an invite link.
  static const String _host = 'join';

  /// The query parameter holding the relay address.
  static const String _relayParam = 'r';

  /// The query parameter holding the project id.
  static const String _projectIdParam = 'p';

  /// The query parameter holding the access token.
  static const String _tokenParam = 't';

  /// The relay this invite pairs to, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The project this invite gives access to, matching `project_info.id`.
  final String projectId;

  /// The secret authenticating every request to [relayBaseUri] for [projectId]. Never logged or
  /// displayed in full — see [toString].
  final String token;

  /// Class constructor
  const OcptRelayInvite({required this.relayBaseUri, required this.projectId, required this.token});

  /// Encode this invite as the single string a QR code carries and [OcptRelayInvite.parse] reads
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

  /// Get a human-readable summary that never leaks [token] in full.
  @override
  String toString() {
    final maskedToken = token.length <= 4
        ? '***'
        : '${token.substring(0, 2)}***${token.substring(token.length - 2)}';
    return 'OcptRelayInvite(relayBaseUri: $relayBaseUri, projectId: $projectId, '
        'token: $maskedToken)';
  }

  /// Parse [inviteString] back into an [OcptRelayInvite], answering the matching failure status
  /// (and no value) when it is not an `ocpt://join` URI carrying all three of `r`, `p` and `t`
  /// non-empty.
  ///
  /// A failure is not logged: the string is, or holds, a token.
  static ResultWithStatus<OcptRelayInviteStatus, OcptRelayInvite> parse(String inviteString) {
    final uri = Uri.tryParse(inviteString);
    if (uri == null) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.malformedUri);
    }

    if (uri.scheme != _scheme) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.wrongScheme);
    }
    if (uri.host != _host) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.wrongHost);
    }

    // A percent-escape that is not valid UTF-8 parses as a URI but throws on this read.
    final query = ocptQueryParametersOrNull(uri);
    if (query == null) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.malformedUri);
    }
    final relay = query[_relayParam];
    final projectId = query[_projectIdParam];
    final token = query[_tokenParam];
    if (relay == null || relay.isEmpty) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.missingRelay);
    }
    if (projectId == null || projectId.isEmpty) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.missingProjectId);
    }
    if (token == null || token.isEmpty) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.missingToken);
    }

    final relayBaseUri = Uri.tryParse(relay);
    if (relayBaseUri == null) {
      return const ResultWithStatus(status: OcptRelayInviteStatus.malformedRelay);
    }

    return ResultWithStatus(
      status: OcptRelayInviteStatus.ok,
      value: OcptRelayInvite(relayBaseUri: relayBaseUri, projectId: projectId, token: token),
    );
  }

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [relayBaseUri, projectId, token];
}
