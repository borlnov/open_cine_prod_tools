// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:ocpt_sync_relay/ocpt_sync_relay.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('buildRelayServerFromEnvironment', () {
    test('throws StateError when the enrolment secret is missing', () {
      expect(() => buildRelayServerFromEnvironment(const {}), throwsStateError);
    });

    test('throws StateError when the enrolment secret is empty', () {
      expect(
        () => buildRelayServerFromEnvironment({relayEnrolmentSecretEnvVar: ''}),
        throwsStateError,
      );
    });

    test('throws ArgumentError when the port is not a valid port number', () {
      expect(
        () => buildRelayServerFromEnvironment({
          relayEnrolmentSecretEnvVar: 'a-secret',
          relayPortEnvVar: 'not-a-port',
        }),
        throwsArgumentError,
      );
    });

    test('resolves the documented defaults when only the secret is set', () {
      // The default db path is relative, so building against it actually creates a file under the
      // current directory — run this one from a throwaway temporary directory, restored and
      // deleted afterwards, rather than leaving a stray `relay.sqlite` behind in the package.
      final originalDirectory = Directory.current;
      final tempDirectory = Directory.systemTemp.createTempSync('ocpt_relay_environment_test_');
      Directory.current = tempDirectory;
      addTearDown(() {
        Directory.current = originalDirectory;
        tempDirectory.deleteSync(recursive: true);
      });

      final binding = buildRelayServerFromEnvironment({relayEnrolmentSecretEnvVar: 'a-secret'});
      addTearDown(binding.store.close);

      expect(binding.port, defaultRelayPort);
      expect(binding.dbPath, defaultRelayDbPath);
    });

    test('resolves an explicit port and db path', () {
      final binding = buildRelayServerFromEnvironment({
        relayEnrolmentSecretEnvVar: 'a-secret',
        relayPortEnvVar: '0',
        relayDbPathEnvVar: ':memory:',
      });
      addTearDown(binding.store.close);

      expect(binding.port, 0);
      expect(binding.dbPath, ':memory:');
    });

    test('the server it builds is wired and actually answers a request', () async {
      final binding = buildRelayServerFromEnvironment({
        relayEnrolmentSecretEnvVar: 'a-secret',
        relayPortEnvVar: '0',
        relayDbPathEnvVar: ':memory:',
      });
      addTearDown(binding.store.close);
      binding.store.createProject(projectId: 'p1', tokenHash: 'irrelevant-for-this-test');

      final httpServer = await shelf_io.serve(
        binding.server.handler,
        InternetAddress.loopbackIPv4,
        binding.port,
      );
      addTearDown(() => httpServer.close(force: true));

      final request = await HttpClient().getUrl(
        Uri.parse('http://127.0.0.1:${httpServer.port}/projects/p1/changesets?since=0'),
      );
      final response = await request.close();
      await response.drain<void>();

      // No bearer token was sent, so the request is refused before ever reaching the store's
      // changeset log — this is enough to prove the handler this test built is actually the one
      // serving the socket, wired against the same store the test can inspect.
      expect(response.statusCode, 401);
    });
  });
}
