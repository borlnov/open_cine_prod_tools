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

/// A camera symbol's own field-of-view **tip** handle, straight ahead of its lens at the middle of
/// the wedge's own far chord — its own axial height/depth
/// ([OcptFloorPlanSymbolShape.cameraFovWedgeReachM]) along the heading — dragging it changes how
/// deep the wedge reaches, never its angle (the two edge handles' own job,
/// `OcptFloorPlanSymbolFovHandle`), which stays exactly where it was: the two corners move together
/// with this handle since they share the very same height, but their own spread apart (the angle)
/// is untouched.
///
/// Drags are only *reported*, with the pointer's **global** position, as for
/// `OcptFloorPlanSymbolRotateHandle`.
class OcptFloorPlanSymbolFovReachHandle extends StatelessWidget {
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

  /// Called with the wedge's current reach, in metres, when a drag starts.
  final ValueChanged<double> onDragStarted;

  /// Called with the pointer's global position on every frame of the drag.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanSymbolFovReachHandle({
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

  /// Build the floor plan symbol fov reach handle as a [Positioned].
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

    final override = liveOverride;
    final fovReachM =
        (override != null && override.symbolId == symbol.symbolId ? override.fovReachM : null) ??
        symbol.cameraFovWedgeReachM!;
    final tipLocalPx = Offset(0, -symbol.heightM / 2 * pixelsPerMetre);
    final localPx = tipLocalPx + Offset(0, -fovReachM * pixelsPerMetre);
    final screen = centre + ocptFloorPlanRotateVector(localPx, geometry.rotationDeg);

    return Positioned(
      left: screen.dx - ocptFloorPlanHandleHitSize / 2,
      top: screen.dy - ocptFloorPlanHandleHitSize / 2,
      width: ocptFloorPlanHandleHitSize,
      height: ocptFloorPlanHandleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => onDragStarted(fovReachM),
        onPanUpdate: (details) => onDragUpdated(details.globalPosition),
        onPanEnd: (_) => onDragEnded(),
        child: OcptFloorPlanHandleDot(color: Theme.of(context).colorScheme.tertiary),
      ),
    );
  }
}
