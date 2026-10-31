// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_handle_dot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// The selected symbol's own resize handle, on the bottom-right corner of its footprint. Drags are
/// only *reported*: the canvas owns the live geometry, and settles it into one write when the drag
/// ends. A camera has none: its own footprint is a fixed drawing convention, never a real-world
/// dimension.
class OcptFloorPlanSymbolResizeHandle extends StatelessWidget {
  /// The selected symbol these handles belong to.
  final OcptFloorPlanSymbolShape symbol;

  /// The live geometry of the symbol being dragged, or null while none is — ignored when it names
  /// another symbol.
  final OcptFloorPlanSymbolLiveOverride? liveOverride;

  /// The size of the canvas the symbol is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// Called when a drag starts.
  final VoidCallback onDragStarted;

  /// Called with the pointer's delta on every frame of the drag.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanSymbolResizeHandle({
    super.key,
    required this.symbol,
    required this.liveOverride,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final geometry = ocptFloorPlanSymbolGeometryOf(symbol, liveOverride);
    final centre = ocptFloorPlanScreenPointOf(
      xM: geometry.xM,
      yM: geometry.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);

    final resizeLocal = Offset(geometry.widthM / 2, geometry.heightM / 2);
    final resizeScreen =
        centre + ocptFloorPlanRotateVector(resizeLocal * pixelsPerMetre, geometry.rotationDeg);

    return Positioned(
      left: resizeScreen.dx - ocptFloorPlanHandleHitSize / 2,
      top: resizeScreen.dy - ocptFloorPlanHandleHitSize / 2,
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
}
