// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_symbol_drag_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_drag_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_delete_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_fov_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_fov_reach_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_resize_handle.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_rotate_handle.dart';

/// The selected symbol's own resize, aim (rotate) and — for a camera whose own field-of-view wedge
/// is drawn — field-of-view handles, plus its delete button, layered over the canvas.
///
/// Which of them exist is the canvas's call ([canResize] and the like: a write withheld by the
/// canvas's own callbacks, a camera having no resize handle since its footprint is a fixed drawing
/// convention). Drags go through [drag], which owns the live geometry, and end by calling
/// [onDragEnded], which settles the geometry into one write.
class OcptFloorPlanSymbolHandles extends StatelessWidget {
  /// The selected symbol these handles belong to.
  final OcptFloorPlanSymbolShape symbol;

  /// The size of the canvas the symbol is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// The canvas's drag state, which the handles start, update and read.
  final OcptFloorPlanCanvasDragController drag;

  /// Converts a global pointer position into the canvas's own coordinate space.
  final Offset Function(Offset globalPosition) resolveLocalPosition;

  /// Whether `Shift` is held, which snaps an aim drag to fixed steps.
  final bool Function() isSnapping;

  /// Whether the symbol has a resize handle.
  final bool canResize;

  /// Whether the symbol has an aim handle.
  final bool canRotate;

  /// Whether the symbol has its two field-of-view edge handles.
  final bool canChangeFov;

  /// Whether the symbol has its field-of-view tip handle.
  final bool canChangeFovReach;

  /// Called when the delete button is tapped, or null while withheld.
  final VoidCallback? onDeleteRequested;

  /// Called when a drag ends, to settle its geometry.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanSymbolHandles({
    super.key,
    required this.symbol,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.drag,
    required this.resolveLocalPosition,
    required this.isSnapping,
    required this.canResize,
    required this.canRotate,
    required this.canChangeFov,
    required this.canChangeFovReach,
    required this.onDeleteRequested,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final liveOverride = drag.liveOverride;
    final onDeleteRequested = this.onDeleteRequested;

    return Positioned.fill(
      child: Stack(
        children: [
          if (canResize)
            OcptFloorPlanSymbolResizeHandle(
              symbol: symbol,
              liveOverride: liveOverride,
              canvasSize: canvasSize,
              zoom: zoom,
              pan: pan,
              onDragStarted: () => drag.beginSymbolDrag(OcptFloorPlanSymbolDragKind.resize, symbol),
              onDragUpdated: (delta) => drag.updateSymbolDrag(symbol.symbolId, delta, zoom),
              onDragEnded: onDragEnded,
            ),
          if (canRotate)
            OcptFloorPlanSymbolRotateHandle(
              symbol: symbol,
              liveOverride: liveOverride,
              canvasSize: canvasSize,
              zoom: zoom,
              pan: pan,
              onDragStarted: () => drag.beginSymbolDrag(OcptFloorPlanSymbolDragKind.rotate, symbol),
              onDragUpdated: (globalPosition) => drag.updateRotateDrag(
                symbol.symbolId,
                resolveLocalPosition(globalPosition),
                canvasSize,
                zoom,
                pan,
                isSnapping: isSnapping(),
              ),
              onDragEnded: onDragEnded,
            ),
          if (canChangeFov)
            for (final sign in const [-1.0, 1.0])
              OcptFloorPlanSymbolFovHandle(
                symbol: symbol,
                liveOverride: liveOverride,
                canvasSize: canvasSize,
                zoom: zoom,
                pan: pan,
                sign: sign,
                onDragStarted: (fovDeg) =>
                    drag.beginSymbolDrag(OcptFloorPlanSymbolDragKind.fov, symbol, fovDeg: fovDeg),
                onDragUpdated: (globalPosition) => drag.updateFovDrag(
                  symbol.symbolId,
                  resolveLocalPosition(globalPosition),
                  canvasSize,
                  zoom,
                  pan,
                ),
                onDragEnded: onDragEnded,
              ),
          if (canChangeFovReach)
            OcptFloorPlanSymbolFovReachHandle(
              symbol: symbol,
              liveOverride: liveOverride,
              canvasSize: canvasSize,
              zoom: zoom,
              pan: pan,
              onDragStarted: (fovReachM) => drag.beginSymbolDrag(
                OcptFloorPlanSymbolDragKind.fovReach,
                symbol,
                fovReachM: fovReachM,
              ),
              onDragUpdated: (globalPosition) => drag.updateFovReachDrag(
                symbol.symbolId,
                resolveLocalPosition(globalPosition),
                canvasSize,
                zoom,
                pan,
              ),
              onDragEnded: onDragEnded,
            ),
          if (onDeleteRequested != null)
            OcptFloorPlanSymbolDeleteHandle(
              symbol: symbol,
              liveOverride: liveOverride,
              canvasSize: canvasSize,
              zoom: zoom,
              pan: pan,
              onDeleteRequested: onDeleteRequested,
            ),
        ],
      ),
    );
  }
}
