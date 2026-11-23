// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// The text the editor last reported, written by [_pump].
String _lastEncoded = "";

/// Pump a styled editor over [text] that records the text it reports into [_lastEncoded].
Future<void> _pump(
  WidgetTester tester,
  String text, {
  OcptStyledEditorController? controller,
  bool isPageSimulationEnabled = false,
}) async {
  _lastEncoded = text;
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testWrap(
      OcptStyledScreenplayEditor(
        text: text,
        pageSetup: const OcptPageSetup.standard(),
        isPageSimulationEnabled: isPageSimulationEnabled,
        areSceneNumbersVisible: false,
        isSpellCheckVisible: false,
        onTextChanged: (value) => _lastEncoded = value,
        onCaretLineChanged: (_) {},
        jumpRequest: null,
        styledController: controller,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The dual-dialogue suffix of the node at [index] of [document].
String? _suffixAt(Document document, int index) =>
    OcptWysiwygDualDialogue.suffixOf(nodeAt(document, index));

/// Run the tests of the dual-dialogue marker in the styled editor.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  const pair = "ROSS\nHello.\n\nKIM ^\nHi.\n";

  group("the dual-dialogue marker", () {
    testWidgets("is hidden from the text and written back", (tester) async {
      await _pump(tester, pair);
      final document = SuperEditorInspector.findDocument()!;

      expect(nodeAt(document, 2).text.toPlainText(), "KIM");
      expect(_suffixAt(document, 2), " ^");
      await pumpPastSettleDebounce(tester);
      expect(_lastEncoded, pair);
    });

    testWidgets("a typed ^ is absorbed and undone in one step", (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 8, 18, 10)), () async {
        await _pump(tester, "ROSS\nHello.\n\nKIM\nHi.\n");
        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);

        await tester.typeImeText("^");
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 2).text.toPlainText(), "KIM");
        expect(_suffixAt(document, 2), "^");
        expect(_lastEncoded, "ROSS\nHello.\n\nKIM^\nHi.\n");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 2).text.toPlainText(), "KIM");
        expect(_suffixAt(document, 2), isNull);
        expect(_lastEncoded, "ROSS\nHello.\n\nKIM\nHi.\n");
      });
    });

    testWidgets("a cue turned into action drops it", (tester) async {
      await _pump(tester, pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 1);
      await sendKey(tester, LogicalKeyboardKey.tab);
      await sendKey(tester, LogicalKeyboardKey.tab);
      await pumpPastSettleDebounce(tester);

      // Tab cycles from character through parenthetical and dialogue: no longer a cue.
      expect(typeAt(document, 2), isNot(FountainLineType.character));
      expect(_suffixAt(document, 2), isNull);
    });

    testWidgets("Enter in a cue carrying it does not copy it", (tester) async {
      await _pump(tester, pair);
      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 3);

      await sendKey(tester, LogicalKeyboardKey.enter);
      await tester.typeImeText("Aside.");
      await pumpPastSettleDebounce(tester);

      expect(typeAt(document, 2), FountainLineType.character);
      expect(_suffixAt(document, 3), isNull);
      expect(_suffixAt(document, 2), " ^");
    });
  });

  group("the dual-dialogue marker on the clipboard", () {
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

    testWidgets("survives a copy and a paste", (tester) async {
      await _pump(tester, "$pair\nEND.\n");
      final document = SuperEditorInspector.findDocument()!;
      final lastIndex = document.nodeCount - 1;
      await tester.pumpAndSettle();

      await tester.placeCaretInParagraph(nodeAt(document, 2).id, 0);
      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: nodeAt(document, 2).id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: nodeAt(document, 3).id,
            nodePosition: const TextNodePosition(offset: 3),
          ),
        ),
      );
      await tester.pump();
      await sendCtrl(tester, LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(clipboardText, "KIM ^\nHi.");

      await tester.placeCaretInParagraph(nodeAt(document, lastIndex).id, 4);
      await sendKey(tester, LogicalKeyboardKey.enter);
      await sendKey(tester, LogicalKeyboardKey.enter);
      await sendCtrl(tester, LogicalKeyboardKey.keyV);
      await pumpPastSettleDebounce(tester);

      expect("KIM ^\nHi.".allMatches(_lastEncoded), hasLength(2));
    });
  });
}

/// Send one key press.
Future<void> sendKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}
