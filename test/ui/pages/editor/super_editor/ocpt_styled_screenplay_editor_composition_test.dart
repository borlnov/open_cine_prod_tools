// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Pump a styled editor over [text] and wait out its first settle.
Future<OcptStyledEditorController> _pump(WidgetTester tester, String text) async {
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

/// Get the composer of the live editor.
MutableDocumentComposer _composer() =>
    SuperEditorInspector.findComposer()! as MutableDocumentComposer;

/// Get the composing region of the live editor as (start, end) offsets, or null when none.
(int, int)? _composing() {
  final region = _composer().composingRegion.value;
  if (region == null) {
    return null;
  }
  return (
    (region.start.nodePosition as TextNodePosition).offset,
    (region.end.nodePosition as TextNodePosition).offset,
  );
}

/// Type a space after `KIM`, then send [mark] as a pending composition, the way a dead key does.
Future<String> _composeAfterKim(WidgetTester tester, String mark) async {
  final document = SuperEditorInspector.findDocument()!;
  await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);
  await tester.typeImeText(" ");
  await pumpPastSettleDebounce(tester);
  final value = imeClientGetter().currentTextEditingValue!;
  final caret = value.selection.baseOffset;
  await tester.ime.sendDeltas([
    TextEditingDeltaInsertion(
      oldText: value.text,
      textInserted: mark,
      insertionOffset: caret,
      selection: TextSelection.collapsed(offset: caret + 1),
      composing: TextRange(start: caret, end: caret + 1),
    ),
  ], getter: imeClientGetter);
  return value.text;
}

/// Run the tests of the derived passes meeting an input method's composition.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("a dead-key ^ at the end of a cue", () {
    testWidgets("is left alone while it is composed, with the region inside the text", (
      tester,
    ) async {
      await _pump(tester, "ROSS\nHello.\n\nKIM\nHi.\n");
      final document = SuperEditorInspector.findDocument()!;
      await _composeAfterKim(tester, "^");
      expect(nodeAt(document, 2).text.toPlainText(), "KIM ^");
      expect(_composing(), isNotNull);

      await pumpPastSettleDebounce(tester);

      expect(tester.takeException(), isNull);
      expect(nodeAt(document, 2).text.toPlainText(), "KIM ^");
      expect(OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 2)), isNull);
      final (start, end) = _composing()!;
      expect(end, lessThanOrEqualTo(nodeAt(document, 2).text.length));
      expect(start, lessThan(end));
    });

    testWidgets("is absorbed at the settle after the composition ends, in one undo step", (
      tester,
    ) async {
      final controller = await _pump(tester, "ROSS\nHello.\n\nKIM\nHi.\n");
      final document = SuperEditorInspector.findDocument()!;
      final before = await _composeAfterKim(tester, "^");
      await pumpPastSettleDebounce(tester);
      final caret = (_composing()!).$1;

      await tester.ime.sendDeltas([
        TextEditingDeltaNonTextUpdate(
          oldText: "${before.substring(0, caret)}^${before.substring(caret)}",
          selection: TextSelection.collapsed(offset: caret + 1),
          composing: TextRange.empty,
        ),
      ], getter: imeClientGetter);
      await pumpPastSettleDebounce(tester);

      expect(tester.takeException(), isNull);
      expect(nodeAt(document, 2).text.toPlainText(), "KIM");
      expect(OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 2)), isNotNull);
      expect(_composing(), isNull);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 2)), isNull);
      expect(nodeAt(document, 2).text.toPlainText(), isNot(contains("^")));
      expect(controller.canRedo, isTrue);

      await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(nodeAt(document, 2).text.toPlainText(), "KIM");
      expect(OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 2)), isNotNull);
    });
  });

  group("a character cue under composition", () {
    testWidgets("is not uppercased", (tester) async {
      await _pump(tester, "ROSS\nHello.\n\nKIM\nHi.\n");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
      await tester.typeImeText("a");
      final value = imeClientGetter().currentTextEditingValue!;
      await tester.ime.sendDeltas([
        TextEditingDeltaInsertion(
          oldText: value.text,
          textInserted: "e",
          insertionOffset: value.selection.baseOffset,
          selection: TextSelection.collapsed(offset: value.selection.baseOffset + 1),
          composing: TextRange(
            start: value.selection.baseOffset,
            end: value.selection.baseOffset + 1,
          ),
        ),
      ], getter: imeClientGetter);

      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), isNot(equals("AEROSS")));
      expect(nodeAt(document, 0).text.toPlainText(), contains("e"));
    });
  });

  group("OcptReplaceNodeTextCommand", () {
    /// Build an editor over a one-node document of `KIM ^` whose composing region is
    /// [start] to [end], and replace the text with `KIM`.
    MutableDocumentComposer replaceWithComposing(int start, int end) {
      final node = ParagraphNode(id: "kim", text: AttributedText("KIM ^"));
      final document = MutableDocument(nodes: [node]);
      final composer = MutableDocumentComposer();
      addTearDown(composer.dispose);
      final editor = Editor(
        editables: {Editor.documentKey: document, Editor.composerKey: composer},
        requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
          ..add(ocptReplaceNodeTextRequestHandler),
      );
      addTearDown(editor.dispose);
      composer.setComposingRegion(
        DocumentRange(
          start: DocumentPosition(
            nodeId: "kim",
            nodePosition: TextNodePosition(offset: start),
          ),
          end: DocumentPosition(
            nodeId: "kim",
            nodePosition: TextNodePosition(offset: end),
          ),
        ),
      );

      editor.execute([OcptReplaceNodeTextRequest(nodeId: "kim", text: node.text.copyText(0, 3))]);
      return composer;
    }

    test("brings a composing region past the new text back inside it", () {
      final composer = replaceWithComposing(1, 5);

      final region = composer.composingRegion.value!;
      expect((region.start.nodePosition as TextNodePosition).offset, 1);
      expect((region.end.nodePosition as TextNodePosition).offset, 3);
    });

    test("clears a composing region that nothing of the new text holds", () {
      expect(replaceWithComposing(4, 5).composingRegion.value, isNull);
    });
  });
}
