// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/utils/ocpt_element_code.dart';

void main() {
  group("ocptElementCodePrefixOf", () {
    test("gives every category a distinct three-letter prefix", () {
      final prefixes = OcptElementCategory.values.map(ocptElementCodePrefixOf).toList();

      expect(prefixes.toSet(), hasLength(OcptElementCategory.values.length));
      for (final prefix in prefixes) {
        expect(prefix, matches(RegExp(r"^[A-Z]{3}$")));
      }
    });
  });

  group("ocptElementCodeOf", () {
    test("starts a category at 1", () {
      expect(
        ocptElementCodeOf(category: OcptElementCategory.prop, existingCodes: const []),
        "PRP-1",
      );
    });

    test("numbers within the category, not across the catalogue", () {
      expect(
        ocptElementCodeOf(
          category: OcptElementCategory.vehicle,
          existingCodes: const ["PRP-1", "PRP-2", "COS-1"],
        ),
        "VEH-1",
      );
    });

    test("continues from the highest number in use, not from how many there are", () {
      // `PRP-2` was deleted: handing its number out again would end the day with two `PRP-3`.
      expect(
        ocptElementCodeOf(
          category: OcptElementCategory.prop,
          existingCodes: const ["PRP-1", "PRP-3"],
        ),
        "PRP-4",
      );
    });

    test("ignores codes nobody generated", () {
      expect(
        ocptElementCodeOf(
          category: OcptElementCategory.prop,
          existingCodes: const ["bureau", "PRP-2 bis", "prp-9", "", "PRP-0"],
        ),
        "PRP-1",
      );
    });

    test("reads a code with surrounding whitespace", () {
      expect(
        ocptElementCodeOf(category: OcptElementCategory.prop, existingCodes: const [" PRP-7 "]),
        "PRP-8",
      );
    });
  });

  group("ocptElementCodeIsGeneratedFor", () {
    test("recognises its own output", () {
      expect(
        ocptElementCodeIsGeneratedFor(code: "PRP-4", category: OcptElementCategory.prop),
        isTrue,
      );
    });

    test("refuses the code of another category", () {
      expect(
        ocptElementCodeIsGeneratedFor(code: "PRP-4", category: OcptElementCategory.vehicle),
        isFalse,
      );
    });

    test("refuses a code somebody typed", () {
      for (final code in const ["4L jaune", "PRP-4 bis", "PRP4", "", "  "]) {
        expect(
          ocptElementCodeIsGeneratedFor(code: code, category: OcptElementCategory.prop),
          isFalse,
          reason: "$code is not a generated code",
        );
      }
    });
  });
}
