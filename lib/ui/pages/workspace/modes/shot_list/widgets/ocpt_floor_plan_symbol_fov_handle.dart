// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_handle_dot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// One of a camera symbol's own two field-of-view edge handles, at one far corner of its wedge
/// (drawn by `OcptFloorPlanCanvasPainter._paintCameraGlyph`, at the wedge's own resolved height):
/// dragging either narrows or widens [OcptFloorPlanSymbolShape.cameraFovWedgeDeg] — the wedge
/// stays symmetric around the symbol's own heading, so both handles always sit the same distance
/// from it, and always at the same height, since only the angle drag they carry ever changes.
/// [sign] picks the corner, `-1` for the left one and `1` for the right one.
///
/// Drags are only *reported*, with the pointer's **global** position, as for
/// `OcptFloorPlanSymbolRotateHandle`.
class OcptFloorPlanSymbolFovHandle extends StatelessWidget {
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

  /// Which corner of the wedge this handle sits on: `-1` for the left one, `1` for the right one.
  final double sign;

  /// Called with the wedge's current angle, in degrees, when a drag starts.
  final ValueChanged<double> onDragStarted;

  /// Called with the pointer's global position on every frame of the drag.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanSymbolFovHandle({
    super.key,
    required this.symbol,
    required this.liveOverride,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.sign,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
  });

  /// Build the floor plan symbol fov handle as a [Positioned].
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
    final isLiveOverride = override != null && override.symbolId == symbol.symbolId;
    final fovDeg = (isLiveOverride ? override.fovDeg : null) ?? symbol.cameraFovWedgeDeg!;
    final fovReachM = (isLiveOverride ? override.fovReachM : null) ?? symbol.cameraFovWedgeReachM!;
    final halfAngleRad = fovDeg * math.pi / 180 / 2;
    final wedgeHeightPx = fovReachM * pixelsPerMetre;
    final tipLocalPx = Offset(0, -symbol.heightM / 2 * pixelsPerMetre);

    final localPx =
        tipLocalPx + Offset(sign * wedgeHeightPx * math.tan(halfAngleRad), -wedgeHeightPx);
    final screen = centre + ocptFloorPlanRotateVector(localPx, geometry.rotationDeg);

    return Positioned(
      left: screen.dx - ocptFloorPlanHandleHitSize / 2,
      top: screen.dy - ocptFloorPlanHandleHitSize / 2,
      width: ocptFloorPlanHandleHitSize,
      height: ocptFloorPlanHandleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => onDragStarted(fovDeg),
        onPanUpdate: (details) => onDragUpdated(details.globalPosition),
        onPanEnd: (_) => onDragEnded(),
        child: OcptFloorPlanHandleDot(color: Theme.of(context).colorScheme.tertiary),
      ),
    );
  }
}
