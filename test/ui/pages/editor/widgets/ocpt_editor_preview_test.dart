// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
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
///
/// [theme] defaults to [ocptTheme]'s light variant: the preview reads its backdrop color from an
/// [OcptSpecificColors] theme extension, which only a theme built from [ocptTheme] carries.
///
/// [textScaler] stands in for the platform's font-scaling preference, which the desktop hands the
/// app through `MediaQuery`.
Widget _wrap(
  Widget child, {
  required double width,
  double height = 600,
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: theme ?? ocptTheme.lightThemeData,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

/// An action line of exactly [columns] characters, made of short lower-case words so it has plenty
/// of wrap opportunities — and so the parser reads it as action rather than as a character cue,
/// which an all-upper-case line would be.
///
/// A line this long is the interesting case for the tests below: it fills the action element's box
/// to the very last column, so it renders on a single line if (and only if) the preview typesets it
/// at the same fixed pitch [OcptEditorPreviewLayout] measured that box with.
String _actionLineOfColumns(int columns) {
  final characters = List.generate(columns, (index) => (index + 1) % 5 == 0 ? " " : "m");
  // Never end on the space of the last group: a trailing space is trimmed at wrap time, so it
  // would quietly make the line one column shorter than asked for.
  characters[columns - 1] = "m";

  return characters.join();
}

/// Widens the test surface well past [unscaledPanelWidth], so a `SizedBox`-constrained panel of
/// that width actually gets it: the default 800x600 test surface would otherwise clamp it first
/// (`Align`, this file's `_wrap`'s outermost widget, never offers its child more width than its
/// own — the test surface's), silently forcing every test into the narrow/scaled branch.
void _widenTestSurface(WidgetTester tester, double unscaledPanelWidth, {double height = 900}) {
  tester.view.physicalSize = Size(unscaledPanelWidth + 200, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The [ColoredBox] [OcptEditorPreview] paints its own panel backdrop with, scoped to its subtree
/// (the test surface also carries an unrelated, transparent framework [ColoredBox] ancestor).
final _backdropFinder = find.descendant(
  of: find.byType(OcptEditorPreview),
  matching: find.byType(ColoredBox),
);

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
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
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
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
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
          pageSetup: const OcptPageSetup.standard(),
          currentLine: 0,
          isPageSimulationEnabled: false,
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
    "a line filling the element's box to its last column still renders on a single line",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      // The regression this guards: the base style used to inherit, so `Text.rich` merged it onto
      // the ambient `DefaultTextStyle` — Material's `bodyMedium`, whose `letterSpacing` widened
      // every glyph past the fixed pitch the page's columns are measured at. This line then no
      // longer fitted its own box and wrapped onto a second line that
      // `OcptEditorPreviewLayout.estimatedLineCount` (which counts columns, not pixels) never
      // counted, so with page simulation on each page rendered taller than its simulated sheet and
      // spilled out under it.
      final columns = layout.metrics.action.maxWidthColumns;
      final document = const FountainParser().parse(_actionLineOfColumns(columns));

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
          ),
          width: unscaledPanelWidth,
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(RichText).first).height,
        closeTo(layout.lineHeight, 1),
      );
    },
  );

  testWidgets(
    "the platform's font-scaling preference never grows the page's own type",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      // Same line, same box, but with the desktop asking for larger text: the page is a simulation
      // of paper, so its type size is the page's own. Scaling the glyphs without scaling the page
      // would wrap and overflow it exactly the way the inherited `letterSpacing` above did.
      final columns = layout.metrics.action.maxWidthColumns;
      final document = const FountainParser().parse(_actionLineOfColumns(columns));

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
          ),
          width: unscaledPanelWidth,
          textScaler: const TextScaler.linear(1.6),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(RichText).first).height,
        closeTo(layout.lineHeight, 1),
      );
    },
  );

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
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
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
            pageSetup: const OcptPageSetup.standard(),
            currentLine: targetLine,
            isPageSimulationEnabled: false,
          ),
          width: narrowWidth,
        ),
      );
      // The sync is scheduled from a post-frame callback and then animates.
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0));
    },
  );

  testWidgets(
    "page simulation renders one white sheet per page for a document long enough to overflow one",
    (tester) async {
      // Tall enough that the lazy page list actually builds (and this test can find) the second
      // sheet, rather than leaving it unbuilt below the fold.
      final tallPanelHeight = layout.pageHeight * 2 + 200;
      _widenTestSurface(tester, unscaledPanelWidth, height: tallPanelHeight + 100);
      final document = const FountainParser().parse(_longSampleText);

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: true,
          ),
          width: unscaledPanelWidth,
          height: tallPanelHeight,
        ),
      );
      await tester.pump();

      final sheetCount = find.byType(Material).evaluate().length;
      expect(sheetCount, greaterThan(1));

      final firstSheetHeight = tester.getSize(find.byType(Material).first).height;
      expect(firstSheetHeight, closeTo(layout.pageHeight, 0.5));
    },
  );

  testWidgets(
    "a page-simulation sheet is the full page width, not collapsed to a 0-width sliver",
    (tester) async {
      final tallPanelHeight = layout.pageHeight * 2 + 200;
      _widenTestSurface(tester, unscaledPanelWidth, height: tallPanelHeight + 100);
      final document = const FountainParser().parse(_longSampleText);

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: true,
          ),
          width: unscaledPanelWidth,
          height: tallPanelHeight,
        ),
      );
      await tester.pump();

      final sheetRect = tester.getRect(find.byType(Material).first);
      expect(sheetRect.width, closeTo(layout.pageWidth, 0.5));
      expect(sheetRect.height, closeTo(layout.pageHeight, 0.5));
    },
  );

  testWidgets(
    "in dark theme the preview panel's backdrop is white, not the themed dock background",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      final document = const FountainParser().parse(_longSampleText);

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
          ),
          width: unscaledPanelWidth,
          theme: ocptTheme.darkThemeData,
        ),
      );
      await tester.pump();

      final coloredBox = tester.widget<ColoredBox>(_backdropFinder);
      expect(coloredBox.color, Colors.white);
    },
  );

  testWidgets("in light theme the preview panel's backdrop is unchanged", (tester) async {
    _widenTestSurface(tester, unscaledPanelWidth);
    final document = const FountainParser().parse(_longSampleText);

    await tester.pumpWidget(
      _wrap(
        OcptEditorPreview(
          document: document,
          pageSetup: const OcptPageSetup.standard(),
          currentLine: 0,
          isPageSimulationEnabled: false,
        ),
        width: unscaledPanelWidth,
      ),
    );
    await tester.pump();

    final coloredBox = tester.widget<ColoredBox>(_backdropFinder);
    expect(
      coloredBox.color,
      ocptTheme.lightThemeData!.extension<OcptSpecificColors>()!.previewBackdrop,
    );
    expect(coloredBox.color, ocptTheme.lightThemeData!.colorScheme.surfaceContainerLow);
  });

  testWidgets(
    "page simulation off keeps a single continuous sheet even for a long document",
    (tester) async {
      _widenTestSurface(tester, unscaledPanelWidth);
      final document = const FountainParser().parse(_longSampleText);

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: false,
          ),
          width: unscaledPanelWidth,
        ),
      );
      await tester.pump();

      expect(find.byType(Material), findsOneWidget);
    },
  );

  testWidgets(
    "a simulated page's content stays inside its own sheet, blank separator lines included",
    (tester) async {
      final tallPanelHeight = layout.pageHeight + 200;
      _widenTestSurface(tester, unscaledPanelWidth, height: tallPanelHeight + 100);
      // Enough one-line paragraphs to overrun a page several times over. Each of them renders with
      // one blank line of trailing space, exactly like the separator `FountainScriptComposer` emits
      // between two blocks: the paginator used to pack pages counting the text lines alone, so a
      // page of ~27 paragraphs took twice its own height and half of it rendered below the sheet,
      // on the panel's backdrop.
      final document = const FountainParser().parse(
        List.generate(120, (index) => "Action line $index.").join("\n\n"),
      );

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: true,
          ),
          width: unscaledPanelWidth,
          height: tallPanelHeight,
        ),
      );
      await tester.pump();

      // The first page's block column, whose height is the page's rendered content: it must fit the
      // printable area the sheet reserves for it — its own trailing blank line aside, which falls
      // harmlessly into the bottom margin.
      final contentHeight = tester.getSize(find.byType(Column).first).height;
      final printableHeight = layout.metrics.linesPerPage * layout.lineHeight;
      expect(contentHeight, lessThanOrEqualTo(printableHeight + layout.blockSpacing + 0.5));
    },
  );

  testWidgets(
    "a forced page break starts a fresh sheet even when the content alone would fit one page",
    (tester) async {
      final tallPanelHeight = layout.pageHeight * 2 + 200;
      _widenTestSurface(tester, unscaledPanelWidth, height: tallPanelHeight + 100);
      final document = const FountainParser().parse("Some action.\n\n===\n\nMore action.");

      await tester.pumpWidget(
        _wrap(
          OcptEditorPreview(
            document: document,
            pageSetup: const OcptPageSetup.standard(),
            currentLine: 0,
            isPageSimulationEnabled: true,
          ),
          width: unscaledPanelWidth,
          height: tallPanelHeight,
        ),
      );
      await tester.pump();

      expect(find.byType(Material), findsNWidgets(2));
      // The forced page break itself is a structural marker (represented by the fresh sheet), not
      // printed content: it must never render as its own block on either sheet.
      expect(find.textContaining("==="), findsNothing);
    },
  );
}
