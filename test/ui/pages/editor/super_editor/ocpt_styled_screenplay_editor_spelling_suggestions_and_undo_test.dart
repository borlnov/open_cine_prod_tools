// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Run the tests of the styled screenplay editor spelling suggestions and undo.
void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  group("one gesture, one undo step", () {
    // The rule these cases pin down: one undo step is one gesture of the writer's, plus
    // everything the editor derived from it 120 ms later on the settle debounce — never one
    // keystroke of a run, and never a derived pass on its own. Every case that types a run does
    // so under `withClock`, so what it measures is the grouping rule rather than how long the
    // test VM happened to take between two simulated keystrokes: `OcptTypingRunMergePolicy`
    // compares timestamps taken with `clock.now()`, which is real wall-clock time even inside a
    // widget test's own fake async.

    /// A fixed instant for [withClock]: any value works, only its fixedness matters.
    final frozenNow = DateTime(2026, 8, 18, 10);

    testWidgets("a whole typing run is given back by a single Ctrl+Z", (tester) async {
      await withClock(Clock.fixed(frozenNow), () async {
        await pumpStandaloneEditor(tester, "");

        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
        for (final character in "Some action text".split("")) {
          await tester.typeImeText(character);
          // Settles between every keystroke, exactly as a real hand slower than the 120 ms
          // debounce does: this is what used to leave a derived transaction on top of the run.
          await pumpPastSettleDebounce(tester);
        }
        expect(nodeAt(document, 0).text.toPlainText(), "Some action text");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 0).text.toPlainText(), "");
      });
    });

    testWidgets("a scene heading typed in lowercase is given back whole, its reclassification and "
        "its uppercasing with it", (tester) async {
      await withClock(Clock.fixed(frozenNow), () async {
        await pumpStandaloneEditor(tester, "");

        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
        for (final character in "Ext. garden - night".split("")) {
          await tester.typeImeText(character);
          await pumpPastSettleDebounce(tester);
        }
        // The settle passes have reclassified and uppercased the line as it was being typed: it is
        // no longer what the writer's keystrokes alone produced.
        expect(typeAt(document, 0), FountainLineType.sceneHeading);
        expect(nodeAt(document, 0).text.toPlainText(), "EXT. GARDEN - NIGHT");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 0).text.toPlainText(), "");
        expect(typeAt(document, 0), FountainLineType.action);
      });
    });

    testWidgets("Tab is undone in one step — type, lock and text together — and the next Ctrl+Z "
        "reaches the edit before it", (tester) async {
      await pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
      await tester.typeImeText("Some action text.");
      await pumpPastSettleDebounce(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpPastSettleDebounce(tester);
      expect(typeAt(document, 0), FountainLineType.character);
      expect(isLockedAt(document, 0), isTrue);
      expect(nodeAt(document, 0).text.toPlainText(), "SOME ACTION TEXT.");

      // One Ctrl+Z takes back the manual type choice *and* the lock and the uppercasing the settle
      // pass derived from it. This is the case that used to be impossible to undo at all: the
      // settle re-derived what the undo had just taken back, and pushed it as a fresh step.
      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(typeAt(document, 0), FountainLineType.action);
      expect(isLockedAt(document, 0), isFalse);
      expect(nodeAt(document, 0).text.toPlainText(), "Some action text.");

      // And the step before it is still reachable, rather than the settle having stacked a new
      // one in between.
      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(nodeAt(document, 0).text.toPlainText(), "");
    });

    testWidgets("the settle pass that follows an undo writes no history of its own", (
      tester,
    ) async {
      await pumpStandaloneEditor(tester, "");

      final document = SuperEditorInspector.findDocument()!;
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
      await tester.typeImeText("Some action text.");
      await pumpPastSettleDebounce(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await pumpPastSettleDebounce(tester);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      final afterFirstUndo = nodeAt(document, 0).text.toPlainText();

      // Ctrl+Z twice more: the document keeps walking *backwards*, never returning to the state
      // the undone settle had derived. A settle that pushed its own transaction would show up
      // here as an undo that reinstates the uppercased, locked `character` line.
      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(nodeAt(document, 0).text.toPlainText(), "");
      expect(typeAt(document, 0), FountainLineType.action);
      expect(isLockedAt(document, 0), isFalse);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      expect(nodeAt(document, 0).text.toPlainText(), "");
      expect(afterFirstUndo, "Some action text.");
    });

    testWidgets("an Enter split is undone in one step, its blankLinesBefore metadata and the caret "
        "with it", (tester) async {
      await pumpStandaloneEditor(tester, "Some action text.");

      final document = SuperEditorInspector.findDocument()!;
      final originalNodeId = nodeAt(document, 0).id;
      await tester.placeCaretInParagraph(originalNodeId, "Some action text.".length);

      await tester.pressEnter();
      await pumpPastSettleDebounce(tester);
      expect(document.nodeCount, 2);
      expect(nodeAt(document, 1).getMetadataValue(ocptBlankLinesBeforeMetadataKey), 1);

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);

      expect(document.nodeCount, 1);
      expect(nodeAt(document, 0).text.toPlainText(), "Some action text.");
      // The caret comes back to where the undone edit was, not to wherever it happened to sit.
      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection, isNotNull);
      expect(selection!.extent.nodeId, originalNodeId);
      expect(
        (selection.extent.nodePosition as TextNodePosition).offset,
        "Some action text.".length,
      );
    });

    testWidgets(
      "a scene number the editor renumbered comes back with the gesture that shifted it",
      (tester) async {
        await pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nEXT. GARDEN - NIGHT");

        final document = SuperEditorInspector.findDocument()!;
        expect(sceneNumberAt(document, 0), "1");
        expect(sceneNumberAt(document, 1), "2");

        // Tab cycles a scene heading to `action`: the second heading is then the only one left, and
        // the settle pass renumbers it from 2 to 1.
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await pumpPastSettleDebounce(tester);
        expect(typeAt(document, 0), FountainLineType.action);
        expect(sceneNumberAt(document, 1), "1");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);

        expect(typeAt(document, 0), FountainLineType.sceneHeading);
        expect(sceneNumberAt(document, 0), "1");
        expect(sceneNumberAt(document, 1), "2");
      },
    );

    testWidgets("Replace all is undone in one step", (tester) async {
      final controller = OcptStyledEditorController();
      addTearDown(controller.dispose);

      await pumpStandaloneEditor(
        tester,
        "MARIE enters.\n\nMARIE speaks.\n\nMARIE leaves.",
        styledController: controller,
      );

      final document = SuperEditorInspector.findDocument()!;
      // Ctrl+Z is a `SuperEditor` keyboard action, so it only ever arrives once the editor holds
      // keyboard focus — which placing a caret is what gives it here.
      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);

      controller.updateSearch(
        query: const OcptEditorSearchQuery(
          query: "MARIE",
          isCaseSensitive: false,
          isWholeWord: false,
        ),
        currentMatchIndex: 0,
      );
      await tester.pump();

      controller.replaceAllMatches("CLARA");
      await pumpPastSettleDebounce(tester);
      expect(nodeAt(document, 0).text.toPlainText(), "CLARA enters.");
      expect(nodeAt(document, 1).text.toPlainText(), "CLARA speaks.");
      expect(nodeAt(document, 2).text.toPlainText(), "CLARA leaves.");

      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);

      expect(nodeAt(document, 0).text.toPlainText(), "MARIE enters.");
      expect(nodeAt(document, 1).text.toPlainText(), "MARIE speaks.");
      expect(nodeAt(document, 2).text.toPlainText(), "MARIE leaves.");
    });

    testWidgets("the load-time scene-number normalization is not an undo step", (tester) async {
      var lastEncoded = "";
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            // Numbered out of order in the source (by hand, or in raw mode): decoding corrects
            // them to 1 and 2 before the writer has done anything at all.
            text: "INT. HOUSE - DAY #5#\n\nEXT. GARDEN - NIGHT #2#",
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
      await pumpPastSettleDebounce(tester);

      final document = SuperEditorInspector.findDocument()!;
      expect(sceneNumberAt(document, 0), "1");
      expect(sceneNumberAt(document, 1), "2");
      final normalizedText = lastEncoded;

      await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);
      await sendCtrl(tester, LogicalKeyboardKey.keyZ);
      await pumpPastSettleDebounce(tester);

      expect(sceneNumberAt(document, 0), "1");
      expect(sceneNumberAt(document, 1), "2");
      expect(lastEncoded, normalizedText);
    });
  });

  group("a redo that cannot invent text", () {
    // `Editor` never clears its `future` list when a new edit arrives — its own `future` getter's
    // doc comment says it should, and nothing in the package does it — so a redo that follows an
    // undo *and* an edit made after it replays a transaction blind onto a document that has moved
    // on. Measured on this editor before the guard existed: type `abcdef`, Ctrl+Z, type `XY`,
    // Ctrl+Shift+Z, and the line read `abcdefXY`. These cases pin down the refusal, and — just as
    // importantly — that it refuses nothing else.

    /// A fixed instant for [withClock], so a typing run merges into the single undo step
    /// `OcptTypingRunMergePolicy` promises rather than into one step per keystroke (see the
    /// "one gesture, one undo step" group's own note).
    final frozenNow = DateTime(2026, 8, 18, 10);

    /// Types [text] one character at a time into the node holding the caret, settling between
    /// keystrokes exactly as a real hand slower than the 120 ms debounce does.
    Future<void> typeRun(WidgetTester tester, String text) async {
      for (final character in text.split("")) {
        await tester.typeImeText(character);
        await pumpPastSettleDebounce(tester);
      }
    }

    testWidgets("a redo asked for after a new edit is refused, and writes nothing at all", (
      tester,
    ) async {
      await withClock(Clock.fixed(frozenNow), () async {
        await pumpStandaloneEditor(tester, "");

        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
        await typeRun(tester, "abcdef");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);
        expect(nodeAt(document, 0).text.toPlainText(), "");

        // The edit that overtakes the undone transaction: from here on, what `Editor.future` still
        // holds can only ever be replayed onto a document it was never recorded against.
        await typeRun(tester, "XY");
        expect(nodeAt(document, 0).text.toPlainText(), "XY");

        await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);
        expect(nodeAt(document, 0).text.toPlainText(), "XY");

        // The Windows habit is the same action and must refuse the same way.
        await sendCtrl(tester, LogicalKeyboardKey.keyY);
        await pumpPastSettleDebounce(tester);

        expect(document.nodeCount, 1);
        expect(nodeAt(document, 0).text.toPlainText(), "XY");
      });
    });

    testWidgets("a refused redo leaves the history alone: Ctrl+Z still walks back through it", (
      tester,
    ) async {
      await withClock(Clock.fixed(frozenNow), () async {
        await pumpStandaloneEditor(tester, "");

        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
        await typeRun(tester, "abc");

        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);
        await typeRun(tester, "XY");

        await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);
        expect(nodeAt(document, 0).text.toPlainText(), "XY");

        // The refusal is a refusal, not a swallowed keystroke that also breaks undo: the writer's
        // own last gesture is still there to take back.
        await sendCtrl(tester, LogicalKeyboardKey.keyZ);
        await pumpPastSettleDebounce(tester);

        expect(nodeAt(document, 0).text.toPlainText(), "");
      });
    });

    testWidgets(
      "an undo left to settle can still be redone: the derived pass does not stale the stack",
      (tester) async {
        await withClock(Clock.fixed(frozenNow), () async {
          await pumpStandaloneEditor(tester, "");

          final document = SuperEditorInspector.findDocument()!;
          await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
          // A line the editor derives from, rather than plain action text: the settle pass that
          // runs after the undo has reclassification and uppercasing to redo if the undo left it
          // anything to do at all, which is exactly what must not count as an edit of the writer's.
          await typeRun(tester, "Ext. garden - night");
          expect(nodeAt(document, 0).text.toPlainText(), "EXT. GARDEN - NIGHT");

          await sendCtrl(tester, LogicalKeyboardKey.keyZ);
          await pumpPastSettleDebounce(tester);
          expect(nodeAt(document, 0).text.toPlainText(), "");

          await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
          await pumpPastSettleDebounce(tester);

          expect(nodeAt(document, 0).text.toPlainText(), "EXT. GARDEN - NIGHT");
          expect(typeAt(document, 0), FountainLineType.sceneHeading);
        });
      },
    );

    testWidgets("the controller reports what can be undone and redone, refusal included", (
      tester,
    ) async {
      await withClock(Clock.fixed(frozenNow), () async {
        final controller = OcptStyledEditorController();
        addTearDown(controller.dispose);

        await pumpStandaloneEditor(tester, "", styledController: controller);
        expect(controller.canUndo, isFalse);
        expect(controller.canRedo, isFalse);

        final document = SuperEditorInspector.findDocument()!;
        await tester.placeCaretInParagraph(nodeAt(document, 0).id, 0);
        await typeRun(tester, "abc");
        expect(controller.canUndo, isTrue);
        expect(controller.canRedo, isFalse);

        controller.undo();
        await pumpPastSettleDebounce(tester);
        expect(nodeAt(document, 0).text.toPlainText(), "");
        expect(controller.canRedo, isTrue);

        // The very predicate an `Undo`/`Redo` affordance reads: a fresh edit takes the redo away,
        // rather than leaving one that would invent text.
        await typeRun(tester, "XY");
        expect(controller.canUndo, isTrue);
        expect(controller.canRedo, isFalse);

        controller.redo();
        await pumpPastSettleDebounce(tester);
        expect(nodeAt(document, 0).text.toPlainText(), "XY");

        controller.undo();
        await pumpPastSettleDebounce(tester);
        expect(nodeAt(document, 0).text.toPlainText(), "");
      });
    });

    testWidgets(
      "an undo keeps the numbering the editor gave the screenplay when it opened it, adds no undo "
      "step of its own, and can still be redone",
      (tester) async {
        await withClock(Clock.fixed(frozenNow), () async {
          final controller = OcptStyledEditorController();
          addTearDown(controller.dispose);

          // Neither heading carries a `#N#` of its own, so the load-time pass numbers both — and
          // that numbering is exactly what an undo used to drop, `Editor.undo()` restoring the
          // document to the snapshot taken before that pass ran. The debounced settle then
          // re-derived it as a change of its own, which staled the redo stack and, on an emptied
          // history, left an undo step that un-numbered the screenplay.
          await pumpStandaloneEditor(
            tester,
            "INT. KITCHEN - DAY\n\nSomething moves.\n\nEXT. GARDEN - NIGHT\n\nMore.\n",
            styledController: controller,
          );

          final document = SuperEditorInspector.findDocument()!;
          expect(sceneNumberAt(document, 0), "1");
          expect(sceneNumberAt(document, 2), "2");
          expect(controller.canUndo, isFalse);

          await tester.placeCaretInParagraph(nodeAt(document, 1).id, "Something moves.".length);
          await typeRun(tester, " Again.");
          expect(nodeAt(document, 1).text.toPlainText(), "Something moves. Again.");

          await sendCtrl(tester, LogicalKeyboardKey.keyZ);
          await pumpPastSettleDebounce(tester);

          expect(nodeAt(document, 1).text.toPlainText(), "Something moves.");
          expect(sceneNumberAt(document, 0), "1");
          expect(sceneNumberAt(document, 2), "2");
          // The numbering survived the restore, so the settle that followed had nothing left to
          // derive — and the redo it would otherwise have staled is still offered.
          expect(controller.canRedo, isTrue);

          await sendCtrlShift(tester, LogicalKeyboardKey.keyZ);
          await pumpPastSettleDebounce(tester);

          expect(nodeAt(document, 1).text.toPlainText(), "Something moves. Again.");
          expect(sceneNumberAt(document, 0), "1");
          expect(sceneNumberAt(document, 2), "2");

          // Walking further back than the writer's own gesture never reaches a step that
          // un-numbers the screenplay: the numbering is part of the state every restore lands on,
          // not a transaction of its own.
          await sendCtrl(tester, LogicalKeyboardKey.keyZ);
          await pumpPastSettleDebounce(tester);
          await sendCtrl(tester, LogicalKeyboardKey.keyZ);
          await pumpPastSettleDebounce(tester);

          expect(sceneNumberAt(document, 0), "1");
          expect(sceneNumberAt(document, 2), "2");
        });
      },
    );
  });

  group("scene jump", () {
    /// Pumps the editor over [text] with [jumpRequest], keeping one [key] across calls so a second
    /// pump delivers the request to the same live editor rather than a fresh one.
    Future<void> pumpWithJump(
      WidgetTester tester,
      String text,
      OcptEditorJumpRequest? jumpRequest,
    ) async {
      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            key: const ValueKey("jump-editor"),
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: jumpRequest,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("lands a far scene heading a third of the way down, not at the viewport's edge", (
      tester,
    ) async {
      // A desktop platform: the caret reveal that used to override the jump belongs to
      // super_editor's mouse interactor, which only desktop platforms use.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        // Already numbered, as the bloc's own text is once the editor has reported its first
        // encode: the scene list's offsets are read off that numbered text, and the editor's own
        // node mapping is built from it too.
        final buffer = StringBuffer();
        for (var scene = 1; scene <= 60; scene++) {
          buffer.write("INT. ROOM $scene - DAY #$scene#\n\nSomething happens in room $scene.\n\n");
        }
        final text = buffer.toString();

        await pumpWithJump(tester, text, null);
        await pumpWithJump(
          tester,
          text,
          OcptEditorJumpRequest(charOffset: text.indexOf("INT. ROOM 50 - DAY"), id: 1),
        );

        final viewport = tester.getRect(find.byType(OcptStyledScreenplayEditor));
        final heading = tester.getRect(find.textContaining("ROOM 50 -", findRichText: true).first);
        final relativeTop = (heading.top - viewport.top) / viewport.height;
        expect(relativeTop, inInclusiveRange(0.1, 0.5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
