// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

const _enrolmentSecret = 'enrolment-secret';

OcptChangesetEnvelope _envelope(String changesetId, {int lamport = 1}) => OcptChangesetEnvelope(
  changesetId: changesetId,
  originDeviceId: 'device-1',
  lamport: lamport,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList([1, 2, 3]),
);

OcptSnapshotDescriptor _descriptor({required String snapshotId, required OcptSequenceNumber sequenceUpTo, required Uint8List bytes}) =>
    OcptSnapshotDescriptor(
      snapshotId: snapshotId,
      sequenceUpTo: sequenceUpTo,
      byteLength: bytes.length,
      contentDigest: sha256.convert(bytes).toString(),
    );

Future<shelf.Response> _post(
  shelf.Handler handler,
  String path, {
  String? token,
  String? enrolmentSecret,
  Object? jsonBody,
}) async => handler(
  shelf.Request(
    'POST',
    Uri.parse('http://relay.test$path'),
    headers: {
      if (token != null) 'authorization': 'Bearer $token',
      if (enrolmentSecret != null) 'X-Ocpt-Enrolment-Secret': enrolmentSecret,
    },
    body: jsonBody == null ? null : jsonEncode(jsonBody),
  ),
);

Future<shelf.Response> _get(shelf.Handler handler, String path, {String? token}) async => handler(
  shelf.Request(
    'GET',
    Uri.parse('http://relay.test$path'),
    headers: {if (token != null) 'authorization': 'Bearer $token'},
  ),
);

Future<Map<String, dynamic>> _jsonBodyOf(shelf.Response response) =>
    response.readAsString().then((body) => jsonDecode(body) as Map<String, dynamic>);

