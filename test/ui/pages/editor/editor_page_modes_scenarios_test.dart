// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'editor_page_scenarios_test_doubles.dart';

/// Twenty scenes of wrapped paragraphs, tall enough to scroll in any surface the tests use.
String _longScreenplay() {
  final buffer = StringBuffer();
  for (var scene = 1; scene <= 20; scene++) {
    buffer.write("INT. ROOM $scene - DAY\n\n${"Something happens in room $scene. " * 20}\n\n");
  }

  return buffer.toString();
}

void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final harness = EditorScenarioHarness();

  setUpAll(harness.setUpAll);
  tearDownAll(harness.tearDownAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the scene panel.
  Finder inPanel(Finder target) =>
      find.descendant(of: find.byType(OcptEditorScenePanel), matching: target);

  /// Reads the vertical scroll offset of the raw source field.
  double rawScrollOffset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(Scrollable))
            .first,
      )
      .position
      .pixels;

  /// The styled editor's document.
  MutableDocument styledDocument() => SuperEditorInspector.findDocument()! as MutableDocument;

  /// The text of the styled node at [index].
  String styledTextAt(int index) =>
      (styledDocument().getNodeAt(index)! as ParagraphNode).text.toPlainText();

  testWidgets("a text typed in raw mode and left in flight is what the styled editor shows, and "
      "switching does not save it", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nA fresh action line.");
    await harness.tapQuickly(tester, find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);
    expect(find.byType(OcptEditorSourceField), findsNothing);
    expect(styledTextAt(styledDocument().nodeCount - 1), "A fresh action line.");
    expect(await harness.propertiesManager.editorMode.load(), OcptEditorMode.styled);

    // The switch itself writes nothing; the debounce started by the typing still does.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(await harness.storedText(), contains("A fresh action line."));
  });

  testWidgets("a text typed in the styled editor and left in flight is what raw mode shows", (
    tester,
  ) async {
    await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    final last = styledDocument().getNodeAt(styledDocument().nodeCount - 1)! as ParagraphNode;
    await tester.placeCaretInParagraph(last.id, 0);
    // Tab locks the block as a character cue: a real edit, flushed when the editor leaves the
    // tree rather than when its own sync debounce runs out.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byTooltip(tr.editorSwitchToRawModeTooltip));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(harness.rawText(tester), contains("@SOMETHING MOVES IN THE DARK."));
    expect(await harness.propertiesManager.editorMode.load(), OcptEditorMode.raw);
  });

  testWidgets("Ctrl+Shift+M toggles the mode from the raw field and from the styled editor", (
    tester,
  ) async {
    await harness.mount(tester);

    await tester.tap(harness.rawField);
    await harness.chord(tester, LogicalKeyboardKey.keyM, shift: true);
    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);

    final node = styledDocument().getNodeAt(0)! as ParagraphNode;
    await tester.placeCaretInParagraph(node.id, 0);
    await harness.chord(tester, LogicalKeyboardKey.keyM, shift: true);
    expect(find.byType(OcptEditorSourceField), findsOneWidget);
  });

  testWidgets("odd: the raw caret keeps its offset through the styled editor even though the text "
      "shifted under it", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final offset = scenarioSampleText.indexOf("SARAH");

    await harness.tap(tester, inPanel(find.text("EXT. GARDEN - NIGHT")));
    final controller = tester.widget<TextField>(harness.rawField).controller!;
    controller.selection = TextSelection.collapsed(offset: offset);
    await tester.pump();

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await harness.tap(tester, find.byTooltip(tr.editorSwitchToRawModeTooltip));

    // The offset is kept as a number, while the styled editor numbered the headings meanwhile:
    // the same offset now falls inside the first heading, and the page's idea of the caret line
    // is not recomputed from it.
    expect(harness.rawText(tester), startsWith("INT. KITCHEN - DAY #1#\n"));
    expect(harness.rawSelection(tester), TextSelection.collapsed(offset: offset));
    expect(offset, lessThan("INT. KITCHEN - DAY #1#".length));
    expect(
      tester.widget<OcptEditorScenePanel>(find.byType(OcptEditorScenePanel)).currentLine,
      isNot(0),
    );
  });

  testWidgets("a scene far down lands a third of the way down the raw field, and the scroll is "
      "lost on a round trip through the styled editor", (tester) async {
    await harness.seedScreenplay(_longScreenplay());
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(rawScrollOffset(tester), 0);

    final heading = inPanel(find.text("INT. ROOM 15 - DAY"));
    await tester.scrollUntilVisible(
      heading,
      100,
      scrollable: find
          .descendant(of: find.byType(OcptEditorScenePanel), matching: find.byType(Scrollable))
          .first,
    );
    await harness.tap(tester, heading);
    final scrolled = rawScrollOffset(tester);
    expect(scrolled, greaterThan(1000));
    // The heading sits about a third of the way down the field, not at its edge.
    final editableText = find.descendant(
      of: find.byType(OcptEditorSourceField),
      matching: find.byType(EditableText),
    );
    final renderEditable = tester.state<EditableTextState>(editableText).renderEditable;
    final caret = renderEditable.getLocalRectForCaret(
      TextPosition(offset: _longScreenplay().indexOf("INT. ROOM 15 - DAY")),
    );
    final field = tester.getRect(editableText);
    expect(
      (renderEditable.localToGlobal(caret.topLeft).dy - field.top) / field.height,
      inInclusiveRange(0.2, 0.45),
    );
    expect(
      harness.rawSelection(tester).baseOffset,
      _longScreenplay().indexOf("INT. ROOM 15 - DAY"),
    );

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await harness.tap(tester, find.byTooltip(tr.editorSwitchToRawModeTooltip));

    expect(rawScrollOffset(tester), 0);
  });

  testWidgets("the scene panel follows the text: a heading typed shows up on the parse debounce, "
      "a heading removed goes", (tester) async {
    await harness.mount(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nINT. CELLAR - NIGHT\n");
    await tester.pump(const Duration(milliseconds: 100));
    expect(inPanel(find.text("INT. CELLAR - NIGHT")), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(inPanel(find.text("INT. CELLAR - NIGHT")), findsOneWidget);

    await harness.type(tester, harness.rawField, "INT. KITCHEN - DAY\n\nNothing else.\n");
    await tester.pump(const Duration(milliseconds: 200));
    expect(inPanel(find.text("EXT. GARDEN - NIGHT")), findsNothing);
    expect(inPanel(find.text("INT. KITCHEN - DAY")), findsOneWidget);
  });

  testWidgets("clicking a scene puts the raw caret on its heading and highlights it", (
    tester,
  ) async {
    await harness.mount(tester);

    await harness.tap(tester, inPanel(find.text("EXT. GARDEN - NIGHT")));

    expect(harness.rawSelection(tester).baseOffset, scenarioSampleText.indexOf("EXT. GARDEN"));
    expect(harness.rawSelection(tester).isCollapsed, isTrue);
    // Heading of the second scene: line 6 (0-based) of the sample.
    expect(tester.widget<OcptEditorScenePanel>(find.byType(OcptEditorScenePanel)).currentLine, 6);
  });

  testWidgets("clicking a scene in styled mode puts the caret on its node", (tester) async {
    await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
    await harness.mount(tester);
    // Numbering the headings at mount restarts the parse debounce the panel is built from.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await harness.tap(tester, inPanel(find.text("EXT. GARDEN - NIGHT")));

    final selection = SuperEditorInspector.findDocumentSelection()!;
    expect(styledDocument().getNodeById(selection.extent.nodeId), isA<ParagraphNode>());
    expect(
      styledTextAt(styledDocument().getNodeIndexById(selection.extent.nodeId)),
      startsWith("EXT. GARDEN"),
    );
  });

  testWidgets("the counters move on the statistics debounce, a beat after the scene panel", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.textContaining(tr.editorStatsScenes(2)), findsOneWidget);

    await harness.type(
      tester,
      harness.rawField,
      "$scenarioSampleText\nINT. CELLAR - NIGHT\n\nMARC\nHello there friend.\n",
    );
    await tester.pump(const Duration(milliseconds: 300));
    // The parse has ticked, the pagination has not.
    expect(inPanel(find.text("INT. CELLAR - NIGHT")), findsOneWidget);
    expect(find.textContaining(tr.editorStatsScenes(2)), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining(tr.editorStatsScenes(3)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsCharacters(2)), findsOneWidget);
  });

  testWidgets("the right dock opens on the formatted preview in raw mode, closes when the styled "
      "editor takes over and comes back with it", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptEditorRightDock), findsOneWidget);
    expect(find.byType(OcptEditorPreview), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    expect(find.byType(OcptEditorRightDock), findsNothing);

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToRawModeTooltip));
    expect(find.byType(OcptEditorRightDock), findsOneWidget);
    expect(find.byType(OcptEditorPreview), findsOneWidget);
  });

  testWidgets("the inspector tab describes the scene under the caret", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.text(tr.editorRightDockInspectorTabLabel));
    await harness.tap(tester, inPanel(find.text("EXT. GARDEN - NIGHT")));

    expect(
      find.descendant(
        of: find.byType(OcptEditorInspectorPanel),
        matching: find.textContaining("EXT. GARDEN - NIGHT"),
      ),
      findsOneWidget,
    );
  });

  testWidgets("the scene panel can be hidden and shown again from the toolbar", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptEditorScenePanel), findsNothing);

    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
  });

  testWidgets("a phone-width window always shows the styled editor, and the raw field comes back "
      "when the window widens", (tester) async {
    await harness.mount(tester, size: const Size(500, 900));

    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);
    expect(find.byType(OcptEditorSourceField), findsNothing);
    expect(await harness.propertiesManager.editorMode.load(), OcptEditorMode.raw);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();

    expect(find.byType(OcptStyledScreenplayEditor), findsNothing);
    expect(find.byType(OcptEditorSourceField), findsOneWidget);
  });

  testWidgets("the title page dialog writes the title page into the screenplay and saves it", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapOverflowEntry(tester, tr.editorTitlePageAction);
    await tester.enterText(
      find.widgetWithText(TextField, tr.editorTitlePageTitleLabel),
      "Big Fish",
    );
    await tester.enterText(find.widgetWithText(TextField, tr.editorTitlePageAuthorLabel), "Jane");
    await harness.tap(tester, find.text(tr.editorPageSetupApplyAction));

    expect(harness.rawText(tester), startsWith("Title: Big Fish\nAuthor: Jane\n"));
    expect(await harness.storedText(), startsWith("Title: Big Fish\nAuthor: Jane\n"));
  });
}
