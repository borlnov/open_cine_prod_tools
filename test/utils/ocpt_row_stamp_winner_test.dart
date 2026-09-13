// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_winner.dart';

void main() {
  test('an incoming stamp always wins when the column carries no local stamp', () {
    expect(
      ocptIncomingStampWins(incomingVersion: 1, incomingDeviceId: 'a', localVersion: null, localDeviceId: null),
      isTrue,
    );
  });

  test('a strictly higher incoming version wins, whatever the device ids compare as', () {
    expect(
      ocptIncomingStampWins(incomingVersion: 5, incomingDeviceId: 'aaa', localVersion: 4, localDeviceId: 'zzz'),
      isTrue,
    );
    expect(
      ocptIncomingStampWins(incomingVersion: 4, incomingDeviceId: 'zzz', localVersion: 5, localDeviceId: 'aaa'),
      isFalse,
    );
  });

  test('a tied version is broken by the device id, lexicographically', () {
    expect(
      ocptIncomingStampWins(incomingVersion: 3, incomingDeviceId: 'device-b', localVersion: 3, localDeviceId: 'device-a'),
      isTrue,
    );
    expect(
      ocptIncomingStampWins(incomingVersion: 3, incomingDeviceId: 'device-a', localVersion: 3, localDeviceId: 'device-b'),
      isFalse,
    );
  });

  test('an identical stamp never wins, so re-applying one is a no-op', () {
    expect(
      ocptIncomingStampWins(incomingVersion: 3, incomingDeviceId: 'device-a', localVersion: 3, localDeviceId: 'device-a'),
      isFalse,
    );
  });
}
