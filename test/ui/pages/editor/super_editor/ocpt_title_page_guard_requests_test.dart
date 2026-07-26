// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_guard_requests.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Builds a live [Editor] over [document] with [ocptTitlePageGuardRequestHandler] installed ahead
/// of the default handlers, exactly like `OcptStyledScreenplayEditor._rebuildEditorFrom`/
/// `_flushPendingSync` install it: a `CombineParagraphsRequest` executed against it exercises the
/// same "first handler that recognises the request wins" path the real editor relies on.
Editor _editorFor(MutableDocument document) => Editor(
  editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
  requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)..insert(0, ocptTitlePageGuardRequestHandler),
);

void main() {
  group("ocptTitlePageGuardRequestHandler", () {
    test("drops a merge between two different title-page fields (Draft date <- Contact)", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
      final document = decoded.document;
      final draftDate = document.getNodeAt(3)!;
      final contact = document.getNodeAt(4)!;
      final editor = _editorFor(document);

      editor.execute([CombineParagraphsRequest(firstNodeId: draftDate.id, secondNodeId: contact.id)]);

      expect(document.nodeCount, 7);
      expect(document.getNodeById(draftDate.id), isNotNull);
      expect(document.getNodeById(contact.id), isNotNull);
    });

    test("drops a merge between the first body node and the Source field", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
      final document = decoded.document;
      final source = document.getNodeAt(5)!;
      final body = document.getNodeAt(6)!;
      final editor = _editorFor(document);

      editor.execute([CombineParagraphsRequest(firstNodeId: source.id, secondNodeId: body.id)]);

      expect(document.nodeCount, 7);
      expect(document.getNodeById(source.id), isNotNull);
      expect(document.getNodeById(body.id), isNotNull);
    });

    test("still merges two nodes of the same title-page field (a Contact continuation)", () {
      const source = "Contact:\n    line one\n    line two\n\nINT. HOUSE - DAY";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);
      final document = decoded.document;
      // Title, Credit, Author, Draft date (indices 0-3), Contact spans indices 4-5.
      final contactLine1 = document.getNodeAt(4)!;
      final contactLine2 = document.getNodeAt(5)! as ParagraphNode;
      final editor = _editorFor(document);

      editor.execute([CombineParagraphsRequest(firstNodeId: contactLine1.id, secondNodeId: contactLine2.id)]);

      expect(document.nodeCount, 7);
      expect(document.getNodeById(contactLine2.id), isNull);
      expect((document.getNodeById(contactLine1.id)! as ParagraphNode).text.toPlainText(), "line oneline two");
    });

    test("leaves an ordinary body-to-body merge untouched", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("Some action.\nMore action.");
      final document = decoded.document;
      final firstBody = document.getNodeAt(6)!;
      final secondBody = document.getNodeAt(7)!;
      final editor = _editorFor(document);

      editor.execute([CombineParagraphsRequest(firstNodeId: firstBody.id, secondNodeId: secondBody.id)]);

      expect(document.nodeCount, 7);
      expect(document.getNodeById(secondBody.id), isNull);
    });

    test("ignores every request that isn't a CombineParagraphsRequest", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
      expect(ocptTitlePageGuardRequestHandler(_editorFor(decoded.document), const ClearSelectionRequest()), isNull);
    });
  });
}
