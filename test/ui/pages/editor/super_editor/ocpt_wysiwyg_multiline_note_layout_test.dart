// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_notes.dart';
import 'package:super_editor/super_editor.dart';

/// Build a text holding [before], a note whose text is [note] as a placeholder, then [after].
AttributedText _textWithNote(String before, String note, String after) => AttributedText(before)
    .copyAndAppend(AttributedText("").insertPlaceholder(0, OcptFountainNote.create(note)))
    .copyAndAppend(AttributedText(after));

/// Build a body node holding [text], [blanks] blank lines before it.
ParagraphNode _node(AttributedText text, {int blanks = 0}) => ParagraphNode(
  id: Editor.createNodeId(),
  text: text,
  metadata: {"blockType": paragraphAttribution, ocptBlankLinesBeforeMetadataKey: blanks},
);

/// Run the tests of a node covering several source lines in the layout.
void main() {
  group("a node holding a note running over several lines", () {
    test("is laid out as one line per line of its source", () {
      final nodes = [
        _node(_textWithNote("Hello ", "a\nb", " world")),
        _node(AttributedText("next"), blanks: 1),
      ];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      expect(ranges, [(0, 2), (3, 1)]);
      expect(layout.lineStarts, [0, 10, 20, 21]);
      expect(layout.classificationLines, ["Hello [[a", "b]] world", "", "next"]);
    });

    test("counts the lines of its source", () {
      expect(OcptWysiwygComments.lineCountOf(_node(_textWithNote("x ", "a\nb\nc", ""))), 3);
      expect(OcptWysiwygComments.lineCountOf(_node(_textWithNote("x ", "a", ""))), 1);
    });

    test("is inert when every character of its lines is commented", () {
      final nodes = [_node(_textWithNote("", "a\nb", "  "))];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      expect(layout.isInertOfNode(ranges[0].$1, ranges[0].$2), isTrue);
    });

    test("is inert with a line of whitespace in the middle of its note", () {
      final nodes = [_node(_textWithNote("", "a\n  \nb", ""))];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      expect(ranges, [(0, 3)]);
      expect(layout.isInertByLine, [true, false, true]);
      expect(layout.isInertOfNode(ranges[0].$1, ranges[0].$2), isTrue);
    });

    test("is live when text outside the note shares one of its lines", () {
      final nodes = [_node(_textWithNote("", "a\nb", " tail"))];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      expect(layout.isInertOfNode(ranges[0].$1, ranges[0].$2), isFalse);
    });

    test("answers its commented range over the lines joined by a newline", () {
      final nodes = [_node(_textWithNote("x ", "a\nb", " y"))];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      expect(layout.commentRangesOfNode(ranges[0].$1, ranges[0].$2), [(2, 9)]);
      expect(layout.noteRangesOfNode(ranges[0].$1, ranges[0].$2), [(2, 9)]);
      expect(
        OcptWysiwygComments.nodeRangesOf(
          nodes[0],
          layout.commentRangesOfNode(ranges[0].$1, ranges[0].$2),
        ),
        [(2, 3)],
      );
    });

    test("answers the stars of a boneyard on a later line relative to its text", () {
      final nodes = [_node(_textWithNote("", "a\nb", " /* c */"))];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      // The text is "[[a\nb]] /* c */": the stars are the second of `/*` and the first of `*/`.
      expect(layout.boneyardStarsOfNode(ranges[0].$1, ranges[0].$2), [9, 13]);
    });

    test("leaves out a note that opens in it and closes in the next node", () {
      final nodes = [_node(AttributedText("x [[a")), _node(AttributedText("b]] y"))];

      final (layout, ranges) = OcptWysiwygComments.layoutOfNodes(nodes);

      expect(layout.noteRangesOfNode(ranges[0].$1, ranges[0].$2), isEmpty);
      expect(layout.commentRangesOfNode(ranges[0].$1, ranges[0].$2), [(2, 5)]);
      expect(layout.commentRangesOfNode(ranges[1].$1, ranges[1].$2), [(0, 3)]);
    });
  });

  group("the note passes and a note running over several lines", () {
    test("a decode absorbs it into a placeholder", () {
      final node = _node(AttributedText("x [[a\nb]] y"));

      final absorbed = OcptWysiwygNotes.absorbedNodes([node]).single;

      expect(absorbed.text.toPlainText(), "x ￼ y");
      expect((absorbed.text.placeholders[2]! as OcptFountainNote).text, "a\nb");
    });

    test("a live pass leaves a placeholder holding a newline as it is", () {
      final document = MutableDocument(
        nodes: <DocumentNode>[_node(_textWithNote("x ", "a\nb", " y"))],
      );

      expect(OcptWysiwygNotes.requests(document), isEmpty);
    });

    test("a live pass keeps it whatever opens before it", () {
      final document = MutableDocument(
        nodes: <DocumentNode>[_node(_textWithNote("[[x ", "a\nb", " y"))],
      );

      expect(OcptWysiwygNotes.requests(document), isEmpty);
    });

    test("a live pass never makes one from text holding a newline", () {
      final document = MutableDocument(
        nodes: <DocumentNode>[_node(AttributedText("x [[a\nb]] y"))],
      );

      expect(OcptWysiwygNotes.requests(document), isEmpty);
    });

    test("a live pass still absorbs a note on one line beside it", () {
      final document = MutableDocument(
        nodes: <DocumentNode>[_node(_textWithNote("[[c]] ", "a\nb", " y"))],
      );

      final requests = OcptWysiwygNotes.requests(document);

      expect(requests, hasLength(1));
    });
  });
}
