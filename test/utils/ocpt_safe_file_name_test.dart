// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_safe_file_name.dart';

void main() {
  group("ocptSafeFileNameOf", () {
    test("leaves an ordinary name untouched", () {
      expect(ocptSafeFileNameOf("Les Vagues", fallback: "project"), "Les Vagues");
    });

    test("replaces every character Windows forbids, and collapses what that leaves behind", () {
      // A colon is exactly what a French subtitle brings: "Les Vagues : acte 2" must not turn
      // into an ambiguous "Les VaguesActe2" nor a path Windows refuses outright.
      expect(ocptSafeFileNameOf("Les Vagues : acte 2", fallback: "project"), "Les Vagues acte 2");

      expect(
        ocptSafeFileNameOf(r'a\b/c:d*e?f"g<h>i|j', fallback: "project"),
        "a b c d e f g h i j",
      );
    });

    test("strips control characters", () {
      expect(ocptSafeFileNameOf("Les\x00Vagues\x7F", fallback: "project"), "Les Vagues");
    });

    test("trims leading and trailing whitespace and dots", () {
      expect(ocptSafeFileNameOf("  .Les Vagues.  ", fallback: "project"), "Les Vagues");
    });

    test("returns the fallback when nothing usable is left", () {
      expect(ocptSafeFileNameOf("", fallback: "project"), "project");
      expect(ocptSafeFileNameOf("...", fallback: "project"), "project");
      expect(ocptSafeFileNameOf("   ", fallback: "project"), "project");
      expect(ocptSafeFileNameOf(r'\/:*?"<>|', fallback: "project"), "project");
    });

    test("caps the length, and never leaves a trailing separator at the cut", () {
      final tooLong = "A${' word' * 40}"; // far past ocptSafeFileNameMaxLength once collapsed
      final result = ocptSafeFileNameOf(tooLong, fallback: "project");

      expect(result.length, lessThanOrEqualTo(ocptSafeFileNameMaxLength));
      expect(result, isNot(endsWith(" ")));
      expect(result, isNot(endsWith(".")));
    });

    test("caps exactly at the limit landing mid-word, without crashing on the boundary", () {
      final exactlyAtLimit = "x" * ocptSafeFileNameMaxLength;
      final overByOne = "${"x" * ocptSafeFileNameMaxLength}y";

      expect(ocptSafeFileNameOf(exactlyAtLimit, fallback: "project"), exactlyAtLimit);
      expect(
        ocptSafeFileNameOf(overByOne, fallback: "project").length,
        ocptSafeFileNameMaxLength,
      );
    });
  });
}
