// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_remote_storage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A function establishing a WebSocket connection to [uri], returning the channel a caller reads
/// events from. [OcptRelayRemoteStorage] takes one as a constructor parameter so a test can hand it
/// a fake backed by a plain `StreamController` instead of opening a real socket.
typedef OcptWebSocketConnector = WebSocketChannel Function(Uri uri);

/// An [OcptRemoteStorage] talking to `packages/ocpt_sync_relay`'s five routes over HTTP and a
/// WebSocket — see `docs/plans/relay.md` (M4, Phase B) and
/// `docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`.
///
/// This class never imports `ocpt_sync_relay`: per ADR 0009, the app never depends on the relay
/// package, and speaks to it purely through `ocpt_sync_protocol`'s wire types and opaque bytes,
/// exactly as [OcptRemoteStorage] itself requires. The wire shapes below mirror
/// `OcptRelayServer`'s own doc comment one for one:
///
/// - `POST /projects/<projectId>/changesets` — body [OcptChangesetEnvelope.toJson]; `200` with
///   `{"sequence": <int>}`.
/// - `GET /projects/<projectId>/changesets?since=<seq>` — `since` always sent; `200` with a JSON
///   list of [OcptStoredChangeset.toJson], oldest first.
/// - `POST /projects/<projectId>/snapshot` — body
///   `{"descriptor": <OcptSnapshotDescriptor.toJson()>, "bytes": "<base64>"}`; `204`.
/// - `GET /projects/<projectId>/snapshot` — `200` with the same shape as the upload body, or `404`
///   when the project has no snapshot yet.
/// - `GET /projects/<projectId>/events` — a WebSocket; every message is an opaque "new work"
///   ping, react to arrival only.
///
/// Every route is authenticated with `Authorization: Bearer <token>`; an append that might be the
/// first request ever made for [projectId] also carries `X-Ocpt-Enrolment-Secret` when
/// [enrolmentSecret] is set (see that field's own doc comment). A non-2xx response is decoded as
/// [OcptSyncError] and thrown, except the snapshot route's `404`, which [fetchLatestSnapshot] maps
/// to `null` per its own contract.
class OcptRelayRemoteStorage implements OcptRemoteStorage {
  /// Creates a transport talking to the relay at [relayBaseUri] for [projectId], authenticating
  /// every request with [token].
  ///
  /// [enrolmentSecret] is only ever needed the first time this project is pushed to a relay that
  /// has never heard of it — the relay creates the project on that first append and ignores the
  /// header on every request after, so this class does not track whether creation already
  /// happened: when [enrolmentSecret] is set, [append] sends it every time, which is harmless once
  /// the project exists and keeps this class simple. A caller that knows creation has already
  /// succeeded (a previously paired project) simply does not pass one.
  ///
  /// [httpClient] defaults to a fresh [http.Client] and [webSocketConnector] to
  /// [IOWebSocketChannel.connect] carrying the bearer header — both are injectable so a test can
  /// substitute a `package:http/testing.dart` `MockClient` and a fake connector instead of a live
  /// relay.
  /// [reconnectDelay] is the backoff [newWorkStream] waits before reconnecting a dropped socket;
  /// its default is a sensible value for a real relay, and a test passes a short one so a
  /// regression in the reconnect path fails fast instead of timing out.
  OcptRelayRemoteStorage({
    required this.relayBaseUri,
    required this.projectId,
    required this.token,
    this.enrolmentSecret,
    http.Client? httpClient,
    OcptWebSocketConnector? webSocketConnector,
    this.reconnectDelay = const Duration(seconds: 2),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       // A bearer header on a WebSocket handshake is only possible because the default connector
       // below is `IOWebSocketChannel` (`dart:io`), which forwards arbitrary headers to
       // `WebSocket.connect` — the `dart:html` implementation this package also ships has no way
       // to set request headers at all, so this default only ever works on desktop/mobile, which
       // is the only place this transport runs.
       _webSocketConnector =
           webSocketConnector ??
           ((uri) => IOWebSocketChannel.connect(uri, headers: {_authorizationHeader: 'Bearer $token'}));

  static const _authorizationHeader = 'Authorization';
  static const _enrolmentSecretHeader = 'X-Ocpt-Enrolment-Secret';
  static const _contentTypeHeader = 'Content-Type';
  static const _contentTypeJson = 'application/json';
  static const _sinceParam = 'since';
  static const _sequenceKey = 'sequence';
  static const _descriptorKey = 'descriptor';
  static const _bytesKey = 'bytes';

  /// The relay instance this transport talks to, e.g. `https://relay.example.org/`.
  final Uri relayBaseUri;

  /// The project this transport reads and writes, as the relay names it in every route.
  final String projectId;

  /// The bearer token authenticating every request this transport makes against [projectId].
  final String token;

  /// The instance-wide secret letting [append] create [projectId] on the relay the first time it
  /// is pushed there, or null when this pairing never needs to create a project (see the
  /// constructor's own doc comment).
  final String? enrolmentSecret;

  /// How long [newWorkStream] waits after a dropped socket before reconnecting.
  final Duration reconnectDelay;

  final http.Client _httpClient;

  /// True when this transport created [_httpClient] itself (no [http.Client] was handed in), and
  /// so must close it itself from [dispose] rather than leaving that to whoever owns the client it
  /// was given.
  final bool _ownsHttpClient;
  final OcptWebSocketConnector _webSocketConnector;

  StreamController<void>? _newWorkController;
  WebSocketChannel? _activeSocket;
  StreamSubscription<Object?>? _activeSocketSubscription;
  Timer? _reconnectTimer;
  bool _newWorkStreamWanted = false;

  @override
  Future<OcptSequenceNumber> append(OcptChangesetEnvelope envelope) async {
    final response = await _httpClient.post(
      _changesetsUri(),
      headers: _jsonHeaders(includeEnrolmentSecret: true),
      body: jsonEncode(envelope.toJson()),
    );
    final json = _decodeObjectOrThrow(response);

    return OcptSequenceNumber.fromJson(json[_sequenceKey] as int);
  }

  @override
  Future<List<OcptStoredChangeset>> readSince(OcptSequenceNumber cursor) async {
    final response = await _httpClient.get(
      _changesetsUri().replace(queryParameters: {_sinceParam: cursor.value.toString()}),
      headers: _authHeaders(),
    );
    final decoded = _decodeListOrThrow(response);

    return [
      for (final entry in decoded) OcptStoredChangeset.fromJson(entry as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> uploadSnapshot(OcptSnapshotDescriptor descriptor, Uint8List bytes) async {
    final response = await _httpClient.post(
      _snapshotUri(),
      headers: _jsonHeaders(),
      body: jsonEncode({_descriptorKey: descriptor.toJson(), _bytesKey: base64Encode(bytes)}),
    );
    _throwIfFailed(response);
  }

  @override
  Future<(OcptSnapshotDescriptor, Uint8List)?> fetchLatestSnapshot() async {
    final response = await _httpClient.get(_snapshotUri(), headers: _authHeaders());
    if (response.statusCode == 404) {
      return null;
    }
    final json = _decodeObjectOrThrow(response);
    final descriptor = OcptSnapshotDescriptor.fromJson(json[_descriptorKey] as Map<String, dynamic>);
    final bytes = base64Decode(json[_bytesKey] as String);

    return (descriptor, bytes);
  }

  /// Releases every resource this transport holds: tears down the `events` WebSocket and its
  /// pending reconnect timer exactly as unsubscribing from [newWorkStream] would, closes that
  /// stream's own broadcast controller, and — only when this transport created its own
  /// [http.Client] rather than being handed one — closes that client too.
  ///
  /// [OcptRemoteStorage] declares no disposal method of its own (a folder-backed transport holds
  /// nothing that needs releasing), so a caller pairing a project with a relay owns calling this
  /// once it is done with the transport, exactly as it would for any other object it constructed
  /// with its own resources.
  void dispose() {
    _stopWatchingForNewWork();
    unawaited(_newWorkController?.close());
    _newWorkController = null;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  /// A broadcast stream emitting one event per opaque ping the relay's `events` WebSocket sends.
  ///
  /// Connecting starts only once this stream gets its first listener and stops the moment its last
  /// listener cancels, so an unpaired or idle transport never holds a socket open. While listened
  /// to, a dropped connection (the relay restarting, a network blip) is retried every
  /// [reconnectDelay] until it succeeds again; per [OcptRemoteStorage.newWorkStream]'s own
  /// contract, nothing is emitted while disconnected — a caller falls back to polling [readSince]
  /// during that window, exactly as it would for a transport with no push channel at all.
  @override
  Stream<void> get newWorkStream {
    // This controller lives for as long as the transport itself and is closed by dispose(), not
    // at the end of this getter — the lint cannot see that far.
    // ignore: close_sinks
    final controller = _newWorkController ??= StreamController<void>.broadcast(
      onListen: _startWatchingForNewWork,
      onCancel: _stopWatchingForNewWork,
    );

    return controller.stream;
  }

  void _startWatchingForNewWork() {
    _newWorkStreamWanted = true;
    _connectEventsSocket();
  }

  void _stopWatchingForNewWork() {
    _newWorkStreamWanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_activeSocketSubscription?.cancel());
    _activeSocketSubscription = null;
    unawaited(_activeSocket?.sink.close());
    _activeSocket = null;
  }

  void _connectEventsSocket() {
    if (!_newWorkStreamWanted) {
      return;
    }

    final WebSocketChannel socket;
    try {
      socket = _webSocketConnector(_eventsUri());
    } on Object {
      _scheduleReconnect();

      return;
    }

    _activeSocket = socket;
    _activeSocketSubscription = socket.stream.listen(
      (_) => _newWorkController?.add(null),
      onDone: () => _handleEventsSocketDown(socket),
      onError: (Object _) => _handleEventsSocketDown(socket),
      cancelOnError: true,
    );
  }

  /// Reacts to [socket] going down (from either end): reconnects only when [socket] is still the
  /// transport's active one — a socket superseded by [_stopWatchingForNewWork] or a fresh
  /// [_connectEventsSocket] call reports its own demise here too late to matter, and must not
  /// schedule a second, redundant reconnect.
  void _handleEventsSocketDown(WebSocketChannel socket) {
    if (!identical(_activeSocket, socket)) {
      return;
    }
    _activeSocket = null;
    _activeSocketSubscription = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_newWorkStreamWanted) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, _connectEventsSocket);
  }

  Uri _changesetsUri() => _projectUri('changesets');

  Uri _snapshotUri() => _projectUri('snapshot');

  Uri _eventsUri() {
    final httpUri = _projectUri('events');

    return httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
  }

  /// Builds `<relayBaseUri>/projects/<projectId>/<suffix>`, joining paths explicitly rather than
  /// through [Uri.resolve] — which would silently drop [relayBaseUri]'s last path segment when it
  /// does not already end in `/`.
  Uri _projectUri(String suffix) {
    final basePath = relayBaseUri.path.endsWith('/')
        ? relayBaseUri.path.substring(0, relayBaseUri.path.length - 1)
        : relayBaseUri.path;

    return relayBaseUri.replace(path: '$basePath/projects/$projectId/$suffix');
  }

  Map<String, String> _authHeaders({bool includeEnrolmentSecret = false}) => {
    _authorizationHeader: 'Bearer $token',
    if (includeEnrolmentSecret && enrolmentSecret != null) _enrolmentSecretHeader: enrolmentSecret!,
  };

  Map<String, String> _jsonHeaders({bool includeEnrolmentSecret = false}) => {
    ..._authHeaders(includeEnrolmentSecret: includeEnrolmentSecret),
    _contentTypeHeader: _contentTypeJson,
  };

  Map<String, dynamic> _decodeObjectOrThrow(http.Response response) {
    _throwIfFailed(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  List<dynamic> _decodeListOrThrow(http.Response response) {
    _throwIfFailed(response);

    return jsonDecode(response.body) as List<dynamic>;
  }

  /// Throws the [OcptSyncError] [response]'s body decodes to when [response] is not a 2xx.
  ///
  /// [OcptSyncError] is a plain value class, not an [Exception] or [Error] — deliberately, per its
  /// own doc comment, so a caller can inspect, display or re-carry it — which is exactly what a
  /// caller of this transport does with what it catches here.
  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    // OcptSyncError is a plain value class by design (see its own doc comment) so a caller can
    // inspect, display or re-carry it — not an Exception/Error this lint expects to be thrown.
    // ignore: only_throw_errors
    throw OcptSyncError.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
