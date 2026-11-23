// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The text the editor last reported, written by [_pump].
String _lastEncoded = "";

/// The pair every test edits: KIM carries a hidden ` ^`.
const _pair = "ROSS\nHello.\n\nKIM ^\nHi.\n";

/// Pump a styled editor over [text] that records the text it reports into [_lastEncoded].
Future<void> _pump(WidgetTester tester, String text) async {
  _lastEncoded = text;
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: false,
        areSceneNumbersVisible: false,
        isSpellCheckVisible: false,
        onTextChanged: (value) => _lastEncoded = value,
        onCaretLineChanged: (_) {},
        jumpRequest: null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Send one key press.
Future<void> _sendKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Get the offset of the caret, which must be collapsed in a text node.
int _caretOffset() {
  final selection = SuperEditorInspector.findDocumentSelection()!;
  return (selection.extent.nodePosition as TextNodePosition).offset;
}

/// Run the tests of the edits that touch the dual-dialogue marker in the styled editor.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  group("absorbing a typed marker", () {
    testWidgets("leaves the caret inside the shorter cue, so typing and Enter go on", (
      tester,
    ) async {
      await _pump(tester, "ROSS\nHello.\n\nKIM\nHi.\n");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);

      await tester.typeImeText(" ^");
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 2).text.toPlainText(), "KIM");
      expect(_caretOffset(), 3);
      await _sendKey(tester, LogicalKeyboardKey.enter);
      await tester.typeImeText("x");
      await pumpPastSettleDebounce(tester);
      expect(tester.takeException(), isNull);
      expect(_lastEncoded, startsWith("ROSS\nHello.\n\nKIM ^\n"));
    });

    testWidgets("undo and redo keep the caret inside the text", (tester) async {
      await _pump(tester, "ROSS\nHello.\n\nKIM\nHi.\n");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);
      await tester.typeImeText(" ^");
      await pumpPastSettleDebounce(tester);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(_caretOffset(), lessThanOrEqualTo(nodeAt(document, 2).text.length));
      await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(_caretOffset(), lessThanOrEqualTo(nodeAt(document, 2).text.length));
      expect(tester.takeException(), isNull);
    });

    testWidgets("a scene number typed at the end of a heading keeps the caret inside", (
      tester,
    ) async {
      await _pump(tester, "INT. HOUSE - DAY\n\nAction.\n");
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 16);

      await tester.typeImeText(" #12#");
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "INT. HOUSE - DAY");
      expect(_caretOffset(), 16);
      await tester.typeImeText("X");
      await pumpPastSettleDebounce(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group("a cue that stops being one", () {
    testWidgets("keeps the marker when a letter is typed at its end", (tester) async {
      await _pump(tester, _pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);

      await tester.typeImeText("a");
      await pumpPastSettleDebounce(tester);

      expect(" ^".allMatches(_lastEncoded), hasLength(1));
      expect(_lastEncoded, contains(" ^\nHi."));
    });

    testWidgets("keeps the marker when a lowercase extension is typed", (tester) async {
      await _pump(tester, _pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);

      await tester.typeImeText(" (cont'd)");
      await pumpPastSettleDebounce(tester);

      expect(_lastEncoded, contains(" ^\nHi."));
    });

    testWidgets("keeps the marker when the cue is cut off from its speech by Shift+Enter", (
      tester,
    ) async {
      await _pump(tester, _pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);

      await sendShift(tester, LogicalKeyboardKey.enter);
      await pumpPastSettleDebounce(tester);

      expect(_lastEncoded, contains("KIM ^"));
    });

    testWidgets("keeps the marker when the dialogue after it is emptied and retyped", (
      tester,
    ) async {
      await _pump(tester, _pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 3).id, 3);
      for (var index = 0; index < 3; index++) {
        await _sendKey(tester, LogicalKeyboardKey.backspace);
      }
      await pumpPastSettleDebounce(tester);
      await tester.typeImeText("Yes.");
      await pumpPastSettleDebounce(tester);

      expect(_lastEncoded, "ROSS\nHello.\n\nKIM ^\nYes.\n");
    });

    testWidgets("puts the marker back as a cue again when it reads as one", (tester) async {
      await _pump(tester, _pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);
      await tester.typeImeText("a");
      await pumpPastSettleDebounce(tester);
      await _sendKey(tester, LogicalKeyboardKey.backspace);
      await pumpPastSettleDebounce(tester);

      expect(typeAt(document, 2), FountainLineType.character);
      expect(" ^".allMatches(_lastEncoded), hasLength(1));
      expect(_lastEncoded, startsWith("ROSS\nHello.\n\nKIM ^\n"));
    });
  });

  group("splitting a cue carrying the marker", () {
    /// Split KIM's node at [offset] with Enter and report the suffixes of the two nodes, read as
    /// soon as the split is done.
    Future<(String?, String?)> splitAt(WidgetTester tester, int offset) async {
      await _pump(tester, _pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, offset);
      await _sendKey(tester, LogicalKeyboardKey.enter);
      return (
        OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 2)),
        OcptWysiwygDualDialogue.suffixOf(nodeAt(document, 3)),
      );
    }

    testWidgets("at its start gives the suffix to the cue that follows", (tester) async {
      final (before, after) = await splitAt(tester, 0);
      await pumpPastSettleDebounce(tester);

      expect(before, isNull);
      expect(after, " ^");
      expect(" ^".allMatches(_lastEncoded), hasLength(1));
      expect(_lastEncoded, contains("KIM ^\nHi."));
    });

    testWidgets("in the middle gives the suffix to the tail", (tester) async {
      final (before, after) = await splitAt(tester, 2);
      await pumpPastSettleDebounce(tester);

      expect(before, isNull);
      expect(after, " ^");
      expect(_lastEncoded, isNot(contains("KI ^")));
      expect(_lastEncoded, contains("M ^"));
    });

    testWidgets("at its end leaves the suffix where it was", (tester) async {
      final (before, after) = await splitAt(tester, 3);
      await pumpPastSettleDebounce(tester);

      expect(before, " ^");
      expect(after, isNull);
      expect(_lastEncoded, contains("KIM ^"));
    });
  });
}
