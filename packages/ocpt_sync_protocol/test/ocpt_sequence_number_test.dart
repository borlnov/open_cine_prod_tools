// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('OcptSequenceNumber', () {
    test('round-trips through JSON', () {
      const sequenceNumber = OcptSequenceNumber(42);

      final json = sequenceNumber.toJson();
      final decoded = OcptSequenceNumber.fromJson(json);

      expect(decoded, sequenceNumber);
      expect(json, 42);
    });

    test('orders positions strictly', () {
      const earlier = OcptSequenceNumber(1);
      const later = OcptSequenceNumber(2);

      expect(earlier < later, isTrue);
      expect(later > earlier, isTrue);
      expect(earlier <= const OcptSequenceNumber(1), isTrue);
      expect(earlier >= const OcptSequenceNumber(1), isTrue);
      expect(earlier.compareTo(later), lessThan(0));
      expect(later.compareTo(earlier), greaterThan(0));
      expect(earlier.compareTo(earlier), 0);
    });

    test('next() is monotonic and one past the current position', () {
      const sequenceNumber = OcptSequenceNumber(7);

      final next = sequenceNumber.next();

      expect(next, const OcptSequenceNumber(8));
      expect(next > sequenceNumber, isTrue);
    });

    test('zero is the starting cursor', () {
      expect(OcptSequenceNumber.zero.value, 0);
    });

    test('two sequence numbers with the same value are equal', () {
      expect(const OcptSequenceNumber(5), const OcptSequenceNumber(5));
    });

    test('rejects a negative value', () {
      expect(() => OcptSequenceNumber(-1), throwsA(isA<AssertionError>()));
    });
  });
}
