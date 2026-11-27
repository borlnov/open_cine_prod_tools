// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// Decode [source], encode it back and get the text written.
String _roundTrip(String source) {
  final decoded = OcptWysiwygCodec.decode(source);
  return OcptWysiwygCodec.encode(
    decoded.document,
    trailingBlankLines: decoded.trailingBlankLines,
  ).text;
}

/// Get a selection of the node at [index] of [document] from offset [from] to offset [to].
DocumentSelection _selectionIn(Document document, int index, int from, int to) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  return DocumentSelection(
    base: DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: from),
    ),
    extent: DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: to),
    ),
  );
}

/// Run the tests of what a node covering several lines does to what reads the nodes around it.
void main() {
  group("a clip cutting a node holding a note running over several lines", () {
    // The text of the node is "He looks ￼ away.": the note is the character at offset 9.
    const source = "He looks [[a\nb]] away.";

    test("keeps the note whole when it ends right after it", () {
      final document = OcptWysiwygCodec.decode(source).document;

      expect(
        OcptWysiwygCodec.encodeSelectionToFountain(document, _selectionIn(document, 0, 0, 10)),
        "He looks [[a\nb]]",
      );
    });

    test("keeps the note whole when it starts right before it", () {
      final document = OcptWysiwygCodec.decode(source).document;

      expect(
        OcptWysiwygCodec.encodeSelectionToFountain(document, _selectionIn(document, 0, 9, 14)),
        "[[a\nb]] awa",
      );
    });

    test("leaves the note out when the cut ends before it", () {
      final document = OcptWysiwygCodec.decode(source).document;

      expect(
        OcptWysiwygCodec.encodeSelectionToFountain(document, _selectionIn(document, 0, 0, 9)),
        "He looks ",
      );
    });

    test("is decoded into a node holding the note again", () {
      final document = OcptWysiwygCodec.decode(source).document;
      final clip = OcptWysiwygCodec.encodeSelectionToFountain(
        document,
        _selectionIn(document, 0, 3, 16),
      );

      final nodes = OcptWysiwygCodec.decodeNodesFromFountain(clip);

      expect(nodes, hasLength(1));
      expect((nodes.single.text.placeholders.values.single as OcptFountainNote).text, "a\nb");
    });
  });

  group("a dialogue holding a note running over several lines", () {
    const source = "ROSS\nHello [[a\nb]] there.\n\nKIM ^\nHi [[c\nd]].\n";

    test("round-trips byte for byte", () {
      expect(_roundTrip(source), source);
    });

    test("is a speech of its own in the pairs", () {
      final document = OcptWysiwygCodec.decode(source).document;

      expect(document.nodeCount, 4);
      expect(OcptWysiwygDualDialogue.groupsOf(document), hasLength(2));
      expect(OcptWysiwygDualDialogue.pairsOf(document), hasLength(1));
    });

    test("is toggled like any other from a caret in it", () {
      final document = OcptWysiwygCodec.decode("ROSS\nHello [[a\nb]] there.\n\nKIM\nHi [[c\nd]].\n")
          .document;

      final requests = OcptWysiwygDualDialogue.toggleRequestsAt(
        document,
        document.getNodeAt(1)!.id,
      );

      expect(requests, isNotNull);
    });

    test("does not stop the pairing from reading the lines after it", () {
      final decoded = OcptWysiwygCodec.decode("A\nx [[a\nb]]\n\nB ^\ny\n\nC\nz\n\nD ^\nw\n");

      expect(OcptWysiwygDualDialogue.pairsOf(decoded.document), hasLength(2));
      expect(decoded.mapping.lineOfNodeIndex(2), 4);
    });
  });

  group("a node holding a note running over several lines, in the passes of a settle", () {
    test("is left alone by the classification, the numbering and the uppercase passes", () {
      final document = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY\n\nHe looks [[a\nb]] away.\n\n[[c\nd]]\n\nmarie [[e\nf]]",
      ).document;

      expect(OcptWysiwygCodec.reclassifyRequests(document), isEmpty);
      expect(OcptWysiwygCodec.sceneNumberRequests(document), isEmpty);
      expect(OcptWysiwygCodec.uppercaseRequests(document), isEmpty);
      expect(OcptWysiwygCodec.noteRequests(document), isEmpty);
      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty);
      expect(OcptWysiwygCodec.commentAttributionRequests(document), isEmpty);
    });

    test("keeps its type when its first line is read in the context of the lines before", () {
      final document = OcptWysiwygCodec.decode("MARIE\nHello [[a\nb]] there.").document;

      expect(typeAt(document, 1), FountainLineType.dialogue);
      expect(OcptWysiwygCodec.reclassifyRequests(document), isEmpty);
    });
  });
}
