// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_gestures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

/// The selected symbol's own small delete button, just outside its top-right corner. It only
/// *asks*, through [onDeleteRequested]: the confirmation is the mode's.
class OcptFloorPlanSymbolDeleteHandle extends StatelessWidget {
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

  /// Called when the button is tapped.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptFloorPlanSymbolDeleteHandle({
    super.key,
    required this.symbol,
    required this.liveOverride,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.onDeleteRequested,
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
    final theme = Theme.of(context);

    return Positioned(
      left: resizeScreen.dx + ocptFloorPlanHandleHitSize,
      top: centre.dy - geometry.heightM / 2 * pixelsPerMetre - ocptFloorPlanHandleHitSize,
      child: Tooltip(
        message: Tr.of(context).shotListFloorPlanDeleteSymbolAction,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDeleteRequested,
          child: Container(
            width: ocptFloorPlanHandleHitSize,
            height: ocptFloorPlanHandleHitSize,
            decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
            child: Icon(Icons.close, size: 12, color: theme.colorScheme.onError),
          ),
        ),
      ),
    );
  }
}
