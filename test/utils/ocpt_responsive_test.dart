// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

void main() {
  group("ocptIsCompactWidth", () {
    test("classifies a width just below the breakpoint as compact", () {
      expect(ocptIsCompactWidth(815.9), isTrue);
    });

    test("classifies the breakpoint itself as not compact", () {
      expect(ocptIsCompactWidth(ocptCompactWidthBreakpoint), isFalse);
    });

    test("classifies zero as compact", () {
      expect(ocptIsCompactWidth(0), isTrue);
    });

    test("classifies a wide desktop width as not compact", () {
      expect(ocptIsCompactWidth(2000), isFalse);
    });
  });
}