void main() {
  group('OcptRelayServer', () {
    late OcptRelayStore store;
    late shelf.Handler handler;

    setUp(() {
      store = OcptRelayStore(':memory:');
      handler = OcptRelayServer(store: store, enrolmentSecret: _enrolmentSecret).handler;
    });

    tearDown(() => store.close());

    test('an unknown project is created and appended to with a matching enrolment secret', () async {
      final response = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        enrolmentSecret: _enrolmentSecret,
        jsonBody: _envelope('changeset-1').toJson(),
      );

      expect(response.statusCode, 200);
      final body = await _jsonBodyOf(response);
      expect(body, {'sequence': 1});
      expect(store.findProject('project-1'), isNotNull);
    });

    test('an unknown project is refused, and not created, without the enrolment secret', () async {
      final response = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: _envelope('changeset-1').toJson(),
      );

      expect(response.statusCode, 404);
      final body = await _jsonBodyOf(response);
      expect(body['code'], 'unknownProject');
      expect(store.findProject('project-1'), isNull);
    });

    test('an unknown project is refused, and not created, with a wrong enrolment secret', () async {
      final response = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        enrolmentSecret: 'wrong-secret',
        jsonBody: _envelope('changeset-1').toJson(),
      );

      expect(response.statusCode, 404);
      expect(store.findProject('project-1'), isNull);
    });

    test('only POST changesets may create a project: an unknown project on GET is 404', () async {
      final response = await _get(handler, '/projects/project-1/changesets?since=0', token: 'token-1');

      expect(response.statusCode, 404);
      expect(store.findProject('project-1'), isNull);
    });

    test('a changeset appended over the route is read back via readSince over the route', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final appendResponse = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: _envelope('changeset-1').toJson(),
      );
      expect(appendResponse.statusCode, 200);
      expect(await _jsonBodyOf(appendResponse), {'sequence': 1});

      final readResponse = await _get(handler, '/projects/project-1/changesets?since=0', token: 'token-1');
      expect(readResponse.statusCode, 200);
      final body = jsonDecode(await readResponse.readAsString()) as List<dynamic>;
      final stored = [for (final row in body) OcptStoredChangeset.fromJson(row as Map<String, dynamic>)];
      expect(stored, [OcptStoredChangeset(sequenceNumber: const OcptSequenceNumber(1), envelope: _envelope('changeset-1'))]);
    });

    test('sequence numbers are monotonic across several route calls', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final first = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: _envelope('changeset-1').toJson(),
      );
      final second = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: _envelope('changeset-2').toJson(),
      );
      final third = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: _envelope('changeset-3').toJson(),
      );

      expect(await _jsonBodyOf(first), {'sequence': 1});
      expect(await _jsonBodyOf(second), {'sequence': 2});
      expect(await _jsonBodyOf(third), {'sequence': 3});
    });

    test('posting the same changeset twice over the route is idempotent', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());
      final envelope = _envelope('changeset-1');

      final first = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: envelope.toJson(),
      );
      final second = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: envelope.toJson(),
      );

      expect(await _jsonBodyOf(first), {'sequence': 1});
      expect(await _jsonBodyOf(second), {'sequence': 1});

      final readResponse = await _get(handler, '/projects/project-1/changesets?since=0', token: 'token-1');
      final body = jsonDecode(await readResponse.readAsString()) as List<dynamic>;
      expect(body, hasLength(1));
    });

    test('readSince requires a since query parameter', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final response = await _get(handler, '/projects/project-1/changesets', token: 'token-1');

      expect(response.statusCode, 400);
      final body = await _jsonBodyOf(response);
      expect(body['code'], 'malformed');
    });

    test('a missing bearer token is rejected with 401', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final response = await _get(handler, '/projects/project-1/changesets?since=0');

      expect(response.statusCode, 401);
      final body = await _jsonBodyOf(response);
      expect(body['code'], 'badToken');
    });

    test('a bad bearer token is rejected with 401', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final response = await _get(handler, '/projects/project-1/changesets?since=0', token: 'wrong-token');

      expect(response.statusCode, 401);
      final body = await _jsonBodyOf(response);
      expect(body['code'], 'badToken');
    });

    test('a snapshot uploaded is fetched back over the routes, descriptor and bytes intact', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());
      final bytes = Uint8List.fromList(utf8.encode('a snapshot payload'));
      final descriptor = _descriptor(snapshotId: 'snapshot-1', sequenceUpTo: OcptSequenceNumber.zero, bytes: bytes);

      final uploadResponse = await _post(
        handler,
        '/projects/project-1/snapshot',
        token: 'token-1',
        jsonBody: {'descriptor': descriptor.toJson(), 'bytes': base64Encode(bytes)},
      );
      expect(uploadResponse.statusCode, 204);

      final fetchResponse = await _get(handler, '/projects/project-1/snapshot', token: 'token-1');
      expect(fetchResponse.statusCode, 200);
      final body = await _jsonBodyOf(fetchResponse);
      expect(OcptSnapshotDescriptor.fromJson(body['descriptor'] as Map<String, dynamic>), descriptor);
      expect(base64Decode(body['bytes'] as String), bytes);
    });

    test('fetching a snapshot on a project with none yet is 404', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final response = await _get(handler, '/projects/project-1/snapshot', token: 'token-1');

      expect(response.statusCode, 404);
      final body = await _jsonBodyOf(response);
      expect(body.containsKey('code'), isTrue);
    });

    test('a malformed changeset body is rejected with 400', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final response = await _post(
        handler,
        '/projects/project-1/changesets',
        token: 'token-1',
        jsonBody: {'notAChangeset': true},
      );

      expect(response.statusCode, 400);
      final body = await _jsonBodyOf(response);
      expect(body['code'], 'malformed');
    });

    test('a malformed snapshot upload body is rejected with 400', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      final response = await _post(
        handler,
        '/projects/project-1/snapshot',
        token: 'token-1',
        jsonBody: {'descriptor': 'not an object', 'bytes': 'not base64!!'},
      );

      expect(response.statusCode, 400);
      final body = await _jsonBodyOf(response);
      expect(body['code'], 'malformed');
    });

    test('the rate limiter rejects a source after repeated bad tokens', () async {
      final throttledHandler = OcptRelayServer(
        store: store,
        enrolmentSecret: _enrolmentSecret,
        maxAuthFailuresPerSource: 3,
      ).handler;
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      for (var i = 0; i < 3; i++) {
        final response = await _get(throttledHandler, '/projects/project-1/changesets?since=0', token: 'wrong-token');
        expect(response.statusCode, 401);
      }

      final blockedResponse = await _get(
        throttledHandler,
        '/projects/project-1/changesets?since=0',
        token: 'wrong-token',
      );
      expect(blockedResponse.statusCode, 429);

      // Even a correct token is rejected while the source is throttled.
      final stillBlockedWithGoodToken = await _get(
        throttledHandler,
        '/projects/project-1/changesets?since=0',
        token: 'token-1',
      );
      expect(stillBlockedWithGoodToken.statusCode, 429);
    });

    test('the rate limiter does not interfere with a generous default across many happy-path calls', () async {
      store.createProject(projectId: 'project-1', tokenHash: sha256.convert(utf8.encode('token-1')).toString());

      for (var i = 0; i < 10; i++) {
        final response = await _get(handler, '/projects/project-1/changesets?since=0', token: 'token-1');
        expect(response.statusCode, 200);
      }
    });
  });
}
