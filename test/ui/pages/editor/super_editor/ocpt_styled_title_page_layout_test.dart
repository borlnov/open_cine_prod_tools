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

    test("Draft date and Contact split the row half-and-half, Source keeps the full content width", () {
      final contentWidth = layout.pageWidth - layout.marginLeft - layout.marginRight;
      final halfWidth = contentWidth / 2;

      final draftDate = ocptTitlePageFieldLayoutOf("Draft date", layout);
      final contact = ocptTitlePageFieldLayoutOf("Contact", layout);
      final source = ocptTitlePageFieldLayoutOf("Source", layout);

      // Both keep the same full-row `maxWidth`, and shrink their usable box from opposite sides,
      // so neither box overlaps the other's half (see `ocptTitlePageFieldLayoutOf`'s own doc
      // comment for why a narrowed `maxWidth` isn't used instead).
      expect(draftDate.maxWidth, layout.marginLeft + contentWidth);
      expect(contact.maxWidth, layout.marginLeft + contentWidth);
      expect(draftDate.left, closeTo(layout.marginLeft + halfWidth, 0.01));
      expect(draftDate.right, 0);
      expect(contact.left, layout.marginLeft);
      expect(contact.right, closeTo(halfWidth, 0.01));
      expect(draftDate.maxWidth - draftDate.left - draftDate.right, closeTo(halfWidth, 0.01));
      expect(contact.maxWidth - contact.left - contact.right, closeTo(halfWidth, 0.01));

      // Contact's own top gap is 0 (the row shift takes its place instead); Source is unaffected,
      // following underneath at the full content width with its usual one-line gap.
      expect(contact.topGap, 0);
      expect(source.right, 0);
      expect(source.maxWidth - source.left - source.right, closeTo(contentWidth, 0.01));
    });
  });

  group("computeOcptStyledTitlePageMetrics", () {
    test("an empty title page's flow height matches the hand computation", () {
      final document = OcptWysiwygCodec.decodeWithTitlePage("Some action.").document;

      // Worked example (see the F3 plan): each field's own top gap (Title and Draft date's own
      // fraction of the sheet height, every other field one or two line heights) plus one line of
      // text at the field's own font scale (only Title differs, at `ocptTitlePageTitleFontScale`).
      // Contact's own top gap is 0 (F4's row shift takes its place, painted rather than flowed —
      // see `OcptStyledTitlePageMetrics.flowHeight`'s own doc comment for why that leaves this sum
      // one `lineHeight` short of the sheet's visual height, on purpose).
      const titleTopFraction = 0.32;
      const bottomGroupTopFraction = 0.22;
      final expected =
          (layout.pageHeight * titleTopFraction + layout.lineHeight * ocptTitlePageTitleFontScale) +
          (layout.lineHeight * 2 + layout.lineHeight) + // Credit
          (layout.lineHeight + layout.lineHeight) + // Author
          (layout.pageHeight * bottomGroupTopFraction + layout.lineHeight) + // Draft date
          (0 + layout.lineHeight) + // Contact
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

    test("a one-line Draft date's rowShift is exactly one lineHeight", () {
      final document = OcptWysiwygCodec.decodeWithTitlePage(
        "Draft date: 2026-07-26\n\nSome action.",
      ).document;

      final result = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics);

      expect(result.rowShift, closeTo(layout.lineHeight, 0.01));
    });

    test("an Enter-split, two-line Draft date doubles rowShift", () {
      final document = OcptWysiwygCodec.decodeWithTitlePage(
        "Draft date:\n    First line\n    Second line\n\nSome action.",
      ).document;

      final result = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics);

      expect(result.rowShift, closeTo(layout.lineHeight * 2, 0.01));
    });

    test("a document with no Draft date node has a rowShift of 0", () {
      final document = OcptWysiwygCodec.decode("Some action.").document;

      final result = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics);

      expect(result.rowShift, 0);
    });

    test("Contact wraps at half the content width, not the full width", () {
      final contentWidth = layout.pageWidth - layout.marginLeft - layout.marginRight;
      final halfColumns = (contentWidth / 2 / layout.glyphWidth).floor();
      // One word filling half the box exactly, plus a short second word: wraps to 2 lines under
      // the new half-width box, but would still fit on 1 line under the old full-width box.
      final contact = "${List.generate(halfColumns, (_) => "A").join()} B";

      final document = OcptWysiwygCodec.decodeWithTitlePage("Contact: $contact\n\nSome action.").document;

      final result = computeOcptStyledTitlePageMetrics(document: document, metrics: metrics);

      // Credit + Author + Draft date's own contributions are the same regardless of Contact's
      // text, so isolate Contact's own line count by comparing against a short Contact.
      final shortDocument = OcptWysiwygCodec.decodeWithTitlePage("Contact: x\n\nSome action.").document;
      final shortResult = computeOcptStyledTitlePageMetrics(document: shortDocument, metrics: metrics);

      expect(result.flowHeight - shortResult.flowHeight, closeTo(layout.lineHeight, 0.01));
    });
  });
}
