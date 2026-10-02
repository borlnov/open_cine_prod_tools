// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_character_colour.dart';

void main() {
  group("ocptFloorPlanCharacterColourOf", () {
    test("the same name always yields the same colour", () {
      expect(ocptFloorPlanCharacterColourOf("Sam"), ocptFloorPlanCharacterColourOf("Sam"));
    });

    test("is case- and whitespace-insensitive", () {
      final reference = ocptFloorPlanCharacterColourOf("sam");
      expect(ocptFloorPlanCharacterColourOf("Sam"), reference);
      expect(ocptFloorPlanCharacterColourOf("SAM"), reference);
      expect(ocptFloorPlanCharacterColourOf(" sam "), reference);
    });

    test("different names generally yield different colours", () {
      final colours = {
        for (final name in ["Sam", "Alex", "Jordan", "Casey", "Riley", "Morgan", "Taylor", "Drew"])
          name: ocptFloorPlanCharacterColourOf(name),
      };

      expect(colours.values.toSet().length, greaterThan(1));
    });

    test("an empty name is handled deterministically rather than throwing", () {
      expect(() => ocptFloorPlanCharacterColourOf(""), returnsNormally);
      expect(ocptFloorPlanCharacterColourOf(""), ocptFloorPlanCharacterColourOf(""));
    });

    test("a whitespace-only name is handled deterministically too", () {
      expect(() => ocptFloorPlanCharacterColourOf("   "), returnsNormally);
      expect(ocptFloorPlanCharacterColourOf("   "), ocptFloorPlanCharacterColourOf(""));
    });

    test("every colour is fully opaque", () {
      final colour = ocptFloorPlanCharacterColourOf("Sam");
      expect(colour & 0xFF000000, 0xFF000000);
    });
  });
}
