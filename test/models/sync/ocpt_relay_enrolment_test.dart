// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_enrolment.dart';
import 'package:open_cine_prod_tools/types/ocpt_relay_enrolment_status.dart';

void main() {
  group('OcptRelayEnrolment', () {
    test('round-trips a plain enrolment through toEnrolmentString/parse', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'abcDEF123',
      );

      final encoded = enrolment.toEnrolmentString();
      final decoded = OcptRelayEnrolment.parse(encoded).value!;

      expect(decoded, enrolment);
    });

    test('round-trips a relay URL carrying a port and a path', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org:8443/on-set/relay'),
        enrolmentSecret: 'secret-value',
      );

      final decoded = OcptRelayEnrolment.parse(enrolment.toEnrolmentString()).value!;

      expect(decoded, enrolment);
      expect(decoded.relayBaseUri.port, 8443);
      expect(decoded.relayBaseUri.path, '/on-set/relay');
    });

    test('round-trips a secret with URL-unsafe characters', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'ab+cd/ef==with spaces',
      );

      final decoded = OcptRelayEnrolment.parse(enrolment.toEnrolmentString()).value!;

      expect(decoded, enrolment);
      expect(decoded.enrolmentSecret, 'ab+cd/ef==with spaces');
    });

    test('reads back a valid enrolment with an ok status', () {
      final enrolment = OcptRelayEnrolment(
        relayBaseUri: Uri.parse('https://relay.example.org/'),
        enrolmentSecret: 'abcDEF123',
      );

      final result = OcptRelayEnrolment.parse(enrolment.toEnrolmentString());
      expect(result.status, OcptRelayEnrolmentStatus.ok);
      expect(result.value, enrolment);
    });

    test('rejects a plain string', () {
      final result = OcptRelayEnrolment.parse('not a uri at all');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.wrongScheme);
      expect(result.value, isNull);
    });

    test('rejects an unrelated https:// URL', () {
      final result = OcptRelayEnrolment.parse('https://example.org/relay?r=x&e=y');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.wrongScheme);
      expect(result.value, isNull);
    });

    test('rejects an ocpt:// URL with the wrong host', () {
      final result = OcptRelayEnrolment.parse('ocpt://join?r=relay&e=secret');
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.wrongHost);
      expect(result.value, isNull);
    });

    test('rejects a missing relay parameter', () {
      const enrolmentString = 'ocpt://relay?e=secret';

      final result = OcptRelayEnrolment.parse(enrolmentString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.missingRelay);
      expect(result.value, isNull);
    });

    test('rejects a missing enrolment secret parameter', () {
      const enrolmentString = 'ocpt://relay?r=relay';

      final result = OcptRelayEnrolment.parse(enrolmentString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.missingSecret);
      expect(result.value, isNull);
    });

    test('rejects an empty relay parameter value', () {
      const enrolmentString = 'ocpt://relay?r=&e=secret';

      final result = OcptRelayEnrolment.parse(enrolmentString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.missingRelay);
      expect(result.value, isNull);
    });

    test('rejects an empty enrolment secret value', () {
      const enrolmentString = 'ocpt://relay?r=relay&e=';

      final result = OcptRelayEnrolment.parse(enrolmentString);
      expect(result.isSuccess, isFalse);
      expect(result.status, OcptRelayEnrolmentStatus.missingSecret);
      expect(result.value, isNull);
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
