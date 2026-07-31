// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

void main() {
  group("ocptParseShotDuration / ocptFormatShotDuration round trip", () {
    test("a blank input parses to null, matching the null formatting", () {
      expect(ocptParseShotDuration(""), isNull);
      expect(ocptParseShotDuration("   "), isNull);
      expect(ocptParseShotDuration(ocptFormatShotDuration(null)), isNull);
    });

    test("m:ss round-trips through both directions", () {
      for (final milliseconds in [0, 5000, 65000, 600000, 3599000]) {
        final formatted = ocptFormatShotDuration(milliseconds);
        expect(ocptParseShotDuration(formatted), milliseconds, reason: "for $formatted");
      }
    });

    test("a bare non-negative integer is read as a number of seconds", () {
      expect(ocptParseShotDuration("90"), 90000);
      expect(ocptParseShotDuration("0"), 0);
    });

    test("an unparseable value throws FormatException, leaving the caller to reject it", () {
      expect(() => ocptParseShotDuration("banana"), throwsFormatException);
      expect(() => ocptParseShotDuration("-5"), throwsFormatException);
      expect(() => ocptParseShotDuration("1:75"), throwsFormatException);
      expect(() => ocptParseShotDuration("1:2:3"), throwsFormatException);
    });
  });

  group("ocptShotFieldOrDash", () {
    test("returns the dash placeholder for null or blank, the value otherwise", () {
      expect(ocptShotFieldOrDash(null), ocptShotListEmptyValue);
      expect(ocptShotFieldOrDash("   "), ocptShotListEmptyValue);
      expect(ocptShotFieldOrDash("Wide shot"), "Wide shot");
    });
  });
}
