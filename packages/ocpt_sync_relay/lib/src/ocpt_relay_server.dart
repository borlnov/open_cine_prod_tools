// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/src/ocpt_relay_store.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart' as shelf_web_socket;
import 'package:web_socket_channel/web_socket_channel.dart';

/// The relay's HTTP surface over an [OcptRelayStore]: the five routes a replica's
/// `OcptRemoteStorage` transport speaks against, each behind a bearer-token check. This class only
/// assembles [handler] — `bin/ocpt_sync_relay.dart` is what serves it over a real socket, built on
/// `buildRelayServerFromEnvironment`.
///
/// ## Routes and their wire shapes
///
/// Every body is JSON; every opaque payload inside one is base64 text, never raw bytes, so a JSON
/// body stays JSON end to end. None of the routes below ever looks inside a changeset's own
/// payload or a snapshot's own bytes — see [OcptRelayStore]'s own doc comment for why that is the
/// whole point of this package.
///
/// - `POST /projects/<projectId>/changesets` — body is one [OcptChangesetEnvelope.toJson]. Appends
///   it, notifies that project's `events` subscribers (below), and answers `200` with
///   `{"sequence": <int>}`, the assigned [OcptSequenceNumber.value]. Idempotent on the envelope's
///   own `changesetId` ([OcptRelayStore.append]): posting the same changeset twice stores it once
///   and answers both times with the same sequence — the route a set relay re-pushing a whole
///   day's log to a prep relay every evening relies on to not duplicate it on a re-run.
/// - `GET /projects/<projectId>/changesets?since=<seq>` — `since` is required and must be a
///   non-negative integer; answers `200` with the JSON list of [OcptStoredChangeset.toJson],
///   oldest first, exactly as [OcptRelayStore.readSince] returns them.
/// - `POST /projects/<projectId>/snapshot` — body is
///   `{"descriptor": <OcptSnapshotDescriptor.toJson()>, "bytes": "<base64>"}`. Stores it, notifies
///   that project's `events` subscribers, and answers `204` with an empty body.
/// - `GET /projects/<projectId>/snapshot` — answers `200` with
///   `{"descriptor": <OcptSnapshotDescriptor.toJson()>, "bytes": "<base64>"}` for the project's
///   latest snapshot, or `404` when it has none yet.
/// - `GET /projects/<projectId>/events` — upgrades to a WebSocket, and is bidirectional. While
///   connected, the socket receives one opaque frame (the literal string [_newWorkPing]) every time
///   any replica appends a changeset or uploads a snapshot to `<projectId>`, including a write made
///   over a different connection to this same server process — nothing about that frame is
///   meaningful beyond its arrival, exactly as `OcptRemoteStorage.newWorkStream`'s own contract says
///   a listener should treat it: react by calling `readSince`/`fetchLatestSnapshot` again, never by
///   parsing it. Any *other* frame a subscriber sends — a peer's opaque presence payload, per
///   `docs/plans/presence.md` (M5, Phase A) — is rebroadcast verbatim to that same project's other
///   subscribers only, never back to the sender and never to another project's subscribers; this
///   relay only moves that frame, exactly as it moves a changeset payload, and never looks inside
///   it. The subscriber set behind this is in-memory and per server process
///   ([_eventSubscribersByProject]): fine for the one relay process a project talks to, and
///   cleared as each socket closes.
///
/// A request this class refuses — a bad body, a bad token, an unknown project, or the rate limiter
/// tripping — answers with the matching HTTP status and an [OcptSyncError] JSON body
/// ([OcptSyncError.toJson]). [OcptSyncErrorCode] has no member of its own for "no snapshot yet" or
/// "too many failed attempts": both reuse the closest existing code
/// ([OcptSyncErrorCode.unknownProject] and [OcptSyncErrorCode.badToken] respectively, documented
/// again at each call site) since the HTTP status carried alongside is what a caller actually
/// branches on for those two cases.
///
/// ## Authentication
///
/// Every route requires `Authorization: Bearer <token>`. [OcptRelayStore] keeps only a sha256 hex
/// hash of each project's token ([_hashToken]); a request's token is hashed the same way and
/// compared against the stored one — a fast hash is the right tool here because the token is
/// full-entropy machine output picked by the client, not a human password to slow an attacker down
/// against.
///
/// `POST .../changesets` is the one route that may create a project: when `<projectId>` is not yet
/// known to [store] *and* the request also carries `X-Ocpt-Enrolment-Secret` equal to
/// [enrolmentSecret], it calls [OcptRelayStore.createProject] with the presented token's hash
/// before appending — the client picks both the project id and its own token. An unknown project
/// without a matching enrolment secret is refused with `404` on every route, including this one,
/// and is never created. A bad or missing bearer token against a project that does exist is
/// refused with `401`.
///
/// Every refused authentication — bad token, unknown project, missing enrolment secret — is
/// counted against its request's source by an in-memory throttle (the constructor's
/// `maxAuthFailuresPerSource`/`authFailureWindow`): once a source has failed that many times
/// within the window, every further request from it is answered `429` for the rest of the window,
/// with no work done against [store] at all. This is deliberately coarse (in-process, not
/// persisted, reset by a restart) — it is the cheapest guard against a brute-force or DoS attempt,
/// not a security boundary on its own.
class OcptRelayServer {
  /// Creates a relay server answering requests against [store], accepting [enrolmentSecret] as the
  /// only credential able to register a brand-new project.
  ///
  /// [maxAuthFailuresPerSource] and [authFailureWindow] configure the failed-authentication
  /// throttle described on this class: defaults are generous enough that ordinary traffic never
  /// trips them, and a test exercising the throttle passes a small [maxAuthFailuresPerSource] of
  /// its own so it stays independent of every other test's timing.
  OcptRelayServer({
    required this.store,
    required this.enrolmentSecret,
    int maxAuthFailuresPerSource = 20,
    Duration authFailureWindow = const Duration(minutes: 1),
  }) : _rateLimiter = _AuthRateLimiter(maxFailures: maxAuthFailuresPerSource, window: authFailureWindow);

