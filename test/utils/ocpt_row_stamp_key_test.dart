// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

void main() {
  group("ocptCompositeRowStampKey", () {
    test("joins the parts of a two-column key with the separator", () {
      expect(ocptCompositeRowStampKey(["shot-1", "CLARA"]), "shot-1/CLARA");
    });

    test("joins the parts of a key with more than two columns the same way", () {
      expect(ocptCompositeRowStampKey(["a", "b", "c"]), "a/b/c");
    });

    test("passes a single-part key through unchanged", () {
      expect(ocptCompositeRowStampKey(["shot-1"]), "shot-1");
    });

    test("keys two rows sharing a first part apart by their second part", () {
      final first = ocptCompositeRowStampKey(["shot-1", "CLARA"]);
      final second = ocptCompositeRowStampKey(["shot-1", "MARC"]);

      expect(first, isNot(second));
    });
  });
}
