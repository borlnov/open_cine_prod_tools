// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_script_page_number.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'ocpt_styled_screenplay_editor_test_doubles.dart';

/// Finds the page-simulation background painter (`OcptPageSheetsPainter`) by the runtime name of
/// its painter: it's private to the production file, so it can't be named from here directly.
Finder _pageSheetsPainterFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter.runtimeType.toString() == "OcptPageSheetsPainter",
);

/// Whether the page-simulation background painter (`OcptPageSheetsPainter`, private to the
/// production file) is currently mounted: the most that can be asserted on it from outside its own
/// library without exposing an otherwise-unneeded public type.
bool _hasPageSheetsPainter() => _pageSheetsPainterFinder().evaluate().isNotEmpty;

/// Run the tests of the styled screenplay editor layout and page simulation.
void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; every test below that gives the styled editor a selection is affected.
  BlinkController.indeterminateAnimationsEnabled = false;

  testWidgets(
    "renders a scene heading bold at the margin and indents a character cue further than action",
    (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.\n\nSARAH\nHello.";

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
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      // Blank source lines are folded into node metadata (not their own node), so nodes are
      // dense: 0 = heading, 1 = action, 2 = character, 3 = dialogue.
      final headingNodeId = document.getNodeAt(0)!.id;
      final actionNodeId = document.getNodeAt(1)!.id;
      final characterNodeId = document.getNodeAt(2)!.id;

      expect(SuperEditorInspector.findParagraphStyle(headingNodeId)?.fontWeight, FontWeight.bold);

      final headingOffset = SuperEditorInspector.findComponentOffset(
        headingNodeId,
        Alignment.topLeft,
      );
      final actionOffset = SuperEditorInspector.findComponentOffset(
        actionNodeId,
        Alignment.topLeft,
      );
      final characterOffset = SuperEditorInspector.findComponentOffset(
        characterNodeId,
        Alignment.topLeft,
      );

      // The scene heading sits at the same left margin as action text...
      expect(headingOffset.dx, actionOffset.dx);
      // ...while the character cue is indented noticeably further in.
      expect(characterOffset.dx, greaterThan(actionOffset.dx));
    },
  );

  testWidgets(
    "sizes and positions every element type at the raw preview's indent/width, wide enough that "
    "a long character cue never wraps",
    (tester) async {
      // One line per element type. "DETECTIVE JONATHAN" (19 characters) is comfortably narrower
      // than the character box's correct width (38 columns on US Letter) but would have wrapped
      // to nearly one letter per line under the pre-fix box, whose usable text width collapsed to
      // roughly `width - indent` (about 1 column).
      const text =
          "INT. HOUSE - DAY\n\n"
          "Some action text describing the scene in some detail.\n\n"
          "DETECTIVE JONATHAN\n"
          "(quietly)\n"
          "Hello there, how are you doing today my friend?\n\n"
          "CUT TO:\n\n"
          ">THE END<";

      // The default test surface (800x600) is narrower than a full-width US Letter box at font
      // size 13 (indent + width can reach ~975 logical pixels), which would clip every full-width
      // element's rendered size before it ever reached its styled `maxWidth`: widen the surface,
      // like the app's own desktop window would be in practice.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          ),
        ),
      );
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
      final metrics = layout.metrics;

      // Blank source lines are folded into node metadata (not their own node), so nodes are
      // dense in source order: heading, action, character, parenthetical, dialogue, transition,
      // centered text.
      final elementsByNodeIndex = [
        metrics.sceneHeading,
        metrics.action,
        metrics.character,
        metrics.parenthetical,
        metrics.dialogue,
        metrics.transition,
        metrics.centeredText,
      ];
      final nodeIds = [
        for (var index = 0; index < elementsByNodeIndex.length; index++) nodeAt(document, index).id,
      ];
      final actionOffset = SuperEditorInspector.findComponentOffset(nodeIds[1], Alignment.topLeft);

      for (var index = 0; index < elementsByNodeIndex.length; index++) {
        final element = elementsByNodeIndex[index];
        final nodeId = nodeIds[index];

        // The component's rendered width is `Styles.maxWidth` minus the left padding super_editor
        // applies inside it: with the fix, that's exactly the element's own text width.
        final size = SuperEditorInspector.findComponentSize(nodeId);
        expect(
          size.width,
          closeTo(layout.widthOf(element), 1),
          reason: "width of node $index ($element)",
        );

        // The component's left edge sits at the element's indent, relative to the action box's —
        // but only for element types whose box is exactly as wide as action's (`indent + width`,
        // the fixed value the `Styles.maxWidth` fix now sets): the document's internal `Column`
        // centers each block's box within the widest sibling's, so a narrower box (dialogue,
        // fixed at 3.5in regardless of page size, unlike the others which stretch to the
        // printable area's right edge) picks up extra centering offset that has nothing to do
        // with this fix, and would make a direct indent comparison against action meaningless.
        final sameBoxWidthAsAction =
            layout.indentOf(element) + layout.widthOf(element) ==
            layout.indentOf(metrics.action) + layout.widthOf(metrics.action);
        if (!sameBoxWidthAsAction) {
          continue;
        }
        final offset = SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft);
        expect(
          offset.dx - actionOffset.dx,
          closeTo(layout.indentOf(element) - layout.indentOf(metrics.action), 1),
          reason: "indent of node $index ($element)",
        );
      }

      // The most visible symptom of the bug: the character cue box collapsed to near-zero usable
      // width, wrapping to one letter per line. `findOffsetOfLineBreak` throws when a text node
      // renders on a single line, which is what must happen now.
      expect(() => SuperEditorInspector.findOffsetOfLineBreak(nodeIds[2]), throwsException);
    },
  );

  testWidgets("moving the caret to another line reports its 0-based source line", (tester) async {
    const text = "INT. HOUSE - DAY\n\nSome action text.";
    var reportedLine = -1;

    await tester.pumpWidget(
      testWrap(
        OcptStyledScreenplayEditor(
          text: text,
          pageSetup: const OcptPageSetup.standard(),
          isPageSimulationEnabled: false,
          areSceneNumbersVisible: false,
          isSpellCheckVisible: false,
          onTextChanged: (_) {},
          onCaretLineChanged: (line) => reportedLine = line,
          jumpRequest: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    // Blank source lines are folded into node metadata (not their own node): node 1 is the
    // action line, at source line 2 (source lines: 0 = heading, 1 = blank, 2 = action).
    final actionNodeId = document.getNodeAt(1)!.id;

    await tester.placeCaretInParagraph(actionNodeId, 0);

    expect(reportedLine, 2);
  });

  group("page simulation", () {
    testWidgets("renders a background page-sheets painter when enabled", (tester) async {
      await pumpStandaloneEditor(
        tester,
        "INT. HOUSE - DAY\n\nSome action text.",
        isPageSimulationEnabled: true,
        areSceneNumbersVisible: true,
      );

      expect(_hasPageSheetsPainter(), isTrue);
    });

    testWidgets("renders no background page-sheets painter when disabled", (tester) async {
      await pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nSome action text.");

      expect(_hasPageSheetsPainter(), isFalse);
    });

    testWidgets(
      "paints exactly one Scrollbar, ancestor of SuperEditor, so the thumb never sits over the "
      "page",
      (tester) async {
        await pumpStandaloneEditor(
          tester,
          "INT. HOUSE - DAY\n\nSome action text.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: true,
        );

        expect(find.byType(Scrollbar), findsOneWidget);
        expect(
          find.descendant(of: find.byType(Scrollbar), matching: find.byType(SuperEditor)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "paints exactly one Scrollbar, ancestor of SuperEditor, with page simulation disabled too",
      (tester) async {
        await pumpStandaloneEditor(tester, "INT. HOUSE - DAY\n\nSome action text.");

        expect(find.byType(Scrollbar), findsOneWidget);
        expect(
          find.descendant(of: find.byType(Scrollbar), matching: find.byType(SuperEditor)),
          findsOneWidget,
        );
      },
    );

    testWidgets("the page sheets are clipped to the editor's own bounds", (tester) async {
      await pumpStandaloneEditor(
        tester,
        List.generate(80, (index) => "Action line $index.").join("\n\n"),
        isPageSimulationEnabled: true,
        areSceneNumbersVisible: true,
      );

      // `CustomPaint` does not clip its painter: without an explicit `clipRect`, a scrolled-away
      // sheet's negative top would paint the white page straight over whatever sits above the
      // editor — in the real app, the editor toolbar (it reads as the page scrolling over it).
      // Pinning the clip is what keeps every sheet inside the editor.
      expect(
        _pageSheetsPainterFinder(),
        paints
          ..clipRect()
          ..rrect(color: Colors.white),
      );
    });

    testWidgets("a screenplay that fits on one sheet is not numbered at all", (tester) async {
      await pumpStandaloneEditor(
        tester,
        "INT. HOUSE - DAY\n\nSome action text.",
        isPageSimulationEnabled: true,
      );

      // Two sheets are painted here (the title page, then the one and only script page), and
      // neither of them is ever numbered: the printed screenplay numbers nothing before its
      // second script page, and the styled mode prints that rule and no other.
      expect(_pageSheetsPainterFinder(), paintsExactlyCountTimes(#drawParagraph, 0));
    });

    testWidgets(
      "the second script page is numbered, half an inch below its own sheet's top edge and "
      "right-aligned at the page's right margin",
      (tester) async {
        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        // Tall enough for the title sheet, the first script page and the second one to be laid out
        // at once: a sheet scrolled out of view has its number skipped (see `_paintPageNumber`),
        // and wide enough for a full US Letter page to lay out unscaled.
        tester.view.physicalSize = Size(
          1600,
          3 * (layout.pageHeight + OcptEditorPreviewLayout.pageGap) + 100,
        );
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 40 one-line action paragraphs, each preceded by a blank line: 79 lines, which overflows
        // US Letter's 54 lines per page exactly once — a title sheet plus two script pages.
        await pumpStandaloneEditor(
          tester,
          List.generate(40, (index) => "Action line $index.").join("\n\n"),
          isPageSimulationEnabled: true,
        );

        // "2." is two columns wide in a fixed-pitch font, and the number's right edge lands exactly
        // where the printed page's own right margin starts.
        final expectedOffset = Offset(
          layout.pageWidth - layout.marginRight - 2 * layout.glyphWidth,
          2 * (layout.pageHeight + OcptEditorPreviewLayout.pageGap) +
              ocptScriptPageNumberTopInches * layout.pixelsPerInch,
        );

        expect(
          _pageSheetsPainterFinder(),
          paints..paragraph(offset: within(distance: 0.5, from: expectedOffset)),
        );
        // Exactly one number on screen: the title sheet and the first script page carry none.
        expect(_pageSheetsPainterFinder(), paintsExactlyCountTimes(#drawParagraph, 1));
      },
    );

    testWidgets(
      "every element still spans its exact preview width, at its exact preview indent from the "
      "page's left edge",
      (tester) async {
        // Wide enough for a full US Letter page to lay out unclipped at font size 13.
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(
          tester,
          "INT. HOUSE - DAY\n\nSome action text.\n\nSARAH\nHello there.",
          isPageSimulationEnabled: true,
          areSceneNumbersVisible: true,
        );

        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
        final metrics = layout.metrics;
        final document = SuperEditorInspector.findDocument()!;

        // The editor's box is deliberately shifted left by the stylesheet's horizontal
        // `documentPadding` inset (see `OcptStyledScreenplayEditor.build`), so the page's own left
        // edge sits exactly one inset to the right of the box's.
        final pageLeft =
            tester.getRect(find.byType(SuperEditor)).left +
            OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;

        // Blank source lines are folded into metadata, so nodes are dense: heading, action,
        // character, dialogue. `titlePageFieldCount` leading nodes come first (page simulation is
        // on, and this text has no title page of its own, so all six fields synthesize empty).
        final elementsByNodeIndex = [metrics.sceneHeading, metrics.action, metrics.character];

        for (var index = 0; index < elementsByNodeIndex.length; index++) {
          final element = elementsByNodeIndex[index];
          final nodeId = document.getNodeAt(index + testTitlePageFieldCount)!.id;

          // The whole point of the horizontal-inset compensation: page simulation must not shrink
          // any element's wrap width, nor shift its indent, away from what the raw preview
          // typesets the very same line at — otherwise the two modes would wrap the same text at
          // different columns.
          expect(
            SuperEditorInspector.findComponentSize(nodeId).width,
            closeTo(layout.widthOf(element), 0.5),
            reason: "width of node $index",
          );
          expect(
            SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft).dx - pageLeft,
            closeTo(layout.indentOf(element), 0.5),
            reason: "indent of node $index",
          );
        }
      },
    );

    testWidgets("toggling it on and off swaps the background painter accordingly", (tester) async {
      const text = "INT. HOUSE - DAY\n\nSome action text.";

      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            key: const ValueKey("editor"),
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: true,
            areSceneNumbersVisible: true,
            isSpellCheckVisible: false,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_hasPageSheetsPainter(), isTrue);

      await tester.pumpWidget(
        testWrap(
          OcptStyledScreenplayEditor(
            key: const ValueKey("editor"),
            text: text,
            pageSetup: const OcptPageSetup.standard(),
            isPageSimulationEnabled: false,
            areSceneNumbersVisible: false,
            isSpellCheckVisible: false,
            onTextChanged: (_) {},
            onCaretLineChanged: (_) {},
            jumpRequest: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_hasPageSheetsPainter(), isFalse);
    });

    testWidgets("a document long enough to span multiple pages flags a page-start node", (
      tester,
    ) async {
      final longText = List.generate(80, (index) => "Action line $index.").join("\n\n");

      await pumpStandaloneEditor(tester, longText, isPageSimulationEnabled: true);

      final document = SuperEditorInspector.findDocument()!;
      // The pagination pass now stores the exact top padding (a positive double), not a boolean
      // flag, so a page-starting node lands precisely at its sheet's text origin.
      final hasPageStartNode = document.any((node) {
        final value = node.getMetadataValue("ocptStartsNewPage");
        return value is double && value > 0;
      });
      expect(hasPageStartNode, isTrue);
    });

    testWidgets(
      "a full-width element's box exactly fills the editor's own width, flush with the page's "
      "left edge, leaving the true right margin outside it (no leftover super_editor centering "
      "slack eating half of it)",
      (tester) async {
        // The default test surface (800x600) is narrower than the full page-simulation width
        // (`pageWidth` can reach ~975 logical pixels at US Letter): widen it first, like the
        // earlier test and the app's own desktop window would be in practice.
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpStandaloneEditor(tester, "Some action text.", isPageSimulationEnabled: true);

        final document = SuperEditorInspector.findDocument()!;
        final nodeId = nodeAt(document, testTitlePageFieldCount).id;
        final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());

        final editorRect = tester.getRect(find.byType(SuperEditor));
        final componentOffset = SuperEditorInspector.findComponentOffset(nodeId, Alignment.topLeft);
        final componentSize = SuperEditorInspector.findComponentSize(nodeId);

        // The editor's box spans the page's content area (`pageWidth - marginRight`) widened by the
        // stylesheet's horizontal `documentPadding` inset on each side, and is shifted left by one
        // inset — so it's the *content area inside that padding*, not the box itself, that lands
        // flush on the page's left edge (see `OcptStyledScreenplayEditor.build`). That compensation
        // is what keeps every element at its exact preview width instead of one inset short per
        // side.
        const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
        expect(editorRect.width, closeTo(layout.pageWidth - layout.marginRight + inset * 2, 0.5));
        final pageLeftEdge = editorRect.left + inset;
        final pageRightEdge = pageLeftEdge + layout.pageWidth;

        // The action element's text starts exactly `marginLeft` from the page's left edge and ends
        // exactly `marginRight` short of its right edge — the very same numbers the raw preview
        // typesets it at. Asserted to the half-pixel: the pre-fix centering bug put ~`marginRight /
        // 2` of slack on each side, and the uncompensated `documentPadding` inset a further 8px.
        final leftGap = componentOffset.dx - pageLeftEdge;
        final rightGap = pageRightEdge - (componentOffset.dx + componentSize.width);
        expect(leftGap, closeTo(layout.marginLeft, 0.5));
        expect(rightGap, closeTo(layout.marginRight, 0.5));
      },
    );

    testWidgets("a panel narrower than the page scales the page down instead of squeezing it", (
      tester,
    ) async {
      final layout = OcptEditorPreviewLayout(metrics: FountainLayoutMetrics.usLetter());
      // Narrower than the page on purpose — what the centre panel actually is once both workspace
      // docks are open. The regression this guards: the page used to be laid out at whatever width
      // the panel offered, and since every element's `Styles.maxWidth` is an absolute pixel width
      // taken from the page metrics, each line then wrapped several columns early. Those surplus
      // lines made every page render taller than the sheet `computeOcptStyledPagination` sized for
      // it, and the text ran out under the sheet's bottom edge, page after page.
      final narrowPanelWidth = layout.pageWidth / 2;
      tester.view.physicalSize = Size(narrowPanelWidth, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpStandaloneEditor(tester, "Some action text.", isPageSimulationEnabled: true);

      // The editor's own box keeps the page's geometry (`getSize` reports it before the scale),
      // while its on-screen bounds (`getRect`, after it) fit inside the narrow panel.
      const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
      final unscaledWidth = layout.pageWidth - layout.marginRight + inset * 2;
      expect(tester.getSize(find.byType(SuperEditor)).width, closeTo(unscaledWidth, 0.5));
      expect(tester.getRect(find.byType(SuperEditor)).width, closeTo(unscaledWidth / 2, 0.5));
      expect(
        tester.getRect(find.byType(SuperEditor)).right,
        lessThanOrEqualTo(narrowPanelWidth + 0.5),
      );
    });
  });
}
