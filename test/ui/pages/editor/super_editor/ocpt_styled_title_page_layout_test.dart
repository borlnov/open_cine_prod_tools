// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_title_page_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

void main() {
  final metrics = FountainLayoutMetrics.usLetter();
  final layout = OcptEditorPreviewLayout(metrics: metrics);

  group("ocptTitlePageFieldLayoutOf", () {
    test("only the Title field scales its font and turns bold", () {
      for (final key in ocptTitlePageFieldKeys) {
        final fieldLayout = ocptTitlePageFieldLayoutOf(key, layout);
        if (key == "Title") {
          expect(fieldLayout.fontScale, ocptTitlePageTitleFontScale);
          expect(fieldLayout.fontWeight, FontWeight.bold);
        } else {
          expect(fieldLayout.fontScale, 1);
          expect(fieldLayout.fontWeight, isNull);
        }
      }
    });

    test("Draft date is right-aligned, Contact and Source are left-aligned, the rest are centered", () {
      expect(ocptTitlePageFieldLayoutOf("Title", layout).textAlign, TextAlign.center);
      expect(ocptTitlePageFieldLayoutOf("Credit", layout).textAlign, TextAlign.center);
      expect(ocptTitlePageFieldLayoutOf("Author", layout).textAlign, TextAlign.center);
      expect(ocptTitlePageFieldLayoutOf("Draft date", layout).textAlign, TextAlign.right);
      expect(ocptTitlePageFieldLayoutOf("Contact", layout).textAlign, TextAlign.left);
      expect(ocptTitlePageFieldLayoutOf("Source", layout).textAlign, TextAlign.left);
    });
  });

  group("computeOcptStyledTitlePageMetrics", () {
    test("an empty title page's flow height matches the hand computation", () {
      final document = OcptWysiwygCodec.decodeWithTitlePage("Some action.").document;

      // Worked example (see the F3 plan): each field's own top gap (Title and Draft date's own
      // fraction of the sheet height, every other field one or two line heights) plus one line of
      // text at the field's own font scale (only Title differs, at `ocptTitlePageTitleFontScale`).
      const titleTopFraction = 0.32;
      const bottomGroupTopFraction = 0.22;
      final expected =
          (layout.pageHeight * titleTopFraction + layout.lineHeight * ocptTitlePageTitleFontScale) +
          (layout.lineHeight * 2 + layout.lineHeight) + // Credit
          (layout.lineHeight + layout.lineHeight) + // Author
          (layout.pageHeight * bottomGroupTopFraction + layout.lineHeight) + // Draft date
          (layout.lineHeight + layout.lineHeight) + // Contact
          (layout.lineHeight + layout.lineHeight); // Source

      final result = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics);

      expect(result.flowHeight, closeTo(expected, 0.01));
    });

    test("a multi-line Contact adds exactly one lineHeight per extra line", () {
      final oneLine = OcptWysiwygCodec.decodeWithTitlePage(
        "Contact:\n    123 Reel Street\n\nSome action.",
      ).document;
      final twoLines = OcptWysiwygCodec.decodeWithTitlePage(
        "Contact:\n    123 Reel Street\n    Second line\n\nSome action.",
      ).document;

      final oneLineHeight = computeOcptStyledTitlePageMetrics(document: oneLine, metrics: metrics).flowHeight;
      final twoLinesHeight = computeOcptStyledTitlePageMetrics(document: twoLines, metrics: metrics).flowHeight;

      expect(twoLinesHeight - oneLineHeight, closeTo(layout.lineHeight, 0.01));
    });

    test("a title long enough to wrap adds ocptTitlePageTitleFontScale x lineHeight", () {
      final contentWidth = layout.pageWidth - layout.marginLeft - layout.marginRight;
      final titleColumns = (contentWidth / (layout.glyphWidth * ocptTitlePageTitleFontScale)).floor();
      // One word filling the box exactly, plus a short second word: a greedy word-wrap pushes the
      // second word to a second line, so this wraps to exactly 2 lines (rather than a single
      // over-long word, which would hard-wrap mid-word into an unpredictable number of lines).
      final longTitle = "${List.generate(titleColumns, (_) => "A").join()} B";

      final shortDocument = OcptWysiwygCodec.decodeWithTitlePage("Title: Short\n\nSome action.").document;
      final longDocument = OcptWysiwygCodec.decodeWithTitlePage("Title: $longTitle\n\nSome action.").document;

      final shortHeight = computeOcptStyledTitlePageMetrics(document: shortDocument, metrics: metrics).flowHeight;
      final longHeight = computeOcptStyledTitlePageMetrics(document: longDocument, metrics: metrics).flowHeight;

      expect(longHeight - shortHeight, closeTo(layout.lineHeight * ocptTitlePageTitleFontScale, 0.01));
    });

    test("a document with no title-page nodes at all has a flow height of 0", () {
      final document = OcptWysiwygCodec.decode("Some action.").document;

      final result = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics);

      expect(result.flowHeight, 0);
    });
  });
}
