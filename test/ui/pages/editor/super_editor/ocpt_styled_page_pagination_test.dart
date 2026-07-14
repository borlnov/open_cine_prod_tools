// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
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
  });
}
