// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';

void main() {
  group('OcptRelayEnrolment', () {
    test('round-trips a plain enrolment through toEnrolmentString/parse', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'abcDEF123',
      );

      final encoded = enrolment.toEnrolmentString();
      final decoded = OcptRelayEnrolment.parse(encoded);

      expect(decoded, enrolment);
    });

    test('round-trips a relay URL carrying a port and a path', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org:8443/on-set/relay'),
        enrolmentSecret: 'secret-value',
      );

      final decoded = OcptRelayEnrolment.parse(enrolment.toEnrolmentString());

      expect(decoded, enrolment);
      expect(decoded.relayBaseUri.port, 8443);
      expect(decoded.relayBaseUri.path, '/on-set/relay');
    });

    test('round-trips a secret with URL-unsafe characters', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'ab+cd/ef==with spaces',
      );

      final decoded = OcptRelayEnrolment.parse(enrolment.toEnrolmentString());

      expect(decoded, enrolment);
      expect(decoded.enrolmentSecret, 'ab+cd/ef==with spaces');
    });

    test('tryParse mirrors parse on a valid enrolment', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'abcDEF123',
      );

      expect(OcptRelayEnrolment.tryParse(enrolment.toEnrolmentString()), enrolment);
    });

    test('rejects a plain string', () {
      expect(() => OcptRelayEnrolment.parse('not a uri at all'), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse('not a uri at all'), isNull);
    });

    test('rejects an unrelated https:// URL', () {
      expect(() => OcptRelayEnrolment.parse('https://example.org/relay?r=x&e=y'), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse('https://example.org/relay?r=x&e=y'), isNull);
    });

    test('rejects an ocpt:// URL with the wrong host', () {
      expect(() => OcptRelayEnrolment.parse('ocpt://join?r=relay&e=secret'), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse('ocpt://join?r=relay&e=secret'), isNull);
    });

    test('rejects a missing relay parameter', () {
      const enrolmentString = 'ocpt://relay?e=secret';

      expect(() => OcptRelayEnrolment.parse(enrolmentString), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse(enrolmentString), isNull);
    });

    test('rejects a missing enrolment secret parameter', () {
      const enrolmentString = 'ocpt://relay?r=relay';

      expect(() => OcptRelayEnrolment.parse(enrolmentString), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse(enrolmentString), isNull);
    });

    test('rejects an empty relay parameter value', () {
      const enrolmentString = 'ocpt://relay?r=&e=secret';

      expect(() => OcptRelayEnrolment.parse(enrolmentString), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse(enrolmentString), isNull);
    });

    test('rejects an empty enrolment secret value', () {
      const enrolmentString = 'ocpt://relay?r=relay&e=';

      expect(() => OcptRelayEnrolment.parse(enrolmentString), throwsFormatException);
      expect(OcptRelayEnrolment.tryParse(enrolmentString), isNull);
    });

    test('toString does not leak the raw enrolment secret', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'super-secret-value-value',
      );

      expect(enrolment.toString(), isNot(contains(enrolment.enrolmentSecret)));
    });
  });
}
