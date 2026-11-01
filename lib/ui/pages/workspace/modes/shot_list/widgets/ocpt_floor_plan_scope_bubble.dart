// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// The scope bubble: anchored just below [liveOverride]'s own footprint, offering
/// `Every sequence (n)` / `Only sequence n` / `Cancel` for a set-scope symbol whose own set is
/// linked to two or more sequences, or `The whole sequence` / `Only shot n` / `Cancel` for a
/// scene-scope symbol of a sequence with two or more shots — shown the instant a
/// move/rotate/resize ends, in place of writing straight away. Works with mouse and touch alike:
/// three plain tappable buttons, nothing gesture-specific.
///
/// A small card of three plain buttons, `Cancel` first (the least committal, and the one a
/// dismissal already means), then `Only sequence n`, then `Every sequence (n)` (the current
/// default, so it reads last as the "keep going" option) — laid out as a `Column` rather than a
/// `Row` so it never has to guess how wide either localized label runs.
class OcptFloorPlanScopeBubble extends StatelessWidget {
  /// The live geometry of the symbol the decision is about, which the bubble is anchored under.
  final OcptFloorPlanSymbolLiveOverride liveOverride;

  /// The size of the canvas the symbol is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// The `Every sequence (n)` button's own label.
  final String everyLabel;

  /// The `Only sequence n` button's own label.
  final String onlyLabel;

  /// The `Cancel` button's own label.
  final String cancelLabel;

  /// Called when `Every sequence` is tapped, or null while withheld.
  final VoidCallback? onEveryRequested;

  /// Called when `Only sequence n` is tapped, or null while withheld.
  final VoidCallback? onOnlyRequested;

  /// Called when `Cancel` is tapped, or null while withheld.
  final VoidCallback? onCancelRequested;

  /// Class constructor
  const OcptFloorPlanScopeBubble({
    super.key,
    required this.liveOverride,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.everyLabel,
    required this.onlyLabel,
    required this.cancelLabel,
    required this.onEveryRequested,
    required this.onOnlyRequested,
    required this.onCancelRequested,
  });

  @override
  @override
  @override
  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final centre = ocptFloorPlanScreenPointOf(
      xM: liveOverride.xM,
      yM: liveOverride.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final heightPx = liveOverride.heightM * pixelsPerMetre;

    return Positioned(
      left: centre.dx,
      top: centre.dy + heightPx / 2 + 8,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: IntrinsicWidth(
          child: Material(
            elevation: 4,
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(onPressed: onCancelRequested, child: Text(cancelLabel)),
                  TextButton(onPressed: onOnlyRequested, child: Text(onlyLabel)),
                  FilledButton(onPressed: onEveryRequested, child: Text(everyLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
