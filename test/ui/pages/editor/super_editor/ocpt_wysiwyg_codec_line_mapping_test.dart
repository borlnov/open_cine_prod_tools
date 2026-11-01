// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// Run the tests of the wysiwyg codec line mapping.
void main() {
  group("OcptWysiwygLineMapping", () {
    test("lineOfNodeIndex accounts for every preceding node's blank-lines-before count", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY\n\nSome action.\n\n\nSARAH\nHello.",
      );

      expect(decoded.mapping.lineOfNodeIndex(0), 0);
      expect(decoded.mapping.lineOfNodeIndex(1), 2);
      expect(decoded.mapping.lineOfNodeIndex(2), 5);
      expect(decoded.mapping.lineOfNodeIndex(3), 6);
    });

    test("nodeIndexOfCharOffset resolves a real offset to the node owning that line", () {
      const source = "INT. HOUSE - DAY\n\nSome action.\n\n\nSARAH\nHello.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.mapping.nodeIndexOfCharOffset(0), 0);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("Some action.")), 1);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("SARAH")), 2);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("Hello.")), 3);
    });

    test("a blank line's offset snaps to the node that follows it", () {
      const source = "INT. HOUSE - DAY\n\nSome action.";
      final decoded = OcptWysiwygCodec.decode(source);

      // The offset right after the heading's own newline sits on the blank line between the
      // heading and the action line.
      final blankLineOffset = "INT. HOUSE - DAY\n".length;
      expect(decoded.mapping.nodeIndexOfCharOffset(blankLineOffset), 1);
    });

    test("clamps an out-of-range offset to the last line's node", () {
      const source = "line0\nline1";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.mapping.nodeIndexOfCharOffset(source.length + 10), 1);
      expect(decoded.mapping.nodeIndexOfCharOffset(-5), 0);
    });

    test("a trailing blank run's offset snaps to the last node", () {
      const source = "Some action.\n\n\n";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.mapping.nodeIndexOfCharOffset(source.length), 0);
    });

    test("encode produces a fresh mapping consistent with its own output text", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\nSARAH\nHello.");
      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.mapping.lineOfNodeIndex(0), 0);
      expect(encoded.mapping.lineOfNodeIndex(1), 2);
      expect(encoded.mapping.lineOfNodeIndex(2), 3);
      expect(encoded.mapping.nodeIndexOfCharOffset(encoded.text.indexOf("SARAH")), 1);
    });
  });

  group("OcptWysiwygCodec.encodeSelectionToFountain / decodeNodesFromFountain", () {
    /// Builds an expanded [DocumentSelection] spanning the full node at [fromIndex] to the full
    /// node at [toIndex] of [document] (inclusive), in whichever order [base]/[extent] are asked
    /// for, so a reversed selection can be exercised too.
    DocumentSelection selectFullNodes(
      Document document, {
      required int fromIndex,
      required int toIndex,
    }) {
      final fromNode = document.getNodeAt(fromIndex)! as ParagraphNode;
      final toNode = document.getNodeAt(toIndex)! as ParagraphNode;
      return DocumentSelection(
        base: DocumentPosition(
          nodeId: fromNode.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: toNode.id,
          nodePosition: TextNodePosition(offset: toNode.text.toPlainText().length),
        ),
      );
    }

    test(
      "a selection spanning a scene heading, an action line, a character cue and dialogue "
      "round-trips with types and blank lines intact, but never starts with a leading blank line",
      () {
        // The action line originally sits 2 blank lines below the heading; the copied fragment
        // must start directly with it instead (see encodeSelectionToFountain's doc comment).
        const source = "INT. HOUSE - DAY\n\n\nSome action.\n\nSARAH\nHello there.";
        final decoded = OcptWysiwygCodec.decode(source);
        final document = decoded.document;
        expect(blanksBeforeAt(document, 1), 2);

        final selection = selectFullNodes(document, fromIndex: 1, toIndex: 3);
        final fragmentText = OcptWysiwygCodec.encodeSelectionToFountain(document, selection);

        expect(fragmentText, "Some action.\n\nSARAH\nHello there.");

        final fragmentNodes = OcptWysiwygCodec.decodeNodesFromFountain(fragmentText);
        expect(fragmentNodes, hasLength(3));
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(
            fragmentNodes[0].getMetadataValue("blockType"),
          ),
          FountainLineType.action,
        );
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(
            fragmentNodes[1].getMetadataValue("blockType"),
          ),
          FountainLineType.character,
        );
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(
            fragmentNodes[2].getMetadataValue("blockType"),
          ),
          FountainLineType.dialogue,
        );
        expect(fragmentNodes[0].getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
        expect(fragmentNodes[1].getMetadataValue(ocptBlankLinesBeforeMetadataKey), 1);
        expect(fragmentNodes[2].getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
      },
    );

    test(
      "a reversed selection (base after extent in document order) encodes the same fragment",
      () {
        const source = "SARAH\nHello there.\n\nJOHN\nHi.";
        final decoded = OcptWysiwygCodec.decode(source);
        final document = decoded.document;

        final forwardSelection = selectFullNodes(document, fromIndex: 0, toIndex: 3);
        final reversedSelection = DocumentSelection(
          base: forwardSelection.extent,
          extent: forwardSelection.base,
        );

        expect(
          OcptWysiwygCodec.encodeSelectionToFountain(document, reversedSelection),
          OcptWysiwygCodec.encodeSelectionToFountain(document, forwardSelection),
        );
      },
    );

    test("a partial single-node selection yields just its selected text", () {
      final decoded = OcptWysiwygCodec.decode("Some action text here.");
      final node = decoded.document.getNodeAt(0)! as ParagraphNode;

      final selection = DocumentSelection(
        base: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 5)),
        extent: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 11)),
      );

      expect(OcptWysiwygCodec.encodeSelectionToFountain(decoded.document, selection), "action");
    });

    test("decodeNodesFromFountain returns an empty list for all-blank text", () {
      expect(OcptWysiwygCodec.decodeNodesFromFountain(""), isEmpty);
      expect(OcptWysiwygCodec.decodeNodesFromFountain("\n\n"), isEmpty);
    });

    test("decodeNodesFromFountain preserves an explicit forcing marker", () {
      final fragmentNodes = OcptWysiwygCodec.decodeNodesFromFountain("!Some action.");

      expect(fragmentNodes, hasLength(1));
      expect(fragmentNodes.single.getMetadataValue(ocptHadForcingMarkerMetadataKey), isTrue);
      expect(fragmentNodes.single.text.toPlainText(), "Some action.");
    });
  });

  group("decodeWithTitlePage / encodeWithTitlePage", () {
    /// The [ocptTitlePageKeyMetadataKey] of the node at [index] of [document], or null if it isn't
    /// a title-page field node.
    String? titlePageKeyAt(Document document, int index) {
      final value = document.getNodeAt(index)!.getMetadataValue(ocptTitlePageKeyMetadataKey);
      return value is String ? value : null;
    }

    test(
      "a screenplay with no title page still synthesizes all six fields, empty, in canonical order",
      () {
        final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY\n\nSome action.");

        expect(decoded.titlePageNodeCount, 6);
        expect(decoded.document.nodeCount, 8);
        expect([
          for (var index = 0; index < 6; index++) titlePageKeyAt(decoded.document, index),
        ], ocptTitlePageFieldKeys);
        for (var index = 0; index < 6; index++) {
          expect(
            decoded.document.getNodeAt(index)!.getMetadataValue("blockType"),
            ocptTitlePageFieldAttribution,
          );
          expect((decoded.document.getNodeAt(index)! as ParagraphNode).text.toPlainText(), isEmpty);
          expect(
            OcptWysiwygCodec.isTitlePageNode(decoded.document.getNodeAt(index)! as ParagraphNode),
            isTrue,
          );
        }

        // The body starts right where a plain `decode` of the same (title-page-free) text would
        // put it, just shifted by the six title-page nodes.
        expect(typeAt(decoded.document, 6), FountainLineType.sceneHeading);
        expect(
          (decoded.document.getNodeAt(6)! as ParagraphNode).text.toPlainText(),
          "INT. HOUSE - DAY",
        );
        expect(typeAt(decoded.document, 7), FountainLineType.action);
        expect(
          OcptWysiwygCodec.isTitlePageNode(decoded.document.getNodeAt(7)! as ParagraphNode),
          isFalse,
        );
      },
    );

    test("an existing title page decodes its present fields, absent ones stay empty", () {
      const source = "Title: My Movie\nCredit: written by\n\nINT. HOUSE - DAY";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      expect((decoded.document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "My Movie");
      expect((decoded.document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "written by");
      // Author, Draft date, Contact, Source: absent from the source, still synthesized empty.
      for (var index = 2; index < 6; index++) {
        expect((decoded.document.getNodeAt(index)! as ParagraphNode).text.toPlainText(), isEmpty);
      }
      expect(decoded.titlePagePrefixLength, source.length - "INT. HOUSE - DAY".length);
      expect(typeAt(decoded.document, 6), FountainLineType.sceneHeading);
    });

    test("Authors: written as continuation lines decodes into one node per line", () {
      const source = "Authors:\n    Jane Doe\n    John Smith\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      // Title, Credit: empty (indices 0-1). Author spans indices 2-3 (two continuation lines).
      expect(titlePageKeyAt(decoded.document, 2), "Author");
      expect(titlePageKeyAt(decoded.document, 3), "Author");
      expect((decoded.document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "Jane Doe");
      expect((decoded.document.getNodeAt(3)! as ParagraphNode).text.toPlainText(), "John Smith");
      // Draft date, Contact, Source (indices 4-6) follow, then the body.
      expect(titlePageKeyAt(decoded.document, 6), "Source");
      expect(typeAt(decoded.document, 7), FountainLineType.action);
    });

    test(
      "round trip: an untouched decode/encode of a title-page-free screenplay changes nothing",
      () {
        const source = "INT. HOUSE - DAY\n\nSome action.\n\nJOHN\nHello.";
        final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

        final encoded = OcptWysiwygCodec.encodeWithTitlePage(
          decoded.document,
          trailingBlankLines: decoded.trailingBlankLines,
        );

        expect(encoded.text, source);
        // The document still carries six (all-empty) title-page nodes; only the *rendered* text
        // omits them, since every field is empty.
        expect(encoded.titlePageNodeCount, 6);
      },
    );

    test("filling only the Title field of an untitled screenplay writes just a Title: line", () {
      const source = "INT. HOUSE - DAY\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);
      replaceText(decoded.document, 0, "My Movie");

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "Title: My Movie\n\n$source");
    });

    test("Author continuation lines round-trip byte-for-byte", () {
      const source = "Author:\n    Jane Doe\n    John Smith\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, source);
    });

    test("emptying every field drops the title page entirely, back to a plain body", () {
      const source = "Title: My Movie\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);
      replaceText(decoded.document, 0, "");

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "Some action.");
    });

    test("Author also matches a source written with the singular Author key on encode", () {
      // `_titlePageEntriesFromNodes` always writes the canonical singular key, regardless of
      // which of `Author`/`Authors` the source used (mirrors `editor_bloc.dart`'s dialog flow).
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("Authors: Jane Doe\n\nSome action.");
      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "Author: Jane Doe\n\nSome action.");
    });

    test(
      "a locked/uppercased title-page field is never reclassified or uppercased by the body passes",
      () {
        final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY\n\nSome action.");
        replaceText(decoded.document, 0, "lowercase title");

        expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
        expect(OcptWysiwygCodec.uppercaseRequests(decoded.document), isEmpty);
        expect(OcptWysiwygCodec.sceneNumberRequests(decoded.document), isEmpty);
      },
    );

    test(
      "every synthesized title-page node starts fully deletable (F6: edited like any other line)",
      () {
        // `isDeletable: false` used to also block ordinary in-field editing (Backspace, Delete):
        // the sheet is protected from deletion by `ocptTitlePageGuardRequestHandler` alone now, so
        // a title-page node must never carry the flag at all.
        final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
        for (var index = 0; index < 6; index++) {
          expect(decoded.document.getNodeAt(index)!.isDeletable, isTrue, reason: "node $index");
        }
      },
    );

    test(
      "a metadata merge (OcptChangeNodeMetadataRequest) keeps a title-page node's field key",
      () {
        final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
        final document = decoded.document;
        final creditNode = document.getNodeAt(1)!;
        final editor = Editor(
          editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
          requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
            ..add(ocptChangeNodeMetadataRequestHandler),
        );

        editor.execute([
          OcptChangeNodeMetadataRequest(
            nodeId: creditNode.id,
            metadata: {ocptTypeLockedMetadataKey: true},
          ),
        ]);

        expect(
          document.getNodeById(creditNode.id)!.getMetadataValue(ocptTitlePageKeyMetadataKey),
          "Credit",
        );
      },
    );

    test(
      "encodeWithTitlePage ignores node metadata that isn't the field key or the text itself",
      () {
        const source = "Title: My Movie\n\nSome action.";
        final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

        final titleNode = decoded.document.getNodeAt(0)! as ParagraphNode;
        final withExtraMetadata = MutableDocument(
          nodes: [
            titleNode.copyParagraphWith(
              metadata: {...titleNode.metadata, ocptTypeLockedMetadataKey: true},
            ),
            ...decoded.document.skip(1),
          ],
        );

        final encoded = OcptWysiwygCodec.encodeWithTitlePage(
          withExtraMetadata,
          trailingBlankLines: decoded.trailingBlankLines,
        );

        expect(encoded.text, source);
      },
    );
  });

  group("Editor.undo() survives a document built by decode/decodeWithTitlePage", () {
    // Regression coverage for a bug invisible to every other test in this file: none of them ever
    // hand their `MutableDocument` to a live, history-enabled `Editor`. Before
    // `OcptWysiwygCodec.decode`/`decodeWithTitlePage` were fixed to build that document from a
    // genuine `List<DocumentNode>`, `Editor.undo()` threw `type 'List<DocumentNode>' is not a
    // subtype of type 'Iterable<ParagraphNode>'` out of `MutableDocument.reset()`'s own
    // `_nodes..clear()..addAll(_latestNodesSnapshot)` — *after* the `clear()` had already run — so
    // the document undo() was called on was left with zero nodes, not "not undone".

    test("decode: undoing an edit restores the document instead of leaving it empty", () {
      final decoded = OcptWysiwygCodec.decode("Some action text.");
      final document = decoded.document;
      final nodeId = document.getNodeAt(0)!.id;

      final editor = Editor(
        editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
        requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
          ..add(ocptReplaceNodeTextRequestHandler),
        isHistoryEnabled: true,
      );

      editor.execute([
        OcptReplaceNodeTextRequest(
          nodeId: nodeId,
          text: AttributedText("Some action text, edited."),
        ),
      ]);
      expect(
        (document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
        "Some action text, edited.",
      );

      expect(editor.undo, returnsNormally);

      expect(document.nodeCount, 1);
      expect((document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "Some action text.");
    });

    test(
      "decodeWithTitlePage: undoing an edit restores the document instead of leaving it empty",
      () {
        final decoded = OcptWysiwygCodec.decodeWithTitlePage(
          "Title: My Movie\n\nSome action text.",
        );
        final document = decoded.document;
        final originalNodeCount = document.nodeCount;
        final bodyNodeId = document.getNodeAt(originalNodeCount - 1)!.id;

        final editor = Editor(
          editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
          requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
            ..add(ocptReplaceNodeTextRequestHandler),
          isHistoryEnabled: true,
        );

        editor.execute([
          OcptReplaceNodeTextRequest(
            nodeId: bodyNodeId,
            text: AttributedText("Some action text, edited."),
          ),
        ]);
        expect(
          (document.getNodeAt(originalNodeCount - 1)! as ParagraphNode).text.toPlainText(),
          "Some action text, edited.",
        );

        expect(editor.undo, returnsNormally);

        expect(document.nodeCount, originalNodeCount);
        expect(
          (document.getNodeAt(originalNodeCount - 1)! as ParagraphNode).text.toPlainText(),
          "Some action text.",
        );
      },
    );
  });
}
