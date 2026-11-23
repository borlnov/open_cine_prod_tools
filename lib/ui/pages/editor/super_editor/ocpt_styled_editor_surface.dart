// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_dual_dialogue_bracket.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_fluid_surface.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_simulation_surface.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_zoom_anchor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_zoom_wheel_physics.dart';

/// The surface the styled editor's `SuperEditor` is laid out on: the fluid surface, or the
/// simulated paper sheets while page simulation is on, both with the same scroll configuration
/// around [editor].
///
/// Material's `ScrollBehavior` would otherwise wrap `SuperEditor`'s internal `Scrollable` in its own
/// implicit `Scrollbar`, painted at the edge of whichever box happens to contain it — i.e. on top of
/// the white page in the page-simulation branch. Suppressing it here and painting a single explicit
/// `Scrollbar` around the whole panel instead (both branches, so the behaviour is identical with
/// page simulation on or off) keeps the thumb in the panel's gutter.
///
/// `withNoTextScaling` pins the page's type size to the page's own: `SuperText` otherwise falls back
/// to `MediaQuery.textScalerOf`, so a desktop font-scaling preference would grow every glyph without
/// growing the page it is typeset on — the lines would wrap early and grow taller than the
/// `OcptEditorPreviewLayout` metrics `computeOcptStyledPagination` sized each simulated sheet with,
/// spilling out under its bottom edge. The raw preview pins it the same way, for the same reason
/// (see `OcptEditorPreviewBlock`).
class OcptStyledEditorSurface extends StatelessWidget {
  /// The `SuperEditor` laid out on the surface.
  final Widget editor;

  /// The pixel layout of the page, at the current zoom.
  final OcptEditorPreviewLayout layout;

  /// Whether the paper sheets are simulated rather than the text laid out fluidly.
  final bool isPageSimulationEnabled;

  /// Whether the fluid surface paints paper colors.
  final bool usePaperColors;

  /// The editor's own vertical scroll controller.
  final ScrollController scrollController;

  /// The controller of the sideways scroll a page wider than the surface gets.
  final ScrollController horizontalScrollController;

  /// The zoom the page is typeset at.
  final double zoom;

  /// The number of simulated sheets.
  final int pageCount;

  /// How many of the simulated sheets are taken by the title page.
  final int titlePageSheetCount;

  /// Whether the page can be zoomed here, which is what lets Ctrl + wheel stop scrolling it.
  final bool canZoom;

  /// Class constructor
  const OcptStyledEditorSurface({
    required this.editor,
    required this.layout,
    required this.isPageSimulationEnabled,
    required this.usePaperColors,
    required this.scrollController,
    required this.horizontalScrollController,
    required this.zoom,
    required this.pageCount,
    required this.titlePageSheetCount,
    required this.canZoom,
    super.key,
  });

  /// Build the fluid or simulated surface around [editor].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final framedEditor = MediaQuery.withNoTextScaling(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          physics: OcptZoomWheelPhysics.over(context, isEnabled: canZoom),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => OcptDualDialogueColumnScope(
            // The document column's width: the surface's, less the stylesheet's side padding.
            width:
                constraints.maxWidth -
                2 * OcptFountainEditorStylesheet.horizontalDocumentPaddingInset,
            child: editor,
          ),
        ),
      ),
    );

    return isPageSimulationEnabled
        ? OcptStyledPageSimulationSurface(
            theme: theme,
            layout: layout,
            scrollController: scrollController,
            pageCount: pageCount,
            titlePageSheetCount: titlePageSheetCount,
            editor: framedEditor,
            horizontalScrollController: horizontalScrollController,
            scrollsSideways: zoom > 1,
          )
        : OcptStyledFluidSurface(
            theme: theme,
            usePaperColors: usePaperColors,
            scrollController: scrollController,
            editor: framedEditor,
            horizontalScrollController: horizontalScrollController,
            scrollsSideways: zoom > 1,
            minContentWidth: OcptStyledZoomAnchor.fluidContentWidthOf(layout),
          );
  }
}
