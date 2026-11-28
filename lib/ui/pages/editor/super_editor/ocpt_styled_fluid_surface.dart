// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_notes_margin.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scaled_to_fit.dart';

/// The fluid editing surface the styled editor shows while page simulation is off: no sheets, no
/// page numbers, just [editor], scrollable. Its ground follows the app theme, except on a phone
/// ([usePaperColors], see `OcptStyledScreenplayEditor.usesPaperColorsWhileFluid`), where it is
/// white paper so the screenplay reads the way the desktop's simulated page does.
///
/// When there are notes and the area keeps the text its minimum width beside them, [notesMargin]
/// is reserved at the right and the text narrows to leave it room.
class OcptStyledFluidSurface extends StatelessWidget {
  /// The theme the ground color follows when [usePaperColors] is false.
  final ThemeData theme;

  /// Whether the ground is the fixed white paper rather than the theme's surface.
  final bool usePaperColors;

  /// The scroll controller the editor scrolls with, shared with the scrollbar painted around it.
  final ScrollController scrollController;

  /// The editor, already stripped of its implicit scrollbar.
  final Widget editor;

  /// The controller of the horizontal scroll the editor gets when it is zoomed in past the width
  /// the area has.
  final ScrollController horizontalScrollController;

  /// Whether the editor is zoomed in, and so scrolls sideways when [minContentWidth] is more than
  /// the area has.
  final bool scrollsSideways;

  /// The width the editor's blocks need at the current zoom, in logical pixels.
  final double minContentWidth;

  /// The notes of the document, which tell whether a margin is needed.
  final OcptStyledNotes notes;

  /// The column of note cards shown at the right of the text when it fits.
  final Widget notesMargin;

  /// Whether the surface is compact, which never has a notes margin.
  final bool isCompact;

  /// Create an [OcptStyledFluidSurface].
  const OcptStyledFluidSurface({
    super.key,
    required this.theme,
    required this.usePaperColors,
    required this.scrollController,
    required this.editor,
    required this.horizontalScrollController,
    required this.scrollsSideways,
    required this.minContentWidth,
    required this.notes,
    required this.notesMargin,
    required this.isCompact,
  });

  /// Build the styled fluid surface as a [Scrollbar].
  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: scrollController,
    notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
    child: ColoredBox(
      color: usePaperColors ? Colors.white : theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<List<OcptNoteEntry>>(
          valueListenable: notes.entries,
          builder: (context, entries, child) {
            // The margin is only ever there when the text keeps its minimum width beside it, so
            // it never makes the text scroll sideways.
            final hasMargin = OcptStyledNotesMargin.fits(
              hasNotes: entries.isNotEmpty,
              isCompact: isCompact,
              availableWidth: constraints.maxWidth,
              contentWidth: minContentWidth,
            );
            notes.reportMargin(isShown: hasMargin);
            return OcptStyledScaledToFit(
              constraints: constraints,
              pageWidth: minContentWidth,
              horizontalScrollController: horizontalScrollController,
              scrollsSideways: scrollsSideways,
              scalesDown: false,
              // One tree whether the margin is there or not, so the editor is never mounted again
              // when the first note appears or the last one goes.
              page: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      right: hasMargin
                          ? OcptStyledNotesMargin.reservedWidth + OcptStyledNotesMargin.outerMargin
                          : 0,
                    ),
                    child: editor,
                  ),
                  if (hasMargin)
                    Positioned(
                      right: OcptStyledNotesMargin.outerMargin,
                      top: 0,
                      bottom: 0,
                      width: OcptStyledNotesMargin.cardWidth,
                      child: notesMargin,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
