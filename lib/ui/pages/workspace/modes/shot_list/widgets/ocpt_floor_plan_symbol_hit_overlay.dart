// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

/// One symbol's own invisible move + select overlay, rotated to match its own drawn shape.
///
/// Dragging is withheld ([canDrag] false) whenever the canvas says the symbol is locked under the
/// current focus or under a read-only preview. Double-clicking a ghost calls
/// [onGhostShotFocusRequested] with its own shot id, focusing it. Taps and drags are only
/// *reported*: the canvas owns what they mean.
class OcptFloorPlanSymbolHitOverlay extends StatelessWidget {
  /// The symbol this overlay covers.
  final OcptFloorPlanSymbolShape symbol;

  /// The size of the canvas the symbol is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// The live geometry of the symbol being dragged, or of the one a pending scope decision holds
  /// in place, or null while neither is — ignored when it names another symbol.
  final OcptFloorPlanSymbolLiveOverride? liveOverride;

  /// Whether this symbol may be dragged.
  final bool canDrag;

  /// Called when the symbol is tapped.
  final VoidCallback onTap;

  /// Called with the id of the shot a double-clicked ghost belongs to, or null while withheld.
  final ValueChanged<String>? onGhostShotFocusRequested;

  /// Called when a drag starts.
  final VoidCallback onDragStarted;

  /// Called with the pointer's delta on every frame of the drag, in the symbol's own rotated
  /// frame.
  final ValueChanged<Offset> onDragUpdated;

  /// Called when the drag ends.
  final VoidCallback onDragEnded;

  /// Class constructor
  const OcptFloorPlanSymbolHitOverlay({
    super.key,
    required this.symbol,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.liveOverride,
    required this.canDrag,
    required this.onTap,
    required this.onGhostShotFocusRequested,
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
    final widthPx = geometry.widthM * pixelsPerMetre;
    final heightPx = geometry.heightM * pixelsPerMetre;
    final shotId = symbol.shotId;

    return Positioned(
      left: centre.dx - widthPx / 2,
      top: centre.dy - heightPx / 2,
      width: widthPx,
      height: heightPx,
      child: Transform.rotate(
        angle: geometry.rotationDeg * math.pi / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: onTap,
          onDoubleTap: symbol.isGhost && shotId != null
              ? () => onGhostShotFocusRequested?.call(shotId)
              : null,
          onPanStart: !canDrag ? null : (_) => onDragStarted(),
          onPanUpdate: !canDrag ? null : (details) => onDragUpdated(details.delta),
          onPanEnd: !canDrag ? null : (_) => onDragEnded(),
        ),
      ),
    );
  }
}
