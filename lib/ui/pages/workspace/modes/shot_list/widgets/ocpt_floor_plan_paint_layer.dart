// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// The layer of the floor plan canvas that draws the plan itself: a [CustomPaint] of
/// [OcptFloorPlanCanvasPainter], coloured from the theme and worded through `Tr`, on a layer of its
/// own.
///
/// The plan repaints on every pan, zoom and drag frame, and the widgets stacked over it do not
/// repaint with it, hence the [RepaintBoundary].
class OcptFloorPlanPaintLayer extends StatelessWidget {
  /// The sheet to draw.
  final OcptFloorPlanSheet sheet;

  /// The size of the canvas the sheet is drawn on.
  final Size canvasSize;

  /// The current zoom of the canvas.
  final double zoom;

  /// The current pan of the canvas.
  final Offset pan;

  /// The id of the symbol the canvas has selected, or null when none is.
  final String? selectedSymbolId;

  /// The selected symbol as [sheet] draws it, or null when none is selected or the sheet does not
  /// hold it.
  final OcptFloorPlanSymbolShape? selectedSymbol;

  /// The id of the symbol an arrow in the making is anchored on, or null when there is none.
  final String? arrowAnchorSymbolId;

  /// The live override of a symbol being dragged or waiting for its scope answer, or null.
  final OcptFloorPlanSymbolLiveOverride? liveOverride;

  /// The opacity the onion-skin ghosts are drawn with.
  final double onionSkinOpacity;

  /// Whether the metrics of the selected symbol are drawn.
  final bool isMetricsShown;

  /// Class constructor
  const OcptFloorPlanPaintLayer({
    super.key,
    required this.sheet,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.selectedSymbolId,
    required this.selectedSymbol,
    required this.arrowAnchorSymbolId,
    required this.liveOverride,
    required this.onionSkinOpacity,
    required this.isMetricsShown,
  });

  /// Build the plan, with its scale bar and its metric lines.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final barLengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);

    return RepaintBoundary(
      child: CustomPaint(
        size: canvasSize,
        painter: OcptFloorPlanCanvasPainter(
          sheet: sheet,
          zoom: zoom,
          pan: pan,
          selectedSymbolId: selectedSymbolId,
          arrowAnchorSymbolId: arrowAnchorSymbolId,
          liveOverride: liveOverride,
          symbolBorderColor: theme.colorScheme.outline,
          selectionColor: theme.colorScheme.primary,
          arrowAnchorColor: theme.colorScheme.secondary,
          arrowColor: theme.colorScheme.onSurface,
          labelTextColor: theme.colorScheme.onSurface,
          scaleColor: theme.colorScheme.onSurfaceVariant,
          scaleBarLabel: tr.shotListFloorPlanScaleBarLengthLabel(
            ocptFloorPlanScaleBarLengthLabelOf(barLengthM),
          ),
          onionSkinOpacity: onionSkinOpacity,
          metricLines: ocptFloorPlanMetricLinesOf(
            sheet: sheet,
            selected: selectedSymbol,
            isMetricsShown: isMetricsShown,
            tr: tr,
          ),
          metricLineColor: theme.colorScheme.tertiary,
        ),
      ),
    );
  }
}
