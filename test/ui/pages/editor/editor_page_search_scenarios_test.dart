// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'editor_page_scenarios_test_doubles.dart';

/// A screenplay repeating `line` three times, once in capitals and once inside a longer word.
const _repeatedText = "line one.\n\nLINE two.\n\nOutline three.\n";

void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final harness = EditorScenarioHarness();

  setUpAll(harness.setUpAll);
  tearDownAll(harness.tearDownAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Opens the find bar through the `⋮` menu and types [query] into it.
  Future<void> search(WidgetTester tester, String query, {bool withReplace = false}) async {
    final tr = harness.trOf(tester);
    await harness.tapOverflowEntry(
      tester,
      withReplace ? tr.editorFindAndReplaceAction : tr.editorFindAction,
    );
    await tester.enterText(harness.barFields.first, query);
    await tester.pumpAndSettle();
  }

  /// Types [replacement] into the replace row of the open bar.
  Future<void> replaceWith(WidgetTester tester, String replacement) async {
    await tester.enterText(harness.barFields.last, replacement);
    await tester.pumpAndSettle();
  }

  /// The styled editor's document.
  MutableDocument styledDocument() => SuperEditorInspector.findDocument()! as MutableDocument;

  /// The plain texts of every styled node, in order.
  List<String> styledTexts() => [
    for (var index = 0; index < styledDocument().nodeCount; index++)
      (styledDocument().getNodeAt(index)! as ParagraphNode).text.toPlainText(),
  ];

  /// Taps the bar's button carrying [tooltip].
  Future<void> tapBar(WidgetTester tester, String tooltip) => harness.tap(
    tester,
    find.descendant(of: find.byType(OcptEditorFindBar), matching: find.byTooltip(tooltip)),
  );

  testWidgets("the bar opens from Ctrl+F on find alone and from Ctrl+H with the replace row, and "
      "Escape closes it", (tester) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await tester.tap(harness.rawField);
    await tester.pumpAndSettle();

    await harness.chord(tester, LogicalKeyboardKey.keyF);
    expect(find.byType(OcptEditorFindBar), findsOneWidget);
    expect(harness.barFields, findsOneWidget);
    expect(find.text(tr.editorReplaceAction), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorFindBar), findsNothing);

    await harness.chord(tester, LogicalKeyboardKey.keyH);
    expect(harness.barFields, findsNWidgets(2));
    expect(find.text(tr.editorReplaceAction), findsOneWidget);
  });

  testWidgets("a query counts its matches, case-insensitively and inside longer words by default", (
    tester,
  ) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);

    await search(tester, "line");

    expect(find.text("1/3"), findsOneWidget);
    // The first match is selected in the field, without the field taking the focus.
    expect(harness.rawSelection(tester), const TextSelection(baseOffset: 0, extentOffset: 4));
  });

  testWidgets("next and previous walk the matches and wrap around, moving the raw selection", (
    tester,
  ) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "line");

    await tapBar(tester, tr.editorFindNextTooltip);
    expect(find.text("2/3"), findsOneWidget);
    expect(harness.rawSelection(tester).start, _repeatedText.indexOf("LINE"));

    await tapBar(tester, tr.editorFindNextTooltip);
    expect(find.text("3/3"), findsOneWidget);
    expect(harness.rawSelection(tester).start, _repeatedText.indexOf("line three"));

    await tapBar(tester, tr.editorFindNextTooltip);
    expect(find.text("1/3"), findsOneWidget);
    expect(harness.rawSelection(tester).start, 0);

    await tapBar(tester, tr.editorFindPreviousTooltip);
    expect(find.text("3/3"), findsOneWidget);
  });

  testWidgets("the case and whole-word toggles narrow the matches", (tester) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "line");
    expect(find.text("1/3"), findsOneWidget);

    // "line" and "Outline", not "LINE".
    await tapBar(tester, tr.editorFindMatchCaseTooltip);
    expect(find.text("1/2"), findsOneWidget);

    // Only the word on its own.
    await tapBar(tester, tr.editorFindWholeWordTooltip);
    expect(find.text("1/1"), findsOneWidget);

    // "line" and "LINE", not "Outline".
    await tapBar(tester, tr.editorFindMatchCaseTooltip);
    expect(find.text("1/2"), findsOneWidget);
  });

  testWidgets("a query with no match says so, and a query is read literally", (tester) async {
    await harness.seedScreenplay("Price (A+B) is 5.\n");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await search(tester, "line");
    expect(find.text(tr.editorFindNoMatches), findsOneWidget);

    await harness.type(tester, harness.barFields.first, "(A+B)");
    await tester.pumpAndSettle();
    expect(find.text("1/1"), findsOneWidget);

    await harness.type(tester, harness.barFields.first, "5.");
    await tester.pumpAndSettle();
    expect(find.text("1/1"), findsOneWidget);
  });

  testWidgets("a count gone stale is recomputed when the text changes under an open bar", (
    tester,
  ) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "line");
    await tapBar(tester, tr.editorFindNextTooltip);
    await tapBar(tester, tr.editorFindNextTooltip);
    expect(find.text("3/3"), findsOneWidget);

    await harness.type(tester, harness.rawField, "Line one.\n");
    await tester.pumpAndSettle();

    // The current match was the third; only one is left, and the index is clamped onto it.
    expect(find.text("1/1"), findsOneWidget);

    await harness.type(tester, harness.rawField, "Nothing at all.\n");
    await tester.pumpAndSettle();
    expect(find.text(tr.editorFindNoMatches), findsOneWidget);
  });

  testWidgets("Replace changes the current match and moves on to the next, even when the "
      "replacement matches the query itself", (tester) async {
    await harness.seedScreenplay("MARIE enters.\n\nMARIE speaks.\n");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "MARIE", withReplace: true);
    await replaceWith(tester, "MARIE-JEANNE");

    await harness.tap(tester, find.text(tr.editorReplaceAction));
    // The renamed word still matches: the current match moved past it, onto the second one.
    expect(harness.rawText(tester), "MARIE-JEANNE enters.\n\nMARIE speaks.\n");
    expect(find.text("2/2"), findsOneWidget);

    await harness.tap(tester, find.text(tr.editorReplaceAction));
    expect(harness.rawText(tester), "MARIE-JEANNE enters.\n\nMARIE-JEANNE speaks.\n");
    // Nothing starts after the last one written: the search wraps to the first match.
    expect(find.text("1/2"), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(await harness.storedText(), "MARIE-JEANNE enters.\n\nMARIE-JEANNE speaks.\n");
  });

  testWidgets("Replace all asks first, replaces nothing when cancelled and everything when "
      "confirmed", (tester) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "line", withReplace: true);
    await replaceWith(tester, "Scene");

    await harness.tap(tester, find.text(tr.editorReplaceAllAction));
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(find.text(tr.editorReplaceAllConfirmMessage(3)), findsOneWidget);
    await harness.tap(tester, find.text(tr.editorReplaceAllConfirmCancelAction));
    expect(find.byType(OcptConfirmDialog), findsNothing);
    expect(harness.rawText(tester), _repeatedText);

    await harness.tap(tester, find.text(tr.editorReplaceAllAction));
    await harness.tap(tester, find.text(tr.editorReplaceAllConfirmAction).last);
    expect(harness.rawText(tester), "Scene one.\n\nScene two.\n\nOutScene three.\n");
    expect(find.text(tr.editorFindNoMatches), findsOneWidget);
  });

  testWidgets("closing the bar keeps the query and the options for the next opening", (
    tester,
  ) async {
    await harness.seedScreenplay(_repeatedText);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "line");
    await tapBar(tester, tr.editorFindMatchCaseTooltip);
    expect(find.text("1/2"), findsOneWidget);

    await tapBar(tester, tr.editorFindCloseTooltip);
    expect(find.byType(OcptEditorFindBar), findsNothing);

    await harness.tapOverflowEntry(tester, tr.editorFindAction);
    expect(find.text("line"), findsOneWidget);
    expect(find.text("1/2"), findsOneWidget);
  });

  testWidgets("the search survives a switch to the styled editor and back, each mode counting "
      "what it shows", (tester) async {
    await harness.seedScreenplay("INT. ROOM - DAY\n\nLine one.\n\nLine two.\n");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "line");
    expect(find.text("1/2"), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    expect(find.byType(OcptEditorFindBar), findsOneWidget);
    expect(find.text("line"), findsOneWidget);
    expect(find.text("1/2"), findsOneWidget);

    // Opening the styled editor numbered the headings in the source: "#" is in the raw text
    // twice over, and nowhere in what the styled editor displays.
    await harness.type(tester, harness.barFields.first, "#");
    await tester.pumpAndSettle();
    expect(find.text(tr.editorFindNoMatches), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToRawModeTooltip));
    expect(find.text("1/2"), findsOneWidget);
  });

  testWidgets("styled mode: Replace and Replace all edit the nodes, the latter behind the "
      "confirmation", (tester) async {
    await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
    await harness.seedScreenplay("INT. ROOM - DAY\n\nLine one.\n\nLine two.\n\nLine three.\n");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await search(tester, "Line", withReplace: true);
    await replaceWith(tester, "Scene");
    expect(find.text("1/3"), findsOneWidget);

    await harness.tap(tester, find.text(tr.editorReplaceAction));
    expect(styledTexts(), containsAllInOrder(["Scene one.", "Line two.", "Line three."]));
    expect(find.text("1/2"), findsOneWidget);

    await harness.tap(tester, find.text(tr.editorReplaceAllAction));
    await harness.tap(tester, find.text(tr.editorReplaceAllConfirmCancelAction));
    expect(styledTexts(), containsAllInOrder(["Scene one.", "Line two.", "Line three."]));

    await harness.tap(tester, find.text(tr.editorReplaceAllAction));
    await harness.tap(tester, find.text(tr.editorReplaceAllConfirmAction).last);
    expect(styledTexts(), containsAllInOrder(["Scene one.", "Scene two.", "Scene three."]));
    expect(find.text(tr.editorFindNoMatches), findsOneWidget);
  });
}
