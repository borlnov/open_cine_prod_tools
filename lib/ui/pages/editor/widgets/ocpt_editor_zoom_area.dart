// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The area a zoomable page is shown in: it resolves the factor the page is typeset at from the
/// zoom and the width it is given, and hands it to [builder].
///
/// A step is the factor as it is. The "fit to width" mode is the factor that makes the sheet fill
/// this area's width, bounded to the zoom bounds, which follows the area as the window is
/// resized and is reported through [onFitFactorMeasured] (the factor a step starts from). With
/// [isZoomAvailable] false (a compact window) the page is at 100 % and [builder] is given no
/// stepping callback, so the wheel is left alone.
class OcptEditorZoomArea extends StatelessWidget {
  /// The zoom to resolve.
  final OcptPageZoom zoom;

  /// The page setup whose sheet is fitted in the "fit to width" mode.
  final OcptPageSetup pageSetup;

  /// Whether the page can be zoomed at all.
  final bool isZoomAvailable;

  /// Called with the factor the "fit to width" mode resolves to, once the frame is laid out and
  /// only while that mode is the zoom.
  final ValueChanged<double> onFitFactorMeasured;

  /// Called with the way to step the zoom (-1 out, 1 in).
  final ValueChanged<int> onZoomStepRequested;

  /// Builds the page from the factor it is typeset at and the callback of a wheel step, null when
  /// the page can't be zoomed.
  final Widget Function(double factor, ValueChanged<int>? onZoomStepRequested) builder;

  /// Class constructor
  const OcptEditorZoomArea({
    required this.zoom,
    required this.pageSetup,
    required this.isZoomAvailable,
    required this.onFitFactorMeasured,
    required this.onZoomStepRequested,
    required this.builder,
    super.key,
  });

  /// Build the zoom area as a [LayoutBuilder].
  ///
  /// The page is always built behind the same layout builder, whatever the zoom is: switching
  /// between a step and the "fit to width" mode must not change the shape of the tree, or the page
  /// below would be remounted, losing its scroll position, caret, focus and history.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!isZoomAvailable) {
        return builder(1, null);
      }

      if (!zoom.isFitToWidth) {
        return builder(zoom.step, onZoomStepRequested);
      }

      final metrics = pageSetup.toMetrics();
      final firstFactor = OcptPageZoom.fitFactorFor(
        availableWidth: constraints.maxWidth,
        pageWidthAtActualSize: OcptEditorPreviewLayout(metrics: metrics).pageWidth,
      );
      // A glyph is measured at the font size it is typeset at, which isn't exactly linear in the
      // zoom: one correction lands the sheet on the width the area has.
      final firstWidth = OcptEditorPreviewLayout(metrics: metrics, zoom: firstFactor).pageWidth;
      final factor = (firstFactor * (constraints.maxWidth - 32) / firstWidth).clamp(
        OcptPageZoom.minFactor,
        OcptPageZoom.maxFactor,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => onFitFactorMeasured(factor));

      return builder(factor, onZoomStepRequested);
    },
  );
}
