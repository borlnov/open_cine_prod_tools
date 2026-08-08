// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';

void main() {
  group("ocptFormatDayMinute", () {
    test("formats midnight", () {
      expect(ocptFormatDayMinute(0), "00:00");
    });

    test("formats the last minute of the day", () {
      expect(ocptFormatDayMinute(1439), "23:59");
    });

    test("wraps the following midnight back to 00:00", () {
      expect(ocptFormatDayMinute(1440), "00:00");
    });

    test("reads a night shoot's small hours as a clock face, not as 27:00", () {
      // A 19:00 -> 03:00 night slot stores 1140 -> 1620, and the whole point of this formatter is
      // to print the clock reading a call sheet shows, not the raw offset from midnight.
      expect(ocptFormatDayMinute(1140), "19:00");
      expect(ocptFormatDayMinute(1620), "03:00");
    });

    test("wraps a negative minute back onto the previous evening's clock face", () {
      expect(ocptFormatDayMinute(-181), "20:59");
      expect(ocptFormatDayMinute(-1), "23:59");
    });

    test("pads single-digit hours and minutes", () {
      expect(ocptFormatDayMinute(65), "01:05");
    });
  });

  group("ocptParseDayMinute", () {
    test("reads a two-digit clock reading back into minutes", () {
      expect(ocptParseDayMinute("00:00"), 0);
      expect(ocptParseDayMinute("23:59"), 1439);
      expect(ocptParseDayMinute("19:00"), 1140);
    });

    test("accepts a single-digit hour", () {
      expect(ocptParseDayMinute("3:00"), 180);
    });

    test("reads nothing at all, or something with no clock in it, as null", () {
      expect(ocptParseDayMinute(""), isNull);
      expect(ocptParseDayMinute("not a time"), isNull);
      expect(ocptParseDayMinute("19h00"), isNull);
    });

    test("refuses an hour or a minute out of range rather than wrapping it", () {
      expect(ocptParseDayMinute("24:00"), isNull);
      expect(ocptParseDayMinute("12:60"), isNull);
    });

    test("round-trips through the formatter for an ordinary minute", () {
      const minute = 575; // 09:35
      expect(ocptParseDayMinute(ocptFormatDayMinute(minute)), minute);
    });

    test("round-trips a night minute onto its wrapped clock reading, not the original offset", () {
      // The parser has no way to know a "03:00" reading belongs to a day that started the
      // evening before: that is the caller's own "next day" fact, not this function's to recover.
      expect(ocptParseDayMinute(ocptFormatDayMinute(1620)), 180);
    });
  });

  group("ocptFormatMinuteDuration", () {
    test("formats a duration under an hour as minutes alone", () {
      expect(ocptFormatMinuteDuration(45), "45 min");
    });

    test("formats a duration crossing an hour as hours and minutes", () {
      expect(ocptFormatMinuteDuration(90), "1 h 30");
    });

    test("drops the minutes entirely on an exact number of hours", () {
      expect(ocptFormatMinuteDuration(60), "1 h");
      expect(ocptFormatMinuteDuration(120), "2 h");
    });

    test("formats a zero duration as no minutes", () {
      expect(ocptFormatMinuteDuration(0), "0 min");
    });

    test("keeps the sign of a negative duration", () {
      expect(ocptFormatMinuteDuration(-45), "-45 min");
      expect(ocptFormatMinuteDuration(-90), "-1 h 30");
    });
  });
}
