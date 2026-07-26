// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// Builds a styled editor document from [source], the same way the live editor decodes one.
MutableDocument _documentFrom(String source) => OcptWysiwygCodec.decode(source).document;

/// A screenplay long enough to span several pages at [FountainLayoutMetrics.usLetter]'s
/// `linesPerPage` (54): 80 short, one-line action paragraphs, each separated by a blank line.
final String _longSource = List.generate(80, (index) => "Action line $index.").join("\n\n");

void main() {
  final metrics = FountainLayoutMetrics.usLetter();

  group("computeOcptStyledPagination", () {
    test("an empty document is a single page with no page-start node", () {
      final pagination = computeOcptStyledPagination(document: _documentFrom(""), metrics: metrics);

      expect(pagination.pageCount, 1);
      expect(pagination.pageStartNodeIds, isEmpty);
    });

    test("a short document is a single page with no page-start node", () {
      final document = _documentFrom("INT. KITCHEN - DAY\n\nSomething moves in the dark.");

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, 1);
      expect(pagination.pageStartNodeIds, isEmpty);
    });

    test("a document long enough to exceed linesPerPage spans multiple pages", () {
      final document = _documentFrom(_longSource);

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, greaterThan(1));
      expect(pagination.pageStartNodeIds, isNotEmpty);
      // The very first node never starts a "new" page: there is nothing above it to separate from.
      expect(pagination.pageStartNodeIds, isNot(contains(document.getNodeAt(0)!.id)));
    });

    test("every page-start node id actually belongs to the document", () {
      final document = _documentFrom(_longSource);

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      final nodeIds = document.map((node) => node.id).toSet();
      expect(nodeIds.containsAll(pagination.pageStartNodeIds), isTrue);
    });

    test("a forced page break always starts a fresh page, even with little content", () {
      final document = _documentFrom("Some action.\n\n===\n\nMore action.");
      final pageBreakNode = document.firstWhere(
        (node) =>
            OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")) ==
            FountainLineType.pageBreak,
      );

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, 2);
      expect(pagination.pageStartNodeIds, {pageBreakNode.id});
    });

    test("two consecutive forced page breaks each start their own page", () {
      final document = _documentFrom("Some action.\n\n===\n\n===\n\nMore action.");
      final pageBreakNodeIds = document
          .where(
            (node) =>
                OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")) ==
                FountainLineType.pageBreak,
          )
          .map((node) => node.id)
          .toSet();

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, 3);
      expect(pagination.pageStartNodeIds, pageBreakNodeIds);
    });

    test(
      "a page-start node's exact top padding lands its text precisely at its sheet's text origin",
      () {
        final document = _documentFrom("Some action.\n\n===\n\nMore action.");
        final layout = OcptEditorPreviewLayout(metrics: metrics);
        final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

        final pageBreakNode = document.firstWhere(
          (node) =>
              OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")) ==
              FountainLineType.pageBreak,
        );

        // "Some action." is the only node before the break: one wrapped line, no blank line
        // before it (it's the document's first node).
        final flowYBeforeBreak = layout.marginTop + layout.lineHeight;
        // The break line carries one blank source line before it (the blank line separating it
        // from "Some action." in the source): `OcptFountainEditorStylesheet` renders that as its
        // own `ocptBlankLinesBefore` top padding, stacked on top of the page-boundary padding
        // asserted below, so the padding itself must be smaller by exactly that much.
        const blankLinesBeforeBreak = 1;
        final blankLinesPadding = blankLinesBeforeBreak * layout.lineHeight;
        final desiredSheetTextOrigin =
            (layout.pageHeight + OcptEditorPreviewLayout.pageGap) + layout.marginTop;
        final expectedPadding = desiredSheetTextOrigin - flowYBeforeBreak - blankLinesPadding;

        expect(pagination.pageStartTopPaddings[pageBreakNode.id], closeTo(expectedPadding, 0.01));

        // The identity the padding exists to guarantee: flow height so far, plus this node's
        // page-boundary padding, plus its own blank-line padding, lands exactly at the sheet's
        // text origin — not one `lineHeight` short (the bug a naive `marginTop + marginBottom +
        // pageGap` estimate, or forgetting to subtract the blank-line padding, would produce).
        final actualTextOrigin =
            flowYBeforeBreak + pagination.pageStartTopPaddings[pageBreakNode.id]! + blankLinesPadding;
        expect(actualTextOrigin, closeTo(desiredSheetTextOrigin, 0.01));
      },
    );

    test(
      "a document short enough to fit one page still gets trailing bottom padding filling it to "
      "its sheet's full height",
      () {
        final document = _documentFrom("Some action.");
        final layout = OcptEditorPreviewLayout(metrics: metrics);
        final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

        expect(pagination.pageCount, 1);
        // marginTop (the document's own top padding while page simulation is on) plus one
        // wrapped line of text is the only content; the rest of the sheet must be reserved as
        // trailing bottom padding so the document's scrollable content actually reaches the
        // bottom of its (only) simulated sheet.
        final contentHeight = layout.marginTop + layout.lineHeight;
        expect(contentHeight + pagination.trailingBottomPadding, closeTo(layout.pageHeight, 0.01));
      },
    );

    test("a multi-page document's trailing bottom padding reaches exactly the last sheet's bottom edge", () {
      final document = _documentFrom(_longSource);
      final layout = OcptEditorPreviewLayout(metrics: metrics);
      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, greaterThan(1));

      // Independently replay the same flow the production pass tracks, using only the public
      // building blocks (`OcptEditorPreviewLayout.wrappedLineCount`, the `ocptBlankLinesBefore`
      // metadata, and `pagination.pageStartTopPaddings`), to verify the *combined* effect of
      // every page-start padding plus the trailing padding lands exactly at the last sheet's
      // bottom edge — not just that each individual padding looks plausible in isolation.
      var flowY = layout.marginTop;
      for (final node in document) {
        if (node is! ParagraphNode) {
          continue;
        }
        final padding = pagination.pageStartTopPaddings[node.id];
        if (padding != null) {
          flowY += padding;
        }
        final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
        final wrappedLines = OcptEditorPreviewLayout.wrappedLineCount(
          node.text.toPlainText(),
          _elementMaxWidthColumnsOf(type, metrics),
        );
        final blankLinesBefore = (node.getMetadataValue(ocptBlankLinesBeforeMetadataKey) as int? ?? 0).clamp(
          0,
          ocptMaxBlankLinesBeforeSpacing,
        );
        flowY += (wrappedLines + blankLinesBefore) * layout.lineHeight;
      }

      final desiredBottomY =
          (pagination.pageCount - 1) * (layout.pageHeight + OcptEditorPreviewLayout.pageGap) + layout.pageHeight;
      expect(flowY + pagination.trailingBottomPadding, closeTo(desiredBottomY, 0.01));
    });
  });

  group("computeOcptStyledPagination with a title page", () {
    /// Builds a styled editor document from [source] the same way the live editor decodes one
    /// while page simulation is on: with its leading title-page field nodes.
    MutableDocument documentWithTitlePageFrom(String source) => OcptWysiwygCodec.decodeWithTitlePage(source).document;

    test("a title page always reserves page 1, whatever little content the body has", () {
      final document = documentWithTitlePageFrom("Some action.");

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, 2);
      // The body's one and only node is the document's 7th (index 6, after the six title-page
      // field nodes): it must be flagged as starting a page of its own.
      final bodyNode = document.getNodeAt(6)!;
      expect(pagination.pageStartNodeIds, contains(bodyNode.id));
      expect(pagination.pageStartTopPaddings[bodyNode.id], greaterThan(0));
    });

    test("a longer body still starts on page 2, then paginates normally from there", () {
      final document = documentWithTitlePageFrom(_longSource);

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      // At least the forced title-to-body break, plus whatever `_longSource` alone would need
      // (already asserted to be `greaterThan(1)` on its own, title-page-free, above).
      expect(pagination.pageCount, greaterThan(2));
    });

    test("a document with no title-page nodes at all behaves exactly as without this feature", () {
      final document = _documentFrom("Some action.");

      final pagination = computeOcptStyledPagination(document: document, metrics: metrics);

      expect(pagination.pageCount, 1);
      expect(pagination.pageStartNodeIds, isEmpty);
    });
  });
}

/// Mirrors `OcptFountainEditorStylesheet`'s own element choice per [type] (in particular lyrics
/// sharing the dialogue box, and every non-printing/scaffolding type using the full-width action
/// box), used only to independently recompute the expected flow in the test above without relying
/// on the pagination module's own private helper.
int _elementMaxWidthColumnsOf(FountainLineType type, FountainLayoutMetrics metrics) => switch (type) {
  FountainLineType.sceneHeading => metrics.sceneHeading.maxWidthColumns,
  FountainLineType.character => metrics.character.maxWidthColumns,
  FountainLineType.parenthetical => metrics.parenthetical.maxWidthColumns,
  FountainLineType.dialogue => metrics.dialogue.maxWidthColumns,
  FountainLineType.lyrics => metrics.dialogue.maxWidthColumns,
  FountainLineType.transition => metrics.transition.maxWidthColumns,
  FountainLineType.centeredText => metrics.centeredText.maxWidthColumns,
  FountainLineType.pageBreak => metrics.centeredText.maxWidthColumns,
  FountainLineType.section ||
  FountainLineType.synopsis ||
  FountainLineType.action ||
  FountainLineType.blank => metrics.action.maxWidthColumns,
};
