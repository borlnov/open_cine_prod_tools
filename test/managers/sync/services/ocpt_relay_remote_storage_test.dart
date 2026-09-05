// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_relay_remote_storage.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Builds a changeset envelope distinguishable from any other only by [suffix].
OcptChangesetEnvelope _envelope(String suffix) => OcptChangesetEnvelope(
  changesetId: 'changeset-$suffix',
  originDeviceId: 'device-$suffix',
  lamport: 1,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList('payload-$suffix'.codeUnits),
);

/// A minimal [WebSocketChannel] a test can push incoming messages into through [incoming] and
/// observe whether [sink] was closed through [closed] — everything else this transport never
/// touches (protocol negotiation, close codes) is stubbed to a fixed value.
class _FakeWebSocketChannel with StreamChannelMixin<dynamic> implements WebSocketChannel {
  _FakeWebSocketChannel(this.incoming);

  final StreamController<dynamic> incoming;
  final List<dynamic> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(this);

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future<void>.value();
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._channel);

  final _FakeWebSocketChannel _channel;

  @override
  // Matches StreamSink's own untyped signature, which this fake overrides.
  // ignore: avoid_annotating_with_dynamic
  void add(dynamic event) => _channel.sent.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future get done => Future<void>.value();

  @override
  Future close([int? closeCode, String? closeReason]) async {
    _channel.closed = true;
    await _channel.incoming.close();
  }
}

