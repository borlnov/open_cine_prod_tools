// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

/// The selected arrow's own small delete button, just beside its tip. It only *asks*, through
/// [onDeleteRequested]: the confirmation is the mode's.
class OcptFloorPlanArrowDeleteHandle extends StatelessWidget {
  /// The selected arrow.
  final OcptFloorPlanArrowShape arrow;

  /// The size of the canvas the arrow is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// Called when the button is tapped.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptFloorPlanArrowDeleteHandle({
    super.key,
    required this.arrow,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.onDeleteRequested,
  });

  /// Build the floor plan arrow delete handle as a [Positioned].
  @override
  Widget build(BuildContext context) {
    final tipScreen = ocptFloorPlanScreenPointOf(
      xM: arrow.toXM,
      yM: arrow.toYM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final theme = Theme.of(context);

    return Positioned(
      left: tipScreen.dx + ocptFloorPlanHandleHitSize,
      top: tipScreen.dy - ocptFloorPlanHandleHitSize,
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
