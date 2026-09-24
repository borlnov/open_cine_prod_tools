// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_camera_label.dart';

void main() {
  group("ocptFloorPlanCameraLabelOf", () {
    test("a solo camera carries no letter", () {
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 0, cameraCount: 1),
        "3",
      );
    });

    test("a lone camera with a zero count still carries no letter", () {
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 12, cameraRank: 0, cameraCount: 0),
        "12",
      );
    });

    test("two cameras are lettered starting at the first", () {
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 0, cameraCount: 2),
        "3A",
      );
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 1, cameraCount: 2),
        "3B",
      );
    });

    test("carries whichever shot rank it is given", () {
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 1, cameraRank: 0, cameraCount: 1),
        "1",
      );
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 42, cameraRank: 0, cameraCount: 1),
        "42",
      );
    });

    test("skips I and O, the slate convention", () {
      // A, B, C, D, E, F, G, H, then J (I skipped) is the 9th letter (rank 8).
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 8, cameraCount: 9),
        "3J",
      );
      // ... N, then P (O skipped) is the 14th letter (rank 13).
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 13, cameraCount: 14),
        "3P",
      );
    });

    test("wraps past Z into a second letter, spreadsheet-column style", () {
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 23, cameraCount: 24),
        "3Z",
      );
      expect(
        ocptFloorPlanCameraLabelOf(shotRank: 3, cameraRank: 24, cameraCount: 25),
        "3AA",
      );
    });
  });
}
