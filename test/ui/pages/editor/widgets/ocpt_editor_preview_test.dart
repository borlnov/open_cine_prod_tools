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
Widget _wrap(Widget child, {required double width, double height = 600}) => MaterialApp(
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
  final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
  // Matches `_OcptEditorPreviewState._pagePadding`: the horizontal padding kept around the page.
  const pagePadding = 16.0;
  final unscaledPanelWidth = layout.pageWidth + pagePadding * 2;

  testWidgets("a panel at least as wide as the page renders it unscaled, fully visible", (
    tester,
  ) async {
    _widenTestSurface(tester, unscaledPanelWidth);
    final document = const FountainParser().parse(_longSampleText);

    await tester.pumpWidget(
      _wrap(
        OcptEditorPreview(document: document, pageFormat: OcptPageFormat.usLetter, currentLine: 0),
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
  });

  testWidgets(
    "a panel narrower than the page scales it down instead of cropping it, right margin included",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      final document = const FountainParser().parse(_longSampleText);
      final narrowWidth = unscaledPanelWidth / 2;

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(document: document, pageFormat: OcptPageFormat.usLetter, currentLine: 0),
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
      // The page is meaningfully scaled down (not just barely), proving the panel's narrowness
      // actually drove the shrink rather than coincidental rounding.
      expect(pageRect.width, lessThan(layout.pageWidth * 0.6));
    },
  );

  testWidgets("caret scroll-sync still scrolls to the current line's block when the page is scaled", (
    tester,
  ) async {
    _widenTestSurface(tester, unscaledPanelWidth);
    final document = const FountainParser().parse(_longSampleText);
    final narrowWidth = unscaledPanelWidth / 2;

    await tester.pumpWidget(
      _wrap(
        OcptEditorPreview(document: document, pageFormat: OcptPageFormat.usLetter, currentLine: 0),
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
  });
}
