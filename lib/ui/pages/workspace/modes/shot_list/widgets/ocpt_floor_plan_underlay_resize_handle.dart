// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_handle_dot.dart';

/// The underlay's own invisible resize handle, on the bottom-right corner of its screen rect.
///
/// Drags are only *reported*: the canvas owns the live frame, and settles it into one write when
/// the drag ends.
class OcptFloorPlanUnderlayResizeHandle extends StatelessWidget {
  /// The underlay's own screen rect, un-rotated.
  final Rect rect;

  /// Called when a drag starts.
  final VoidCallback onDragStarted;

  /// Called with the pointer's delta on every frame of the drag.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanUnderlayResizeHandle({
    super.key,
    required this.rect,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
  });

  /// Build the floor plan underlay resize handle as a [Positioned].
  @override
  Widget build(BuildContext context) => Positioned(
    left: rect.right - ocptFloorPlanHandleHitSize / 2,
    top: rect.bottom - ocptFloorPlanHandleHitSize / 2,
    width: ocptFloorPlanHandleHitSize,
    height: ocptFloorPlanHandleHitSize,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (_) => onDragStarted(),
      onPanUpdate: (details) => onDragUpdated(details.delta),
      onPanEnd: (_) => onDragEnded(),
      child: OcptFloorPlanHandleDot(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
