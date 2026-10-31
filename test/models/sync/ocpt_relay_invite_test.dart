// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/types/ocpt_relay_invite_status.dart';

void main() {
  group('OcptRelayInvite', () {
    test('round-trips a plain invite through toInviteString/parse', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        projectId: 'project-123',
        token: 'abcDEF123',
      );

      final encoded = invite.toInviteString();
      final decoded = OcptRelayInvite.parse(encoded).value!;

      expect(decoded, invite);
    });

    test('round-trips a relay URL carrying a port and a path', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org:8443/on-set/relay'),
        projectId: 'project-abc',
        token: 'token-value',
      );

      final decoded = OcptRelayInvite.parse(invite.toInviteString()).value!;

      expect(decoded, invite);
      expect(decoded.relayBaseUri.port, 8443);
      expect(decoded.relayBaseUri.path, '/on-set/relay');
    });

    test('round-trips a token with URL-unsafe characters', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        projectId: 'project-123',
        token: 'ab+cd/ef==with spaces',
      );

      final decoded = OcptRelayInvite.parse(invite.toInviteString()).value!;

      expect(decoded, invite);
      expect(decoded.token, 'ab+cd/ef==with spaces');
    });

    test('reads back a valid invite with an ok status', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        projectId: 'project-123',
        token: 'abcDEF123',
      );

      final result = OcptRelayInvite.parse(invite.toInviteString());
      expect(result.status, OcptRelayInviteStatus.ok);
      expect(result.value, invite);
    });

    test('reports a query that is not valid UTF-8 as a malformed URI', () {
      final result = OcptRelayInvite.parse('ocpt://join?r=%FF&p=x&t=y');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.malformedUri);
      expect(result.value, isNull);
    });

    test('rejects a plain string', () {
      final result = OcptRelayInvite.parse('not a uri at all');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.wrongScheme);
      expect(result.value, isNull);
    });

    test('rejects an unrelated https:// URL', () {
      final result = OcptRelayInvite.parse('https://example.org/join?r=x&p=y&t=z');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.wrongScheme);
      expect(result.value, isNull);
    });

    test('rejects an ocpt:// URL with the wrong host', () {
      final result = OcptRelayInvite.parse('ocpt://pair?r=relay&p=proj&t=tok');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.wrongHost);
      expect(result.value, isNull);
    });

    test('rejects a missing relay parameter', () {
      const inviteString = 'ocpt://join?p=proj&t=tok';

      final result = OcptRelayInvite.parse(inviteString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.missingRelay);
      expect(result.value, isNull);
    });

    test('rejects a missing project id parameter', () {
      const inviteString = 'ocpt://join?r=relay&t=tok';

      final result = OcptRelayInvite.parse(inviteString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.missingProjectId);
      expect(result.value, isNull);
    });

    test('rejects a missing token parameter', () {
      const inviteString = 'ocpt://join?r=relay&p=proj';

      final result = OcptRelayInvite.parse(inviteString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.missingToken);
      expect(result.value, isNull);
    });

    test('rejects an empty parameter value', () {
      const inviteString = 'ocpt://join?r=relay&p=proj&t=';

      final result = OcptRelayInvite.parse(inviteString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayInviteStatus.missingToken);
      expect(result.value, isNull);
    });

    test('toString does not leak the raw token', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        projectId: 'project-123',
        token: 'super-secret-token-value',
      );

      expect(invite.toString(), isNot(contains(invite.token)));
    });
  });
}
