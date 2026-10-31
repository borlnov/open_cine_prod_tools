// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// The underlay's own visual: a real `OcptReferencedImage`, positioned and rotated to its current
/// frame, drawn behind the canvas's `CustomPaint` (so symbols draw over it) and taking no pointer
/// of its own — separate invisible handles (`OcptFloorPlanUnderlayMoveHandle` and
/// `OcptFloorPlanUnderlayResizeHandle`) handle its interaction, decoupling visual draw order from
/// hit-test order.
class OcptFloorPlanUnderlayVisual extends StatelessWidget {
  /// The set whose underlay is drawn.
  final OcptFloorPlanSet floorPlanSet;

  /// The underlay's own screen rect, un-rotated (its rotation is applied by the `Transform.rotate`
  /// wrapping the image).
  final Rect rect;

  /// Class constructor
  const OcptFloorPlanUnderlayVisual({super.key, required this.floorPlanSet, required this.rect});

  @override
  Widget build(BuildContext context) {
    final rotationDeg = floorPlanSet.underlayRotationDeg ?? 0;

    return IgnorePointer(
      child: Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Transform.rotate(
          angle: rotationDeg * math.pi / 180,
          child: OcptReferencedImage(
            path: floorPlanSet.underlayPath,
            fit: BoxFit.fill,
            fallbackBuilder: (context) =>
                ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
        ),
      ),
    );
  }
}