  static const _enrolmentSecretHeader = 'X-Ocpt-Enrolment-Secret';
  static const _bearerPrefix = 'Bearer ';
  static const _sinceParam = 'since';
  static const _sequenceKey = 'sequence';
  static const _descriptorKey = 'descriptor';
  static const _bytesKey = 'bytes';

  /// The opaque frame sent to every `events` subscriber of a project on new work. Its content is
  /// not part of the contract — a listener reacts to a frame's arrival, never to what it says —
  /// this is simply the smallest constant that does the job.
  static const _newWorkPing = 'new-work';

  /// The relay's own storage: every route is a thin HTTP wrapper around one of its methods.
  final OcptRelayStore store;

  /// The instance-wide secret a request must carry, alongside a brand-new project id, to register
  /// it (see this class's own doc comment).
  final String enrolmentSecret;

  final _AuthRateLimiter _rateLimiter;

  /// The sockets currently subscribed to each project's `events` route, so a write can be
  /// broadcast to every subscriber of the project it landed in. Per server process only (see this
  /// class's own doc comment) — a project with no subscriber has no entry here at all.
  final Map<String, Set<WebSocketChannel>> _eventSubscribersByProject = {};

  /// The assembled request handler for this relay's five routes: mount it under `shelf_io.serve`
  /// or any other shelf adapter that supports request hijacking, which the `events` route needs
  /// for its WebSocket upgrade.
  shelf.Handler get handler {
    final router = shelf_router.Router()
      ..post('/projects/<projectId>/changesets', _postChangesets)
      ..get('/projects/<projectId>/changesets', _getChangesets)
      ..post('/projects/<projectId>/snapshot', _postSnapshot)
      ..get('/projects/<projectId>/snapshot', _getSnapshot)
      ..get('/projects/<projectId>/events', _getEvents);

    return router.call;
  }

