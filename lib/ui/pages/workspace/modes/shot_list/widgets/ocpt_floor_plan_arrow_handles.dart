// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_arrow_midpoint_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_arrow_straighten_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_drag_controller.dart';

/// The selected arrow's own midpoint handle (drag to bend, drop to write one row) and, while it
/// already carries a curve, its neighbouring straighten button, layered over the canvas.
///
/// Drags go through [drag], which owns the live control point, and end by calling [onDragEnded],
/// which settles the control point into one write; the straighten button calls
/// [onStraightenRequested] straight away.
class OcptFloorPlanArrowHandles extends StatelessWidget {
  /// The selected arrow.
  final OcptFloorPlanArrowShape arrow;

  /// The size of the canvas the arrow is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// The canvas's drag state, which the midpoint handle starts, updates and reads.
  final OcptFloorPlanCanvasDragController drag;

  /// Called when the midpoint drag ends, to settle its control point.
  final VoidCallback onDragEnded;

  /// Called when the straighten button is tapped.
  final VoidCallback onStraightenRequested;

  /// Class constructor
  const OcptFloorPlanArrowHandles({
    super.key,
    required this.arrow,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.drag,
    required this.onDragEnded,
    required this.onStraightenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isDragged = drag.draggedArrowId == arrow.arrowId;

    return Positioned.fill(
      child: Stack(
        children: [
          OcptFloorPlanArrowMidpointHandle(
            arrow: arrow,
            liveCtrl: isDragged ? drag.liveArrowCtrl : null,
            canvasSize: canvasSize,
            zoom: zoom,
            pan: pan,
            onDragStarted: (ctrlXM, ctrlYM) =>
                drag.beginArrowCurveDrag(arrow.arrowId, ctrlXM, ctrlYM),
            onDragUpdated: (delta) => drag.updateArrowCurveDrag(arrow.arrowId, delta, zoom),
            onDragEnded: onDragEnded,
          ),
          if (arrow.ctrlXM != null && !(drag.liveArrowCtrl != null && isDragged))
            OcptFloorPlanArrowStraightenHandle(
              arrow: arrow,
              canvasSize: canvasSize,
              zoom: zoom,
              pan: pan,
              onStraightenRequested: onStraightenRequested,
            ),
        ],
      ),
    );
  }
}
