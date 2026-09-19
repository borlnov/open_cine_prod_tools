// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_storyboard_aspect_ratio.dart';

void main() {
  group("ocptAspectRatioOf", () {
    test("parses a colon-separated scope ratio", () {
      expect(ocptAspectRatioOf("2.39:1"), closeTo(2.39, 1e-9));
    });

    test("parses a plain 16:9 ratio", () {
      expect(ocptAspectRatioOf("16:9"), closeTo(16 / 9, 1e-9));
    });

    test("parses a slash-separated ratio", () {
      expect(ocptAspectRatioOf("4/3"), closeTo(4 / 3, 1e-9));
    });

    test("parses a colon-separated 4:3 ratio", () {
      expect(ocptAspectRatioOf("4:3"), closeTo(4 / 3, 1e-9));
    });

    test("parses a ratio embedded in surrounding free text", () {
      expect(ocptAspectRatioOf("Anamorphic 2.39:1 · 4K"), closeTo(2.39, 1e-9));
    });

    test("parses a bare decimal already written as a ratio to 1", () {
      expect(ocptAspectRatioOf("1.85"), closeTo(1.85, 1e-9));
    });

    test("falls back to 16:9 when the text carries no ratio at all", () {
      expect(ocptAspectRatioOf("4K · 25 fps"), closeTo(ocptStoryboardFallbackAspectRatio, 1e-9));
      expect(ocptAspectRatioOf(""), closeTo(16 / 9, 1e-9));
      expect(ocptAspectRatioOf("anamorphic"), closeTo(16 / 9, 1e-9));
    });

    test("does not mistake a frame rate for a ratio", () {
      // A decimal frame rate carries a decimal point but sits far outside any plausible cinema
      // aspect ratio, so it must not be picked up as one.
      expect(ocptAspectRatioOf("23.976 fps"), closeTo(16 / 9, 1e-9));
    });
  });
}