  Future<shelf.Response> _postChangesets(shelf.Request request) async {
    final projectId = request.params['projectId']!;
    final rejection = _authenticate(request, projectId: projectId, allowCreate: true);
    if (rejection != null) {
      return rejection;
    }

    final OcptChangesetEnvelope envelope;
    try {
      envelope = OcptChangesetEnvelope.fromJson(_decodeJsonObject(await request.readAsString()));
    } on FormatException catch (error) {
      return _errorResponse(400, OcptSyncErrorCode.malformed, 'bad changeset envelope: $error');
    } on OcptSyncMalformedDataError catch (error) {
      return _errorResponse(400, OcptSyncErrorCode.malformed, error.reason);
    } on OcptSyncUnsupportedFormatError catch (error) {
      return _errorResponse(400, OcptSyncErrorCode.unsupportedFormat, error.toString());
    }

    final sequence = store.append(projectId, envelope);
    _notifyNewWork(projectId);

    return _jsonResponse(200, {_sequenceKey: sequence.value});
  }

  Future<shelf.Response> _getChangesets(shelf.Request request) async {
    final projectId = request.params['projectId']!;
    final rejection = _authenticate(request, projectId: projectId, allowCreate: false);
    if (rejection != null) {
      return rejection;
    }

    final sinceText = request.url.queryParameters[_sinceParam];
    final since = sinceText == null ? null : int.tryParse(sinceText);
    if (since == null || since < 0) {
      return _errorResponse(
        400,
        OcptSyncErrorCode.malformed,
        "'$_sinceParam' query parameter is required and must be a non-negative integer",
      );
    }

    final stored = store.readSince(projectId, OcptSequenceNumber(since));

    return _jsonResponse(200, [for (final changeset in stored) changeset.toJson()]);
  }

  Future<shelf.Response> _postSnapshot(shelf.Request request) async {
    final projectId = request.params['projectId']!;
    final rejection = _authenticate(request, projectId: projectId, allowCreate: false);
    if (rejection != null) {
      return rejection;
    }

    final OcptSnapshotDescriptor descriptor;
    final Uint8List bytes;
    try {
      final json = _decodeJsonObject(await request.readAsString());
      descriptor = OcptSnapshotDescriptor.fromJson(_requireObject(json, _descriptorKey));
      bytes = base64Decode(_requireString(json, _bytesKey));
    } on FormatException catch (error) {
      return _errorResponse(400, OcptSyncErrorCode.malformed, 'bad snapshot upload: $error');
    } on OcptSyncMalformedDataError catch (error) {
      return _errorResponse(400, OcptSyncErrorCode.malformed, error.reason);
    } on OcptSyncUnsupportedFormatError catch (error) {
      return _errorResponse(400, OcptSyncErrorCode.unsupportedFormat, error.toString());
    }

    store.uploadSnapshot(projectId, descriptor, bytes);
    _notifyNewWork(projectId);

    return shelf.Response(204);
  }

  Future<shelf.Response> _getSnapshot(shelf.Request request) async {
    final projectId = request.params['projectId']!;
    final rejection = _authenticate(request, projectId: projectId, allowCreate: false);
    if (rejection != null) {
      return rejection;
    }

    final latest = store.fetchLatestSnapshot(projectId);
    if (latest == null) {
      // OcptSyncErrorCode has no dedicated "nothing uploaded yet" member; this is the closest
      // existing one, and the 404 status is what a caller (`fetchLatestSnapshot` returning null)
      // actually acts on.
      return _errorResponse(404, OcptSyncErrorCode.unknownProject, 'project $projectId has no snapshot yet');
    }
    final (descriptor, bytes) = latest;

    return _jsonResponse(200, {_descriptorKey: descriptor.toJson(), _bytesKey: base64Encode(bytes)});
  }

