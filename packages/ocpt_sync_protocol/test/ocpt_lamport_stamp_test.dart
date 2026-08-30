// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('OcptLamportStamp', () {
    test('a higher version wins over a lower one', () {
      const higher = OcptLamportStamp(version: 5, deviceId: 'device-a');
      const lower = OcptLamportStamp(version: 3, deviceId: 'device-a');

      expect(higher.wins(lower), isTrue);
      expect(lower.wins(higher), isFalse);
      expect(higher.compareTo(lower), greaterThan(0));
    });

    test('a higher version wins regardless of which side it is compared from', () {
      const higher = OcptLamportStamp(version: 9, deviceId: 'device-z');
      const lower = OcptLamportStamp(version: 1, deviceId: 'device-a');

      // Swapping which device holds the higher version does not change the outcome: version
      // alone decides, so the device with the higher version wins either way round.
      expect(higher.wins(lower), isTrue);
      expect(lower.wins(higher), isFalse);
    });

    test('an equal version is broken by deviceId, lexicographically after wins', () {
      const before = OcptLamportStamp(version: 4, deviceId: 'device-a');
      const after = OcptLamportStamp(version: 4, deviceId: 'device-b');

      expect(after.wins(before), isTrue);
      expect(before.wins(after), isFalse);
    });

    test('the deviceId tiebreak holds in either direction', () {
      const alpha = OcptLamportStamp(version: 10, deviceId: 'alpha');
      const zulu = OcptLamportStamp(version: 10, deviceId: 'zulu');

      expect(zulu.wins(alpha), isTrue);
      expect(alpha.wins(zulu), isFalse);
    });

    test('an identical stamp does not win over itself', () {
      const stamp = OcptLamportStamp(version: 2, deviceId: 'device-a');
      const identical = OcptLamportStamp(version: 2, deviceId: 'device-a');

      expect(stamp.wins(identical), isFalse);
      expect(identical.wins(stamp), isFalse);
      expect(stamp.compareTo(identical), 0);
      expect(stamp, identical);
    });
  });
}
