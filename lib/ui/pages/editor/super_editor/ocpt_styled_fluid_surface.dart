// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

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

  /// Creates an [OcptStyledFluidSurface].
  const OcptStyledFluidSurface({
    super.key,
    required this.theme,
    required this.usePaperColors,
    required this.scrollController,
    required this.editor,
  });

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: scrollController,
    child: ColoredBox(
      color: usePaperColors ? Colors.white : theme.colorScheme.surface,
      child: editor,
    ),
  );
}