  /// Upgrades [request] to the `events` WebSocket for `<projectId>`, behind the same bearer check
  /// every other route makes (`allowCreate: false` — a socket does not create a project). A
  /// rejected request never reaches the upgrade at all: [_authenticate] answers the ordinary HTTP
  /// status (`401`/`404`/`429`) instead, exactly as it would for any other route.
  ///
  /// Once upgraded, the socket is added to [_eventSubscribersByProject] and removed again as soon
  /// as it closes from either end. What it sends is rebroadcast to its project's other subscribers
  /// by [_subscribe] — see this class's own doc comment for the `events` route.
  Future<shelf.Response> _getEvents(shelf.Request request) async {
    final projectId = request.params['projectId']!;
    final rejection = _authenticate(request, projectId: projectId, allowCreate: false);
    if (rejection != null) {
      return rejection;
    }

    final upgrade = shelf_web_socket.webSocketHandler((webSocket, _) => _subscribe(projectId, webSocket));

    return upgrade(request);
  }

  /// Adds [webSocket] to [projectId]'s subscriber set, rebroadcasts every frame it sends to that
  /// project's other subscribers ([_rebroadcastToPeers]), and arranges for [_unsubscribe] to run
  /// the moment the connection closes, from either end.
  void _subscribe(String projectId, WebSocketChannel webSocket) {
    _eventSubscribersByProject.putIfAbsent(projectId, () => {}).add(webSocket);
    webSocket.stream.listen(
      (frame) => _rebroadcastToPeers(projectId, sender: webSocket, frame: frame),
      onDone: () => _unsubscribe(projectId, webSocket),
      onError: (Object _) => _unsubscribe(projectId, webSocket),
      cancelOnError: true,
    );
  }

  /// Removes [webSocket] from [projectId]'s subscriber set, dropping the set entirely once it is
  /// left empty so a project nobody is watching leaves no trace in [_eventSubscribersByProject].
  void _unsubscribe(String projectId, WebSocketChannel webSocket) {
    final subscribers = _eventSubscribersByProject[projectId];
    if (subscribers == null) {
      return;
    }
    subscribers.remove(webSocket);
    if (subscribers.isEmpty) {
      _eventSubscribersByProject.remove(projectId);
    }
  }

  /// Sends the opaque [_newWorkPing] frame to every socket currently subscribed to [projectId]'s
  /// `events` route — called once a changeset append or a snapshot upload for that project has
  /// actually landed in [store]. A project with no subscriber does nothing.
  void _notifyNewWork(String projectId) {
    final subscribers = _eventSubscribersByProject[projectId];
    if (subscribers == null) {
      return;
    }
    for (final webSocket in List.of(subscribers)) {
      webSocket.sink.add(_newWorkPing);
    }
  }

  /// Forwards [frame] — an opaque presence payload one replica sent over its own `events` socket —
  /// to every *other* subscriber of [projectId], never back to [sender] and never to another
  /// project's subscribers. Distinct from [_notifyNewWork], which is relay-generated and goes to
  /// every subscriber including whichever socket triggered it: this method only ever moves a frame
  /// a client itself sent, and never inspects it — [frame] passes through exactly as received,
  /// keeping this class domain-blind.
  void _rebroadcastToPeers(String projectId, {required WebSocketChannel sender, required Object? frame}) {
    final subscribers = _eventSubscribersByProject[projectId];
    if (subscribers == null) {
      return;
    }
    for (final webSocket in List.of(subscribers)) {
      if (identical(webSocket, sender)) {
        continue;
      }
      webSocket.sink.add(frame);
    }
  }

  /// Authenticates [request] for [projectId], creating the project first when [allowCreate] is
  /// true and every condition in this class's own doc comment is met. Returns null when the
  /// request may proceed, or the [shelf.Response] to send instead.
  shelf.Response? _authenticate(shelf.Request request, {required String projectId, required bool allowCreate}) {
    final source = _sourceKeyFor(request);
    if (_rateLimiter.isBlocked(source)) {
      return _errorResponse(
        429,
        OcptSyncErrorCode.badToken,
        'too many failed authentication attempts; try again later',
      );
    }

    final token = _bearerToken(request);
    final project = store.findProject(projectId);

    if (project == null) {
      if (allowCreate && token != null && request.headers[_enrolmentSecretHeader] == enrolmentSecret) {
        store.createProject(projectId: projectId, tokenHash: _hashToken(token));

        return null;
      }
      _rateLimiter.recordFailure(source);

      return _errorResponse(
        404,
        OcptSyncErrorCode.unknownProject,
        'no project $projectId, and no valid enrolment secret to create one',
      );
    }

    if (token == null || _hashToken(token) != project.tokenHash) {
      _rateLimiter.recordFailure(source);

      return _errorResponse(401, OcptSyncErrorCode.badToken, 'bad or missing bearer token');
    }

    return null;
  }

