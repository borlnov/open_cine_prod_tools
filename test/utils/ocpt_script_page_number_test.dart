// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_script_page_number.dart';

void main() {
  group("ocptScriptPageNumberLabelOf", () {
    test("the first script page is never numbered", () {
      expect(ocptScriptPageNumberLabelOf(1), isNull);
    });

    test("a page that precedes the first script page (a title page) is never numbered either", () {
      expect(ocptScriptPageNumberLabelOf(0), isNull);
    });

    test("every page from the second one onwards reads its number followed by a full stop", () {
      expect(ocptScriptPageNumberLabelOf(2), "2.");
      expect(ocptScriptPageNumberLabelOf(3), "3.");
      expect(ocptScriptPageNumberLabelOf(120), "120.");
    });
  });

  test("the page number sits half an inch below the page's top edge", () {
    // The header band, not the body's own top margin: the number stays there whatever margin the
    // page setup configures (see the constant's own doc comment).
    expect(ocptScriptPageNumberTopInches, 0.5);
  });
}
