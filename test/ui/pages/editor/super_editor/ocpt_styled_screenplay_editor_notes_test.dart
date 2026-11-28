// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note_marker.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// A fixed instant for [withClock], so a typing run merges into one undo step.
final DateTime _frozenNow = DateTime(2026, 8, 18, 10);

/// Type [text] one character at a time into the node holding the caret, settling between
/// keystrokes the way a hand slower than the settle debounce does.
Future<void> _typeRun(WidgetTester tester, String text) async {
  for (final character in text.split("")) {
    await tester.typeImeText(character);
    await pumpPastSettleDebounce(tester);
  }
}

/// Read the caret offset of the document's selection.
int _caretOffset() =>
    (SuperEditorInspector.findDocumentSelection()!.extent.nodePosition as TextNodePosition).offset;

/// Select the offsets [start] to [end] of the node [nodeId].
Future<void> _select(WidgetTester tester, String nodeId, int start, int end) async {
  await tester.placeCaretInParagraph(nodeId, start);
  final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
  composer.setSelectionWithReason(
    DocumentSelection(
      base: DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: start),
      ),
      extent: DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: end),
      ),
    ),
  );
  await tester.pump();
}

/// Run the tests of the notes of the styled screenplay editor.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("a note held as a placeholder", () {
    testWidgets("is drawn as a small marker, one per note, and never as brackets", (tester) async {
      await pumpStandaloneEditor(tester, "a [[one]] b [[two]]");

      expect(find.byType(OcptFountainNoteMarker), findsNWidgets(2));
      final size = tester.getSize(find.byType(OcptFountainNoteMarker).first);
      expect(size.width, closeTo(OcptFountainNoteMarker.baseWidth, 0.01));
      expect(size.height, closeTo(OcptFountainNoteMarker.baseHeight, 0.01));
      expect(find.textContaining("one", findRichText: true), findsNothing);
    });

    testWidgets("reads out the translated label of a note", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpStandaloneEditor(tester, "a [[one]] b");
      final tr = Tr.of(tester.element(find.byType(OcptFountainNoteMarker)));

      final label = tester.getSemantics(find.byType(OcptFountainNoteMarker)).label;
      semantics.dispose();

      expect(label, contains(tr.editorNoteMarkerLabel));
    });

    testWidgets("is one position of the caret and Backspace deletes it whole", (tester) async {
      await pumpStandaloneEditor(tester, "a [[note]] b");
      final document = SuperEditorInspector.findDocument()!;
      expect(nodeAt(document, 0).text.toPlainText(), "a ￼ b");
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(_caretOffset(), 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "a  b");
      expect(nodeAt(document, 0).text.placeholders, isEmpty);
    });

    testWidgets("is absorbed when its closing brackets are typed, the caret after it", (
      tester,
    ) async {
      await pumpStandaloneEditor(tester, "He waits.");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 9);

      await _typeRun(tester, " [[typed]");
      expect(nodeAt(document, 0).text.toPlainText(), "He waits. [[typed]");
      await _typeRun(tester, "]");

      expect(nodeAt(document, 0).text.toPlainText(), "He waits. ￼");
      expect((nodeAt(document, 0).text.placeholders[10]! as OcptFountainNote).text, "typed");
      expect(_caretOffset(), 11);

      await _typeRun(tester, "x");
      expect(nodeAt(document, 0).text.toPlainText(), "He waits. ￼x");
    });

    testWidgets("is absorbed and taken back in the one undo step of the keystroke", (tester) async {
      await withClock(Clock.fixed(_frozenNow), () async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        await pumpStandaloneEditor(tester, "He waits.", styledController: controller);
        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 9);

        await _typeRun(tester, " [[typed]]");
        expect(nodeAt(document, 0).text.toPlainText(), "He waits. ￼");

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 0).text.toPlainText(), "He waits.");
        expect(nodeAt(document, 0).text.placeholders, isEmpty);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 0).text.toPlainText(), "He waits. ￼");
        expect((nodeAt(document, 0).text.placeholders[10]! as OcptFountainNote).text, "typed");
      });
    });

    testWidgets("Enter next to it splits the line around it, the note kept whole", (tester) async {
      await pumpStandaloneEditor(tester, "a [[x]] b");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "a ￼");
      expect(nodeAt(document, 1).text.toPlainText(), " b");
      expect((nodeAt(document, 0).text.placeholders[2]! as OcptFountainNote).text, "x");

      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "a ");
      expect(nodeAt(document, 1).text.toPlainText(), "￼");
      expect((nodeAt(document, 1).text.placeholders[0]! as OcptFountainNote).text, "x");
    });
  });

  group("the note on the clipboard", () {
    String? clipboardText;
    setUp(() {
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          switch (methodCall.method) {
            case "Clipboard.setData":
              clipboardText = (methodCall.arguments as Map)["text"] as String?;
              return null;
            case "Clipboard.getData":
              return {"text": clipboardText};
            default:
              return null;
          }
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets("is copied as its Fountain note and pasted back as a note", (tester) async {
      await pumpStandaloneEditor(tester, "a [[kept]] b\n\nEnd.");
      final document = SuperEditorInspector.findDocument()!;
      await _select(tester, nodeAt(document, 0).id, 2, 3);

      await sendCtrl(tester, LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(clipboardText, "[[kept]]");

      await _select(tester, nodeAt(document, 1).id, 4, 4);
      await sendCtrl(tester, LogicalKeyboardKey.keyV);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 1).text.toPlainText(), "End.￼");
      final pasted = nodeAt(document, 1).text.placeholders[4]! as OcptFountainNote;
      final original = nodeAt(document, 0).text.placeholders[2]! as OcptFountainNote;
      expect(pasted.text, "kept");
      expect(pasted.id, isNot(original.id));
    });

    testWidgets("a note typed into the clipboard text is pasted as a note", (tester) async {
      await pumpStandaloneEditor(tester, "Hello");
      final document = SuperEditorInspector.findDocument()!;
      clipboardText = " [[from outside]]";
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 5);

      await sendCtrl(tester, LogicalKeyboardKey.keyV);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "Hello ￼");
    });

    testWidgets("a cut takes the note away and gives its Fountain text", (tester) async {
      await pumpStandaloneEditor(tester, "a [[kept]] b");
      final document = SuperEditorInspector.findDocument()!;
      await _select(tester, nodeAt(document, 0).id, 2, 3);

      await sendCtrl(tester, LogicalKeyboardKey.keyX);
      await pumpPastSettleDebounce(tester);

      expect(clipboardText, "[[kept]]");
      expect(nodeAt(document, 0).text.toPlainText(), "a  b");
    });
  });
}
