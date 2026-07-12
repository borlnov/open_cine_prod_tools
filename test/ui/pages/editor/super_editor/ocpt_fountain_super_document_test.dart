// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_super_document.dart';
import 'package:super_editor/super_editor.dart';

/// Reads the classified [FountainLineType] the node at [index] of [document] currently carries.
FountainLineType _typeAt(Document document, int index) => OcptFountainLineAttributions.typeOfAttributionValue(
  document.getNodeAt(index)!.getMetadataValue("blockType"),
);

/// Replaces the text of the node at [index] of [document] with [newText], keeping its id (so a
/// caller can then re-run [OcptFountainSuperDocument.reclassifyRequests] on the mutated document,
/// the same way a real edit would change a node's text before the next classification pass).
void _replaceText(MutableDocument document, int index, String newText) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  document.replaceNodeById(node.id, node.copyParagraphWith(text: AttributedText(newText)));
}

void main() {
  group("OcptFountainSuperDocument.buildDocument", () {
    test("builds one node per source line, blank lines included, with the line's classified type", () {
      final document = OcptFountainSuperDocument.buildDocument("INT. HOUSE - DAY\n\nSARAH\nHello.");

      expect(document.nodeCount, 4);
      expect(_typeAt(document, 0), FountainLineType.sceneHeading);
      expect(_typeAt(document, 1), FountainLineType.blank);
      expect(_typeAt(document, 2), FountainLineType.character);
      expect(_typeAt(document, 3), FountainLineType.dialogue);
    });

    test("an empty source text still builds a single (blank) node", () {
      final document = OcptFountainSuperDocument.buildDocument("");

      expect(document.nodeCount, 1);
      expect((document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "");
    });

    test("normalizes CRLF line endings before splitting", () {
      final document = OcptFountainSuperDocument.buildDocument("Action one.\r\nAction two.");

      expect(document.nodeCount, 2);
      expect((document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "Action one.");
      expect((document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "Action two.");
    });
  });

  group("OcptFountainSuperDocument.joinText", () {
    test("round-trips a document built from a multi-line source back to the same text", () {
      const source = "INT. HOUSE - DAY\n\nSARAH\n(to herself)\nHello.\n\nEXT. GARDEN - NIGHT\n\nSilence.";
      final document = OcptFountainSuperDocument.buildDocument(source);

      expect(OcptFountainSuperDocument.joinText(document), source);
    });

    test("round-trips an empty source", () {
      final document = OcptFountainSuperDocument.buildDocument("");

      expect(OcptFountainSuperDocument.joinText(document), "");
    });

    test("round-trips text with a trailing blank line", () {
      const source = "Some action.\n\n";
      final document = OcptFountainSuperDocument.buildDocument(source);

      expect(OcptFountainSuperDocument.joinText(document), source);
    });
  });

  group("OcptFountainSuperDocument.reclassifyRequests", () {
    test("requests a blockType change when typing turns an action line into a scene heading", () {
      final document = OcptFountainSuperDocument.buildDocument("\nSome action\n");
      expect(_typeAt(document, 1), FountainLineType.action);

      _replaceText(document, 1, "INT. HOUSE - DAY");
      final requests = OcptFountainSuperDocument.reclassifyRequests(document).cast<ChangeParagraphBlockTypeRequest>();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, document.getNodeAt(1)!.id);
      expect(requests.single.blockType, OcptFountainLineAttributions.attributionOf(FountainLineType.sceneHeading));
    });

    test("returns no request when no line's classified type actually changed", () {
      final document = OcptFountainSuperDocument.buildDocument("INT. HOUSE - DAY\n\nAction.");

      expect(OcptFountainSuperDocument.reclassifyRequests(document), isEmpty);
    });

    test("inserting a blank line re-classifies a previously-unrecognized scene heading candidate", () {
      // "INT HOUSE DAY" isn't preceded and followed by a blank line here, so the classifier
      // doesn't recognize it as a scene heading yet: it falls back to plain action text.
      final document = OcptFountainSuperDocument.buildDocument("Some text\nINT HOUSE DAY\nMore text");
      expect(_typeAt(document, 1), FountainLineType.action);

      // Insert a blank node before and after it, exactly like the user pressing Enter around it
      // (already carrying the correct "blank" blockType, as a freshly re-classified node would,
      // to isolate this test to the heading's own re-classification).
      final headingNode = document.getNodeAt(1)!;
      final blankMetadata = {"blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.blank)};
      document
        ..insertNodeBefore(
          existingNodeId: headingNode.id,
          newNode: ParagraphNode(id: "blank-before", text: AttributedText(""), metadata: blankMetadata),
        )
        ..insertNodeAfter(
          existingNodeId: headingNode.id,
          newNode: ParagraphNode(id: "blank-after", text: AttributedText(""), metadata: blankMetadata),
        );

      final requests = OcptFountainSuperDocument.reclassifyRequests(document).cast<ChangeParagraphBlockTypeRequest>();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, headingNode.id);
      expect(requests.single.blockType, OcptFountainLineAttributions.attributionOf(FountainLineType.sceneHeading));
    });
  });

  group("OcptFountainSuperDocument.lineIndexForCharOffset", () {
    test("returns the 0-based line number containing the offset", () {
      const text = "line0\nline1\nline2";

      expect(OcptFountainSuperDocument.lineIndexForCharOffset(text, 0), 0);
      expect(OcptFountainSuperDocument.lineIndexForCharOffset(text, text.indexOf("line1")), 1);
      expect(OcptFountainSuperDocument.lineIndexForCharOffset(text, text.indexOf("line2")), 2);
    });

    test("clamps an out-of-range offset to the text's length", () {
      const text = "line0\nline1";

      expect(OcptFountainSuperDocument.lineIndexForCharOffset(text, text.length + 10), 1);
      expect(OcptFountainSuperDocument.lineIndexForCharOffset(text, -5), 0);
    });
  });
}