  /// The bearer token [request] carries, or null when it carries none (a missing header, a header
  /// not shaped as `Bearer <token>`, or an empty token).
  String? _bearerToken(shelf.Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith(_bearerPrefix)) {
      return null;
    }
    final token = header.substring(_bearerPrefix.length).trim();

    return token.isEmpty ? null : token;
  }

  /// A coarse "where did this request come from" key for the failed-authentication throttle: the
  /// remote address a real socket adapter (`shelf_io`) attaches to [request]'s context, falling
  /// back to a single shared key when nothing of the sort is present — as it is not when this
  /// handler is driven directly in a test, or behind an adapter that never sets it.
  String _sourceKeyFor(shelf.Request request) {
    final connectionInfo = request.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      return connectionInfo.remoteAddress.address;
    }

    return 'unknown';
  }

  /// The sha256 hex digest of [token] — the only form of a bearer token [OcptRelayStore] ever
  /// stores or compares against.
  String _hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

  shelf.Response _jsonResponse(int statusCode, Object body) => shelf.Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );

  shelf.Response _errorResponse(int statusCode, OcptSyncErrorCode code, String message) =>
      _jsonResponse(statusCode, OcptSyncError(code: code, message: message).toJson());

  /// Decodes [body] as JSON, throwing [OcptSyncMalformedDataError] (never a raw [TypeError]) when
  /// it parses to anything but a JSON object — mirrors what `ocpt_sync_protocol`'s own `fromJson`
  /// constructors do for a single field, one level up, for the request body as a whole.
  Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const OcptSyncMalformedDataError('the request body must be a JSON object');
    }

    return decoded;
  }

  /// Reads the [String] at [key] in [json], throwing [OcptSyncMalformedDataError] when it is
  /// missing or not a string.
  String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw OcptSyncMalformedDataError("'$key' is missing or isn't a string");
    }

    return value;
  }

  /// Reads the JSON object at [key] in [json], throwing [OcptSyncMalformedDataError] when it is
  /// missing or not an object.
  Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw OcptSyncMalformedDataError("'$key' is missing or isn't a JSON object");
    }

    return value;
  }
}

/// A minimal in-memory throttle over failed authentications, keyed by whatever coarse source key
/// [OcptRelayServer._sourceKeyFor] hands it. Not distributed and not persisted — a restart of the
/// relay process resets it — which is an acceptable cost for what this is meant to be: the
/// cheapest guard against a brute-force or denial-of-service attempt, not a security boundary of
/// its own.
class _AuthRateLimiter {
  _AuthRateLimiter({required this.maxFailures, required this.window});

  final int maxFailures;
  final Duration window;
  final Map<String, _FailureWindow> _failuresBySource = {};

  /// True when [source] has already failed authentication [maxFailures] times or more within the
  /// current window, and every further request from it should be rejected without even looking at
  /// its credentials.
  bool isBlocked(String source) {
    final record = _failuresBySource[source];
    if (record == null) {
      return false;
    }
    if (DateTime.now().difference(record.windowStart) > window) {
      _failuresBySource.remove(source);

      return false;
    }

    return record.count >= maxFailures;
  }

  /// Records one failed authentication attempt from [source], starting a fresh window when none
  /// is open yet or the previous one has expired.
  void recordFailure(String source) {
    final now = DateTime.now();
    final record = _failuresBySource[source];
    if (record == null || now.difference(record.windowStart) > window) {
      _failuresBySource[source] = _FailureWindow(windowStart: now, count: 1);
    } else {
      record.count += 1;
    }
  }
}

/// One source's failure count within its current window, as tracked by [_AuthRateLimiter].
class _FailureWindow {
  _FailureWindow({required this.windowStart, required this.count});

  final DateTime windowStart;
  int count;
}
