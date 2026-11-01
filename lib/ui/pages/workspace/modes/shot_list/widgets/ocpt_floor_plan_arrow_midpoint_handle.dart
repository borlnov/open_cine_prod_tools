// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_handle_dot.dart';

/// The selected arrow's own midpoint handle: dragging it bends the arrow through a live bezier
/// control point, dropping it back onto the straight from-to line straightens it out again.
/// Drags are only *reported*: the canvas owns the live control point and settles it into one write
/// when the drag ends.
class OcptFloorPlanArrowMidpointHandle extends StatelessWidget {
  /// The selected arrow.
  final OcptFloorPlanArrowShape arrow;

  /// The arrow's live control point while its handle is being dragged, or null while it isn't.
  final ({double xM, double yM})? liveCtrl;

  /// The size of the canvas the arrow is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// Called with the handle's current control point, in metres, when a drag starts.
  final void Function(double xM, double yM) onDragStarted;

  /// Called with the pointer's delta on every frame of the drag.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanArrowMidpointHandle({
    super.key,
    required this.arrow,
    required this.liveCtrl,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
  });

  /// Build the floor plan arrow midpoint handle as a [Positioned].
  @override
  Widget build(BuildContext context) {
    final live = liveCtrl;
    final ctrlXM = live != null ? live.xM : (arrow.ctrlXM ?? (arrow.fromXM + arrow.toXM) / 2);
    final ctrlYM = live != null ? live.yM : (arrow.ctrlYM ?? (arrow.fromYM + arrow.toYM) / 2);
    final handleScreen = ocptFloorPlanScreenPointOf(
      xM: ctrlXM,
      yM: ctrlYM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );

    return Positioned(
      left: handleScreen.dx - ocptFloorPlanHandleHitSize / 2,
      top: handleScreen.dy - ocptFloorPlanHandleHitSize / 2,
      width: ocptFloorPlanHandleHitSize,
      height: ocptFloorPlanHandleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => onDragStarted(ctrlXM, ctrlYM),
        onPanUpdate: (details) => onDragUpdated(details.delta),
        onPanEnd: (_) => onDragEnded(),
        child: OcptFloorPlanHandleDot(color: Theme.of(context).colorScheme.tertiary),
      ),
    );
  }
}
