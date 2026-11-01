// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller_delegate.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:spell_kit/spell_kit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// A bare [OcptStyledEditorControllerDelegate] recording every [updateSpellCheckRanges] call it
/// receives, in call order, so a controller test can assert the pending value `attach` pushes at
/// attach time without needing a live styled editor (whose own node ids are freshly generated on
/// every decode, and so cannot be reused across a genuine detach/re-attach — see the "spell check"
/// group's own doc comment for why this test double exists instead). Every other delegate method
/// is a bare no-op: nothing under test here ever calls them.
class _RecordingStyledEditorControllerDelegate implements OcptStyledEditorControllerDelegate {
  /// Every [updateSpellCheckRanges] call this delegate received, in call order.
  final List<Map<String, List<SpellRange>>> rangesReceived = [];

  @override
  void updateSpellCheckRanges(Map<String, List<SpellRange>> rangesByNodeId) {
    rangesReceived.add(rangesByNodeId);
  }

  @override
  void applyBlockType(FountainLineType type) {}

  @override
  void applyToggleInlineStyle(OcptInlineStyle style) {}

  @override
  void updateSearch({required OcptEditorSearchQuery? query, required int? currentMatchIndex}) {}

  @override
  int? replaceCurrentMatch(String replacement) => null;

  @override
  void replaceAllMatches(String replacement) {}

  @override
  bool get canUndo => false;

  @override
  bool get canRedo => false;

  @override
  void undo() {}

