// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_horizontal_overflow.dart';

/// The fluid editing surface the styled editor shows while page simulation is off: no sheets, no
/// page numbers, just [editor], scrollable. Its ground follows the app theme, except on a phone
/// ([usePaperColors], see `OcptStyledScreenplayEditor.usesPaperColorsWhileFluid`), where it is
/// white paper so the screenplay reads the way the desktop's simulated page does.
class OcptStyledFluidSurface extends StatelessWidget {
  /// The theme the ground color follows when [usePaperColors] is false.
  final ThemeData theme;

  /// Whether the ground is the fixed white paper rather than the theme's surface.
  final bool usePaperColors;

  /// The scroll controller the editor scrolls with, shared with the scrollbar painted around it.
  final ScrollController scrollController;

  /// The editor, already stripped of its implicit scrollbar.
  final Widget editor;

  /// The controller of the horizontal scroll the editor gets when the area is narrower than
  /// [minContentWidth], or null to let the editor take the width the area has.
  final ScrollController? horizontalScrollController;

  /// The width the editor's blocks need at the current zoom, in logical pixels.
  final double minContentWidth;

  /// Create an [OcptStyledFluidSurface].
  const OcptStyledFluidSurface({
    super.key,
    required this.theme,
    required this.usePaperColors,
    required this.scrollController,
    required this.editor,
    this.horizontalScrollController,
    this.minContentWidth = 0,
  });

  /// Build the styled fluid surface as a [Scrollbar].
  @override
  Widget build(BuildContext context) {
    final horizontalScrollController = this.horizontalScrollController;

    return Scrollbar(
      controller: scrollController,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
      child: ColoredBox(
        color: usePaperColors ? Colors.white : theme.colorScheme.surface,
        child: horizontalScrollController == null
            ? editor
            : LayoutBuilder(
                builder: (context, constraints) => OcptStyledHorizontalOverflow(
                  constraints: constraints,
                  minWidth: minContentWidth,
                  controller: horizontalScrollController,
                  child: editor,
                ),
              ),
      ),
    );
  }
}
