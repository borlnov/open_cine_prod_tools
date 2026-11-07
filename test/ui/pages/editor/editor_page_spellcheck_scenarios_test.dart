// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../../ocpt_result_expectations.dart';
import 'editor_page_scenarios_test_doubles.dart';

/// A screenplay whose second action line holds one misspelling, `wrold`, and whose first one is
/// spelt right.
const _misspeltText = """
INT. ROOM - DAY

SARAH
Hello world.

Hello wrold.
""";

/// Run the tests of the editor page spellcheck scenarios.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final harness = EditorScenarioHarness();

  setUpAll(harness.setUpAll);
  tearDownAll(harness.tearDownAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Gives the open project [language] and switches the underlines on, as a writer who opened the
  /// project settings once would have.
  Future<void> enableSpellCheck({
    OcptScreenplayLanguage? language = OcptScreenplayLanguage.enGb,
  }) async {
    await harness.projectsManager.saveCurrentProjectScreenplayLanguage(language).okOrFail;
    await harness.propertiesManager.spellCheckVisible.store(true);
  }

  /// Runs a desktop-only gesture case: a right-click is only wired on the desktop interactor,
  /// which `flutter test` does not pick by default.
  void desktopTestWidgets(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  /// The id of the styled node whose text is [text], or null while none reads so: the styled
  /// editor rebuilds its document when the page hands it a corrected text, so an id is only worth
  /// as much as the moment it was read.
  String? nodeIdOf(String text) {
    final document = SuperEditorInspector.findDocument();
    if (document == null) {
      return null;
    }
    for (var index = 0; index < document.nodeCount; index++) {
      final node = document.getNodeAt(index)! as ParagraphNode;
      if (node.text.toPlainText() == text) {
        return node.id;
      }
    }

    return null;
  }

  /// The misspelled ranges the styled editor paints on the node reading [text].
  List<TextRange> styledErrorsOf(String text) {
    final nodeId = nodeIdOf(text);
    if (nodeId == null) {
      return const [];
    }

    return SuperEditorInspector.findWidgetForComponent<ParagraphComponent>(
      nodeId,
    ).viewModel.spellingErrors;
  }

  /// Opens the page in raw mode over [text], waits until the dictionary has underlined something,
  /// then switches to the styled editor, which reports its texts against a dictionary that is
  /// ready.
  ///
  /// Opening in styled mode straight away would race the dictionary load and, today, never be
  /// underlined before the first edit; a scenario of its own pins that.
  Future<void> openStyledOver(WidgetTester tester, String text) async {
    await harness.seedScreenplay(text);
    await enableSpellCheck();
    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);
    await harness.tap(tester, find.byTooltip(harness.trOf(tester).editorSwitchToStyledModeTooltip));
  }

  /// Right-clicks the styled node reading [text], on its first glyphs.
  Future<void> rightClick(WidgetTester tester, String text) async {
    final nodeId = nodeIdOf(text)!;
    await tester.tapAt(
      SuperEditorInspector.findComponentOffset(nodeId, Alignment.centerLeft) + const Offset(4, 0),
      buttons: kSecondaryButton,
    );
    // The menu fetches its suggestions from the isolate before it shows the spelling group.
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(harness.trOf(tester).editorContextMenuIgnoreWordAction)),
    );
  }

  testWidgets("raw mode underlines the misspelt word of an action line, and nothing else", (
    tester,
  ) async {
    await harness.seedScreenplay(_misspeltText);
    await enableSpellCheck();

    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);

    // The heading and the cue are never checked; "Hello" and "world" are in the dictionary.
    expect(harness.underlinedWords(tester), ["wrold"]);
    expect(harness.spellCheckManager.loadedLanguage, OcptScreenplayLanguage.enGb);
  });

  testWidgets("raw mode checks a word typed afterwards on the parse debounce", (tester) async {
    await harness.seedScreenplay(_misspeltText);
    await enableSpellCheck();
    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);

    await harness.type(tester, harness.rawField, "$_misspeltText\nThe cat sat on the mta.\n");
    await tester.pump(const Duration(milliseconds: 200));
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).length == 2);

    expect(harness.underlinedWords(tester), ["wrold", "mta"]);
  });

  testWidgets("no underline is painted, and the isolate stays unloaded, while the project names no "
      "language", (tester) async {
    await harness.seedScreenplay(_misspeltText);
    await enableSpellCheck(language: null);

    await harness.mount(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(harness.underlinedWords(tester), isEmpty);
    expect(harness.spellCheckManager.loadedLanguage, isNull);
  });

  testWidgets("the machine's own switch hides the underlines, unloads the dictionary and is "
      "remembered; switching back on checks again", (tester) async {
    await harness.seedScreenplay(_misspeltText);
    await enableSpellCheck();
    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);
    final tr = harness.trOf(tester);

    await harness.tapOverflowEntry(tester, tr.editorToggleSpellCheckAction);
    await harness.pumpUntil(tester, () => harness.spellCheckManager.loadedLanguage == null);

    expect(harness.underlinedWords(tester), isEmpty);
    expect(await harness.propertiesManager.spellCheckVisible.load(), isFalse);

    await harness.tapOverflowEntry(tester, tr.editorToggleSpellCheckAction);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);

    expect(harness.underlinedWords(tester), ["wrold"]);
    expect(await harness.propertiesManager.spellCheckVisible.load(), isTrue);
  });

  testWidgets("a word the project dictionary already holds is never underlined on entry", (
    tester,
  ) async {
    // "wrld" is the control: it proves the check came back, so the silence on "wrold" is its.
    await harness.seedScreenplay("INT. ROOM - DAY\n\nHello wrold wrld.\n");
    await enableSpellCheck();
    final project = harness.projectsManager.currentProject!;
    await harness.projectsManager.projectDictionaryService
        .learnWord(database: project.database, word: "wrold")
        .okOrFail;

    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);

    expect(harness.underlinedWords(tester), ["wrld"]);
  });

  testWidgets("changing the project's language in the settings rechecks the screenplay against the "
      "other dictionary", (tester) async {
    await harness.seedScreenplay("INT. ROOM - DAY\n\nBonjour monde.\n\nHello world.\n");
    await enableSpellCheck(language: OcptScreenplayLanguage.fr);
    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);
    expect(harness.underlinedWords(tester), ["Hello", "world"]);
    final tr = harness.trOf(tester);

    // The settings page writes the language, then closes answering that something changed.
    await harness.projectsManager
        .saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.enGb)
        .okOrFail;
    harness.routerManager.pushAnswer = true;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    await harness.pumpUntil(
      tester,
      () => harness.spellCheckManager.loadedLanguage == OcptScreenplayLanguage.enGb,
    );
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).contains("Bonjour"));

    expect(harness.routerManager.pushed.single.route, OcptRoute.projectSettings);
    expect(harness.underlinedWords(tester), ["Bonjour", "monde"]);
  });

  testWidgets("a settings page closed without a change leaves the dictionary alone", (
    tester,
  ) async {
    await harness.seedScreenplay(_misspeltText);
    await enableSpellCheck();
    await harness.mount(tester);
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);
    final tr = harness.trOf(tester);

    await harness.projectsManager
        .saveCurrentProjectScreenplayLanguage(OcptScreenplayLanguage.fr)
        .okOrFail;
    harness.routerManager.pushAnswer = false;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(harness.spellCheckManager.loadedLanguage, OcptScreenplayLanguage.enGb);
    expect(harness.underlinedWords(tester), ["wrold"]);
  });

  testWidgets("styled mode paints the same misspelling on its node and none on the heading or "
      "the cue", (tester) async {
    await openStyledOver(tester, _misspeltText);
    await harness.pumpUntil(tester, () => styledErrorsOf("Hello wrold.").isNotEmpty);

    expect(styledErrorsOf("Hello wrold."), [const TextRange(start: 6, end: 11)]);
    expect(styledErrorsOf("Hello world."), isEmpty);
    expect(styledErrorsOf("SARAH"), isEmpty);
  });

  desktopTestWidgets("styled mode: picking a suggestion rewrites the word and the edit is saved", (
    tester,
  ) async {
    await openStyledOver(tester, "INT. ROOM - DAY\n\nwrold\n");
    await harness.pumpUntil(tester, () => styledErrorsOf("wrold").isNotEmpty);

    await rightClick(tester, "wrold");
    await harness.tap(tester, find.text("world"));

    expect(nodeIdOf("world"), isNotNull);
    expect(nodeIdOf("wrold"), isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(await harness.storedText(), contains("\nworld\n"));
  });

  desktopTestWidgets("styled mode: adding a word to the project's dictionary stores it and lifts "
      "the underline", (tester) async {
    await openStyledOver(tester, "INT. ROOM - DAY\n\nwrold\n");
    await harness.pumpUntil(tester, () => styledErrorsOf("wrold").isNotEmpty);
    final tr = harness.trOf(tester);

    await rightClick(tester, "wrold");
    await harness.tap(tester, find.text(tr.editorContextMenuAddToDictionaryAction));
    await harness.pumpUntil(tester, () => styledErrorsOf("wrold").isEmpty);

    final project = harness.projectsManager.currentProject!;
    expect(
      await harness.projectsManager.projectDictionaryService
          .loadWords(database: project.database)
          .valueOrFail,
      contains("wrold"),
    );
    expect(styledErrorsOf("wrold"), isEmpty);
  });

  desktopTestWidgets("styled mode: ignoring a word lifts the underline and writes nothing to the "
      "project", (tester) async {
    await openStyledOver(tester, "INT. ROOM - DAY\n\nwrold\n");
    await harness.pumpUntil(tester, () => styledErrorsOf("wrold").isNotEmpty);
    final tr = harness.trOf(tester);

    await rightClick(tester, "wrold");
    await harness.tap(tester, find.text(tr.editorContextMenuIgnoreWordAction));
    await harness.pumpUntil(tester, () => styledErrorsOf("wrold").isEmpty);

    final project = harness.projectsManager.currentProject!;
    expect(
      await harness.projectsManager.projectDictionaryService
          .loadWords(database: project.database)
          .valueOrFail,
      isEmpty,
    );
    expect(styledErrorsOf("wrold"), isEmpty);
  });

  testWidgets("a switch from styled to raw checks the text the raw field is about to show", (
    tester,
  ) async {
    await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
    await harness.seedScreenplay("INT. ROOM - DAY\n\nHello world.\n");
    await enableSpellCheck();
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    // Typed in the styled editor, where nothing paints a raw-mode underline.
    final document = SuperEditorInspector.findDocument()!;
    final node = document.getNodeAt(1)! as ParagraphNode;
    await tester.placeCaretInParagraph(node.id, node.text.toPlainText().length);
    await tester.typeImeText(" Wrold");
    await tester.pumpAndSettle();

    await harness.tap(tester, find.byTooltip(tr.editorSwitchToRawModeTooltip));
    await harness.pumpUntil(tester, () => harness.underlinedWords(tester).isNotEmpty);

    expect(harness.rawText(tester), contains("Hello world. Wrold"));
    expect(harness.underlinedWords(tester), ["Wrold"]);
  });

  testWidgets("odd: opening straight into styled mode underlines nothing until the first edit", (
    tester,
  ) async {
    await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
    await harness.seedScreenplay("INT. ROOM - DAY\n\nwrold\n");
    await enableSpellCheck();
    await harness.mount(tester);

    // The styled editor reports its texts as it mounts, before the dictionary is loaded, and
    // nothing asks it again once it is: the dictionary is ready and the word is still plain.
    await harness.pumpUntil(
      tester,
      () => harness.spellCheckManager.loadedLanguage == OcptScreenplayLanguage.enGb,
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(styledErrorsOf("wrold"), isEmpty);

    final node = SuperEditorInspector.findDocument()!.getNodeAt(1)! as ParagraphNode;
    await tester.placeCaretInParagraph(node.id, 5);
    await tester.typeImeText("x");
    await harness.pumpUntil(tester, () => styledErrorsOf("wroldx").isNotEmpty);

    expect(styledErrorsOf("wroldx"), [const TextRange(start: 0, end: 6)]);
  });
}
