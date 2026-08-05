// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_set_code.dart';

void main() {
  group("ocptSetCodeOf", () {
    test("starts at A when the project holds no set", () {
      expect(ocptSetCodeOf(existingCodes: const []), "A");
    });

    test("counts on from the codes already in use", () {
      expect(ocptSetCodeOf(existingCodes: const ["A", "B", "C"]), "D");
    });

    test("counts from the highest code rather than from how many there are", () {
      // `B` was deleted: handing `C` to the next set would end the day with two of them.
      expect(ocptSetCodeOf(existingCodes: const ["A", "C"]), "D");
    });

    test("rolls over into two letters past Z", () {
      expect(ocptSetCodeOf(existingCodes: const ["Z"]), "AA");
      expect(ocptSetCodeOf(existingCodes: const ["AA"]), "AB");
      expect(ocptSetCodeOf(existingCodes: const ["AZ"]), "BA");
      expect(ocptSetCodeOf(existingCodes: const ["ZZ"]), "AAA");
    });

    test("numbers around whatever it doesn't recognise", () {
      // Everything a build where the field was typed by hand could have left behind: a word, a
      // code of the element shape, lower case, digits, nothing at all. None of them reserves a
      // rank, so a project full of them still starts its generated codes at A.
      expect(
        ocptSetCodeOf(existingCodes: const ["CUISINE", "EXT-1", "b", "2", "", "  ", "AAAA"]),
        "A",
      );
    });

    test("reads a code with surrounding whitespace", () {
      expect(ocptSetCodeOf(existingCodes: const [" C "]), "D");
    });
  });
}
