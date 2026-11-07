// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

/// The selected arrow's own small straighten button, drawn next to its midpoint handle while it
/// already carries a curve — alongside dragging the handle back onto the straight line. It is
/// reversible, so it only ever calls [onStraightenRequested] straight away.
class OcptFloorPlanArrowStraightenHandle extends StatelessWidget {
  /// The selected arrow, which must already carry a curve.
  final OcptFloorPlanArrowShape arrow;

  /// The size of the canvas the arrow is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// Called when the button is tapped.
  final VoidCallback onStraightenRequested;

  /// Class constructor
  const OcptFloorPlanArrowStraightenHandle({
    super.key,
    required this.arrow,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.onStraightenRequested,
  });

  /// Build the floor plan arrow straighten handle as a [Positioned].
  @override
  Widget build(BuildContext context) {
    final handleScreen = ocptFloorPlanScreenPointOf(
      xM: arrow.ctrlXM ?? (arrow.fromXM + arrow.toXM) / 2,
      yM: arrow.ctrlYM ?? (arrow.fromYM + arrow.toYM) / 2,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final theme = Theme.of(context);

    return Positioned(
      left: handleScreen.dx + ocptFloorPlanHandleHitSize,
      top: handleScreen.dy - ocptFloorPlanHandleHitSize,
      child: Tooltip(
        message: Tr.of(context).shotListFloorPlanStraightenArrowAction,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onStraightenRequested,
          child: Container(
            width: ocptFloorPlanHandleHitSize,
            height: ocptFloorPlanHandleHitSize,
            decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
            child: Icon(Icons.straighten, size: 12, color: theme.colorScheme.onSecondary),
          ),
        ),
      ),
    );
  }
}
