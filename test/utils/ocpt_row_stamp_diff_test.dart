// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_diff.dart';

void main() {
  group("ocptChangedColumnNames", () {
    test("names no column when the two maps agree on every value", () {
      final columnNames = ocptChangedColumnNames(
        from: const {"id": "shot-1", "framing": "wide", "lens": "35mm"},
        to: const {"id": "shot-1", "framing": "wide", "lens": "35mm"},
      );

      expect(columnNames, isEmpty);
    });

    test("names only the columns whose value actually differs", () {
      final columnNames = ocptChangedColumnNames(
        from: const {"id": "shot-1", "framing": "wide", "lens": "35mm"},
        to: const {"id": "shot-1", "framing": "close-up", "lens": "35mm"},
      );

      expect(columnNames, ["framing"]);
    });

    test("names every column whose value differs, in the order [to] carries them", () {
      final columnNames = ocptChangedColumnNames(
        from: const {"id": "shot-1", "framing": "wide", "lens": "35mm", "isDeleted": false},
        to: const {"id": "shot-1", "framing": "close-up", "lens": "50mm", "isDeleted": true},
      );

      expect(columnNames, ["framing", "lens", "isDeleted"]);
    });

    test("names a column [from] doesn't carry at all, as a fresh row's every column would", () {
      final columnNames = ocptChangedColumnNames(
        from: const {},
        to: const {"id": "shot-1", "framing": "wide"},
      );

      expect(columnNames, ["id", "framing"]);
    });
  });
}
