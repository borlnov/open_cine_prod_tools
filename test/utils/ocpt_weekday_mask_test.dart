// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

void main() {
  group("ocptWeekdayMaskContains", () {
    test("the every-day mask covers all seven days", () {
      for (final weekday in ocptWeekdays) {
        expect(ocptWeekdayMaskContains(ocptEveryWeekdayMask, weekday), isTrue);
      }

      expect(ocptWeekdayMaskCoversEveryDay(ocptEveryWeekdayMask), isTrue);
    });

    test("a mask covers the days it was built from and no other", () {
      final mask = ocptWeekdayMaskToggled(
        ocptWeekdayMaskToggled(ocptEveryWeekdayMask, DateTime.saturday),
        DateTime.sunday,
      );

      expect(ocptWeekdayMaskContains(mask, DateTime.friday), isTrue);
      expect(ocptWeekdayMaskContains(mask, DateTime.saturday), isFalse);
      expect(ocptWeekdayMaskContains(mask, DateTime.sunday), isFalse);
      expect(ocptWeekdayMaskCoversEveryDay(mask), isFalse);
    });

    test("a number that is no weekday is covered by nothing", () {
      expect(ocptWeekdayMaskContains(ocptEveryWeekdayMask, 0), isFalse);
      expect(ocptWeekdayMaskContains(ocptEveryWeekdayMask, 8), isFalse);
    });
  });

  group("ocptWeekdayMaskToggled", () {
    test("adds a missing day and removes a covered one", () {
      final withoutMonday = ocptWeekdayMaskToggled(ocptEveryWeekdayMask, DateTime.monday);
      expect(ocptWeekdayMaskContains(withoutMonday, DateTime.monday), isFalse);

      final withMondayBack = ocptWeekdayMaskToggled(withoutMonday, DateTime.monday);
      expect(withMondayBack, ocptEveryWeekdayMask);
    });

    test("refuses to clear the last covered day", () {
      var mask = ocptEveryWeekdayMask;
      for (final weekday in ocptWeekdays.where((weekday) => weekday != DateTime.wednesday)) {
        mask = ocptWeekdayMaskToggled(mask, weekday);
      }

      // A window covering no day at all would say nothing, so the control simply doesn't move.
      expect(ocptWeekdayMaskToggled(mask, DateTime.wednesday), mask);
      expect(ocptWeekdayMaskContains(mask, DateTime.wednesday), isTrue);
    });
  });

  group("ocptWeekdayMaskCoversDate", () {
    test("reads a date's own weekday", () {
      // 2026-08-03 is a Monday.
      final monday = DateTime(2026, 8, 3);
      final withoutMonday = ocptWeekdayMaskToggled(ocptEveryWeekdayMask, DateTime.monday);

      expect(ocptWeekdayMaskCoversDate(ocptEveryWeekdayMask, monday), isTrue);
      expect(ocptWeekdayMaskCoversDate(withoutMonday, monday), isFalse);
      expect(ocptWeekdayMaskCoversDate(withoutMonday, monday.add(const Duration(days: 1))), isTrue);
    });
  });
}
