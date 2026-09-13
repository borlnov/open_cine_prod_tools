// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';

void main() {
  group('OcptPresenceFrame', () {
    test('round-trips through toJson/fromJson with a mode key set', () {
      const frame = OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'windows',
        modeKey: 'screenplay',
        heartbeat: 4,
      );

      final decoded = OcptPresenceFrame.fromJson(frame.toJson());

      expect(decoded, frame);
    });

    test('round-trips a null mode key', () {
      const frame = OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'android',
        modeKey: null,
        heartbeat: 1,
      );

      final decoded = OcptPresenceFrame.fromJson(frame.toJson());

      expect(decoded, frame);
      expect(decoded.modeKey, isNull);
    });

    test('rejects a frame missing a required field', () {
      final json = const OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'linux',
        modeKey: 'budget',
        heartbeat: 2,
      ).toJson()..remove('deviceId');

      expect(() => OcptPresenceFrame.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('rejects a field carrying the wrong type', () {
      final json = const OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'linux',
        modeKey: 'budget',
        heartbeat: 2,
      ).toJson();
      json['heartbeat'] = 'not-a-number';

      expect(() => OcptPresenceFrame.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('two frames with the same fields are equal', () {
      const first = OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'windows',
        modeKey: 'schedule',
        heartbeat: 7,
      );
      const second = OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'windows',
        modeKey: 'schedule',
        heartbeat: 7,
      );

      expect(first, second);
    });

    test('two frames differing only by heartbeat are not equal', () {
      const first = OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'windows',
        modeKey: 'schedule',
        heartbeat: 7,
      );
      const second = OcptPresenceFrame(
        deviceId: 'device-1',
        platform: 'windows',
        modeKey: 'schedule',
        heartbeat: 8,
      );

      expect(first, isNot(second));
    });
  });
}
