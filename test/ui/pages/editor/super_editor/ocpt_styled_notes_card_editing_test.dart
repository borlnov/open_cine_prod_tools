// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_card.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The text of the document the tests share: a note in the middle of an action line.
const String _source = "He waits [[old]] now.\n\nShe leaves.";

/// The texts the editor reported through `onTextChanged`, latest last.
final List<String> _reported = [];

/// Pump the editor over [text] on a surface wide enough for the margin, reporting its text to
/// [_reported].
Future<void> _pump(WidgetTester tester, String text, {Key? key}) async {
  _reported.clear();
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        key: key,
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: false,
        areSceneNumbersVisible: false,
        isSpellCheckVisible: false,
        onTextChanged: _reported.add,
        onCaretLineChanged: (_) {},
        jumpRequest: null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Run a [testWidgets] case with a desktop [defaultTargetPlatform], which is what makes the styled
/// editor build the mouse interactor that receives a secondary tap.
void _testWidgetsAsDesktop(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// Get the document of the editor.
Document _document() => SuperEditorInspector.findDocument()!;

/// Get the first node of the document holding a note.
ParagraphNode _noteNode() => _document().whereType<ParagraphNode>().firstWhere(
  (node) => node.text.placeholders.values.any((value) => value is OcptFountainNote),
);

/// Get the notes the document holds, in document order.
List<OcptFountainNote> _notes() => [
  for (final node in _document().whereType<ParagraphNode>())
    ...node.text.placeholders.values.whereType<OcptFountainNote>(),
];

/// Get the field of the selected card.
Finder _field() => find.descendant(of: find.byType(OcptNoteCard), matching: find.byType(TextField));

/// Tell whether the field of the selected card has the focus.
bool _fieldHasFocus(WidgetTester tester) => tester.widget<TextField>(_field()).focusNode!.hasFocus;

/// Get the offset of the caret of the editor.
int _caretOffset() =>
    (SuperEditorInspector.findDocumentSelection()!.extent.nodePosition as TextNodePosition).offset;

/// Select the card of the first note with a tap, which gives its field the focus.
Future<void> _selectFirstCard(WidgetTester tester) async {
  await tester.tap(find.byType(OcptNoteCard).first);
  await tester.pumpAndSettle();
}

/// Write [text] in the field of the selected card, the way a keystroke does.
Future<void> _write(WidgetTester tester, String text) async {
  await tester.enterText(_field(), text);
  await tester.pump();
}

/// Send Ctrl+Shift+[key] or Ctrl+[key] to whatever has the focus.
Future<void> _sendCtrl(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await pumpPastSettleDebounce(tester);
}

/// Find the entry of the context menu labelled [label].
Finder _menuEntry(String label) => find.widgetWithText(MenuItemButton, label);

/// Right-click [dx] logical pixels into the text of the node [nodeId], which places the caret
/// there unless the click lands inside an expanded selection.
Future<Tr> _rightClickIn(WidgetTester tester, String nodeId, {double dx = 4}) async {
  await tester.tapAt(
    SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) + Offset(dx, 0),
    buttons: kSecondaryButton,
  );
  await tester.pumpAndSettle();
  return Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
}

/// Run the tests of the editing of the notes from their cards.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("the card of the selected note", () {
    testWidgets("is a field that grows with its text, the others staying plain text", (
      tester,
    ) async {
      await _pump(tester, "A [[one]] b.\n\nC [[two]] d.");
      expect(_field(), findsNothing);

      await _selectFirstCard(tester);

      expect(_field(), findsOneWidget);
      expect(tester.widget<TextField>(_field()).controller!.text, "one");
      expect(find.text("two"), findsOneWidget);
      final height = tester.getSize(find.byType(OcptNoteCard).first).height;

      await _write(tester, "one\ntwo\nthree");

      expect(tester.getSize(find.byType(OcptNoteCard).first).height, greaterThan(height));
    });

    testWidgets("takes the focus when it is selected", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);

      expect(_fieldHasFocus(tester), isTrue);
    });

    testWidgets("writes each change in the note, which keeps its identifier", (tester) async {
      await _pump(tester, _source);
      final id = _notes().single.id;
      await _selectFirstCard(tester);

      await _write(tester, "new text");
      await pumpPastSettleDebounce(tester);

      expect(_notes().single, OcptFountainNote(id: id, text: "new text"));
      expect(_reported.last, contains("He waits [[new text]] now."));
    });

    testWidgets("gives several keystrokes back in one Ctrl+Z, from the field", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);

      await _write(tester, "old a");
      await _write(tester, "old ab");
      await _write(tester, "old abc");
      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes().single.text, "old");
      expect(tester.widget<TextField>(_field()).controller!.text, "old");
    });

    testWidgets("gives several keystrokes back in one Ctrl+Z, from the editor", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "old a");
      await _write(tester, "old ab");
      await tester.placeCaretInParagraph(_noteNode().id, 0);
      await tester.pumpAndSettle();

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes().single.text, "old");
    });

    testWidgets("puts a change back with Ctrl+Shift+Z and Ctrl+Y, from the field", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "older");
      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);
      expect(_notes().single.text, "old");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(_notes().single.text, "older");
      expect(tester.widget<TextField>(_field()).controller!.text, "older");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await _sendCtrl(tester, LogicalKeyboardKey.keyY);
      expect(_notes().single.text, "older");
    });

    testWidgets("follows the note when it changes from elsewhere", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "changed");
      await pumpPastSettleDebounce(tester);

      tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.undo();
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_field()).controller!.text, "old");
    });

    testWidgets("refuses `]]`, `/*`, `*/` and a closing `]`, keeping the old text", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);

      for (final refused in ["old]]", "old /*", "old */", "old]", "a ]] b"]) {
        await _write(tester, refused);

        expect(tester.widget<TextField>(_field()).controller!.text, "old", reason: refused);
        expect(_notes().single.text, "old", reason: refused);
      }

      await _write(tester, "old [x] y");
      expect(_notes().single.text, "old [x] y");
    });

    testWidgets("gives the focus back to the text with Enter, the caret after the marker", (
      tester,
    ) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "kept");

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpPastSettleDebounce(tester);

      expect(_fieldHasFocus(tester), isFalse);
      expect(SuperEditorInspector.findDocumentSelection()!.extent.nodeId, _noteNode().id);
      expect(_caretOffset(), _noteNode().text.placeholders.keys.single + 1);
      expect(_notes().single.text, "kept");

      await tester.typeImeText("x");
      await pumpPastSettleDebounce(tester);
      expect(_noteNode().text.toPlainText(), "He waits ￼x now.");
    });

    testWidgets("gives the focus back to the text with Escape the same way", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpPastSettleDebounce(tester);

      expect(_fieldHasFocus(tester), isFalse);
      expect(_caretOffset(), _noteNode().text.placeholders.keys.single + 1);
    });

    testWidgets("breaks the line with Shift+Enter, a blank line written with two spaces", (
      tester,
    ) async {
      await _pump(tester, "[[old]]\n\nShe leaves.");
      final id = _notes().single.id;
      await _selectFirstCard(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(tester.widget<TextField>(_field()).controller!.text, "old\n\n");
      await _write(tester, "old\n\nnext");
      await pumpPastSettleDebounce(tester);

      expect(_fieldHasFocus(tester), isTrue);
      expect(_notes().single, OcptFountainNote(id: id, text: "old\n  \nnext"));
      expect(_reported.last, contains("[[old\n  \nnext]]"));
      final decoded = OcptWysiwygCodec.decode(_reported.last).document;
      final notes = [
        for (final node in decoded.whereType<ParagraphNode>())
          ...node.text.placeholders.values.whereType<OcptFountainNote>(),
      ];
      expect(notes.single.text, "old\n  \nnext");
    });

    testWidgets("removes the note when it is left empty and the focus goes", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "");
      expect(_notes().single.text, "");

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpPastSettleDebounce(tester);

      expect(_notes(), isEmpty);
      expect(find.byType(OcptNoteCard), findsNothing);
      expect(_document().first.asTextNode.text.toPlainText(), "He waits now.");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes().single.text, "old");
    });

    testWidgets("removes the note left empty when a tap lands elsewhere in the text", (
      tester,
    ) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "  ");

      await tester.placeCaretInParagraph(_document().last.id, 2);
      await pumpPastSettleDebounce(tester);

      expect(_notes(), isEmpty);
      expect(_document().first.asTextNode.text.toPlainText(), "He waits now.");
    });

    testWidgets("flushes what is being written when the editor leaves the tree", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);

      await _write(tester, "just typed");
      await tester.pumpWidget(const SizedBox());

      expect(_reported.last, contains("[[just typed]]"));
    });

    testWidgets("survives a round trip through the Fountain text after its edits", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      await _write(tester, "edited [brackets] too");
      await pumpPastSettleDebounce(tester);
      final text = _reported.last;

      await _pump(tester, text, key: const ValueKey("second"));

      expect(_notes().single.text, "edited [brackets] too");
      expect(_noteNode().text.toPlainText(), "He waits ￼ now.");
    });
  });

  group("the button of the selected card", () {
    testWidgets("removes the note, and Ctrl+Z brings it back", (tester) async {
      await _pump(tester, _source);
      await _selectFirstCard(tester);
      final tr = Tr.of(tester.element(find.byType(OcptNoteCard).first));

      await tester.tap(find.text(tr.editorContextMenuRemoveNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(_notes(), isEmpty);
      expect(find.byType(OcptNoteCard), findsNothing);
      expect(_document().first.asTextNode.text.toPlainText(), "He waits now.");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes().single.text, "old");
    });

    testWidgets("is only on the selected card", (tester) async {
      await _pump(tester, "A [[one]] b.\n\nC [[two]] d.");
      final tr = Tr.of(tester.element(find.byType(OcptNoteCard).first));
      expect(find.text(tr.editorContextMenuRemoveNoteAction), findsNothing);

      await _selectFirstCard(tester);

      expect(find.text(tr.editorContextMenuRemoveNoteAction), findsOneWidget);
    });
  });

  group("the Insert note and Remove note commands", () {
    _testWidgetsAsDesktop("insert an empty note at the caret and give the focus to its card", (
      tester,
    ) async {
      await _pump(tester, "Some action text.");
      final nodeId = _document().first.id;

      final tr = await _rightClickIn(tester, nodeId);
      await tester.tap(_menuEntry(tr.editorContextMenuInsertNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(_notes().single.text, "");
      expect(_noteNode().text.toPlainText(), "￼Some action text.");
      expect(find.byType(OcptNoteCard), findsOneWidget);
      expect(_fieldHasFocus(tester), isTrue);
    });

    _testWidgetsAsDesktop("insert the note at the end of a selection, its text untouched", (
      tester,
    ) async {
      await _pump(tester, "Some action text.");
      final nodeId = _document().first.id;
      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      await tester.placeCaretInParagraph(nodeId, 0);
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 5)),
          extent: DocumentPosition(
            nodeId: nodeId,
            nodePosition: const TextNodePosition(offset: 11),
          ),
        ),
      );
      await tester.pump();

      final tr = await _rightClickIn(tester, nodeId, dx: 75);
      await tester.tap(_menuEntry(tr.editorContextMenuInsertNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(_noteNode().text.toPlainText(), "Some action￼ text.");
      expect(_noteNode().text.placeholders.keys.single, 11);
    });

    _testWidgetsAsDesktop("undo the insertion in one Ctrl+Z, leaving no empty note", (
      tester,
    ) async {
      await _pump(tester, "Some action text.");
      final tr = await _rightClickIn(tester, _document().first.id);
      await tester.tap(_menuEntry(tr.editorContextMenuInsertNoteAction));
      await pumpPastSettleDebounce(tester);

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes(), isEmpty);
      expect(_document().first.asTextNode.text.toPlainText(), "Some action text.");
      expect(find.byType(OcptNoteCard), findsNothing);
    });

    _testWidgetsAsDesktop("take back an insertion and the text written in it in one Ctrl+Z", (
      tester,
    ) async {
      await _pump(tester, "Some action text.");
      final tr = await _rightClickIn(tester, _document().first.id);
      await tester.tap(_menuEntry(tr.editorContextMenuInsertNoteAction));
      await pumpPastSettleDebounce(tester);
      await _write(tester, "a");
      await _write(tester, "ab");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes(), isEmpty);
      expect(_document().first.asTextNode.text.toPlainText(), "Some action text.");
    });

    _testWidgetsAsDesktop("remove an insertion left empty in the step that created it", (
      tester,
    ) async {
      await _pump(tester, "Some action text.");
      final tr = await _rightClickIn(tester, _document().first.id);
      await tester.tap(_menuEntry(tr.editorContextMenuInsertNoteAction));
      await pumpPastSettleDebounce(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpPastSettleDebounce(tester);
      expect(_notes(), isEmpty);
      expect(_document().first.asTextNode.text.toPlainText(), "Some action text.");

      await _sendCtrl(tester, LogicalKeyboardKey.keyZ);

      expect(_notes(), isEmpty);
      expect(_document().first.asTextNode.text.toPlainText(), "Some action text.");
    });

    _testWidgetsAsDesktop("remove the note a caret touches", (tester) async {
      await _pump(tester, "[[a note]] text.");
      final tr = await _rightClickIn(tester, _document().first.id);

      await tester.tap(_menuEntry(tr.editorContextMenuRemoveNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(_document().first.asTextNode.text.toPlainText(), "text.");
      expect(_notes(), isEmpty);
    });

    _testWidgetsAsDesktop("remove the note a selection holds alone", (tester) async {
      await _pump(tester, "Be [[a note]] text.");
      final nodeId = _document().first.id;
      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      await tester.placeCaretInParagraph(nodeId, 0);
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 1)),
          extent: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 5)),
        ),
      );
      await tester.pump();
      final tr = await _rightClickIn(tester, nodeId, dx: 25);

      await tester.tap(_menuEntry(tr.editorContextMenuRemoveNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(_notes(), isEmpty);
      expect(_document().first.asTextNode.text.toPlainText(), "Be text.");
    });

    _testWidgetsAsDesktop("remove the note selected in the margin from a caret away from it", (
      tester,
    ) async {
      await _pump(tester, "A [[one]] b.\n\nPlain line.");
      await tester.placeCaretInParagraph(_document().last.id, 2);
      await _selectFirstCard(tester);
      final tr = await _rightClickIn(tester, _document().last.id);

      await tester.tap(_menuEntry(tr.editorContextMenuRemoveNoteAction));
      await pumpPastSettleDebounce(tester);

      expect(_notes(), isEmpty);
    });
  });
}
