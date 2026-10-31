// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

/// The selected override's own `Restore` handle — the one affordance that reaches a live override
/// or a hidden override's own ghost even though the canvas locks both against dragging. Drawn just
/// outside [symbol]'s own top-left corner (mirroring the delete handle's own top-right one),
/// reversible — no confirmation — so it only ever calls [onRestoreRequested] straight away.
class OcptFloorPlanSymbolRestoreHandle extends StatelessWidget {
  /// The selected override.
  final OcptFloorPlanSymbolShape symbol;

  /// The size of the canvas the symbol is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// Called when the button is tapped.
  final VoidCallback onRestoreRequested;

  /// Class constructor
  const OcptFloorPlanSymbolRestoreHandle({
    super.key,
    required this.symbol,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.onRestoreRequested,
  });

  @override
  Widget build(BuildContext context) {
    final centre = ocptFloorPlanScreenPointOf(
      xM: symbol.xM,
      yM: symbol.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final resizeLocal = Offset(symbol.widthM / 2, symbol.heightM / 2);
    final resizeScreen =
        centre + ocptFloorPlanRotateVector(resizeLocal * pixelsPerMetre, symbol.rotationDeg);

    final tr = Tr.of(context);
    final theme = Theme.of(context);
    return Positioned(
      left: resizeScreen.dx - ocptFloorPlanHandleHitSize * 2,
      top: centre.dy - symbol.heightM / 2 * pixelsPerMetre - ocptFloorPlanHandleHitSize,
      child: Tooltip(
        message: symbol.overrideLevel == OcptFloorPlanOverrideLevel.shot
            ? tr.shotListFloorPlanRestoreShotOverrideAction
            : tr.shotListFloorPlanRestoreOverrideAction,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onRestoreRequested,
          child: Container(
            width: ocptFloorPlanHandleHitSize,
            height: ocptFloorPlanHandleHitSize,
            decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
            child: Icon(Icons.restore, size: 12, color: theme.colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
