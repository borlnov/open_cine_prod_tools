// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// Run the tests of [OcptEditorPreviewLayout].
void main() {
  group("OcptEditorPreviewLayout pixels-per-inch consistency", () {
    for (final metrics in [
      (name: "usLetter", value: FountainLayoutMetrics.usLetter()),
      (name: "a4", value: FountainLayoutMetrics.a4()),
    ]) {
      testWidgets(
        "${metrics.name}: marginTop + linesPerPage * lineHeight + marginBottom fills pageHeight",
        (tester) async {
          final layout = OcptEditorPreviewLayout(metrics: metrics.value);

          final printableContentHeight = metrics.value.linesPerPage * layout.lineHeight;
          final filledHeight = layout.marginTop + printableContentHeight + layout.marginBottom;

          // `linesPerPage` is `floor(printable height in inches * linesPerInch)`, so the filled
          // height can fall short of `pageHeight` by less than one `lineHeight` (the flooring's
          // own rounding error) but must never exceed it: a full page of `linesPerPage` lines must
          // genuinely fit within the simulated sheet, not overflow it.
          expect(filledHeight, lessThanOrEqualTo(layout.pageHeight + 0.01));
          expect(filledHeight, greaterThan(layout.pageHeight - layout.lineHeight));
        },
      );

      testWidgets(
        "${metrics.name}: horizontal and vertical scales share one pixels-per-inch value",
        (tester) async {
          final layout = OcptEditorPreviewLayout(metrics: metrics.value);

          expect(
            layout.pageWidth / metrics.value.pageWidthInches,
            closeTo(layout.pixelsPerInch, 0.001),
          );
          expect(
            layout.pageHeight / metrics.value.pageHeightInches,
            closeTo(layout.pixelsPerInch, 0.001),
          );
          expect(
            layout.lineHeight,
            closeTo(layout.pixelsPerInch / metrics.value.linesPerInch, 0.001),
          );
        },
      );

      testWidgets("${metrics.name}: lineHeightFactor renders text at exactly lineHeight", (
        tester,
      ) async {
        final layout = OcptEditorPreviewLayout(metrics: metrics.value);

        expect(layout.lineHeightFactor * layout.fontSize, closeTo(layout.lineHeight, 0.001));
      });
    }
  });

  group("OcptEditorPreviewLayout zoom", () {
    final metrics = FountainLayoutMetrics.usLetter();

    testWidgets("a zoom of 2 doubles the glyph, the page and the line, not the line count", (
      tester,
    ) async {
      final actual = OcptEditorPreviewLayout(metrics: metrics);
      final zoomed = OcptEditorPreviewLayout(metrics: metrics, zoom: 2);

      expect(zoomed.fontSize, OcptEditorPreviewLayout.baseFontSize * 2);
      expect(zoomed.glyphWidth, closeTo(actual.glyphWidth * 2, 0.01));
      expect(zoomed.pixelsPerInch, closeTo(actual.pixelsPerInch * 2, 0.1));
      expect(zoomed.lineHeight, closeTo(actual.lineHeight * 2, 0.05));
      expect(zoomed.pageWidth, closeTo(actual.pageWidth * 2, 0.5));
      expect(zoomed.pageHeight, closeTo(actual.pageHeight * 2, 0.5));
      expect(zoomed.marginLeft, closeTo(actual.marginLeft * 2, 0.1));
      expect(zoomed.lineHeightFactor, closeTo(actual.lineHeightFactor, 0.001));

      final block = const FountainParser()
          .parse("A long line of action that wraps over several lines. " * 4)
          .blocks
          .first;
      expect(zoomed.estimatedLineCount(block), actual.estimatedLineCount(block));
    });

    testWidgets("the default zoom is 100 %", (tester) async {
      expect(OcptEditorPreviewLayout(metrics: metrics).zoom, 1);
    });
  });
}