void main() {
  final relayBaseUri = Uri.parse('https://relay.example.org');
  const projectId = 'project-1';
  const token = 'project-token';

  group('append', () {
    test('sends the envelope JSON and returns the assigned sequence', () async {
      final envelope = _envelope('a');
      late http.Request captured;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async {
          captured = request;

          return http.Response(jsonEncode({'sequence': 7}), 200);
        }),
      );

      final sequence = await storage.append(envelope);

      expect(sequence, const OcptSequenceNumber(7));
      expect(captured.method, 'POST');
      expect(captured.url.path, '/projects/$projectId/changesets');
      expect(captured.headers['Authorization'], 'Bearer $token');
      expect(captured.headers.containsKey('X-Ocpt-Enrolment-Secret'), isFalse);
      expect(jsonDecode(captured.body), envelope.toJson());
    });

    test('includes the enrolment header when the transport has a secret', () async {
      late http.Request captured;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        enrolmentSecret: 'enrol-me',
        httpClient: MockClient((request) async {
          captured = request;

          return http.Response(jsonEncode({'sequence': 1}), 200);
        }),
      );

      await storage.append(_envelope('a'));

      expect(captured.headers['X-Ocpt-Enrolment-Secret'], 'enrol-me');
    });

    test('omits the enrolment header when the transport has none', () async {
      late http.Request captured;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async {
          captured = request;

          return http.Response(jsonEncode({'sequence': 1}), 200);
        }),
      );

      await storage.append(_envelope('a'));

      expect(captured.headers.containsKey('X-Ocpt-Enrolment-Secret'), isFalse);
    });
  });

  group('readSince', () {
    test('sends since and parses the list oldest-first', () async {
      final first = OcptStoredChangeset(sequenceNumber: const OcptSequenceNumber(4), envelope: _envelope('a'));
      final second = OcptStoredChangeset(sequenceNumber: const OcptSequenceNumber(5), envelope: _envelope('b'));
      late http.Request captured;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async {
          captured = request;

          return http.Response(jsonEncode([first.toJson(), second.toJson()]), 200);
        }),
      );

      final stored = await storage.readSince(const OcptSequenceNumber(3));

      expect(captured.method, 'GET');
      expect(captured.url.path, '/projects/$projectId/changesets');
      expect(captured.url.queryParameters['since'], '3');
      expect(captured.headers['Authorization'], 'Bearer $token');
      expect(stored, [first, second]);
    });
  });

  group('uploadSnapshot', () {
    test('posts the descriptor and base64-encoded bytes', () async {
      const descriptor = OcptSnapshotDescriptor(
        snapshotId: 'snapshot-1',
        sequenceUpTo: OcptSequenceNumber(9),
        byteLength: 4,
        contentDigest: 'digest',
      );
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      late http.Request captured;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async {
          captured = request;

          return http.Response('', 204);
        }),
      );

      await storage.uploadSnapshot(descriptor, bytes);

      expect(captured.method, 'POST');
      expect(captured.url.path, '/projects/$projectId/snapshot');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['descriptor'], descriptor.toJson());
      expect(body['bytes'], base64Encode(bytes));
    });
  });

  group('fetchLatestSnapshot', () {
    test('round-trips the descriptor and bytes', () async {
      const descriptor = OcptSnapshotDescriptor(
        snapshotId: 'snapshot-1',
        sequenceUpTo: OcptSequenceNumber(9),
        byteLength: 4,
        contentDigest: 'digest',
      );
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/projects/$projectId/snapshot');

          return http.Response(
            jsonEncode({'descriptor': descriptor.toJson(), 'bytes': base64Encode(bytes)}),
            200,
          );
        }),
      );

      final result = await storage.fetchLatestSnapshot();

      expect(result, isNotNull);
      expect(result!.$1, descriptor);
      expect(result.$2, bytes);
    });

    test('maps a 404 to null', () async {
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(const OcptSyncError(code: OcptSyncErrorCode.unknownProject, message: 'none yet').toJson()),
            404,
          ),
        ),
      );

      expect(await storage.fetchLatestSnapshot(), isNull);
    });
  });

  group('error surfacing', () {
    test('a non-2xx response throws the decoded OcptSyncError', () async {
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(const OcptSyncError(code: OcptSyncErrorCode.badToken, message: 'bad token').toJson()),
            401,
          ),
        ),
      );

      await expectLater(
        storage.append(_envelope('a')),
        throwsA(
          isA<OcptSyncError>()
              .having((error) => error.code, 'code', OcptSyncErrorCode.badToken)
              .having((error) => error.message, 'message', 'bad token'),
        ),
      );
    });
  });

  group('newWorkStream', () {
    test('emits once per incoming socket message', () async {
      final incoming = StreamController<dynamic>.broadcast();
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async => http.Response('', 500)),
        webSocketConnector: (uri) => _FakeWebSocketChannel(incoming),
      );
      addTearDown(incoming.close);

      final events = <void>[];
      final subscription = storage.newWorkStream.listen(events.add);
      addTearDown(subscription.cancel);
      // Let the broadcast controller's onListen callback run before pushing a message.
      await Future<void>.delayed(Duration.zero);

      incoming.add('new-work');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
    });

    test('reconnects after a socket drop instead of ending the stream', () async {
      final firstIncoming = StreamController<dynamic>.broadcast();
      final secondIncoming = StreamController<dynamic>.broadcast();
      var connectCount = 0;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        reconnectDelay: const Duration(milliseconds: 10),
        httpClient: MockClient((request) async => http.Response('', 500)),
        webSocketConnector: (uri) {
          connectCount += 1;

          return _FakeWebSocketChannel(connectCount == 1 ? firstIncoming : secondIncoming);
        },
      );
      addTearDown(() {
        if (!firstIncoming.isClosed) {
          unawaited(firstIncoming.close());
        }
        if (!secondIncoming.isClosed) {
          unawaited(secondIncoming.close());
        }
      });

      final events = <void>[];
      final subscription = storage.newWorkStream.listen(events.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      expect(connectCount, 1);

      // Simulate the first socket dropping.
      await firstIncoming.close();
      // Wait past the reconnect backoff for the second connect attempt to happen.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(connectCount, 2);

      secondIncoming.add('new-work');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('presenceStream', () {
    test('a literal new-work frame goes to newWorkStream, not presenceStream', () async {
      final incoming = StreamController<dynamic>.broadcast();
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async => http.Response('', 500)),
        webSocketConnector: (uri) => _FakeWebSocketChannel(incoming),
      );
      addTearDown(incoming.close);

      final newWorkEvents = <void>[];
      final presenceFrames = <String>[];
      final newWorkSubscription = storage.newWorkStream.listen(newWorkEvents.add);
      final presenceSubscription = storage.presenceStream.listen(presenceFrames.add);
      addTearDown(newWorkSubscription.cancel);
      addTearDown(presenceSubscription.cancel);
      await Future<void>.delayed(Duration.zero);

      incoming.add('new-work');
      await Future<void>.delayed(Duration.zero);

      expect(newWorkEvents, hasLength(1));
      expect(presenceFrames, isEmpty);
    });

    test('any other frame goes to presenceStream, not newWorkStream', () async {
      final incoming = StreamController<dynamic>.broadcast();
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async => http.Response('', 500)),
        webSocketConnector: (uri) => _FakeWebSocketChannel(incoming),
      );
      addTearDown(incoming.close);

      final newWorkEvents = <void>[];
      final presenceFrames = <String>[];
      final newWorkSubscription = storage.newWorkStream.listen(newWorkEvents.add);
      final presenceSubscription = storage.presenceStream.listen(presenceFrames.add);
      addTearDown(newWorkSubscription.cancel);
      addTearDown(presenceSubscription.cancel);
      await Future<void>.delayed(Duration.zero);

      incoming.add('{"deviceId":"device-a"}');
      await Future<void>.delayed(Duration.zero);

      expect(presenceFrames, ['{"deviceId":"device-a"}']);
      expect(newWorkEvents, isEmpty);
    });

    test('connecting starts once, shared between newWorkStream and presenceStream listeners', () async {
      final incoming = StreamController<dynamic>.broadcast();
      var connectCount = 0;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async => http.Response('', 500)),
        webSocketConnector: (uri) {
          connectCount += 1;

          return _FakeWebSocketChannel(incoming);
        },
      );
      addTearDown(incoming.close);

      final newWorkSubscription = storage.newWorkStream.listen((_) {});
      final presenceSubscription = storage.presenceStream.listen((_) {});
      addTearDown(newWorkSubscription.cancel);
      addTearDown(presenceSubscription.cancel);
      await Future<void>.delayed(Duration.zero);

      expect(connectCount, 1);
    });
  });

  group('sendPresence', () {
    test('writes the opaque payload to the connected socket', () async {
      final incoming = StreamController<dynamic>.broadcast();
      late _FakeWebSocketChannel channel;
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async => http.Response('', 500)),
        webSocketConnector: (uri) => channel = _FakeWebSocketChannel(incoming),
      );
      addTearDown(incoming.close);

      final subscription = storage.presenceStream.listen((_) {});
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);

      storage.sendPresence('a presence payload');

      expect(channel.sent, ['a presence payload']);
    });

    test('is a silent no-op while the socket is not connected', () async {
      final storage = OcptRelayRemoteStorage(
        relayBaseUri: relayBaseUri,
        projectId: projectId,
        token: token,
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      expect(() => storage.sendPresence('a presence payload'), returnsNormally);
    });
  });
}
