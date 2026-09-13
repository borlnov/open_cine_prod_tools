// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';

void main() {
  group('OcptPresenceRoster', () {
    const selfFrame = OcptPresenceFrame(
      deviceId: 'device-self',
      platform: 'windows',
      modeKey: 'screenplay',
      heartbeat: 3,
    );
    const peerFrame = OcptPresenceFrame(
      deviceId: 'device-peer',
      platform: 'android',
      modeKey: 'breakdown',
      heartbeat: 1,
    );

    test('self is first in participants and isSelf tells it apart from a peer', () {
      const roster = OcptPresenceRoster(participants: [selfFrame, peerFrame], selfDeviceId: 'device-self');

      expect(roster.participants.first, selfFrame);
      expect(roster.isSelf(selfFrame), isTrue);
      expect(roster.isSelf(peerFrame), isFalse);
    });

    test('two rosters with the same fields are equal', () {
      const first = OcptPresenceRoster(participants: [selfFrame, peerFrame], selfDeviceId: 'device-self');
      const second = OcptPresenceRoster(participants: [selfFrame, peerFrame], selfDeviceId: 'device-self');

      expect(first, second);
    });

    test('a roster with different participants is not equal', () {
      const first = OcptPresenceRoster(participants: [selfFrame], selfDeviceId: 'device-self');
      const second = OcptPresenceRoster(participants: [selfFrame, peerFrame], selfDeviceId: 'device-self');

      expect(first, isNot(second));
    });
  });
}
