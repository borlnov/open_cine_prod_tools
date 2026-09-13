// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';

void main() {
  group('OcptRelayInvite', () {
    test('round-trips a plain invite through toInviteString/parse', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        projectId: 'project-123',
        token: 'abcDEF123',
      );

      final encoded = invite.toInviteString();
      final decoded = OcptRelayInvite.parse(encoded);

      expect(decoded, invite);
    });

    test('round-trips a relay URL carrying a port and a path', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org:8443/on-set/relay'),
        projectId: 'project-abc',
        token: 'token-value',
      );

      final decoded = OcptRelayInvite.parse(invite.toInviteString());

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

      final decoded = OcptRelayInvite.parse(invite.toInviteString());

      expect(decoded, invite);
      expect(decoded.token, 'ab+cd/ef==with spaces');
    });

    test('tryParse mirrors parse on a valid invite', () {
      final invite = OcptRelayInvite(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        projectId: 'project-123',
        token: 'abcDEF123',
      );

      expect(OcptRelayInvite.tryParse(invite.toInviteString()), invite);
    });

    test('rejects a plain string', () {
      expect(() => OcptRelayInvite.parse('not a uri at all'), throwsFormatException);
      expect(OcptRelayInvite.tryParse('not a uri at all'), isNull);
    });

    test('rejects an unrelated https:// URL', () {
      expect(
        () => OcptRelayInvite.parse('https://example.org/join?r=x&p=y&t=z'),
        throwsFormatException,
      );
      expect(OcptRelayInvite.tryParse('https://example.org/join?r=x&p=y&t=z'), isNull);
    });

    test('rejects an ocpt:// URL with the wrong host', () {
      expect(
        () => OcptRelayInvite.parse('ocpt://pair?r=relay&p=proj&t=tok'),
        throwsFormatException,
      );
      expect(OcptRelayInvite.tryParse('ocpt://pair?r=relay&p=proj&t=tok'), isNull);
    });

    test('rejects a missing relay parameter', () {
      const inviteString = 'ocpt://join?p=proj&t=tok';

      expect(() => OcptRelayInvite.parse(inviteString), throwsFormatException);
      expect(OcptRelayInvite.tryParse(inviteString), isNull);
    });

    test('rejects a missing project id parameter', () {
      const inviteString = 'ocpt://join?r=relay&t=tok';

      expect(() => OcptRelayInvite.parse(inviteString), throwsFormatException);
      expect(OcptRelayInvite.tryParse(inviteString), isNull);
    });

    test('rejects a missing token parameter', () {
      const inviteString = 'ocpt://join?r=relay&p=proj';

      expect(() => OcptRelayInvite.parse(inviteString), throwsFormatException);
      expect(OcptRelayInvite.tryParse(inviteString), isNull);
    });

    test('rejects an empty parameter value', () {
      const inviteString = 'ocpt://join?r=relay&p=proj&t=';

      expect(() => OcptRelayInvite.parse(inviteString), throwsFormatException);
      expect(OcptRelayInvite.tryParse(inviteString), isNull);
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
