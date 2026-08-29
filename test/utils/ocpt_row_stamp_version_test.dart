// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_version.dart';

void main() {
  group("ocptNextRowStampVersion", () {
    test("starts a never-stamped column at version 1", () {
      expect(ocptNextRowStampVersion(null), 1);
    });

    test("bumps a stamped column strictly above the version it already carried", () {
      expect(ocptNextRowStampVersion(7), 8);
    });
  });

  group("ocptMergedRowStampFloor", () {
    test("adopts the incoming version when nothing is known yet", () {
      expect(ocptMergedRowStampFloor(null, 3), 3);
    });

    test("keeps the known version when it is already above the incoming one", () {
      expect(ocptMergedRowStampFloor(5, 3), 5);
    });

    test("raises the floor to the incoming version when it is the higher of the two", () {
      expect(ocptMergedRowStampFloor(3, 5), 5);
    });

    test("keeps the known version when the two agree exactly", () {
      expect(ocptMergedRowStampFloor(4, 4), 4);
    });
  });
}
