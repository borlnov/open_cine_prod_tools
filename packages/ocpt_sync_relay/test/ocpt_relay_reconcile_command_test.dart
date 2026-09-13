// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

const _enrolmentSecret = 'enrolment-secret';
const _timeout = Timeout(Duration(seconds: 5));

OcptChangesetEnvelope _envelope(String changesetId) => OcptChangesetEnvelope(
  changesetId: changesetId,
  originDeviceId: 'device-1',
  lamport: 1,
  createdAt: DateTime.utc(2026),
  payload: Uint8List.fromList([1, 2, 3]),
);

void main() {
  group('parseReconcileInvite', () {
    test('round-trips a well-formed invite', () {
      final invite = parseReconcileInvite('ocpt://join?r=https://relay.example.org&p=project-1&t=secret-token');

      expect(invite.upstream, Uri.parse('https://relay.example.org'));
      expect(invite.projectId, 'project-1');
      expect(invite.token, 'secret-token');
    });

    test('throws FormatException on a wrong scheme', () {
      expect(
        () => parseReconcileInvite('https://join?r=https://relay.example.org&p=project-1&t=secret-token'),
        throwsFormatException,
      );
    });

    test('throws FormatException on a wrong host', () {
      expect(
        () => parseReconcileInvite('ocpt://relay?r=https://relay.example.org&p=project-1&t=secret-token'),
        throwsFormatException,
      );
    });

    test('throws FormatException on an empty r query parameter', () {
      expect(() => parseReconcileInvite('ocpt://join?r=&p=project-1&t=secret-token'), throwsFormatException);
    });

    test('throws FormatException on an empty p query parameter', () {
      expect(
        () => parseReconcileInvite('ocpt://join?r=https://relay.example.org&p=&t=secret-token'),
        throwsFormatException,
      );
    });

    test('throws FormatException on an empty t query parameter', () {
      expect(
        () => parseReconcileInvite('ocpt://join?r=https://relay.example.org&p=project-1&t='),
        throwsFormatException,
      );
    });
  });

  group('runReconcileCommand', () {
    late OcptRelayStore upstreamStore;
    late OcptRelayServer upstreamServer;
    late HttpServer upstreamHttpServer;
    late Uri upstreamBaseUri;
    late String dbPath;

    setUp(() async {
      upstreamStore = OcptRelayStore(':memory:');
      upstreamServer = OcptRelayServer(store: upstreamStore, enrolmentSecret: _enrolmentSecret);
      upstreamHttpServer = await shelf_io.serve(upstreamServer.handler, 'localhost', 0);
      upstreamBaseUri = Uri.parse('http://localhost:${upstreamHttpServer.port}');
      dbPath = ':memory:';
    });

    tearDown(() async {
      await upstreamHttpServer.close(force: true);
      upstreamStore.close();
    });

    test(
      'the --invite form parses the invite, reconciles, and logs the summary',
      () async {
        final logged = <String>[];
        final localStore = OcptRelayStore(':memory:');
        localStore.append('project-1', _envelope('changeset-1'));

        await runReconcileCommand(
          [
            '--invite',
            'ocpt://join?r=$upstreamBaseUri&p=project-1&t=token-1',
            '--db-path',
            dbPath,
            '--enrolment-secret',
            _enrolmentSecret,
          ],
          environment: const {},
          openStore: (_) => localStore,
          log: logged.add,
        );

        expect(logged, ['pushed 1, pulled 0']);
        expect(
          upstreamStore.readSince('project-1', OcptSequenceNumber.zero).map((c) => c.envelope.changesetId),
          ['changeset-1'],
        );
      },
      timeout: _timeout,
    );

    test(
      'the --upstream/--project/--token trio works the same as --invite',
      () async {
        final logged = <String>[];
        final localStore = OcptRelayStore(':memory:');
        localStore.append('project-1', _envelope('changeset-1'));

        await runReconcileCommand(
          [
            '--upstream',
            upstreamBaseUri.toString(),
            '--project',
            'project-1',
            '--token',
            'token-1',
            '--db-path',
            dbPath,
            '--enrolment-secret',
            _enrolmentSecret,
          ],
          environment: const {},
          openStore: (_) => localStore,
          log: logged.add,
        );

        expect(logged, ['pushed 1, pulled 0']);
      },
      timeout: _timeout,
    );

    test(
      '--db-path is passed through to the injected openStore factory',
      () async {
        final seenDbPaths = <String>[];
        final localStore = OcptRelayStore(':memory:');
        localStore.append('project-1', _envelope('changeset-1'));

        await runReconcileCommand(
          [
            '--invite',
            'ocpt://join?r=$upstreamBaseUri&p=project-1&t=token-1',
            '--db-path',
            '/tmp/custom.sqlite',
            '--enrolment-secret',
            _enrolmentSecret,
          ],
          environment: const {},
          openStore: (path) {
            seenDbPaths.add(path);

            return localStore;
          },
          log: (_) {},
        );

        expect(seenDbPaths, ['/tmp/custom.sqlite']);
      },
      timeout: _timeout,
    );

    test('missing project identity throws FormatException', () {
      expect(
        () => runReconcileCommand(const [], environment: const {}, log: (_) {}),
        throwsFormatException,
      );
    });

    test('an unknown flag throws FormatException', () {
      expect(
        () => runReconcileCommand(
          ['--bogus', 'value'],
          environment: const {},
          log: (_) {},
        ),
        throwsFormatException,
      );
    });
  });
}
