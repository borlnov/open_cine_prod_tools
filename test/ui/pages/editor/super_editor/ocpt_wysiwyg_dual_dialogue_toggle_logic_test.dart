// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// A document that counts the nodes it hands out, to tell how much of it a read walked.
class _CountingDocument extends MutableDocument {
  /// How many nodes were handed out by index or iteration.
  int visited = 0;

  /// Count every node an iteration hands out.
  @override
  Iterator<DocumentNode> get iterator {
    final inner = super.iterator;
    return _CountingIterator(inner, () => visited++);
  }

  /// Create a [_CountingDocument] holding [nodes].
  _CountingDocument({required super.nodes});

  /// Count the node handed out at [index].
  @override
  DocumentNode? getNodeAt(int index) {
    visited++;
    return super.getNodeAt(index);
  }
}

/// An iterator reporting each step it makes.
class _CountingIterator implements Iterator<DocumentNode> {
  /// The iterator walked.
  final Iterator<DocumentNode> _inner;

  /// Called at each step.
  final void Function() _onStep;

  /// Get the node the iterator is on.
  @override
  DocumentNode get current => _inner.current;

  /// Create a [_CountingIterator].
  _CountingIterator(this._inner, this._onStep);

  /// Step forward, reporting it.
  @override
  bool moveNext() {
    _onStep();
    return _inner.moveNext();
  }
}

/// Decode [text] into a document whose nodes are counted.
_CountingDocument _countingDocument(String text) =>
    _CountingDocument(nodes: OcptWysiwygCodec.decode(text).document.toList());

/// Run the tests of what the dual-dialogue toggle reads and writes.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("what the toggle offers", () {
    test("never offers a pairing that would break the pair next to the caret", () {
      final document = OcptWysiwygCodec.decode("A\nx\n\nB\ny\n\nC^\nz\n").document;

      expect(OcptWysiwygDualDialogue.toggleAt(document, document.getNodeAt(0)!.id), isNull);
      final inB = OcptWysiwygDualDialogue.toggleAt(document, document.getNodeAt(2)!.id);
      expect(inB!.isChecked, isTrue);
      expect(inB.cueNodeId, document.getNodeAt(4)!.id);
    });

    test("still pairs a speech with a free speech after it", () {
      final document = OcptWysiwygCodec.decode("A\nx\n\nB\ny\n").document;

      final toggle = OcptWysiwygDualDialogue.toggleAt(document, document.getNodeAt(0)!.id);

      expect(toggle!.isChecked, isFalse);
      expect(toggle.cueNodeId, document.getNodeAt(2)!.id);
    });

    test("reads a pair whose ^ is followed by a note as a pair", () {
      final document = OcptWysiwygCodec.decode("ROSS\nA.\n\nKIM ^ [[aside]]\nB.\n").document;

      for (final index in [0, 2]) {
        final toggle = OcptWysiwygDualDialogue.toggleAt(document, document.getNodeAt(index)!.id);
        expect(toggle!.isChecked, isTrue, reason: "node $index");
        expect(toggle.cueNodeId, document.getNodeAt(2)!.id);
      }
      expect(OcptWysiwygDualDialogue.pairsOf(document), hasLength(1));
    });

    test("unpairs a ^ followed by a note by taking it out of the text, notes kept", () {
      final document = OcptWysiwygCodec.decode("ROSS\nA.\n\nKIM ^ [[aside]]\nB.\n").document;

      final requests = OcptWysiwygDualDialogue.toggleRequestsAt(
        document,
        document.getNodeAt(0)!.id,
      );

      expect(requests, hasLength(1));
      final replacement = requests!.single as OcptReplaceNodeTextRequest;
      expect(replacement.nodeId, document.getNodeAt(2)!.id);
      expect(replacement.text.toPlainText(), "KIM [[aside]]");
    });

    test("writes nothing, not even an empty step, where there is nothing to remove", () {
      final document = OcptWysiwygCodec.decode("ROSS\nA.\n").document;

      expect(OcptWysiwygDualDialogue.toggleRequestsAt(document, document.getNodeAt(0)!.id), isNull);
    });
  });

  group("how much of the document the toggle reads", () {
    test("walks the caret's run of speeches, not the whole document", () {
      final body = List.generate(3000, (index) => "Action $index.").join("\n\n");
      final document = _countingDocument("$body\n\nROSS\nA.\n\nKIM ^\nB.\n\nEND.\n");
      final ross = document.getNodeAt(3000)!;
      document.visited = 0;

      final toggle = OcptWysiwygDualDialogue.toggleAt(document, ross.id);

      expect(toggle!.isChecked, isTrue);
      expect(document.visited, lessThan(40));
    });

    test("a document with no marker reads its neighbours only", () {
      final body = List.generate(3000, (index) => "Action $index.").join("\n\n");
      final document = _countingDocument("$body\n\nROSS\nA.\n\nKIM\nB.\n\nEND.\n");
      final ross = document.getNodeAt(3000)!;
      document.visited = 0;

      final toggle = OcptWysiwygDualDialogue.toggleAt(document, ross.id);

      expect(toggle!.isChecked, isFalse);
      expect(document.visited, lessThan(40));
    });
  });

  group("the analysis", () {
    test("is computed again only once the document has changed", () {
      final document = OcptWysiwygCodec.decode("ROSS\nA.\n\nKIM ^\nB.\n").document;

      final first = OcptWysiwygDualDialogue.analysisOf(document);
      expect(identical(OcptWysiwygDualDialogue.analysisOf(document).pairs, first.pairs), isTrue);

      final editor = createDefaultDocumentEditor(
        document: document,
        composer: MutableDocumentComposer(),
      );
      final cue = document.getNodeAt(2)! as ParagraphNode;
      editor.execute([
        ReplaceNodeRequest(
          existingNodeId: cue.id,
          newNode: cue.copyWithAddedMetadata({ocptDualDialogueMetadataKey: null}),
        ),
      ]);

      expect(OcptWysiwygDualDialogue.analysisOf(document).pairs, isEmpty);
    });

    test("is empty and cheap for a document with no ^ at all", () {
      final document = OcptWysiwygCodec.decode("ROSS\nA.\n\nKIM\nB.\n").document;

      final analysis = OcptWysiwygDualDialogue.analysisOf(document);

      expect(analysis.pairs, isEmpty);
      expect(analysis.orphanCueIds, isEmpty);
    });
  });

  group("the toggle in the editor", () {
    /// Pump a styled editor over [text].
    Future<OcptStyledEditorController> pumpEditor(WidgetTester tester, String text) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
            styledController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets("unpairs a ^ followed by a note in one undo step", (tester) async {
      final controller = await pumpEditor(tester, "ROSS\nHello.\n\nKIM ^ [[aside]]\nHi.\n");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 1);
      await tester.pump();
      expect(controller.isDualDialogueChecked, isTrue);

      controller.toggleDualDialogue();
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 2).text.toPlainText(), "KIM [[aside]]");
      expect(controller.isDualDialogueChecked, isFalse);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 2).text.toPlainText(), "KIM ^ [[aside]]");
    });
  });
}
