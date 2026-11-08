// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// Run the tests of the field-of-view edge handle's drag.
void main() {
  const canvasSize = Size(800, 600);

  /// Drag the handle of [sign] side (1 clockwise, -1 anticlockwise) to [bearingOffsetDeg] off a
  /// camera aimed at [headingDeg] and get the resulting field of view.
  double fovAfterDrag(double headingDeg, double sign, double bearingOffsetDeg) {
    final override = OcptFloorPlanSymbolLiveOverride(
      symbolId: "camera-1",
      xM: 0,
      yM: 0,
      widthM: 1,
      heightM: 1,
      rotationDeg: headingDeg,
    );
    final centre = ocptFloorPlanScreenPointOf(
      xM: 0,
      yM: 0,
      canvasSize: canvasSize,
      zoom: 1,
      pan: Offset.zero,
    );
    final bearingRad = (headingDeg + sign * bearingOffsetDeg) * math.pi / 180;
    final pointer = centre + Offset(math.sin(bearingRad), -math.cos(bearingRad)) * 150;

    return ocptFloorPlanSymbolFovDraggedTo(
      override: override,
      localPosition: pointer,
      canvasSize: canvasSize,
      zoom: 1,
      pan: Offset.zero,
    ).fovDeg!;
  }

  for (final heading in [0.0, 90.0, 180.0, 270.0, 330.0]) {
    for (final sign in [1.0, -1.0]) {
      test("heading $heading, handle $sign: pointer 25 degrees off gives a 50 degrees field", () {
        expect(fovAfterDrag(heading, sign, 25), closeTo(50, 1e-6));
      });
    }
  }

  test("widening to 40 degrees off the heading gives 80 degrees on a wrapped heading", () {
    expect(fovAfterDrag(300, 1, 40), closeTo(80, 1e-6));
    expect(fovAfterDrag(300, -1, 40), closeTo(80, 1e-6));
  });
}
