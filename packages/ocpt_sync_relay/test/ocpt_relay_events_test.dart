// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _enrolmentSecret = 'enrolment-secret';
const _timeout = Timeout(Duration(seconds: 5));

OcptChangesetEnvelope _envelope(String changesetId) => OcptChangesetEnvelope(
  changesetId: changesetId,
  originDeviceId: 'device-1',
  lamport: 1,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList([1, 2, 3]),
);

OcptSnapshotDescriptor _descriptor({required String snapshotId, required Uint8List bytes}) => OcptSnapshotDescriptor(
  snapshotId: snapshotId,
  sequenceUpTo: OcptSequenceNumber.zero,
  byteLength: bytes.length,
  contentDigest: sha256.convert(bytes).toString(),
);

String _tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();

void main() {
  group('OcptRelayServer events route', () {
    late OcptRelayStore store;
    late OcptRelayServer server;
    late HttpServer httpServer;
    late Uri baseUri;
    final channels = <WebSocketChannel>[];

    setUp(() async {
      store = OcptRelayStore(':memory:');
      server = OcptRelayServer(store: store, enrolmentSecret: _enrolmentSecret);
      httpServer = await shelf_io.serve(server.handler, 'localhost', 0);
      baseUri = Uri.parse('http://localhost:${httpServer.port}');
    });

    tearDown(() async {
      for (final channel in channels) {
        unawaited(channel.sink.close());
      }
      channels.clear();
      await httpServer.close(force: true);
      store.close();
    });

    WebSocketChannel connect(String projectId, {String? token}) {
      final uri = baseUri.replace(scheme: 'ws', path: '/projects/$projectId/events');
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {if (token != null) 'authorization': 'Bearer $token'},
      );
      channels.add(channel);

      return channel;
    }

    Future<void> post(String path, {required String token, required Object jsonBody}) async {
      final request = await HttpClient().postUrl(baseUri.replace(path: path));
      request.headers.set('authorization', 'Bearer $token');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(jsonBody));
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, anyOf(200, 204), reason: 'POST $path did not succeed');
    }

    test(
      'a subscribed socket receives a ping after another caller appends a changeset',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final channel = connect('project-1', token: 'token-1');
        await channel.ready;

        await post('/projects/project-1/changesets', token: 'token-1', jsonBody: _envelope('changeset-1').toJson());

        final ping = await channel.stream.first.timeout(const Duration(seconds: 3));
        expect(ping, isNotNull);
      },
      timeout: _timeout,
    );

    test(
      'a subscribed socket receives a ping after a snapshot upload',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final channel = connect('project-1', token: 'token-1');
        await channel.ready;

        final bytes = Uint8List.fromList(utf8.encode('a snapshot payload'));
        await post(
          '/projects/project-1/snapshot',
          token: 'token-1',
          jsonBody: {
            'descriptor': _descriptor(snapshotId: 'snapshot-1', bytes: bytes).toJson(),
            'bytes': base64Encode(bytes),
          },
        );

        final ping = await channel.stream.first.timeout(const Duration(seconds: 3));
        expect(ping, isNotNull);
      },
      timeout: _timeout,
    );

    test(
      'a ping does not arrive for a write to a different project',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        store.createProject(projectId: 'project-2', tokenHash: _tokenHash('token-2'));
        final channel = connect('project-1', token: 'token-1');
        await channel.ready;

        await post('/projects/project-2/changesets', token: 'token-2', jsonBody: _envelope('changeset-1').toJson());

        var pinged = false;
        final subscription = channel.stream.listen((_) => pinged = true);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await subscription.cancel();

        expect(pinged, isFalse);
      },
      timeout: _timeout,
    );

    test(
      'connecting with a missing bearer token is rejected, no upgrade',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final channel = connect('project-1');

        await expectLater(channel.ready, throwsA(anything));
      },
      timeout: _timeout,
    );

    test(
      'connecting with a bad bearer token is rejected, no upgrade',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final channel = connect('project-1', token: 'wrong-token');

        await expectLater(channel.ready, throwsA(anything));
      },
      timeout: _timeout,
    );

    test(
      'a frame one subscriber sends reaches the other subscriber verbatim, not the sender',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final sender = connect('project-1', token: 'token-1');
        final peer = connect('project-1', token: 'token-1');
        await sender.ready;
        await peer.ready;

        var senderReceived = false;
        final senderSubscription = sender.stream.listen((_) => senderReceived = true);
        final peerFrame = peer.stream.first.timeout(const Duration(seconds: 3));

        sender.sink.add('presence-frame-from-sender');

        expect(await peerFrame, 'presence-frame-from-sender');
        // Give the sender a moment to (not) receive its own frame back before asserting it never
        // did — there is nothing else to await here since the assertion is an absence.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await senderSubscription.cancel();
        expect(senderReceived, isFalse);
      },
      timeout: _timeout,
    );

    test(
      'a peer frame for one project never reaches another project\'s subscribers',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        store.createProject(projectId: 'project-2', tokenHash: _tokenHash('token-2'));
        final projectOneSender = connect('project-1', token: 'token-1');
        final projectOnePeer = connect('project-1', token: 'token-1');
        final projectTwoSocket = connect('project-2', token: 'token-2');
        await projectOneSender.ready;
        await projectOnePeer.ready;
        await projectTwoSocket.ready;

        var projectTwoReceived = false;
        final projectTwoSubscription = projectTwoSocket.stream.listen((_) => projectTwoReceived = true);
        final peerFrame = projectOnePeer.stream.first.timeout(const Duration(seconds: 3));

        projectOneSender.sink.add('presence-frame-for-project-1');

        expect(await peerFrame, 'presence-frame-for-project-1');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await projectTwoSubscription.cancel();
        expect(projectTwoReceived, isFalse);
      },
      timeout: _timeout,
    );

    test(
      'a new-work ping still reaches every subscriber alongside peer frame rebroadcast',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final first = connect('project-1', token: 'token-1');
        final second = connect('project-1', token: 'token-1');
        await first.ready;
        await second.ready;

        final firstPing = first.stream.first.timeout(const Duration(seconds: 3));
        final secondPing = second.stream.first.timeout(const Duration(seconds: 3));

        await post('/projects/project-1/changesets', token: 'token-1', jsonBody: _envelope('changeset-1').toJson());

        expect(await firstPing, isNotNull);
        expect(await secondPing, isNotNull);
      },
      timeout: _timeout,
    );

    test(
      'closing a socket cleans up its subscription: a later write to that project does not throw',
      () async {
        store.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        final channel = connect('project-1', token: 'token-1');
        await channel.ready;
        await channel.sink.close();
        // Give the server a moment to observe the close and run its own cleanup.
        await Future<void>.delayed(const Duration(milliseconds: 300));

        await post('/projects/project-1/changesets', token: 'token-1', jsonBody: _envelope('changeset-1').toJson());
        // No exception above is the assertion: a leaked, closed sink in the subscriber set would
        // throw when the server tries to send it a ping.
      },
      timeout: _timeout,
    );
  });
}
