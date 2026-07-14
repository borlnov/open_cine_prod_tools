// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// A screenplay long enough that its preview overflows any reasonable test viewport height, so the
/// scroll-sync tests below have real distance to scroll across.
final String _longSampleText = List.generate(
  30,
  (index) =>
      "Scene $index some fairly long action paragraph describing what happens, "
      "padded out with a bit more text so it takes a couple of wrapped lines too.",
).join("\n\n");

/// Wraps [child] in a [MaterialApp] and a [width]x[height] box (top-left aligned, so the panel's
/// origin lines up with the test surface's own origin, keeping [WidgetTester.getRect] comparisons
/// simple), the same constrained-panel setup the real editor page's `Expanded` gives the preview.
Widget _wrap(Widget child, {required double width, double height = 600}) =>
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );

/// Widens the test surface well past [unscaledPanelWidth], so a `SizedBox`-constrained panel of
/// that width actually gets it: the default 800x600 test surface would otherwise clamp it first
/// (`Align`, this file's `_wrap`'s outermost widget, never offers its child more width than its
/// own — the test surface's), silently forcing every test into the narrow/scaled branch.
void _widenTestSurface(WidgetTester tester, double unscaledPanelWidth) {
  tester.view.physicalSize = Size(unscaledPanelWidth + 200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final layout = OcptEditorPreviewLayout(
    metrics: FountainLayoutMetrics.usLetter(),
  );
  // Matches `_OcptEditorPreviewState._pagePadding`: the horizontal padding kept around the page.
  const pagePadding = 16.0;
  final unscaledPanelWidth = layout.pageWidth + pagePadding * 2;

  testWidgets(
    "a panel at least as wide as the page renders it unscaled, fully visible",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      final document = const FountainParser().parse(_longSampleText);

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageFormat: OcptPageFormat.usLetter,
            currentLine: 0,
          ),
          width: unscaledPanelWidth,
        ),
      );
      await tester.pump();

      // No horizontal scroller is ever built: a wide-enough panel never needed one, and a narrow
      // panel now scales instead of scrolling.
      expect(find.byType(SingleChildScrollView), findsNothing);

      final pageRect = tester.getRect(find.byType(Material));
      expect(pageRect.width, closeTo(layout.pageWidth, 0.5));
      // The full page, including its right edge, sits within the panel.
      expect(pageRect.left, greaterThanOrEqualTo(0));
      expect(pageRect.right, lessThanOrEqualTo(unscaledPanelWidth));
    },
  );

  testWidgets(
    "a panel narrower than the page scales it down instead of cropping it, right margin included",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      final document = const FountainParser().parse(_longSampleText);
      final narrowWidth = unscaledPanelWidth / 2;

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageFormat: OcptPageFormat.usLetter,
            currentLine: 0,
          ),
          width: narrowWidth,
        ),
      );
      await tester.pump();

      // Still no horizontal scroller: the page is scaled to fit instead of being cropped.
      expect(find.byType(SingleChildScrollView), findsNothing);

      // The page's on-screen (post-transform) bounds — including its right margin — fit entirely
      // within the narrow panel; nothing is cropped off either edge.
      final pageRect = tester.getRect(find.byType(Material));
      expect(pageRect.left, greaterThanOrEqualTo(-0.5));
      expect(pageRect.right, lessThanOrEqualTo(narrowWidth + 0.5));
      // The page is horizontally centered: the left gutter (background, outside the white sheet)
      // and the right gutter are equal, so the white page's own left margin renders exactly like
      // its top margin — as part of the white sheet, not swallowed by the gutter.
      final rightGutter = narrowWidth - pageRect.right;
      expect(pageRect.left, closeTo(rightGutter, 0.5));
      // The page is scaled down by exactly `narrowWidth / unscaledPanelWidth` — not further than
      // that (a stricter check than "meaningfully smaller": a prior, buggy implementation scaled
      // the page down by roughly the square of the intended factor, since a `SizedBox` requesting
      // more width than an ancestor's tight constraint silently got clamped back down before the
      // scale was even applied, on both axes).
      final expectedWidth = layout.pageWidth * narrowWidth / unscaledPanelWidth;
      expect(pageRect.width, closeTo(expectedWidth, 1));
    },
  );

  testWidgets("a wrapped action line leaves the page's true right margin visible", (
    tester,
  ) async {
    _widenTestSurface(tester, unscaledPanelWidth);
    // A single action paragraph long enough that it wraps: its wrapped lines fill the action
    // element's box right up to its full width, so the box's own right edge is a reliable proxy
    // for "where the rendered content actually reaches" on this line.
    final document = const FountainParser().parse(
      "A very long action paragraph describing what happens here, padded out with a lot more "
      "text so it definitely wraps across multiple lines and fills the full available width of "
      "its layout box on the simulated paper page, several times over to be sure.",
    );

    await tester.pumpWidget(
      _wrap(
        OcptEditorPreview(
          document: document,
          pageFormat: OcptPageFormat.usLetter,
          currentLine: 0,
        ),
        width: unscaledPanelWidth,
      ),
    );
    await tester.pump();

    final sheetRect = tester.getRect(find.byType(Material));
    final contentRect = tester.getRect(find.byType(RichText).first);

    // The action element's box should end 1 inch (`marginRightInches`) short of the sheet's right
    // edge: `pageWidthInches - marginRightInches - action.leftIndentInches - action.maxWidthInches
    // == marginRightInches` by construction (see `FountainLayoutMetrics`'s `fullWidthLeftAligned`).
    final expectedGap =
        FountainLayoutMetrics.usLetter().marginRightInches *
        layout.metrics.charsPerInch *
        layout.glyphWidth;
    final actualGap = sheetRect.right - contentRect.right;
    expect(actualGap, closeTo(expectedGap, layout.glyphWidth * 2));
  });

  testWidgets(
    "caret scroll-sync still scrolls to the current line's block when the page is scaled",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      final document = const FountainParser().parse(_longSampleText);
      final narrowWidth = unscaledPanelWidth / 2;

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageFormat: OcptPageFormat.usLetter,
            currentLine: 0,
          ),
          width: narrowWidth,
        ),
      );
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, 0);

      // Move the caret to a scene far down the (intentionally long) document.
      final targetLine = document.blocks.last.sourceRange.startLine;
      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageFormat: OcptPageFormat.usLetter,
            currentLine: targetLine,
          ),
          width: narrowWidth,
        ),
      );
      // The sync is scheduled from a post-frame callback and then animates.
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0));
    },
  );
}
