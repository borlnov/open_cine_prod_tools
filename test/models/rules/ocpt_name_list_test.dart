// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_name_list.dart';

/// Run the tests of the name list rule.
void main() {
  group("ocptJoinNames", () {
    test("no name gives an empty string", () {
      expect(ocptJoinNames(const [], "and"), "");
    });

    test("one name is left alone", () {
      expect(ocptJoinNames(const ["Ada"], "and"), "Ada");
    });

    test("two names are joined by the conjunction alone", () {
      expect(ocptJoinNames(const ["Ada", "Bob"], "and"), "Ada and Bob");
    });

    test("three names or more get commas, then the conjunction without a comma", () {
      expect(ocptJoinNames(const ["Ada", "Bob", "Cy"], "et"), "Ada, Bob et Cy");
      expect(ocptJoinNames(const ["Ada", "Bob", "Cy", "Di"], "and"), "Ada, Bob, Cy and Di");
    });

    test("a blank or repeated name is dropped, the order of first occurrence kept", () {
      expect(ocptJoinNames(const ["Bob", " ", "Ada", "Bob"], "and"), "Bob and Ada");
      expect(ocptJoinNames(const ["", "Ada", "Ada"], "and"), "Ada");
    });
  });
}
