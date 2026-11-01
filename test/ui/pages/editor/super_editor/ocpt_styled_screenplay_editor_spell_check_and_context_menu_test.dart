// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_fountain_line_type_labels.dart';
import 'package:spell_kit/spell_kit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// A global offset landing inside the actual glyphs of the node with [nodeId], for a secondary tap
/// meant to resolve to a document position within its text: [Alignment.center] alone isn't reliable
/// for that, since a Fountain element's box is typically much wider than a short line of text (its
/// `Styles.maxWidth`, not the text's own measured width) — the dead centre of the box then falls in
/// the empty space to the right of the actual characters, where
/// `getDocumentPositionNearestToOffset` snaps to the end of the text with an *upstream* affinity,
/// which the exact-offset, *downstream*- affinity end of a selection built with a plain
/// `TextNodePosition(offset: ...)` doesn't compare equal to (`doesSelectionContainPosition` cares
/// about affinity, not just offset).
Offset _tapOffsetInsideText(String nodeId) =>
    SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) + const Offset(4, 0);

/// Runs a right-click context-menu [testWidgets] case with [defaultTargetPlatform] forced to a
/// desktop platform for [body]'s whole duration.
///
/// `flutter test` forces `defaultTargetPlatform` to [TargetPlatform.android] (see
/// `_platform_io.dart`'s own `FLUTTER_TEST` check), which would otherwise make `SuperEditor` build
/// its Android touch interactor instead of `DocumentMouseInteractor` — a completely different
/// gesture surface, whose selection-handle machinery ends up swallowing a right-click's pointer
/// event before it ever reaches this widget's own `GestureDetector`. Overriding it to a desktop
/// platform is what actually exercises the code path this app ships on Linux/Windows, where a real
/// OS never sets `FLUTTER_TEST` in the first place.
///
/// The override is set and reset from *inside* the test body (a `try`/`finally` here), not through
/// `setUp`/`tearDown`: `testWidgets` asserts every foundation debug variable is back to its default
/// before the `test` package's own `tearDown` queue ever runs, so resetting it there fires that
/// assertion too late — resetting it before this function's own `async` body returns is what
/// actually lands in time.
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

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("right-click context menu", () {
    // Mirrors the "copy, cut and paste keep block types" group's own clipboard mock: without it,
    // `Clipboard.getData`/`setData` never complete, and a context-menu Copy/Paste hangs forever.
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

    _testWidgetsAsDesktop(
      "right-clicking with a collapsed caret shows Paste, Select all and Block type, but "
      "neither Cut nor Copy",
      (tester) async {
        await pumpStandaloneEditor(tester, "Some action text.");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        final tapOffset = _tapOffsetInsideText(nodeId);

        await tester.tapAt(tapOffset, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        expect(find.text(tr.editorContextMenuPasteAction), findsOneWidget);
        expect(find.text(tr.editorContextMenuSelectAllAction), findsOneWidget);
        expect(find.text(tr.editorContextMenuBlockTypeSubmenu), findsOneWidget);
        expect(find.text(tr.editorContextMenuCutAction), findsNothing);
        expect(find.text(tr.editorContextMenuCopyAction), findsNothing);
      },
    );

    _testWidgetsAsDesktop(
      "right-clicking with an expanded selection shows Cut and Copy too, and picking Copy "
      "puts that selection's Fountain source on the clipboard",
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

        final tapOffset = _tapOffsetInsideText(dialogueNode.id);
        await tester.tapAt(tapOffset, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        expect(find.text(tr.editorContextMenuCutAction), findsOneWidget);
        expect(find.text(tr.editorContextMenuCopyAction), findsOneWidget);

        await tester.tap(find.text(tr.editorContextMenuCopyAction));
        await tester.pumpAndSettle();

        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
        expect(clipboardData?.text, "SARAH\nHello there.");
      },
    );

    _testWidgetsAsDesktop(
      "picking Paste inserts the clipboard's Fountain source at the caret, block types "
      "and all",
      (tester) async {
        var lastEncoded = "";
        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "Some trailing action.",
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

        // Fountain source put on the clipboard by anything at all — another app, or this editor's
        // own Copy: the payload is plain Fountain text either way, which is the whole point of
        // sharing `ocptPasteFountainClipboardContent` with the Ctrl+V handler.
        await Clipboard.setData(const ClipboardData(text: "SARAH\nHello there."));

        final document = SuperEditorInspector.findDocument()!;
        final actionNode = nodeAt(document, 0);
        // A fresh empty line at the very end of the document, the common "paste elsewhere" target.
        await tester.placeCaretInParagraph(actionNode.id, actionNode.text.toPlainText().length);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        await tester.tapAt(_tapOffsetInsideText(nodeAt(document, 1).id), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        await tester.tap(find.text(tr.editorContextMenuPasteAction));
        await tester.pumpAndSettle();

        expect(document.nodeCount, 3);
        expect(typeAt(document, 1), FountainLineType.character);
        expect(nodeAt(document, 1).text.toPlainText(), "SARAH");
        expect(typeAt(document, 2), FountainLineType.dialogue);
        expect(nodeAt(document, 2).text.toPlainText(), "Hello there.");

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
        expect(lastEncoded, "Some trailing action.\n\nSARAH\nHello there.");
      },
    );

    _testWidgetsAsDesktop(
      "right-clicking a different block than the one holding the caret retypes THAT block "
      "through the submenu, not the previously-focused one",
      (tester) async {
        const text = "INT. HOUSE - DAY\n\nSome action text.";
        await pumpStandaloneEditor(tester, text);

        final document = SuperEditorInspector.findDocument()!;
        final headingNode = nodeAt(document, 0);
        final actionNode = nodeAt(document, 1);

        await tester.placeCaretInParagraph(headingNode.id, 0);

        final tapOffset = _tapOffsetInsideText(actionNode.id);
        await tester.tapAt(tapOffset, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        await tester.tap(find.text(tr.editorContextMenuBlockTypeSubmenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ocptFountainLineTypeLabel(tr, FountainLineType.character)));
        await tester.pumpAndSettle();

        // The heading (where the caret used to sit) is untouched; the action block the right-click
        // actually landed on is the one that got retyped.
        expect(typeAt(document, 0), FountainLineType.sceneHeading);
        expect(typeAt(document, 1), FountainLineType.character);
      },
    );

    _testWidgetsAsDesktop(
      "right-clicking inside an existing expanded selection leaves that selection intact",
      (tester) async {
        const text = "SARAH\nHello there.\n\nSome trailing action.";
        await pumpStandaloneEditor(tester, text);

        final document = SuperEditorInspector.findDocument()!;
        final composer = SuperEditorInspector.findComposer()! as MutableDocumentComposer;
        final characterNode = nodeAt(document, 0);
        final dialogueNode = nodeAt(document, 1);

        await tester.placeCaretInParagraph(characterNode.id, 0);
        final expandedSelection = DocumentSelection(
          base: DocumentPosition(
            nodeId: characterNode.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: dialogueNode.id,
            nodePosition: TextNodePosition(offset: dialogueNode.text.toPlainText().length),
          ),
        );
        composer.setSelectionWithReason(expandedSelection);
        await tester.pump();

        // The tap lands on the character cue, itself inside the selection's own range.
        final tapOffset = _tapOffsetInsideText(characterNode.id);
        await tester.tapAt(tapOffset, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(SuperEditorInspector.findDocumentSelection(), expandedSelection);
      },
    );

    _testWidgetsAsDesktop(
      "picking a type in the submenu changes the block's type and locks it, exactly like "
      "the toolbar dropdown",
      (tester) async {
        await pumpStandaloneEditor(tester, "Some action text.");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        final tapOffset = _tapOffsetInsideText(nodeId);

        expect(typeAt(document, 0), FountainLineType.action);
        expect(isLockedAt(document, 0), isFalse);

        await tester.tapAt(tapOffset, buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        await tester.tap(find.text(tr.editorContextMenuBlockTypeSubmenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ocptFountainLineTypeLabel(tr, FountainLineType.character)));
        await tester.pumpAndSettle();

        expect(typeAt(document, 0), FountainLineType.character);
        expect(isLockedAt(document, 0), isTrue);
      },
    );

    _testWidgetsAsDesktop(
      "a left click elsewhere on the document closes the menu and still places the "
      "caret",
      (tester) async {
        const text = "INT. HOUSE - DAY\n\nSome action text.";
        await pumpStandaloneEditor(tester, text);

        final document = SuperEditorInspector.findDocument()!;
        final headingNode = nodeAt(document, 0);
        final actionNode = nodeAt(document, 1);

        // Right-clicked on the lower node and left-clicked back on the upper one, so the second
        // click lands on the document itself rather than on the menu the first one just opened
        // below it.
        await tester.tapAt(_tapOffsetInsideText(actionNode.id), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        expect(find.text(tr.editorContextMenuSelectAllAction), findsOneWidget);

        await tester.tapAt(_tapOffsetInsideText(headingNode.id));
        await tester.pumpAndSettle();

        expect(find.text(tr.editorContextMenuSelectAllAction), findsNothing);
        expect(SuperEditorInspector.findDocumentSelection()?.extent.nodeId, headingNode.id);
      },
    );

    _testWidgetsAsDesktop("Select all expands the selection across the whole document", (
      tester,
    ) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";
      await pumpStandaloneEditor(tester, text);

      final document = SuperEditorInspector.findDocument()!;
      final headingNode = nodeAt(document, 0);
      final actionNode = nodeAt(document, 1);
      final tapOffset = _tapOffsetInsideText(headingNode.id);

      await tester.tapAt(tapOffset, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      await tester.tap(find.text(tr.editorContextMenuSelectAllAction));
      await tester.pumpAndSettle();

      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection, isNotNull);
      expect(selection!.base.nodeId, headingNode.id);
      expect((selection.base.nodePosition as TextNodePosition).offset, 0);
      expect(selection.extent.nodeId, actionNode.id);
      expect(
        (selection.extent.nodePosition as TextNodePosition).offset,
        actionNode.text.toPlainText().length,
      );
    });
  });

  group("right-click spelling suggestions", () {
    _testWidgetsAsDesktop(
      "right-clicking a misspelled word offers the suggestions the callback returns, and picking "
      "one rewrites exactly that word, undone whole by a single Ctrl+Z",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        final requestedWords = <String>[];

        // The whole action line is the misspelled word itself, so `_tapOffsetInsideText` (which
        // taps near the node's own left edge) is guaranteed to land inside the range below,
        // without needing to resolve a pixel offset for one particular word inside a longer line.
        await pumpStandaloneEditor(
          tester,
          "wrold",
          styledController: controller,
          isSpellCheckVisible: true,
          onSpellingSuggestionsRequested: (word) async {
            requestedWords.add(word);
            return ["world", "word", "wold"];
          },
          // Both actions are wired only so this test can assert they are *offered* beside the
          // suggestions; each is withheld when its own callback is null, and the two tests below
          // are what exercise what picking one actually reports.
          onWordIgnored: (_) {},
          onWordLearned: (_) {},
        );

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        controller.updateSpellCheckRanges({
          nodeId: [const SpellRange(0, 5)],
        });
        await tester.pump();

        await tester.tapAt(_tapOffsetInsideText(nodeId), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        expect(requestedWords, ["wrold"]);
        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        expect(find.text("world"), findsOneWidget);
        expect(find.text("word"), findsOneWidget);
        expect(find.text("wold"), findsOneWidget);
        expect(find.text(tr.editorContextMenuIgnoreWordAction), findsOneWidget);
        expect(find.text(tr.editorContextMenuAddToDictionaryAction), findsOneWidget);

        await tester.tap(find.text("world"));
        await tester.pumpAndSettle();

        expect(nodeAt(document, 0).text.toPlainText(), "world");

        await pumpPastSettleDebounce(tester);
        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await tester.pumpAndSettle();

        expect(nodeAt(document, 0).text.toPlainText(), "wrold");
      },
    );

    _testWidgetsAsDesktop("right-clicking a word that isn't misspelled shows no suggestions and no "
        "spelling actions", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(
        tester,
        "Some correct action.",
        styledController: controller,
        isSpellCheckVisible: true,
        onSpellingSuggestionsRequested: (word) async => ["should not be offered"],
      );

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      // No ranges at all reported for this node: nothing under the tap is flagged.
      await tester.tapAt(_tapOffsetInsideText(nodeId), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
      expect(find.text("should not be offered"), findsNothing);
      expect(find.text(tr.editorContextMenuIgnoreWordAction), findsNothing);
      expect(find.text(tr.editorContextMenuAddToDictionaryAction), findsNothing);
      // The ordinary entries are still there, untouched by the withheld spelling group.
      expect(find.text(tr.editorContextMenuSelectAllAction), findsOneWidget);
    });

    _testWidgetsAsDesktop(
      "picking Ignore this word reports the word up without touching the document",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        String? ignoredWord;

        await pumpStandaloneEditor(
          tester,
          "wrold",
          styledController: controller,
          isSpellCheckVisible: true,
          onSpellingSuggestionsRequested: (word) async => const [],
          onWordIgnored: (word) => ignoredWord = word,
        );

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        controller.updateSpellCheckRanges({
          nodeId: [const SpellRange(0, 5)],
        });
        await tester.pump();

        await tester.tapAt(_tapOffsetInsideText(nodeId), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        await tester.tap(find.text(tr.editorContextMenuIgnoreWordAction));
        await tester.pumpAndSettle();

        expect(ignoredWord, "wrold");
        expect(nodeAt(document, 0).text.toPlainText(), "wrold");
      },
    );

    _testWidgetsAsDesktop(
      "picking Add to the project's dictionary reports the word up without touching the document",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        String? learnedWord;

        await pumpStandaloneEditor(
          tester,
          "wrold",
          styledController: controller,
          isSpellCheckVisible: true,
          onSpellingSuggestionsRequested: (word) async => const [],
          onWordLearned: (word) => learnedWord = word,
        );

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        controller.updateSpellCheckRanges({
          nodeId: [const SpellRange(0, 5)],
        });
        await tester.pump();

        await tester.tapAt(_tapOffsetInsideText(nodeId), buttons: kSecondaryButton);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptStyledScreenplayEditor)));
        await tester.tap(find.text(tr.editorContextMenuAddToDictionaryAction));
        await tester.pumpAndSettle();

        expect(learnedWord, "wrold");
        expect(nodeAt(document, 0).text.toPlainText(), "wrold");
      },
    );
  });

  group("undo and redo", () {
    // These cases only assert that Ctrl+Z/Ctrl+Shift+Z/Ctrl+Y reach a live, history-enabled
    // `Editor` and restore the document rather than throwing. How many keystrokes one Ctrl+Z gives
    // back is a separate question, decided by the `historyGroupingPolicy`
    // `_rebuildEditorFrom` hands its `Editor`, so every case below types a single character and
    // asserts nothing about grouping.

    testWidgets("typing a character then Ctrl+Z removes it, with no exception", (tester) async {
      await pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText("A");

      expect(nodeAt(document, 0).text.toPlainText(), "A");

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();

      expect(document.nodeCount, 1);
      expect(nodeAt(document, 0).text.toPlainText(), "");
    });

    testWidgets("Ctrl+Shift+Z redoes what Ctrl+Z just undid", (tester) async {
      await pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      final nodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(nodeId, 0);
      await tester.typeImeText("A");

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(nodeAt(document, 0).text.toPlainText(), "");

      await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();

      expect(document.nodeCount, 1);
      expect(nodeAt(document, 0).text.toPlainText(), "A");
    });

    testWidgets(
      "Ctrl+Y redoes what Ctrl+Z just undid (the Windows habit Ctrl+Shift+Z coexists with)",
      (tester) async {
        await pumpStandaloneEditor(tester, "");

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("A");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await tester.pumpAndSettle();
        expect(nodeAt(document, 0).text.toPlainText(), "");

        await sendCtrl(tester, LogicalKeyboardKey.keyY);
        await tester.pumpAndSettle();

        expect(document.nodeCount, 1);
        expect(nodeAt(document, 0).text.toPlainText(), "A");
      },
    );
  });
}
