// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';

/// The underlay's own invisible move handle, covering its whole screen rect and rotated with it,
/// positioned before the symbol overlays in the canvas's own stack so a click landing on a symbol
/// drawn over the underlay hits that symbol first.
///
/// Drags are only *reported*: the canvas owns the live frame, and settles it into one write when
/// the drag ends.
class OcptFloorPlanUnderlayMoveHandle extends StatelessWidget {
  /// The set whose underlay is moved, which supplies the rotation the handle is drawn with.
  final OcptFloorPlanSet floorPlanSet;

  /// The underlay's own screen rect, un-rotated.
  final Rect rect;

  /// Called when a drag starts.
  final VoidCallback onDragStarted;

  /// Called with the pointer's delta on every frame of the drag, in the underlay's own rotated
  /// frame.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanUnderlayMoveHandle({
    super.key,
    required this.floorPlanSet,
    required this.rect,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) => Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: Transform.rotate(
      angle: (floorPlanSet.underlayRotationDeg ?? 0) * math.pi / 180,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => onDragStarted(),
        onPanUpdate: (details) => onDragUpdated(details.delta),
        onPanEnd: (_) => onDragEnded(),
      ),
    ),
  );
}
