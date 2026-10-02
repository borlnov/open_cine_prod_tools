// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

void main() {
  group("ocptFloorPlanDefaultFootprintM", () {
    test("a character's default footprint is 0.5 m, the implicit ruler", () {
      expect(
        ocptFloorPlanDefaultFootprintM(OcptFloorPlanLayer.characters),
        ocptFloorPlanCharacterFootprintM,
      );
      expect(ocptFloorPlanCharacterFootprintM, 0.5);
    });

    test("every layer has a defined, positive default footprint", () {
      for (final layer in OcptFloorPlanLayer.values) {
        expect(ocptFloorPlanDefaultFootprintM(layer), greaterThan(0));
      }
    });
  });

  group("metres <-> pixels", () {
    test("pixels per metre scale linearly with zoom", () {
      expect(ocptFloorPlanPixelsPerMetreAt(1), ocptFloorPlanBasePixelsPerMetre);
      expect(ocptFloorPlanPixelsPerMetreAt(2), ocptFloorPlanBasePixelsPerMetre * 2);
      expect(ocptFloorPlanPixelsPerMetreAt(0.5), ocptFloorPlanBasePixelsPerMetre * 0.5);
    });

    test("metres to pixels and back round-trips", () {
      const zoom = 1.3;
      const metres = 2.4;
      final pixels = ocptFloorPlanMetresToPixels(metres: metres, zoom: zoom);
      final backToMetres = ocptFloorPlanPixelsToMetres(pixels: pixels, zoom: zoom);

      expect(backToMetres, closeTo(metres, 1e-9));
    });
  });

  group("ocptFloorPlanDistanceM", () {
    test("the distance between a point and itself is zero", () {
      expect(ocptFloorPlanDistanceM(x1M: 1, y1M: 1, x2M: 1, y2M: 1), 0);
    });

    test("a 3-4-5 triangle measures 5", () {
      expect(ocptFloorPlanDistanceM(x1M: 0, y1M: 0, x2M: 3, y2M: 4), 5);
    });
  });

  group("ocptFloorPlanScaleBarLengthM", () {
    test("picks a round 1-2-5 length whose pixel span does not exceed the target", () {
      // At the base zoom (48 px/m), the default 96 px target rough-measures 2 m exactly.
      expect(ocptFloorPlanScaleBarLengthM(zoom: 1), 2);
    });

    test("represents more metres as the canvas zooms out (fewer pixels per metre)", () {
      // Zooming out means each metre draws smaller, so the same on-screen bar width has to stand
      // for more metres of the real décor.
      final atFullZoom = ocptFloorPlanScaleBarLengthM(zoom: 1);
      final zoomedOut = ocptFloorPlanScaleBarLengthM(zoom: 0.1);

      expect(zoomedOut, greaterThan(atFullZoom));
    });

    test("never exceeds the target pixel length once converted back", () {
      for (final zoom in <double>[0.1, 0.3, 0.5, 1, 2, 5, 10]) {
        final lengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);
        final pixels = ocptFloorPlanMetresToPixels(metres: lengthM, zoom: zoom);
        expect(pixels, lessThanOrEqualTo(96.001));
      }
    });

    test("only ever returns a 1-2-5 (decade) round number", () {
      for (final zoom in <double>[0.07, 0.2, 0.9, 3, 17]) {
        final lengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);

        // Normalise to a single significant digit in [1, 10) and check it is 1, 2 or 5.
        var normalised = lengthM;
        while (normalised >= 10) {
          normalised /= 10;
        }
        while (normalised < 1) {
          normalised *= 10;
        }
        final isNiceNumber =
            (normalised - 1).abs() < 0.01 ||
            (normalised - 2).abs() < 0.01 ||
            (normalised - 5).abs() < 0.01;
        expect(isNiceNumber, isTrue, reason: "$lengthM (zoom $zoom) normalises to $normalised");
      }
    });
  });
}
