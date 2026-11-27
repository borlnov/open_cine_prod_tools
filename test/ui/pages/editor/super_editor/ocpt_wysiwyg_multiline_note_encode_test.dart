// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Build a text holding [before], a note whose text is [note] as a placeholder, then [after].
AttributedText _textWithNote(String before, String note, String after) =>
    AttributedText(before)
        .copyAndAppend(AttributedText("").insertPlaceholder(0, OcptFountainNote.create(note)))
        .copyAndAppend(AttributedText(after));

/// Build a body node of [type] holding [text], [blanks] blank lines before it.
ParagraphNode _node(AttributedText text, FountainLineType type, {int blanks = 0}) => ParagraphNode(
  id: Editor.createNodeId(),
  text: text,
  metadata: {
    "blockType": OcptFountainLineAttributions.attributionOf(type),
    ocptBlankLinesBeforeMetadataKey: blanks,
  },
);

/// Encode the [nodes] as a document.
OcptWysiwygEncodeResult _encode(List<ParagraphNode> nodes) =>
    OcptWysiwygCodec.encode(MutableDocument(nodes: List<DocumentNode>.of(nodes)));

/// Run the tests of the encoding of a node covering several source lines.
void main() {
  group("encode of a node holding a note running over several lines", () {
    test("writes its lines one under the other", () {
      final encoded = _encode([
        _node(_textWithNote("Hello ", "a\nb", " world"), FountainLineType.action),
      ]);

      expect(encoded.text, "Hello [[a\nb]] world");
    });

    test("puts the next node after the last of its lines", () {
      final encoded = _encode([
        _node(AttributedText("INT. HOUSE - DAY"), FountainLineType.sceneHeading),
        _node(_textWithNote("He waits ", "a\nb\nc", "."), FountainLineType.action, blanks: 1),
        _node(AttributedText("Then he leaves."), FountainLineType.action, blanks: 1),
      ]);

      expect(encoded.text, "INT. HOUSE - DAY\n\nHe waits [[a\nb\nc]].\n\nThen he leaves.");
      expect(encoded.mapping.lineOfNodeIndex(1), 2);
      expect(encoded.mapping.lineCountOfNodeIndex(1), 3);
      expect(encoded.mapping.lineOfNodeIndex(2), 6);
      expect(encoded.mapping.nodeIndexOfCharOffset(encoded.text.indexOf("c]]")), 1);
    });

    test("writes a forcing marker on its first line only", () {
      final encoded = _encode([
        _node(_textWithNote("INT. HOUSE ", "a\nb", ""), FountainLineType.sceneHeading),
      ]);

      expect(encoded.text, ".INT. HOUSE [[a\nb]]");
    });

    test("is written as it is when it holds nothing but notes", () {
      final encoded = _encode([
        _node(AttributedText("MARIE"), FountainLineType.character),
        _node(_textWithNote("", "a\n  \nb", ""), FountainLineType.action),
        _node(AttributedText("Hello."), FountainLineType.dialogue, blanks: 1),
      ]);

      // The cue needs its marker, since the parser reads a blank line after it. The notes keep
      // the dialogue open, which the real blank line the last node asks for would break.
      expect(encoded.text, "@MARIE\n[[a\n  \nb]]\nHello.");
    });

    test("leaves the following blank line alone when it does not continue a dialogue", () {
      final encoded = _encode([
        _node(_textWithNote("", "a\nb", ""), FountainLineType.action),
        _node(AttributedText("Hello."), FountainLineType.action, blanks: 1),
      ]);

      expect(encoded.text, "[[a\nb]]\n\nHello.");
    });
  });
}
