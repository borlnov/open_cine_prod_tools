// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Run the tests of the styled screenplay editor typing and shortcuts.
void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("auto-uppercase scene headings, character cues and transitions", () {
    testWidgets(
      "typing a lowercase scene heading uppercases the stored text as you type, caret offset "
      "unchanged",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        await tester.typeImeText("int. kitchen - day");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(nodeAt(document, 0).text.toPlainText(), "INT. KITCHEN - DAY");
        expect(typeAt(document, 0), FountainLineType.sceneHeading);
        expect(lastEncoded, "INT. KITCHEN - DAY #1#");

        final selection = SuperEditorInspector.findDocumentSelection();
        final extentOffset = (selection!.extent.nodePosition as TextNodePosition).offset;
        expect(extentOffset, "int. kitchen - day".length);
      },
    );

    testWidgets(
      "typing lowercase text into a manually-locked character cue or transition uppercases it",
      (tester) async {
        // Unlike scene headings, `FountainLineClassifier` only auto-detects a character cue or
        // transition from already-uppercase text (that asymmetry is the whole reason auto-uppercase
        // is needed for these two types): the only way such a block ever holds lowercase text in
        // practice is a manual type choice (dropdown or Tab, both of which lock the block), so that
        // is what this test drives, through `OcptStyledEditorController.setBlockType`.
        Future<String> typeIntoLockedBlock(FountainLineType type, String lowercaseText) async {
          final controller = OcptStyledEditorController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            testWrap(
              OcptStyledScreenplayEditor(
                key: ValueKey(type),
                text: "",
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

          final document = SuperEditorInspector.findDocument()!;
          final nodeId = nodeAt(document, 0).id;
          await tester.placeCaretInParagraph(nodeId, 0);

          controller.setBlockType(type);
          await tester.pump();

          await tester.typeImeText(lowercaseText);
          await tester.pump(const Duration(milliseconds: 150));
          await tester.pump();

          expect(typeAt(document, 0), type);
          return nodeAt(document, 0).text.toPlainText();
        }

        expect(await typeIntoLockedBlock(FountainLineType.character, "sarah"), "SARAH");
        expect(await typeIntoLockedBlock(FountainLineType.transition, "cut to:"), "CUT TO:");
      },
    );

    testWidgets(
      "a character type set on an empty block survives the reclassify debounce firing before any "
      "text is typed",
      (tester) async {
        // Regression test: the debounce used to fire while the block was still empty and clear
        // `ocptTypeLocked` as a side effect, so the first characters typed afterwards were
        // reclassified away from character. Unlike the test above, this one explicitly pumps past
        // `_syncDebounce` (120 ms) right after `setBlockType`, before typing anything.
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(tester, "", styledController: controller);

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        controller.setBlockType(FountainLineType.character);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(typeAt(document, 0), FountainLineType.character);
        expect(isLockedAt(document, 0), isTrue);

        await tester.typeImeText("john");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(typeAt(document, 0), FountainLineType.character);
        expect(nodeAt(document, 0).text.toPlainText(), "JOHN");
      },
    );

    testWidgets("bold/italic/underline spans survive the uppercase conversion", (tester) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: "",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      await tester.typeImeText("int. ");
      await sendCtrl(tester, LogicalKeyboardKey.keyB);
      await tester.typeImeText("kitchen");
      await sendCtrl(tester, LogicalKeyboardKey.keyB);
      await tester.typeImeText(" - day");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(nodeAt(document, 0).text.toPlainText(), "INT. KITCHEN - DAY");
      expect(lastEncoded, "INT. **KITCHEN** - DAY #1#");
    });
  });

  testWidgets("Ctrl+B, Ctrl+I and Ctrl+U toggle bold/italic/underline, serialized as **/*/_", (
    tester,
  ) async {
    Future<String> encodedAfterToggling(LogicalKeyboardKey key) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            // A distinct key per call: same rationale as `pumpStandaloneEditor`'s doc comment
            // (identical `text` across calls would otherwise reuse the previous call's document).
            key: ValueKey(key),
            text: "Base ",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final node = nodeAt(document, 0);
      await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);

      await sendCtrl(tester, key);
      await tester.typeImeText("styled");
      await sendCtrl(tester, key);
      await tester.typeImeText(" end");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      return lastEncoded;
    }

    expect(await encodedAfterToggling(LogicalKeyboardKey.keyB), "Base **styled** end");
    expect(await encodedAfterToggling(LogicalKeyboardKey.keyI), "Base *styled* end");
    expect(await encodedAfterToggling(LogicalKeyboardKey.keyU), "Base _styled_ end");
  });

  group("scene numbers", () {
    testWidgets(
      "typing a #N# tag that matches its sequential position is absorbed into metadata, hidden "
      "from the text",
      (tester) async {
        await pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nEXT. GARDEN - NIGHT");

        final document = SuperEditorInspector.findDocument()!;
        final secondHeading = nodeAt(document, 1);
        await tester.placeCaretInParagraph(
          secondHeading.id,
          secondHeading.text.toPlainText().length,
        );

        await tester.typeImeText(" #2#");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(nodeAt(document, 1).text.toPlainText(), "EXT. GARDEN - NIGHT");
        expect(sceneNumberAt(document, 1), "2");
      },
    );

    testWidgets(
      "typing a #N# tag that does not fit its position is absorbed then immediately corrected",
      (tester) async {
        await pumpStandaloneEditor(tester, "INT. HOUSE - DAY");

        final document = SuperEditorInspector.findDocument()!;
        final node = nodeAt(document, 0);
        await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);

        await tester.typeImeText(" #4A#");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(nodeAt(document, 0).text.toPlainText(), "INT. HOUSE - DAY");
        expect(sceneNumberAt(document, 0), "1");
      },
    );

    testWidgets("the scene-number gutter renders only while areSceneNumbersVisible is true", (
      tester,
    ) async {
      const text = "INT. HOUSE - DAY\n\nAction.";

      await pumpStandaloneEditor(tester, text);
      expect(find.text("1"), findsNothing);

      await pumpStandaloneEditor(
        tester,
        text,
        key: const Key("visible"),
        areSceneNumbersVisible: true,
      );
      expect(find.text("1"), findsOneWidget);
    });

    testWidgets("every scene heading is auto-numbered into the source, even with no #N# typed", (
      tester,
    ) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: "INT. HOUSE - DAY\n\nAction.\n\nEXT. GARDEN - NIGHT",
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (text) => lastEncoded = text,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastEncoded, "INT. HOUSE - DAY #1#\n\nAction.\n\nEXT. GARDEN - NIGHT #2#");
    });

    testWidgets(
      "badly-ordered numbers entered in raw mode are corrected once decoded into the styled view",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "INT. HOUSE - DAY #9#\n\nEXT. GARDEN - NIGHT #2#",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (text) => lastEncoded = text,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(lastEncoded, "INT. HOUSE - DAY #1#\n\nEXT. GARDEN - NIGHT #2#");
      },
    );
  });

  group("copy, cut and paste keep block types", () {
    // The `flutter/platform` channel's `Clipboard.setData`/`getData` methods have no built-in
    // mock handler on this SDK: without one, `Clipboard.getData` never completes at all, and
    // every paste in this group hangs forever instead of failing loudly.
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

    testWidgets("copying a character cue and its dialogue, then pasting them on a fresh blank "
        "line, "
        "reproduces both blocks with their types and spacing", (tester) async {
      var lastEncoded = "";
      const text = "INT. HOUSE - DAY\n\nSARAH\nHello there.\n\nSome trailing action.";

      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (value) => lastEncoded = value,
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
      // Nodes: 0 = heading, 1 = character, 2 = dialogue, 3 = trailing action.
      final characterNode = nodeAt(document, 1);
      final dialogueNode = nodeAt(document, 2);
      final trailingNode = nodeAt(document, 3);

      // Placing the caret first is what actually gives the editor keyboard focus (a bare
      // `setSelectionWithReason` doesn't); the expanded selection then overrides it.
      await tester.placeCaretInParagraph(characterNode.id, 0);
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: characterNode.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: dialogueNode.id,
            nodePosition: TextNodePosition(offset: dialogueNode.text.toPlainText().length),
          ),
        ),
      );
      await tester.pump();

      await sendCtrl(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      // A fresh Enter at the very end of the document opens a new, empty blank line to paste
      // onto — the common "paste elsewhere" target.
      await tester.placeCaretInParagraph(trailingNode.id, trailingNode.text.toPlainText().length);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      await sendCtrl(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(document.nodeCount, 6);
      expect(typeAt(document, 4), FountainLineType.character);
      expect(nodeAt(document, 4).text.toPlainText(), "SARAH");
      expect(typeAt(document, 5), FountainLineType.dialogue);
      expect(nodeAt(document, 5).text.toPlainText(), "Hello there.");

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(
        lastEncoded,
        "INT. HOUSE - DAY #1#\n\nSARAH\nHello there.\n\nSome trailing action.\n\nSARAH\nHello "
        "there.",
      );
    });

    testWidgets(
      "pasting a single-node fragment inside existing text inserts it inline without splitting the "
      "block",
      (tester) async {
        var lastEncoded = "";
        const text = "Some action text here.";

        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: text,
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
        final actionNode = nodeAt(document, 0);

        // Placing the caret first is what actually gives the editor keyboard focus (a bare
        // `setSelectionWithReason` doesn't); the expanded selection then overrides it.
        await tester.placeCaretInParagraph(actionNode.id, 5);
        composer.setSelectionWithReason(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: actionNode.id,
              nodePosition: const TextNodePosition(offset: 5),
            ),
            extent: DocumentPosition(
              nodeId: actionNode.id,
              nodePosition: const TextNodePosition(offset: 11),
            ),
          ),
        );
        await tester.pump();

        await sendCtrl(tester, LogicalKeyboardKey.keyC);
        await tester.pumpAndSettle();

        await tester.placeCaretInParagraph(actionNode.id, 0);
        await sendCtrl(tester, LogicalKeyboardKey.keyV);
        await tester.pumpAndSettle();

        expect(document.nodeCount, 1);
        expect(typeAt(document, 0), FountainLineType.action);
        expect(nodeAt(document, 0).text.toPlainText(), "actionSome action text here.");

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
        expect(lastEncoded, "actionSome action text here.");
      },
    );

    testWidgets(
      "cutting a selection removes it from the document and copies its Fountain text to the "
      "clipboard",
      (tester) async {
        const text = "SARAH\nHello there.\n\nSome trailing action.";

        await pumpStandaloneEditor(tester, text);

        final document = SuperEditorInspector.findDocument()!;
        final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
        final characterNode = nodeAt(document, 0);
        final dialogueNode = nodeAt(document, 1);

        // Placing the caret first is what actually gives the editor keyboard focus (a bare
        // `setSelectionWithReason` doesn't); the expanded selection then overrides it.
        await tester.placeCaretInParagraph(characterNode.id, 0);
        composer.setSelectionWithReason(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: characterNode.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: dialogueNode.id,
              nodePosition: TextNodePosition(offset: dialogueNode.text.toPlainText().length),
            ),
          ),
        );
        await tester.pump();

        await sendCtrl(tester, LogicalKeyboardKey.keyX);
        await tester.pumpAndSettle();

        // super_editor's own `DeleteContentCommand` inserts a fresh empty paragraph in place of a
        // selection that fully covered every node it touched, so there's somewhere for the caret to
        // land — the deleted character cue and dialogue become one empty node, not zero.
        expect(document.nodeCount, 2);
        expect(nodeAt(document, 0).text.toPlainText(), isEmpty);
        expect(nodeAt(document, 1).text.toPlainText(), "Some trailing action.");

        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
        expect(clipboardData?.text, "SARAH\nHello there.");
      },
    );
  });

  group("OcptStyledEditorController", () {
    testWidgets("becomes attached once the editor is pumped", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      expect(controller.isAttached, isFalse);

      await pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      expect(controller.isAttached, isTrue);
    });

    testWidgets("currentBlockType follows the caret across nodes of different types", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      const text = "INT. HOUSE - DAY\n\nSARAH\nHello.";

      await pumpStandaloneEditor(tester, text, styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final headingNodeId = nodeAt(document, 0).id;
      final characterNodeId = nodeAt(document, 1).id;
      final dialogueNodeId = nodeAt(document, 2).id;

      await tester.placeCaretInParagraph(headingNodeId, 0);
      expect(controller.currentBlockType, FountainLineType.sceneHeading);

      await tester.placeCaretInParagraph(characterNodeId, 0);
      expect(controller.currentBlockType, FountainLineType.character);

      await tester.placeCaretInParagraph(dialogueNodeId, 0);
      expect(controller.currentBlockType, FountainLineType.dialogue);
    });

    testWidgets("currentBlockType follows a Tab cycle immediately, before the sync debounce", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      expect(controller.currentBlockType, FountainLineType.action);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // A single `pump()`, deliberately short of the 120 ms sync debounce: the dropdown must
      // already reflect the new type from `_onDocumentChanged` alone, not from the debounced sync.
      await tester.pump();

      expect(controller.currentBlockType, FountainLineType.character);
    });

    testWidgets("setBlockType changes the live document's node blockType and locks it", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      expect(typeAt(document, 0), FountainLineType.action);
      expect(isLockedAt(document, 0), isFalse);

      controller.setBlockType(FountainLineType.character);
      await tester.pump();

      expect(typeAt(document, 0), FountainLineType.character);
      expect(isLockedAt(document, 0), isTrue);
      expect(controller.currentBlockType, FountainLineType.character);
    });

    testWidgets("toggleInlineStyle on a collapsed caret flips activeInlineStyles", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);

      expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isFalse);

      controller.toggleInlineStyle(OcptInlineStyle.bold);
      await tester.pump();
      expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isTrue);

      controller.toggleInlineStyle(OcptInlineStyle.bold);
      await tester.pump();
      expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isFalse);
    });

    testWidgets("toggleInlineStyle on an expanded selection serializes to **/*/_", (tester) async {
      Future<String> encodedAfterToggling(OcptInlineStyle style) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        var lastEncoded = "";

        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              // A distinct key per call: same rationale as `pumpStandaloneEditor`'s doc comment.
              key: ValueKey(style),
              text: "Base styled end",
              pageSetup: const OcptPageSetup.standard(),
              isPageSimulationEnabled: false,
              areSceneNumbersVisible: false,
              isSpellCheckVisible: false,
              onTextChanged: (value) => lastEncoded = value,
              onCaretLineChanged: (_) {},
              jumpRequest: null,
              styledController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        // A double tap selects the whole word under it: "Base styled end" has "styled" starting
        // at offset 5, so tapping mid-word (offset 7) selects exactly "styled".
        await tester.doubleTapInParagraph(nodeId, 7);

        controller.toggleInlineStyle(style);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        return lastEncoded;
      }

      expect(await encodedAfterToggling(OcptInlineStyle.bold), "Base **styled** end");
      expect(await encodedAfterToggling(OcptInlineStyle.italic), "Base *styled* end");
      expect(await encodedAfterToggling(OcptInlineStyle.underline), "Base _styled_ end");
    });
  });
}
