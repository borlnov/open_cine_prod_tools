// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_camera_label.dart';

void main() {
  group("ocptFloorPlanCameraLabelOf", () {
    test("rank 0 carries no letter", () {
      expect(ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 0), "3");
    });

    test("rank 1 is the first letter", () {
      expect(ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 1), "3A");
    });

    test("rank 2 is the second letter", () {
      expect(ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 2), "3B");
    });

    test("a negative rank is treated as no letter", () {
      expect(ocptFloorPlanCameraLabelOf(shotRank: 12, cameraRank: -1), "12");
    });

    test("carries whichever shot rank it is given", () {
      expect(ocptFloorPlanCameraLabelOf(shotRank: 1, cameraRank: 0), "1");
      expect(ocptFloorPlanCameraLabelOf(shotRank: 42, cameraRank: 0), "42");
    });

    test("wraps past Z into a second letter, spreadsheet-column style", () {
      expect(ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 26), "3Z");
      expect(ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 27), "3AA");
    });
  });
}
