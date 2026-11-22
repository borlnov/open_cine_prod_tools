// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Build a one-paragraph document holding [text], with [metadata] on its node.
MutableDocument _document(String text, {Map<String, dynamic>? metadata}) => MutableDocument(
  nodes: [ParagraphNode(id: "n", text: AttributedText(text), metadata: metadata)],
);

/// Build a selection of the node "n" from offset [base] to [extent].
DocumentSelection _selection(int base, [int? extent]) => DocumentSelection(
  base: DocumentPosition(
    nodeId: "n",
    nodePosition: TextNodePosition(offset: base),
  ),
  extent: DocumentPosition(
    nodeId: "n",
    nodePosition: TextNodePosition(offset: extent ?? base),
  ),
);

/// Read the text the first request of [requests] writes.
String _writtenText(List<EditRequest> requests) =>
    (requests.first as OcptReplaceNodeTextRequest).text.toPlainText();

/// Read the caret offset the last request of [requests] places.
int _caretOffset(List<EditRequest> requests) =>
    ((requests.last as ChangeSelectionRequest).newSelection!.extent.nodePosition
            as TextNodePosition)
        .offset;

/// Run the tests of [OcptFountainNoteActions].
void main() {
  group("insertRequests", () {
    test("a collapsed caret gets an empty note with the caret between the brackets", () {
      final requests = OcptFountainNoteActions.insertRequests(
        _document("Hello world"),
        _selection(5),
      )!;

      expect(_writtenText(requests), "Hello[[]] world");
      expect(_caretOffset(requests), 7);
    });

    test("a selection inside one block is wrapped, the caret just before the closing brackets", () {
      final requests = OcptFountainNoteActions.insertRequests(
        _document("Hello big world"),
        _selection(6, 9),
      )!;

      expect(_writtenText(requests), "Hello [[big]] world");
      expect(_caretOffset(requests), 11);
    });

    test("a backwards selection is wrapped the same way", () {
      final requests = OcptFountainNoteActions.insertRequests(
        _document("Hello big world"),
        _selection(9, 6),
      )!;

      expect(_writtenText(requests), "Hello [[big]] world");
    });

    test("is withheld without a selection", () {
      expect(OcptFountainNoteActions.insertRequests(_document("Hello"), null), isNull);
    });

    test("is withheld for a selection spanning several blocks", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: "n", text: AttributedText("One")),
          ParagraphNode(id: "m", text: AttributedText("Two")),
        ],
      );
      final selection = const DocumentSelection(
        base: DocumentPosition(nodeId: "n", nodePosition: TextNodePosition(offset: 1)),
        extent: DocumentPosition(nodeId: "m", nodePosition: TextNodePosition(offset: 2)),
      );

      expect(OcptFountainNoteActions.insertRequests(document, selection), isNull);
    });

    test("is withheld with the caret inside a note, but not right beside it", () {
      final document = _document("a [[note]] b");

      expect(OcptFountainNoteActions.insertRequests(document, _selection(6)), isNull);
      expect(OcptFountainNoteActions.insertRequests(document, _selection(2)), isNotNull);
      expect(OcptFountainNoteActions.insertRequests(document, _selection(10)), isNotNull);
    });

    test("is withheld for a selection inside or overlapping a note", () {
      final document = _document("a [[note]] b");

      expect(OcptFountainNoteActions.insertRequests(document, _selection(4, 8)), isNull);
      expect(OcptFountainNoteActions.insertRequests(document, _selection(0, 5)), isNull);
      expect(OcptFountainNoteActions.insertRequests(document, _selection(0, 11)), isNull);
    });

    test("is withheld on a title-page field", () {
      final document = _document("Title", metadata: {ocptTitlePageKeyMetadataKey: "title"});

      expect(OcptFountainNoteActions.insertRequests(document, _selection(2)), isNull);
    });

    test("is withheld on a page break", () {
      final document = _document(
        "===",
        metadata: {
          "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.pageBreak),
        },
      );

      expect(OcptFountainNoteActions.insertRequests(document, _selection(1)), isNull);
    });
  });

  group("removeRequests", () {
    test("a caret inside a note removes the whole range, caret where it started", () {
      final requests = OcptFountainNoteActions.removeRequests(
        _document("a [[note]] b"),
        _selection(6),
      )!;

      expect(_writtenText(requests), "a b");
      expect(_caretOffset(requests), 1);
    });

    test("a selection wholly inside a note removes the whole range", () {
      final requests = OcptFountainNoteActions.removeRequests(
        _document("a [[note]] b"),
        _selection(4, 8),
      )!;

      expect(_writtenText(requests), "a b");
    });

    test("only the note the caret is in goes", () {
      final requests = OcptFountainNoteActions.removeRequests(
        _document("[[one]] and [[two]]"),
        _selection(15),
      )!;

      expect(_writtenText(requests), "[[one]] and");
      expect(_caretOffset(requests), 11);
    });

    test("takes the space a note opening the line leaves behind, and none it never had", () {
      expect(
        _writtenText(
          OcptFountainNoteActions.removeRequests(_document("[[x]] word"), _selection(2))!,
        ),
        "word",
      );
      expect(
        _writtenText(OcptFountainNoteActions.removeRequests(_document("a[[x]] b"), _selection(3))!),
        "a b",
      );
    });

    test("is withheld with the caret outside any note", () {
      final document = _document("a [[note]] b");

      expect(OcptFountainNoteActions.removeRequests(document, _selection(1)), isNull);
      expect(OcptFountainNoteActions.removeRequests(document, _selection(11)), isNull);
    });

    test("is withheld for a selection reaching outside the note", () {
      expect(
        OcptFountainNoteActions.removeRequests(_document("a [[note]] b"), _selection(0, 6)),
        isNull,
      );
    });

    test("is withheld without a selection and over an unclosed note", () {
      expect(OcptFountainNoteActions.removeRequests(_document("[[a]]"), null), isNull);
      expect(OcptFountainNoteActions.removeRequests(_document("[[open"), _selection(4)), isNull);
    });
  });

  group("removeRequests over several blocks", () {
    /// Build a document of one paragraph per entry of [texts], the nodes "a", "b", "c"...
    MutableDocument documentOf(List<String> texts) => MutableDocument(
      nodes: [
        for (var index = 0; index < texts.length; index++)
          ParagraphNode(
            id: String.fromCharCode(97 + index),
            text: AttributedText(texts[index]),
            metadata: {ocptBlankLinesBeforeMetadataKey: index == 0 ? 0 : 1},
          ),
      ],
    );

    /// Build a caret at [offset] of the node [nodeId].
    DocumentSelection caret(String nodeId, int offset) => DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: offset),
      ),
    );

    /// Build an [Editor] over [document].
    Editor editorOf(MutableDocument document) => Editor(
      editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
      isHistoryEnabled: true,
      requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
        ..add(ocptChangeNodeMetadataRequestHandler)
        ..add(ocptReplaceNodeTextRequestHandler),
    );

    /// Read the texts of [document]'s paragraphs.
    List<String> textsOf(Document document) => [
      for (final node in document) (node as ParagraphNode).text.toPlainText(),
    ];

    test("a caret in the middle block joins the first and last blocks", () {
      final document = documentOf(["See [[a note", "in the", "middle]] here", "Next."]);
      final requests = OcptFountainNoteActions.removeRequests(document, caret("b", 3))!;

      editorOf(document).execute(requests);

      expect(textsOf(document), ["See here", "Next."]);
    });

    test("a selection wholly inside the note, over two blocks, removes it too", () {
      final document = documentOf(["[[a note", "over two]]", "Next."]);
      const selection = DocumentSelection(
        base: DocumentPosition(nodeId: "a", nodePosition: TextNodePosition(offset: 3)),
        extent: DocumentPosition(nodeId: "b", nodePosition: TextNodePosition(offset: 4)),
      );

      editorOf(document).execute(OcptFountainNoteActions.removeRequests(document, selection)!);

      expect(textsOf(document), ["Next."]);
    });

    test("a note taking whole blocks drops them and keeps the spacing of what follows", () {
      final document = documentOf(["Before.", "[[a note", "over two]]", "After."]);

      editorOf(document).execute(OcptFountainNoteActions.removeRequests(document, caret("b", 4))!);

      expect(textsOf(document), ["Before.", "After."]);
      expect(document.getNodeById("d")!.getMetadataValue(ocptBlankLinesBeforeMetadataKey), 1);
    });

    test("a note opening the body leaves no blank line before what follows", () {
      final document = documentOf(["[[a note", "over two]]", "After."]);

      editorOf(document).execute(OcptFountainNoteActions.removeRequests(document, caret("a", 4))!);

      expect(textsOf(document), ["After."]);
      expect(document.getNodeById("c")!.getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
    });

    test("one undo step brings the whole note back", () {
      final document = documentOf(["See [[a note", "over two]] here", "Next."]);
      final editor = editorOf(document);
      final history = <String>[];
      editor.execute(OcptFountainNoteActions.removeRequests(document, caret("a", 8))!);
      history.addAll(textsOf(document));
      expect(history, ["See here", "Next."]);

      editor.undo();

      expect(textsOf(document), ["See [[a note", "over two]] here", "Next."]);
    });

    test("is withheld outside the note, and for a boneyard", () {
      final document = documentOf(["Hi [[a note", "over two]] there", "/* b", "*/"]);

      expect(OcptFountainNoteActions.removeRequests(document, caret("a", 1)), isNull);
      expect(OcptFountainNoteActions.removeRequests(document, caret("b", 12)), isNull);
      expect(OcptFountainNoteActions.removeRequests(document, caret("c", 1)), isNull);
    });
  });
}
