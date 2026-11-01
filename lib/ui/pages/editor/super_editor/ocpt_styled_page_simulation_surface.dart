// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_script_page_number.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_page_sheets_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scaled_to_fit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The paper-simulated editing surface the styled editor shows while page simulation is on:
/// real-size white sheets behind [editor], scaled to fit a panel narrower than [layout]'s own page
/// width. The inline comments below are the authority on every geometry decision it makes: why
/// the editor is only as wide as the content area, why it is shifted back by one padding inset,
/// and why the sheets are painted rather than laid out.
class OcptStyledPageSimulationSurface extends StatelessWidget {
  /// The theme whose surface color is the backdrop on either side of the sheets.
  final ThemeData theme;

  /// The page layout metrics the sheets and the editor's box are sized from.
  final OcptEditorPreviewLayout layout;

  /// The scroll controller the editor scrolls with, whose live offset keeps the painted sheets in
  /// sync with the scrolled content.
  final ScrollController scrollController;

  /// The number of simulated pages to paint a sheet for.
  final int pageCount;

  /// How many leading sheets the title page occupies (see [OcptPageSheetsPainter]).
  final int titlePageSheetCount;

  /// The editor, already stripped of its implicit scrollbar.
  final Widget editor;

  /// Creates an [OcptStyledPageSimulationSurface].
  const OcptStyledPageSimulationSurface({
    super.key,
    required this.theme,
    required this.layout,
    required this.scrollController,
    required this.pageCount,
    required this.titlePageSheetCount,
    required this.editor,
  });

  @override
  Widget build(BuildContext context) {
    // Page simulation: the document is centered at the physical page width, with a themed
    // backdrop (matching the app's theme) on either side, and a white sheet painted behind it per
    // simulated page (see `OcptPageSheetsPainter`); `OcptFountainEditorStylesheet` already
    // switched to fixed paper colors above, since a theme-derived color could otherwise render
    // invisible on that white backdrop.
    //
    // `editor` itself is only as wide as the page's content area (`pageWidth - marginRight`), left
    // -aligned within the full `pageWidth` box, rather than centered at `pageWidth` directly: every
    // "full width" element's `Styles.maxWidth` (see `OcptFountainEditorStylesheet._rule`) already
    // equals that same content-area width by construction, so super_editor's single-column layout,
    // which centers each block's box within its own parent, now has nothing left to center against
    // — the box fills its parent exactly, flush with the page's left edge. Centering `editor` at
    // the full `pageWidth` instead (a prior version of this code did) left it half a right margin's
    // width of that centering slack on the left, and half on the right, visibly swallowing the
    // right margin. The reserved `marginRight`-wide strip on the right stays part of the white
    // sheet (still `pageWidth` wide, painted by `OcptPageSheetsPainter`), just with no text.
    //
    // The editor's box is additionally widened by the stylesheet's horizontal `documentPadding`
    // inset on each side, and shifted back left by one inset, so that the *content area* left
    // inside that padding — not the box itself — is what lands flush on the page's left edge and
    // spans exactly the content width. Without this compensation the inset would eat into the width
    // available to every block's `Styles.maxWidth`, silently clamping each element one inset
    // narrower on each side, so the styled editor would wrap its text a couple of columns earlier
    // than the raw preview typesets the very same line.
    const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
    return Scrollbar(
      controller: scrollController,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) => OcptStyledScaledToFit(
            constraints: constraints,
            pageWidth: layout.pageWidth,
            page: Stack(
              children: [
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: scrollController,
                    builder: (context, child) => CustomPaint(
                      painter: OcptPageSheetsPainter(
                        pageCount: pageCount,
                        titlePageSheetCount: titlePageSheetCount,
                        pageHeight: layout.pageHeight,
                        pageGap: OcptEditorPreviewLayout.pageGap,
                        pageNumberTop: ocptScriptPageNumberTopInches * layout.pixelsPerInch,
                        pageNumberRight: layout.pageWidth - layout.marginRight,
                        // The sheets are white whatever the app's theme is, so the number is
                        // painted in the same fixed paper colors `OcptFountainEditorStylesheet`
                        // switches to under page simulation — a theme-derived color could render
                        // invisible on that white backdrop — and at the body's own size and family,
                        // since that is what the PDF prints it at.
                        pageNumberStyle: const TextStyle(
                          fontFamily: OcptEditorPreviewLayout.fontFamily,
                          fontSize: OcptEditorPreviewLayout.fontSize,
                          color: Colors.black,
                        ),
                        scrollOffset: scrollController.hasClients ? scrollController.offset : 0,
                      ),
                    ),
                  ),
                ),
                // Deliberately an `Align` (a *non-positioned* Stack child) shifted by a
                // `Transform`, rather than a `Positioned(left: -inset)`: the `Stack` sizes itself
                // to its non-positioned children, so making every child positioned would leave it
                // sizing to its incoming constraints instead, handing `SuperEditor` a
                // differently-constrained viewport — which, in turn, breaks its IME connection
                // (`editor_page_toolbar_and_preview_test.dart`'s "an edit made in styled mode
                // survives switching back to raw mode" catches exactly that).
                Align(
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: const Offset(-inset, 0),
                    child: SizedBox(
                      width: layout.pageWidth - layout.marginRight + inset * 2,
                      child: editor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
