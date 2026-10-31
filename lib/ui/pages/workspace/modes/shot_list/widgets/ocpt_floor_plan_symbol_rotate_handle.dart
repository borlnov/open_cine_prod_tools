// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_handle_dot.dart';

/// The selected symbol's own aim (rotate) handle, above its top edge. Drags are only *reported*,
/// with the pointer's **global** position: the handle's own local position is relative to its tiny
/// hit box, so the canvas converts it into its own coordinate space before computing a bearing.
class OcptFloorPlanSymbolRotateHandle extends StatelessWidget {
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

  /// Called with the pointer's global position on every frame of the drag.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanSymbolRotateHandle({
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

    final rotateLocalM = Offset(0, -(geometry.heightM / 2 + ocptFloorPlanRotateHandleGapM));
    final rotateScreen =
        centre + ocptFloorPlanRotateVector(rotateLocalM * pixelsPerMetre, geometry.rotationDeg);

    return Positioned(
      left: rotateScreen.dx - ocptFloorPlanHandleHitSize / 2,
      top: rotateScreen.dy - ocptFloorPlanHandleHitSize / 2,
      width: ocptFloorPlanHandleHitSize,
      height: ocptFloorPlanHandleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onDragStarted(),
        onPanUpdate: (details) => onDragUpdated(details.globalPosition),
        onPanEnd: (_) => onDragEnded(),
        child: OcptFloorPlanHandleDot(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}
