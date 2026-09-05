// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';

/// A slim, pure-Dart transport speaking two of `OcptRelayServer`'s own routes against an
/// **upstream** relay — the two a set relay needs to reconcile a changeset log with a prep relay
/// (`docs/plans/on-set-server.md`, Phase B): appending a changeset and reading the tail of the log
/// since a cursor. Snapshot routes are deliberately not spoken here — reconciliation never
/// exchanges snapshots, see the reconciler's own doc comment for why.
///
/// This class is a standalone client, not a shared implementation with the app's
/// `OcptRelayRemoteStorage` transport: the two mirror the same wire shapes
/// (`OcptRelayServer`'s own doc comment) because they talk to the same server, but this package
/// never imports app code, per this package's own domain-blindness (`OcptRelayStore`'s own doc
/// comment applies here too — this class never looks inside an envelope's payload).
class OcptRelayUpstreamClient {
  /// Creates a client talking to the upstream relay at [baseUri], authenticating every request
  /// with [token]. [httpClient] defaults to a fresh [http.Client] — inject one in a test to avoid
  /// a real socket, or to reuse a client already open.
  OcptRelayUpstreamClient({required this.baseUri, required this.token, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const _authorizationHeader = 'Authorization';
  static const _enrolmentSecretHeader = 'X-Ocpt-Enrolment-Secret';
  static const _contentTypeHeader = 'content-type';
  static const _contentTypeJson = 'application/json';
  static const _sinceParam = 'since';
  static const _sequenceKey = 'sequence';

  /// The upstream relay this client talks to, e.g. `https://relay.example.org/`.
  final Uri baseUri;

  /// The bearer token authenticating every request this client makes against the upstream.
  final String token;

  final http.Client _httpClient;

  /// Closes the underlying [http.Client]. Call this once this client is no longer needed.
  void close() => _httpClient.close();

  /// Every changeset the upstream relay's log holds for [projectId] strictly after [cursor],
  /// oldest first — `GET <baseUri>/projects/<projectId>/changesets?since=<cursor.value>`.
  ///
  /// Throws [StateError] carrying the response's status and body when the upstream answers
  /// anything but `200` — this is operator tooling run from a terminal, so a thrown error that
  /// aborts the run with a readable message is the right behaviour, not a typed exception a caller
  /// is expected to catch and recover from.
  Future<List<OcptStoredChangeset>> readChangesetsSince(String projectId, OcptSequenceNumber cursor) async {
    final response = await _httpClient.get(
      _changesetsUri(projectId).replace(queryParameters: {_sinceParam: cursor.value.toString()}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, action: 'read changesets since $cursor for project $projectId');

    final decoded = jsonDecode(response.body) as List<dynamic>;

    return [
      for (final entry in decoded) OcptStoredChangeset.fromJson(entry as Map<String, dynamic>),
    ];
  }

  /// Appends [envelope] to the upstream relay's log for [projectId] and returns the sequence
  /// number it was assigned there — `POST <baseUri>/projects/<projectId>/changesets`.
  ///
  /// [enrolmentSecret] is sent as `X-Ocpt-Enrolment-Secret` only when non-null, letting the
  /// upstream create [projectId] on its first append exactly as `OcptRelayServer`'s own doc
  /// comment describes; omit it once the project is known to already exist there. Throws
  /// [StateError] as [readChangesetsSince] does when the upstream answers anything but `200`.
  Future<OcptSequenceNumber> appendChangeset(
    String projectId,
    OcptChangesetEnvelope envelope, {
    String? enrolmentSecret,
  }) async {
    final response = await _httpClient.post(
      _changesetsUri(projectId),
      headers: {
        ..._authHeaders(),
        _contentTypeHeader: _contentTypeJson,
        if (enrolmentSecret != null) _enrolmentSecretHeader: enrolmentSecret,
      },
      body: jsonEncode(envelope.toJson()),
    );
    _throwIfFailed(response, action: 'append changeset ${envelope.changesetId} for project $projectId');

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return OcptSequenceNumber(json[_sequenceKey] as int);
  }

  /// Builds `<baseUri>/projects/<projectId>/changesets`, joining paths explicitly rather than
  /// through [Uri.resolve] — which would silently drop [baseUri]'s last path segment when it does
  /// not already end in `/` — mirroring the app's `OcptRelayRemoteStorage._projectUri`.
  Uri _changesetsUri(String projectId) {
    final basePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;

    return baseUri.replace(path: '$basePath/projects/$projectId/changesets');
  }

  Map<String, String> _authHeaders() => {_authorizationHeader: 'Bearer $token'};

  /// Throws a [StateError] describing [action], [response]'s status code and its body when
  /// [response] is not a `200`.
  void _throwIfFailed(http.Response response, {required String action}) {
    if (response.statusCode == 200) {
      return;
    }
    throw StateError(
      'failed to $action against $baseUri: HTTP ${response.statusCode} — ${response.body}',
    );
  }
}
