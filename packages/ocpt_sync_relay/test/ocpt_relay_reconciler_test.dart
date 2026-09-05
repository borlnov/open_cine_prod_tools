// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

const _enrolmentSecret = 'enrolment-secret';
const _timeout = Timeout(Duration(seconds: 5));

OcptChangesetEnvelope _envelope(String changesetId, {int lamport = 1}) => OcptChangesetEnvelope(
  changesetId: changesetId,
  originDeviceId: 'device-1',
  lamport: lamport,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList([1, 2, 3]),
);

void main() {
  group('OcptRelayReconciler', () {
    late OcptRelayStore upstreamStore;
    late OcptRelayServer upstreamServer;
    late HttpServer upstreamHttpServer;
    late Uri upstreamBaseUri;
    late OcptRelayUpstreamClient upstreamClient;
    late OcptRelayStore setRelayStore;
    late OcptRelayReconciler reconciler;

    setUp(() async {
      upstreamStore = OcptRelayStore(':memory:');
      upstreamServer = OcptRelayServer(store: upstreamStore, enrolmentSecret: _enrolmentSecret);
      upstreamHttpServer = await shelf_io.serve(upstreamServer.handler, 'localhost', 0);
      upstreamBaseUri = Uri.parse('http://localhost:${upstreamHttpServer.port}');
      upstreamClient = OcptRelayUpstreamClient(baseUri: upstreamBaseUri, token: 'token-1');
      setRelayStore = OcptRelayStore(':memory:');
      reconciler = OcptRelayReconciler(store: setRelayStore, upstream: upstreamClient);
    });

    tearDown(() async {
      upstreamClient.close();
      await upstreamHttpServer.close(force: true);
      upstreamStore.close();
      setRelayStore.close();
    });

    test(
      'a fresh push moves every local changeset to an upstream that has none yet',
      () async {
        setRelayStore.append('project-1', _envelope('changeset-1'));
        setRelayStore.append('project-1', _envelope('changeset-2'));
        setRelayStore.append('project-1', _envelope('changeset-3'));

        final result = await reconciler.reconcileProject(projectId: 'project-1', enrolmentSecret: _enrolmentSecret);

        expect(result.pushed, 3);
        expect(result.pulled, 0);
        final onUpstream = upstreamStore.readSince('project-1', OcptSequenceNumber.zero);
        expect(onUpstream.map((changeset) => changeset.envelope.changesetId), [
          'changeset-1',
          'changeset-2',
          'changeset-3',
        ]);
      },
      timeout: _timeout,
    );

    test(
      'bidirectional reconciliation converges both stores when each holds changesets the other lacks',
      () async {
        setRelayStore.append('project-1', _envelope('set-1'));
        setRelayStore.append('project-1', _envelope('set-2'));
        setRelayStore.append('project-1', _envelope('set-3'));
        upstreamStore.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        upstreamStore.append('project-1', _envelope('upstream-1'));
        upstreamStore.append('project-1', _envelope('upstream-2'));

        final result = await reconciler.reconcileProject(projectId: 'project-1');

        expect(result.pushed, 3);
        expect(result.pulled, 2);
        final onUpstream = upstreamStore.readSince('project-1', OcptSequenceNumber.zero);
        expect(onUpstream.map((changeset) => changeset.envelope.changesetId).toSet(), {
          'set-1',
          'set-2',
          'set-3',
          'upstream-1',
          'upstream-2',
        });
        final onSetRelay = setRelayStore.readSince('project-1', OcptSequenceNumber.zero);
        expect(onSetRelay.map((changeset) => changeset.envelope.changesetId).toSet(), {
          'set-1',
          'set-2',
          'set-3',
          'upstream-1',
          'upstream-2',
        });
      },
      timeout: _timeout,
    );

    test(
      'a second run right after the first pushes and pulls nothing new',
      () async {
        setRelayStore.append('project-1', _envelope('set-1'));
        upstreamStore.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        upstreamStore.append('project-1', _envelope('upstream-1'));
        await reconciler.reconcileProject(projectId: 'project-1');
        final upstreamLengthAfterFirst = upstreamStore.readSince('project-1', OcptSequenceNumber.zero).length;
        final setRelayLengthAfterFirst = setRelayStore.readSince('project-1', OcptSequenceNumber.zero).length;

        final second = await reconciler.reconcileProject(projectId: 'project-1');

        expect(second.pushed, 0);
        expect(second.pulled, 0);
        expect(upstreamStore.readSince('project-1', OcptSequenceNumber.zero).length, upstreamLengthAfterFirst);
        expect(setRelayStore.readSince('project-1', OcptSequenceNumber.zero).length, setRelayLengthAfterFirst);
      },
      timeout: _timeout,
    );

    test(
      'a later divergence on each side is picked up by a following reconcile',
      () async {
        setRelayStore.append('project-1', _envelope('set-1'));
        upstreamStore.createProject(projectId: 'project-1', tokenHash: _tokenHash('token-1'));
        upstreamStore.append('project-1', _envelope('upstream-1'));
        await reconciler.reconcileProject(projectId: 'project-1');

        setRelayStore.append('project-1', _envelope('set-2'));
        upstreamStore.append('project-1', _envelope('upstream-2'));

        final result = await reconciler.reconcileProject(projectId: 'project-1');

        expect(result.pushed, 1);
        expect(result.pulled, 1);
        final onUpstream = upstreamStore.readSince('project-1', OcptSequenceNumber.zero);
        expect(onUpstream.map((changeset) => changeset.envelope.changesetId).toSet(), {
          'set-1',
          'set-2',
          'upstream-1',
          'upstream-2',
        });
        final onSetRelay = setRelayStore.readSince('project-1', OcptSequenceNumber.zero);
        expect(onSetRelay.map((changeset) => changeset.envelope.changesetId).toSet(), {
          'set-1',
          'set-2',
          'upstream-1',
          'upstream-2',
        });
      },
      timeout: _timeout,
    );
  });
}

/// The sha256 hex digest [OcptRelayStore.createProject] expects as a `tokenHash` — mirrors
/// `OcptRelayServer`'s own hashing, so a test-seeded upstream project accepts the same bearer
/// token an [OcptRelayUpstreamClient] in this file authenticates with.
String _tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();