  @override
  void redo() {}
}

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("OcptStyledEditorController — find/replace", () {
    /// Reads the [TextStyle] currently painted behind the exact substring [text] inside the
    /// paragraph [nodeId]'s own rendered [TextSpan] tree — the only way to observe
    /// `OcptSearchMatchStyler`'s effect from outside its own library, since it never touches the
    /// live document or exposes anything of its own.
    TextStyle? styleOfSubstring(String nodeId, String text) {
      TextStyle? found;
      SuperEditorInspector.findRichTextInParagraph(nodeId).visitChildren((span) {
        if (span is TextSpan && span.text == text) {
          found = span.style;
          return false;
        }
        return true;
      });
      return found;
    }

    testWidgets("matches are highlighted, the current one more strongly than the rest", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(tester, "Line one.\n\nLine two.\n", styledController: controller);

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = nodeAt(document, 0).id;
      final secondNodeId = nodeAt(document, 1).id;

      controller.updateSearch(
        query: const OcptEditorSearchQuery(
          query: "Line",
          isCaseSensitive: false,
          isWholeWord: false,
        ),
        currentMatchIndex: 0,
      );
      await tester.pump();

      expect(
        styleOfSubstring(firstNodeId, "Line")?.backgroundColor,
        ocptEditorSearchCurrentMatchColor,
      );
      expect(styleOfSubstring(secondNodeId, "Line")?.backgroundColor, ocptEditorSearchMatchColor);
    });

    testWidgets("navigation moves the current match without stealing keyboard focus", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      // Stands in for the real find field's own `FocusNode`, which is what must keep the keyboard
      // focus across a navigation: this test proves it never loses it, rather than asserting on
      // Flutter's own ambient "some scope always has *a* primary focus" default, which would be
      // true even if this widget did nothing at all.
      final proxyFindFieldFocusNode = FocusNode();
      addTearDown(proxyFindFieldFocusNode.dispose);

      await tester.pumpWidget(
        testWrap(
          Column(
            children: [
              SizedBox(height: 40, child: TextField(focusNode: proxyFindFieldFocusNode)),
              Expanded(
                child: OcptStyledScreenplayEditor(
                  text: "Line one.\n\nLine two.\n\nLine three.\n",
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
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      proxyFindFieldFocusNode.requestFocus();
      await tester.pump();
      expect(proxyFindFieldFocusNode.hasFocus, isTrue);

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = nodeAt(document, 0).id;
      final secondNodeId = nodeAt(document, 1).id;
      const query = OcptEditorSearchQuery(
        query: "Line",
        isCaseSensitive: false,
        isWholeWord: false,
      );

      controller.updateSearch(query: query, currentMatchIndex: 0);
      await tester.pump();

      var selection = SuperEditorInspector.findDocumentSelection();
      expect(selection?.extent.nodeId, firstNodeId);
      expect((selection!.extent.nodePosition as TextNodePosition).offset, "Line".length);
      expect(proxyFindFieldFocusNode.hasFocus, isTrue);

      controller.updateSearch(query: query, currentMatchIndex: 1);
      await tester.pump();

      selection = SuperEditorInspector.findDocumentSelection();
      expect(selection?.extent.nodeId, secondNodeId);
      expect(proxyFindFieldFocusNode.hasFocus, isTrue);
    });

    testWidgets("a replacement reaches the encoded text and reports the next match's index", (
      tester,
    ) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      var lastEncoded = "";

      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            text: "Line one.\n\nLine two.\n",
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

      controller.updateSearch(
        query: const OcptEditorSearchQuery(
          query: "Line",
          isCaseSensitive: false,
          isWholeWord: false,
        ),
        currentMatchIndex: 0,
      );
      await tester.pump();

      final nextIndex = controller.replaceCurrentMatch("Scene");
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(lastEncoded, contains("Scene one."));
      expect(lastEncoded, contains("Line two."));
      // Only "Line two." matches "Line" once "Line one." became "Scene one.", so it's the sole
      // remaining match, at index 0.
      expect(nextIndex, 0);
    });

    testWidgets(
      "replacing advances past a replacement that itself still matches the query, renaming every "
      "occurrence exactly once rather than compounding onto the same spot",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);
        var lastEncoded = "";

        await tester.pumpWidget(
          testWrap(
            OcptStyledScreenplayEditor(
              text: "MARIE enters.\n\nMARIE speaks.\n",
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

        const query = OcptEditorSearchQuery(
          query: "MARIE",
          isCaseSensitive: false,
          isWholeWord: false,
        );
        controller.updateSearch(query: query, currentMatchIndex: 0);
        await tester.pump();

        // "MARIE" replaced by "MARIE-JEANNE" still matches "MARIE" at that very same offset, so
        // this is the scenario replace exists for.
        final firstNextIndex = controller.replaceCurrentMatch("MARIE-JEANNE");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        // The first occurrence is renamed, the second isn't touched yet, and — the actual
        // regression this guards — the current match did not stay stuck inside what was just
        // written (it would otherwise turn the next replace into "MARIE-JEANNE-JEANNE").
        expect(lastEncoded, contains("MARIE-JEANNE enters."));
        expect(lastEncoded, contains("MARIE speaks."));
        expect(lastEncoded, isNot(contains("JEANNE-JEANNE")));
        expect(firstNextIndex, isNotNull);

        // The page's own follow-up: dispatching `OcptEditorSearchCurrentMatchSelectedEvent` with
        // `firstNextIndex` ultimately reaches the delegate through another `updateSearch` call.
        controller.updateSearch(query: query, currentMatchIndex: firstNextIndex);
        await tester.pump();

        controller.replaceCurrentMatch("MARIE-JEANNE");
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        expect(lastEncoded, "MARIE-JEANNE enters.\n\nMARIE-JEANNE speaks.\n");
      },
    );
  });

  group("OcptStyledEditorController — spell check", () {
    // The fixture `editor_bloc_test.dart`'s own "a scene heading, a character cue, a transition
    // and a lyrics line produce no range, an action line and a dialogue line do" test uses,
    // reused here so both the bloc's and this widget's own halves of the prose-only rule are
    // proven against the exact same shape of screenplay: scene heading (0), action (1), character
    // cue (2), dialogue (3), transition (4), lyrics (5).
    const text =
        "INT. HOUSE - DAY\n\n"
        "She walks across the room slowly.\n\n"
        "MARIE\n"
        "Bonjour tout le monde.\n\n"
        "CUT TO:\n\n"
        "~La la la la\n";

    testWidgets(
      "only the action and dialogue lines are reported as checkable, never the scene heading, "
      "the character cue, the transition or the lyrics line",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(
          tester,
          text,
          styledController: controller,
          isSpellCheckVisible: true,
        );

        final document = SuperEditorInspector.findDocument()!;
        expect(typeAt(document, 0), FountainLineType.sceneHeading);
        expect(typeAt(document, 1), FountainLineType.action);
        expect(typeAt(document, 2), FountainLineType.character);
        expect(typeAt(document, 3), FountainLineType.dialogue);
        expect(typeAt(document, 4), FountainLineType.transition);
        expect(typeAt(document, 5), FountainLineType.lyrics);

        final reported = controller.spellCheckTextsByNodeId;
        expect(reported.keys, unorderedEquals([nodeAt(document, 1).id, nodeAt(document, 3).id]));
        expect(reported[nodeAt(document, 1).id], "She walks across the room slowly.");
        expect(reported[nodeAt(document, 3).id], "Bonjour tout le monde.");
      },
    );

    testWidgets(
      "nothing at all is reported while OcptStyledScreenplayEditor.isSpellCheckVisible is false",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(tester, text, styledController: controller);

        expect(controller.spellCheckTextsByNodeId, isEmpty);
      },
    );

    testWidgets("a title-page field node is never reported as checkable", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(
        tester,
        "Some action.",
        isPageSimulationEnabled: true,
        styledController: controller,
        isSpellCheckVisible: true,
      );

      final document = SuperEditorInspector.findDocument()!;
      expect(document.nodeCount, testTitlePageFieldCount + 1);

      final titlePageNodeIds = [
        for (var index = 0; index < testTitlePageFieldCount; index++) nodeAt(document, index).id,
      ];
      final reported = controller.spellCheckTextsByNodeId;
      for (final titlePageNodeId in titlePageNodeIds) {
        expect(reported.containsKey(titlePageNodeId), isFalse);
      }
      expect(reported.keys, [nodeAt(document, testTitlePageFieldCount).id]);
    });

    testWidgets(
      "spellingErrors covers a misspelled word on an action line, and a character cue and a "
      "scene heading carry none",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(
          tester,
          text,
          styledController: controller,
          isSpellCheckVisible: true,
        );

        final document = SuperEditorInspector.findDocument()!;
        final headingNodeId = nodeAt(document, 0).id;
        final actionNodeId = nodeAt(document, 1).id;
        final cueNodeId = nodeAt(document, 2).id;

        // "walks" sits at offset 4 in "She walks across the room slowly." — the exact range this
        // widget is handed is not itself asserted on (that round trip is the bloc's own job); what
        // matters here is only that a range handed in for the action node's own id reaches that
        // node's component view model, and never a node this widget never reported.
        controller.updateSpellCheckRanges({
          actionNodeId: [const SpellRange(4, 9)],
        });
        await tester.pump();

        final actionViewModel = SuperEditorInspector.findWidgetForComponent<ParagraphComponent>(
          actionNodeId,
        ).viewModel;
        expect(actionViewModel.spellingErrors, [const TextRange(start: 4, end: 9)]);

        final cueViewModel = SuperEditorInspector.findWidgetForComponent<ParagraphComponent>(
          cueNodeId,
        ).viewModel;
        expect(cueViewModel.spellingErrors, isEmpty);

        final headingViewModel = SuperEditorInspector.findWidgetForComponent<ParagraphComponent>(
          headingNodeId,
        ).viewModel;
        expect(headingViewModel.spellingErrors, isEmpty);
      },
    );

    testWidgets(
      "a range that no longer fits the node's current text length is dropped rather than painted",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          styledController: controller,
          isSpellCheckVisible: true,
        );

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;

        // "Some action." is 12 characters long: a range reaching past that must be dropped, not
        // handed to `TextError.spelling`, which would otherwise build a `TextRange` past the end of
        // the text it addresses.
        controller.updateSpellCheckRanges({
          nodeId: [const SpellRange(0, 100)],
        });
        await tester.pump();

        final viewModel = SuperEditorInspector.findWidgetForComponent<ParagraphComponent>(
          nodeId,
        ).viewModel;
        expect(viewModel.spellingErrors, isEmpty);
      },
    );

    testWidgets(
      "a range for a node id the live document no longer holds is ignored rather than crashing",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(
          tester,
          "Some action.",
          styledController: controller,
          isSpellCheckVisible: true,
        );

        controller.updateSpellCheckRanges({
          "not-a-real-node-id": [const SpellRange(0, 3)],
        });
        await tester.pump();

        // No exception thrown reaching here is the assertion itself; the fresh document still shows
        // no error, matching the case above.
        final document = SuperEditorInspector.findDocument()!;
        final viewModel = SuperEditorInspector.findWidgetForComponent<ParagraphComponent>(
          nodeAt(document, 0).id,
        ).viewModel;
        expect(viewModel.spellingErrors, isEmpty);
      },
    );

    test("updateSpellCheckRanges is re-pushed to a delegate attaching afterwards", () {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);
      final delegate = _RecordingStyledEditorControllerDelegate();

      // Set while detached (no delegate attached at all yet, mirroring a raw → styled mode switch
      // where the ranges were already known): remembered by the controller rather than lost,
      // exactly like `updateSearch`'s own find/replace query.
      const ranges = {
        "some-node-id": [SpellRange(0, 3)],
      };
      controller.updateSpellCheckRanges(ranges);
      expect(delegate.rangesReceived, isEmpty);

      controller.attach(delegate);

      expect(delegate.rangesReceived, [ranges]);
    });
  });

  group("a parenthetical opens on ()", () {
    testWidgets(
      "setBlockType(parenthetical) on an empty block inserts () and places the caret between them",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(tester, "", styledController: controller);

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        controller.setBlockType(FountainLineType.parenthetical);
        await tester.pump();

        expect(typeAt(document, 0), FountainLineType.parenthetical);
        expect(isLockedAt(document, 0), isTrue);
        expect(nodeAt(document, 0).text.toPlainText(), "()");

        final selection = SuperEditorInspector.findDocumentSelection();
        expect(selection, isNotNull);
        expect(selection!.isCollapsed, isTrue);
        expect(selection.extent.nodeId, nodeId);
        expect((selection.extent.nodePosition as TextNodePosition).offset, 1);
      },
    );

    testWidgets(
      "setBlockType(parenthetical) on a block that already holds text leaves the text untouched",
      (tester) async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(tester, "Some action text.", styledController: controller);

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, 0).id;
        await tester.placeCaretInParagraph(nodeId, 0);

        controller.setBlockType(FountainLineType.parenthetical);
        await tester.pump();

        expect(typeAt(document, 0), FountainLineType.parenthetical);
        expect(nodeAt(document, 0).text.toPlainText(), "Some action text.");
      },
    );

    testWidgets(
      "Tab-cycling onto parenthetical from an empty block inserts the () pair, and the encoded "
      "text carries it through the sync debounce",
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
        // An empty block auto-detects as `action`, and `parenthetical` sits two steps further down
        // the cycle, right after `character`: hence the two Tab presses below.
        expect(typeAt(document, 0), FountainLineType.action);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(typeAt(document, 0), FountainLineType.character);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(typeAt(document, 0), FountainLineType.parenthetical);
        expect(nodeAt(document, 0).text.toPlainText(), "()");

        final selection = SuperEditorInspector.findDocumentSelection();
        expect(selection, isNotNull);
        expect(selection!.extent.nodeId, nodeId);
        expect((selection.extent.nodePosition as TextNodePosition).offset, 1);

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();
        expect(lastEncoded.contains("()"), isTrue);
      },
    );
  });
}
