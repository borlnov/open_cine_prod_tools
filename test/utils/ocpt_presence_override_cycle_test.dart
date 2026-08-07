// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/utils/ocpt_presence_override_cycle.dart';

void main() {
  test("starts the cycle at working when there is no override yet", () {
    expect(ocptNextPresenceOverride(null), OcptPresenceCode.working);
  });

  test("steps through the four codes in their declared order", () {
    expect(ocptNextPresenceOverride(OcptPresenceCode.working), OcptPresenceCode.available);
    expect(ocptNextPresenceOverride(OcptPresenceCode.available), OcptPresenceCode.travelling);
    expect(ocptNextPresenceOverride(OcptPresenceCode.travelling), OcptPresenceCode.unavailable);
  });

  test("wraps from unavailable back to no override at all", () {
    expect(ocptNextPresenceOverride(OcptPresenceCode.unavailable), isNull);
  });

  test("a full click cycle returns to null after five steps", () {
    OcptPresenceCode? current;
    for (var i = 0; i < 4; i++) {
      current = ocptNextPresenceOverride(current);
    }
    expect(current, OcptPresenceCode.unavailable);

    current = ocptNextPresenceOverride(current);
    expect(current, isNull);
  });
}
