// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_max_daily_presence.dart';

void main() {
  group("ocptMaxDailyPresenceMinutesOf", () {
    test("reads a plain whole number of minutes", () {
      expect(ocptMaxDailyPresenceMinutesOf("480"), 480);
      expect(ocptMaxDailyPresenceMinutesOf("0"), 0);
    });

    test("trims surrounding whitespace", () {
      expect(ocptMaxDailyPresenceMinutesOf("  480  "), 480);
    });

    test("reads nothing at all as no figure rather than as zero", () {
      expect(ocptMaxDailyPresenceMinutesOf(""), isNull);
      expect(ocptMaxDailyPresenceMinutesOf("   "), isNull);
    });

    test("reads what is not a whole number as no figure", () {
      expect(ocptMaxDailyPresenceMinutesOf("huit heures"), isNull);
      expect(ocptMaxDailyPresenceMinutesOf("8h30"), isNull);
      expect(ocptMaxDailyPresenceMinutesOf("12.5"), isNull);
    });

    test("reads a negative figure as no figure: a duration can't run backwards", () {
      expect(ocptMaxDailyPresenceMinutesOf("-30"), isNull);
    });
  });

  group("ocptMaxDailyPresenceTextOf", () {
    test("writes a figure the parser reads back unchanged", () {
      expect(ocptMaxDailyPresenceTextOf(480), "480");
      expect(ocptMaxDailyPresenceMinutesOf(ocptMaxDailyPresenceTextOf(480)), 480);
      expect(ocptMaxDailyPresenceTextOf(0), "0");
    });

    test("writes no figure as an empty field", () {
      expect(ocptMaxDailyPresenceTextOf(null), "");
    });
  });
}
