// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_block.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_toolbar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// The sample script every test loads: two scenes (the first heading deliberately lowercase, to
/// check the preview renders headings uppercase), one dialogue block and some action text.
const _sampleText = """
int. kitchen - day

SARAH
(to herself)
Smells like Sunday.

EXT. GARDEN - NIGHT

Something moves in the dark.
""";

/// A router manager whose [pop] only records that it was called: these page tests pump the
/// editor page directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; this file's styled-mode tests give the styled editor a selection.
  BlinkController.indeterminateAnimationsEnabled = false;

  // EditorPage builds its OcptEditorBloc internally via `OcptEditorBloc()`, which resolves the
  // projects manager from globalGetIt() by default; a real (but test-controlled) instance is
  // registered in the app's actual GetIt instance once, like the home page test does.
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late _RecordingRouterManager routerManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();

    routerManager = _RecordingRouterManager();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(routerManager)
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(
          fileSaverManager: const FileSaverManager(),
          fileSelectorManager: const FileSelectorManager(),
        ),
      );
  });

  setUp(() async {
    // Most of the existing tests below exercise the raw mode's own widgets (the source
    // `TextField`, the paper preview); force that mode here so they keep passing regardless of
    // the default mode, and let the styled-mode tests further down store their own preference.
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    routerManager.popped = false;

    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_page_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: _sampleText,
      snapshotReason: OcptSnapshotReason.manual,
    );
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  testWidgets('renders the toolbar, the source text, the scene panel and the paper preview', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    expect(find.byType(OcptEditorToolbar), findsOneWidget);
    expect(find.text("My Movie"), findsOneWidget);

    final textField = tester.widget<TextField>(
      find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
    );
    expect(textField.controller?.text, _sampleText);

    // The panel and the preview both show the heading uppercased, even though the source line is
    // lowercase: findRichText also matches the preview's styled text.
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
    expect(find.byType(OcptEditorPreview), findsOneWidget);
    expect(find.text("INT. KITCHEN - DAY", findRichText: true), findsNWidgets(2));
    expect(find.text("Smells like Sunday.", findRichText: true), findsOneWidget);
  });

  testWidgets('the preview typesets character and dialogue at their screenplay indents', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    /// Collects the distinct left padding values used inside the preview block showing [text].
    Set<double> leftIndentsOfBlockWith(String text) {
      final blockFinder = find.ancestor(
        of: find.text(text, findRichText: true),
        matching: find.byType(OcptEditorPreviewBlock),
      );
      final paddings = tester.widgetList<Padding>(
        find.descendant(of: blockFinder, matching: find.byType(Padding)),
      );

      return {
        for (final padding in paddings)
          if (padding.padding.resolve(TextDirection.ltr).left > 0)
            padding.padding.resolve(TextDirection.ltr).left,
      };
    }

    final headingIndents = leftIndentsOfBlockWith("INT. KITCHEN - DAY");
    final dialogueIndents = leftIndentsOfBlockWith("Smells like Sunday.");

    // The heading sits at the page's left margin; the dialogue block uses distinct, deeper
    // indents for the character cue, the parenthetical and the dialogue text.
    expect(headingIndents, hasLength(1));
    expect(dialogueIndents, hasLength(3));
    for (final indent in dialogueIndents) {
      expect(indent, greaterThan(headingIndents.single));
    }
  });

  testWidgets('clicking a scene in the panel moves the editor caret to that scene', (tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    // The heading also appears in the preview, so the tap is scoped to the panel.
    await tester.tap(
      find.descendant(
        of: find.byType(OcptEditorScenePanel),
        matching: find.text("EXT. GARDEN - NIGHT"),
      ),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(
      find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
    );
    expect(
      textField.controller?.selection.baseOffset,
      _sampleText.indexOf("EXT. GARDEN - NIGHT"),
    );
  });

  testWidgets('the preview and the scene panel can be hidden from the toolbar', (tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.editorTogglePreviewTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorPreview), findsNothing);

    await tester.tap(find.byTooltip(tr.editorToggleScenePanelTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorScenePanel), findsNothing);

    // Toggling again brings both back.
    await tester.tap(find.byTooltip(tr.editorTogglePreviewTooltip));
    await tester.tap(find.byTooltip(tr.editorToggleScenePanelTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorPreview), findsOneWidget);
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
  });

  testWidgets(
    "the mode toggle switches from raw to styled editing (no preview panel) and persists the "
    "preference, and back",
    (tester) async {
      await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
      await tester.pumpAndSettle();

      // Starts in raw mode (forced by this file's setUp): the raw source field and its preview
      // are shown, the styled editor isn't.
      expect(find.byType(OcptEditorSourceField), findsOneWidget);
      expect(find.byType(OcptEditorPreview), findsOneWidget);
      expect(find.byType(OcptStyledScreenplayEditor), findsNothing);

      final context = tester.element(find.byType(EditorPage));
      final tr = Tr.of(context);

      await tester.tap(find.byTooltip(tr.editorSwitchToStyledModeTooltip));
      await tester.pumpAndSettle();

      // Styled mode: the styled editor replaces the raw field, and there is no preview panel
      // toggle at all (the styled layout already is the formatted screenplay).
      expect(find.byType(OcptEditorSourceField), findsNothing);
      expect(find.byType(OcptEditorPreview), findsNothing);
      expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);
      expect(find.byTooltip(tr.editorTogglePreviewTooltip), findsNothing);
      expect(await propertiesManager.editorMode.load(), OcptEditorMode.styled);

      await tester.tap(find.byTooltip(tr.editorSwitchToRawModeTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(OcptEditorSourceField), findsOneWidget);
      expect(find.byType(OcptStyledScreenplayEditor), findsNothing);
      expect(await propertiesManager.editorMode.load(), OcptEditorMode.raw);
    },
  );

  testWidgets("an edit made in raw mode survives switching to styled mode", (tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: find.byType(OcptEditorSourceField),
      matching: find.byType(TextField),
    );
    await tester.enterText(textFieldFinder, "$_sampleText\nA fresh action line.");
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);
    await tester.tap(find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    final lastNode = document.getNodeAt(document.nodeCount - 1)! as ParagraphNode;
    expect(lastNode.text.toPlainText(), "A fresh action line.");
  });

  testWidgets("an edit made in styled mode survives switching back to raw mode", (tester) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    final lastNode = document.getNodeAt(document.nodeCount - 1)! as ParagraphNode;
    await tester.placeCaretInParagraph(lastNode.id, lastNode.text.toPlainText().length);
    await tester.typeImeText(" indeed.");
    // `typeImeText` already settles fully after every character it sends (see the doc comment on
    // the equivalent call in `ocpt_styled_screenplay_editor_test.dart`), draining the sync/parse/
    // autosave debounces along the way; this test only cares that the edit survives a mode
    // switch, not about the flush-on-removal path itself (see the dedicated test below for that).
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);
    await tester.tap(find.byTooltip(tr.editorSwitchToRawModeTooltip));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(
      find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
    );
    expect(textField.controller?.text, contains("Something moves in the dark. indeed."));
  });

  testWidgets(
    "an edit made in styled mode survives switching away before its sync debounce clears, "
    "flushed by deactivate() the same way the editor route's own back navigation would",
    (tester) async {
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final lastNode = document.getNodeAt(document.nodeCount - 1)! as ParagraphNode;
      await tester.placeCaretInParagraph(lastNode.id, 0);

      // Tab locks the block's type as a manual override: a genuine document edit, same as typing
      // text would produce, without needing `typeImeText` (which settles fully after every
      // character it sends, draining the very debounce this test needs to catch still pending).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // A bounded pump shorter than the styled editor's 120 ms sync debounce: long enough to
      // process the key event, short enough that its `_syncTimer` is still pending. No
      // `pumpAndSettle` here — it would let the timer fire naturally and hide a missing flush.
      await tester.pump(const Duration(milliseconds: 20));

      final context = tester.element(find.byType(EditorPage));
      final tr = Tr.of(context);
      // Removing the styled editor from the tree is what runs
      // `_OcptStyledScreenplayEditorState.deactivate()`; in this page test (no live GoRouter
      // under `_RecordingRouterManager`) tapping the back button doesn't itself unmount the page,
      // so the mode toggle is used here to exercise the identical removal path the editor route's
      // own back navigation also triggers (see that widget's class doc comment).
      await tester.tap(find.byTooltip(tr.editorSwitchToRawModeTooltip));
      // A zero-duration pump first: enough for the mode-toggle bloc event to be processed and the
      // conditional widget swap to remove the styled editor from the tree — and with it run
      // `deactivate()` — without advancing the fake clock anywhere near the 120 ms debounce.
      // `pumpAndSettle` only afterwards, once that removal (and its flush) has already happened.
      await tester.pump();
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
      );
      // Tab cycled the last node from `action` to `character`: "Something moves in the dark."
      // isn't all-caps, so it never auto-detects as a character cue and always needs its `@`
      // forcing marker once locked as one. If `deactivate()` hadn't flushed the still-pending sync
      // before `dispose()` cancelled its timer (which never fires once cancelled), this edit would
      // have been lost entirely and the line below would still read unprefixed.
      expect(textField.controller?.text, contains("@Something moves in the dark."));
    },
  );

  testWidgets("Ctrl+Shift+M also toggles the editing mode", (tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    expect(find.byType(OcptStyledScreenplayEditor), findsNothing);

    // The `Shortcuts`/`Actions` pair only sees key events that reach a focused descendant, so
    // give the raw source field focus first.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);
  });

  testWidgets("clicking a scene in the panel moves the styled editor's selection to that scene", (
    tester,
  ) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(OcptEditorScenePanel),
        matching: find.text("EXT. GARDEN - NIGHT"),
      ),
    );
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    // Blank source lines are folded into node metadata rather than being their own node, so a
    // node's index is the count of non-blank lines before it, not its raw source line number:
    // "int. kitchen - day", "SARAH", "(to herself)" and "Smells like Sunday." precede
    // "EXT. GARDEN - NIGHT" in `_sampleText`, making it the 5th node (index 4).
    const expectedNodeIndex = 4;
    final selection = SuperEditorInspector.findDocumentSelection();

    expect(selection, isNotNull);
    expect(document.getNodeIndexById(selection!.extent.nodeId), expectedNodeIndex);
  });

  testWidgets("Ctrl+S saves when the styled editor (not the page's own Shortcuts) has focus", (
    tester,
  ) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    final firstNodeId = document.getNodeAt(0)!.id;
    await tester.placeCaretInParagraph(firstNodeId, 0);
    await tester.typeImeText("X");
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);
    expect(find.byTooltip(tr.editorUnsavedChangesTooltip), findsOneWidget);

    // super_editor's own `keyboardActions` (Tab cycle, smart Enter, Ctrl+U) match none of
    // these keys, so the combo falls through, unhandled, all the way to the page-level
    // `Shortcuts`/`Actions` pair.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byTooltip(tr.editorUnsavedChangesTooltip), findsNothing);
  });

  testWidgets("Ctrl+Shift+M also toggles the editing mode when the styled editor has focus", (
    tester,
  ) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();
    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);

    final document = SuperEditorInspector.findDocument()!;
    final firstNodeId = document.getNodeAt(0)!.id;
    await tester.placeCaretInParagraph(firstNodeId, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(OcptStyledScreenplayEditor), findsNothing);
    expect(find.byType(OcptEditorSourceField), findsOneWidget);
  });

  testWidgets(
    'the format controls are absent in raw mode and appear once switched to styled mode',
    (tester) async {
      await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
      final tr = Tr.of(context);

      // Starts in raw mode (forced by this file's setUp): no format controls at all.
      expect(find.byType(OcptEditorBlockTypeDropdown), findsNothing);
      expect(find.byTooltip(tr.editorToggleBoldTooltip), findsNothing);
      expect(find.byTooltip(tr.editorToggleItalicTooltip), findsNothing);
      expect(find.byTooltip(tr.editorToggleUnderlineTooltip), findsNothing);

      await tester.tap(find.byTooltip(tr.editorSwitchToStyledModeTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(OcptEditorBlockTypeDropdown), findsOneWidget);
      expect(find.byTooltip(tr.editorToggleBoldTooltip), findsOneWidget);
      expect(find.byTooltip(tr.editorToggleItalicTooltip), findsOneWidget);
      expect(find.byTooltip(tr.editorToggleUnderlineTooltip), findsOneWidget);
    },
  );

  testWidgets(
    "using the toolbar's dropdown changes the caret's block type in the live styled document",
    (tester) async {
      await propertiesManager.editorMode.store(OcptEditorMode.styled);

      await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = document.getNodeAt(0)!.id;
      await tester.placeCaretInParagraph(firstNodeId, 0);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
      final tr = Tr.of(context);

      await tester.tap(find.byType(DropdownButton<FountainLineType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.editorBlockTypeTransition).last);
      await tester.pumpAndSettle();

      final node = document.getNodeAt(0)! as ParagraphNode;
      expect(
        OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")),
        FountainLineType.transition,
      );
      expect(node.getMetadataValue(ocptTypeLockedMetadataKey), isTrue);
    },
  );

  testWidgets('the toolbar back button closes the project and navigates back', (tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);

    final backButton = find.byTooltip(tr.editorBackToProjectsTooltip);
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(projectsManager.currentProject, isNull);
    expect(routerManager.popped, isTrue);
  });

  testWidgets('the ⋮ menu opens and shows the export and import-and-replace actions', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.editorExportAction), findsOneWidget);
    expect(find.text(tr.editorImportAndReplaceAction), findsOneWidget);
    expect(find.text(tr.editorTogglePageSimulationAction), findsOneWidget);
  });

  testWidgets(
    'toggling page simulation from the ⋮ menu flips it and persists the new value',
    (tester) async {
      await propertiesManager.isPageSimulationEnabled.store(true);
      await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
      final tr = Tr.of(context);

      await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text(tr.editorTogglePageSimulationAction),
          matching: find.byType(CheckedPopupMenuItem<void>),
        ),
      );
      await tester.pumpAndSettle();

      expect(await propertiesManager.isPageSimulationEnabled.load(), isFalse);
    },
  );
}
