// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
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

/// Get the text of the node at [index] of [document].
AttributedText _textAt(Document document, int index) =>
    (document.getNodeAt(index)! as ParagraphNode).text;

/// Get the texts of the notes the node at [index] of [document] holds as placeholders.
List<String> _notesAt(Document document, int index) => [
  for (final placeholder in _textAt(document, index).placeholders.values)
    (placeholder as OcptFountainNote).text,
];

/// Run the tests of the notes running over several lines, folded into one node at decode.
void main() {
  group("a note running over several lines is folded into one node", () {
    test("in the middle of a line of action", () {
      const source = "He looks [[a\nb]] away.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(typeAt(decoded.document, 0), FountainLineType.action);
      expect(_textAt(decoded.document, 0).toPlainText(), "He looks ￼ away.");
      expect(_notesAt(decoded.document, 0), ["a\nb"]);
      expect(decoded.mapping.lineCountOfNodeIndex(0), 2);
      expect(_roundTrip(source), source);
    });

    test("alone on its lines, as an inert node", () {
      const source = "[[a\nb]]";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(typeAt(decoded.document, 0), FountainLineType.action);
      expect(_notesAt(decoded.document, 0), ["a\nb"]);
      expect(OcptWysiwygCodec.inertNodeIds(decoded.document), hasLength(1));
      expect(_roundTrip(source), source);
    });

    test("with a line of two spaces left inside, which keeps it a note", () {
      const source = "[[a\n  \nb]]";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(_notesAt(decoded.document, 0), ["a\n  \nb"]);
      expect(decoded.mapping.lineCountOfNodeIndex(0), 3);
      expect(_roundTrip(source), source);
    });

    test("with the lines around it", () {
      const source = "INT. HOUSE - DAY\n\nHe looks [[a\nb]] away.\n\nShe waits.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 3);
      expect(typeAt(decoded.document, 0), FountainLineType.sceneHeading);
      expect(blanksBeforeAt(decoded.document, 1), 1);
      expect(blanksBeforeAt(decoded.document, 2), 1);
      expect(decoded.mapping.lineOfNodeIndex(2), 5);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("b]]")), 1);
      expect(_roundTrip(source), source);
    });

    test("right before a scene heading", () {
      const source = "He waits [[a\nb]]\n\nINT. HOUSE - DAY\n\nHe leaves.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 3);
      expect(typeAt(decoded.document, 1), FountainLineType.sceneHeading);
      expect(_roundTrip(source), source);
    });

    test("as an inert node right before the line that is a scene heading after it", () {
      const source = "[[a\nb]]\nINT. HOUSE - DAY\n\nHe leaves.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 3);
      expect(typeAt(decoded.document, 1), FountainLineType.sceneHeading);
      expect(_roundTrip(source), source);
    });

    test("inside a dialogue", () {
      const source = "MARIE\nHello [[a\nb]] there.\n(beat)\nGoodbye.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 4);
      expect(typeAt(decoded.document, 0), FountainLineType.character);
      expect(typeAt(decoded.document, 1), FountainLineType.dialogue);
      expect(_notesAt(decoded.document, 1), ["a\nb"]);
      expect(typeAt(decoded.document, 2), FountainLineType.parenthetical);
      expect(_roundTrip(source), source);
    });

    test("after a character cue, whose first line the classifier reads as a dialogue", () {
      const source = "MARIE\n(beat [[a\nb]])\nHello.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 3);
      expect(typeAt(decoded.document, 1), FountainLineType.dialogue);
      expect(_notesAt(decoded.document, 1), ["a\nb"]);
      expect(_roundTrip(source), source);
    });

    test("right after a character cue, on lines of its own", () {
      const source = "MARIE\n[[a\nb]]\nHello.";

      expect(_roundTrip(source), source);
    });

    test("next to a boneyard that does not touch its lines", () {
      const source = "He looks [[a\nb]] away.\n/* c */\nShe waits.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 3);
      expect(_notesAt(decoded.document, 0), ["a\nb"]);
      expect(_roundTrip(source), source);
    });

    test("twice in one node", () {
      const source = "a [[x\ny]] b [[z\nw]] c";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(_notesAt(decoded.document, 0), ["x\ny", "z\nw"]);
      expect(decoded.mapping.lineCountOfNodeIndex(0), 3);
      expect(_roundTrip(source), source);
    });

    test("beside a note on one line", () {
      const source = "a [[x\ny]] b [[z]] c";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(_notesAt(decoded.document, 0), ["x\ny", "z"]);
      expect(_roundTrip(source), source);
    });

    test("with a forcing marker on its first line", () {
      const source = "!INT. HOUSE [[a\nb]]";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(_textAt(decoded.document, 0).toPlainText(), "INT. HOUSE ￼");
      expect(_roundTrip(source), source);
    });

    test("when the classifier reads every one of its lines as the same element", () {
      const source = "MARIE [[aside\nmore]] INT. HOUSE - DAY";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 1);
      expect(typeAt(decoded.document, 0), FountainLineType.action);
      expect(_roundTrip(source), source);
    });

    test("when pasted", () {
      final nodes = OcptWysiwygCodec.decodeNodesFromFountain("a [[x\ny]] b\n\nc");

      expect(nodes, hasLength(2));
      expect((nodes[0].text.placeholders.values.single as OcptFountainNote).text, "x\ny");
    });
  });

  group("a note running over several lines stays text when folding it would change the lines", () {
    test("with a boneyard on one of its lines", () {
      const source = "x [[a\nb]] /* c */";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 2);
      expect(_roundTrip(source), source);
    });

    test("with a boneyard inside the note", () {
      const source = "x [[a /* c */\nb]] y";

      expect(OcptWysiwygCodec.decode(source).document.nodeCount, 2);
      expect(_roundTrip(source), source);
    });

    test("with a blank line inside a live node", () {
      const source = "x [[a\n\nb]] y";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 2);
      expect(_roundTrip(source), source);
    });

    test("escaped, the note being none", () {
      final decoded = OcptWysiwygCodec.decode("x \\[[a\nb]] y");

      expect(decoded.document.nodeCount, 2);
      expect(_textAt(decoded.document, 0).placeholders, isEmpty);
      expect(_textAt(decoded.document, 1).placeholders, isEmpty);
    });

    test("whose lines are not one element", () {
      const source = "MARIE [[aside\nmore]]\n\nINT. HOUSE - DAY";

      expect(_roundTrip(source), source);
    });

    test("closing on a line that is another element", () {
      const source = "x [[a\n.INT. HOUSE]] y";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.document.nodeCount, 2);
      expect(_roundTrip(source), source);
    });

    test("with a character cue for a first line", () {
      const source = "\nMARIE [[A\nb]]\n";

      expect(_roundTrip(source), source);
    });

    test("opened and never closed", () {
      const source = "x [[a\nb y";

      expect(OcptWysiwygCodec.decode(source).document.nodeCount, 2);
      expect(_roundTrip(source), source);
    });

    test("with a note after the first one on the same lines", () {
      const source = "x [[a\nb]] y [[c\nd]] [[e]]\n\n[[f\ng]]\nz";

      expect(_roundTrip(source), source);
    });
  });

  group("changing the type of a folded node", () {
    /// Change the type of the node at [index] of [document] to [type].
    void retype(MutableDocument document, int index, FountainLineType type) {
      final node = document.getNodeAt(index)! as ParagraphNode;
      document.replaceNodeById(
        node.id,
        node.copyWithAddedMetadata({"blockType": OcptFountainLineAttributions.attributionOf(type)}),
      );
    }

    for (final type in [
      FountainLineType.sceneHeading,
      FountainLineType.character,
      FountainLineType.transition,
      FountainLineType.section,
      FountainLineType.centeredText,
      FountainLineType.dialogue,
    ]) {
      test("to ${type.name} reaches a fixed point and loses no character", () {
        const source = "Hello [[a\nb]] world";
        final document = OcptWysiwygCodec.decode(source).document;
        retype(document, 0, type);

        final first = OcptWysiwygCodec.encode(document).text;
        final second = _roundTrip(first);
        final third = _roundTrip(second);

        expect(second, third);
        for (final part in ["Hello", "[[a", "b]]", "world"]) {
          expect(second, contains(part));
        }
      });
    }
  });
}
