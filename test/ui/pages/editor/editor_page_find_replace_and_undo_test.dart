// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import '../../../ocpt_result_expectations.dart';
import 'editor_page_test_doubles.dart';

/// Run the tests of the editor page find replace and undo.
void main() {
  // A blinking caret schedules a repeating `Timer`/`Ticker` for as long as the styled editor has
  // a selection, which never lets `pumpAndSettle` settle and trips the "no pending timers" check
  // at the end of a test; this file's styled-mode tests give the styled editor a selection.
  BlinkController.indeterminateAnimationsEnabled = false;

  // OcptEditorPage builds its OcptEditorBloc internally via `OcptEditorBloc()`, which resolves the
  // projects manager from globalGetIt() by default; a real (but test-controlled) instance is
  // registered in the app's actual GetIt instance once, like the home page test does.
  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late RecordingRouterManager routerManager;

  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    routerManager = RecordingRouterManager();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(routerManager)
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      )
      ..registerSingleton<OcptSpellCheckManager>(
        OcptSpellCheckManager(loadAsset: loadMiniatureDictionaryAsset),
      );
  });

  tearDownAll(
    () => OcptGlobalManager.instance.managers.get<OcptSpellCheckManager>().disposeLifeCycle(),
  );

  setUp(() async {
    // Most of the existing tests below exercise the raw mode's own widgets (the source
    // `TextField`, the paper preview); force that mode here so they keep passing regardless of
    // the default mode, and let the styled-mode tests further down store their own preference.
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    // None of the styled-mode tests below are about the title sheet: page simulation defaults to
    // on in the real app, which would push a `sampleText`-sized document's nodes far enough down
    // the simulated first page that a caret-placing tap could no longer reach them. Force it off
    // here; the two tests that are actually about page simulation store their own `true`.
    await propertiesManager.isPageSimulationEnabled.store(false);
    routerManager.popped = false;

    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_page_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: sampleText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  /// Pumps [OcptEditorPage] on a desktop-sized surface.
  ///
  /// The size is not incidental: the screenplay mode carries the fullest toolbar of any mode — the
  /// `Add an episode…` button included, this fixture's project holding a single episode — and the
  /// 800×600 default `flutter_test` surface leaves that band about a pixel of slack, so any test
  /// pumping at it fails on a toolbar overflow that says nothing about what the test is checking.
  Future<void> pumpEditorPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithLocalization(const OcptEditorPage()));
  }

  group('find/replace (raw mode)', () {
    /// Whether the single [EditableText] found inside [finder] currently has focus.
    bool isFocused(WidgetTester tester, Finder finder) => tester
        .widget<EditableText>(find.descendant(of: finder, matching: find.byType(EditableText)))
        .focusNode
        .hasFocus;

    testWidgets('Ctrl+F opens the bar, focuses the find field, and folds the replace row', (
      tester,
    ) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OcptEditorSourceField));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(OcptEditorFindBar), findsOneWidget);
      expect(
        find.descendant(of: find.byType(OcptEditorFindBar), matching: find.byType(TextField)),
        findsOneWidget,
      );
      expect(isFocused(tester, find.byType(OcptEditorFindBar)), isTrue);
    });

    testWidgets('Ctrl+H opens the bar with the replace row unfolded', (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OcptEditorSourceField));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(OcptEditorFindBar), matching: find.byType(TextField)),
        findsNWidgets(2),
      );
    });

    testWidgets('the ⋮ menu opens the bar on find alone, stating both shortcuts', (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
      await tester.pumpAndSettle();

      expect(find.text('Ctrl+F'), findsOneWidget);
      expect(find.text('Ctrl+H'), findsOneWidget);

      await tester.tap(find.text(tr.editorFindAction));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(OcptEditorFindBar), matching: find.byType(TextField)),
        findsOneWidget,
      );
    });

    testWidgets('the ⋮ menu opens the bar with the replace row unfolded', (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.editorFindAndReplaceAction));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(OcptEditorFindBar), matching: find.byType(TextField)),
        findsNWidgets(2),
      );
    });

    testWidgets('Escape closes the bar', (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OcptEditorSourceField));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorFindBar), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(OcptEditorFindBar), findsNothing);
    });

    testWidgets('typing a query highlights the matches and shows the n/total counter', (
      tester,
    ) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OcptEditorSourceField));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final findFieldFinder = find.descendant(
        of: find.byType(OcptEditorFindBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(findFieldFinder, "MOVES");
      await tester.pumpAndSettle();

      expect(find.text("1/1"), findsOneWidget);
    });

    testWidgets('Replace changes the matched text and moves to the next match', (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
        "Line one.\n\nLine two.\n\nLine three.\n",
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final barTextFields = find.descendant(
        of: find.byType(OcptEditorFindBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(barTextFields.first, "Line");
      await tester.pumpAndSettle();
      expect(find.text("1/3"), findsOneWidget);

      await tester.enterText(barTextFields.last, "Scene");
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);
      await tester.tap(find.text(tr.editorReplaceAction));
      await tester.pumpAndSettle();

      final rawText = tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(OcptEditorSourceField),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text;
      expect(rawText, contains("Scene one."));
      expect(rawText, contains("Line two."));
      expect(rawText, contains("Line three."));
      // The count shrank from 3 to 2, and the current match moved to the one that took the
      // replaced one's place.
      expect(find.text("1/2"), findsOneWidget);
    });

    testWidgets(
      'Replace advances past a replacement that itself still matches the query, renaming every '
      'occurrence exactly once rather than compounding onto the same spot',
      (tester) async {
        await pumpEditorPage(tester);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
          "MARIE enters.\n\nMARIE speaks.\n",
        );
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        final barTextFields = find.descendant(
          of: find.byType(OcptEditorFindBar),
          matching: find.byType(TextField),
        );
        await tester.enterText(barTextFields.first, "MARIE");
        await tester.pumpAndSettle();
        // "MARIE" replaced by "MARIE-JEANNE" still matches "MARIE" at that very same offset, so
        // this is the scenario replace exists for.
        await tester.enterText(barTextFields.last, "MARIE-JEANNE");
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(OcptEditorPage));
        final tr = Tr.of(context);

        String rawText() => tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(OcptEditorSourceField),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text;

        await tester.tap(find.text(tr.editorReplaceAction));
        await tester.pumpAndSettle();
        // The first occurrence is renamed, the second isn't touched yet, and — the actual
        // regression this guards — the current match did not stay stuck inside what was just
        // written (it would otherwise turn the next press into "MARIE-JEANNE-JEANNE").
        expect(rawText(), contains("MARIE-JEANNE enters."));
        expect(rawText(), contains("MARIE speaks."));
        expect(rawText(), isNot(contains("JEANNE-JEANNE")));

        await tester.tap(find.text(tr.editorReplaceAction));
        await tester.pumpAndSettle();

        expect(rawText(), "MARIE-JEANNE enters.\n\nMARIE-JEANNE speaks.\n");
      },
    );

    testWidgets('Replace all goes through the confirm dialog and replaces every match', (
      tester,
    ) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
        "Line one.\n\nLine two.\n\nLine three.\n",
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final barTextFields = find.descendant(
        of: find.byType(OcptEditorFindBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(barTextFields.first, "Line");
      await tester.pumpAndSettle();
      await tester.enterText(barTextFields.last, "Scene");
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);
      await tester.tap(find.text(tr.editorReplaceAllAction));
      await tester.pumpAndSettle();

      // The confirm dialog is on screen, naming the 3 matches, and nothing has been replaced yet.
      expect(find.text(tr.editorReplaceAllConfirmTitle), findsOneWidget);
      var rawText = tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(OcptEditorSourceField),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text;
      expect(rawText, contains("Line one."));

      // Both the bar's own "Replace all" button and the dialog's confirm button share the same
      // label; the dialog's is the last one on screen.
      await tester.tap(find.text(tr.editorReplaceAllConfirmAction).last);
      await tester.pumpAndSettle();

      rawText = tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(OcptEditorSourceField),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text;
      expect(rawText, "Scene one.\n\nScene two.\n\nScene three.\n");
    });

    testWidgets('withheld entirely under a read-only preview', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final version = await projectsManager.createProjectVersion(name: "v1", note: "note");
      expect(version, isNotNull);

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final bloc = BlocProvider.of<OcptEditorBloc>(tester.element(find.byType(OcptWorkspaceShell)));
      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      // Ctrl+F does nothing under a preview: there is no editing surface to search.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorFindBar), findsNothing);

      // The ⋮ menu carries neither entry either.
      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();
      expect(find.text(tr.editorFindAction), findsNothing);
      expect(find.text(tr.editorFindAndReplaceAction), findsNothing);
    });
  });

  group('find/replace (styled mode)', () {
    /// The first node of the current document whose display text contains [substring], re-read
    /// fresh every call: a text replacement swaps a `ParagraphNode` for a new instance, so a
    /// reference captured before the edit would go stale.
    ParagraphNode nodeContaining(String substring) {
      final document = SuperEditorInspector.findDocument()!;
      for (var i = 0; i < document.nodeCount; i++) {
        final node = document.getNodeAt(i)! as ParagraphNode;
        if (node.text.toPlainText().contains(substring)) {
          return node;
        }
      }
      fail('no node contains "$substring"');
    }

    testWidgets('Replace changes the matched text — not gated on raw mode', (tester) async {
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final firstNodeId = SuperEditorInspector.findDocument()!.getNodeAt(0)!.id;
      await tester.placeCaretInParagraph(firstNodeId, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final barTextFields = find.descendant(
        of: find.byType(OcptEditorFindBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(barTextFields.first, "Sunday");
      await tester.pumpAndSettle();
      expect(find.text("1/1"), findsOneWidget);

      await tester.enterText(barTextFields.last, "Monday");
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);
      await tester.tap(find.text(tr.editorReplaceAction));
      await tester.pumpAndSettle();

      expect(nodeContaining("Monday").text.toPlainText(), "Smells like Monday.");
    });

    testWidgets('Replace all goes through the confirm dialog, exactly like raw mode', (
      tester,
    ) async {
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final firstNodeId = SuperEditorInspector.findDocument()!.getNodeAt(0)!.id;
      await tester.placeCaretInParagraph(firstNodeId, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final barTextFields = find.descendant(
        of: find.byType(OcptEditorFindBar),
        matching: find.byType(TextField),
      );
      // "the" (a standalone word inside "Something moves in the dark.") is the sample script's
      // only occurrence of that substring — nothing in it reads "the" inside a longer word.
      await tester.enterText(barTextFields.first, "the");
      await tester.pumpAndSettle();
      expect(find.text("1/1"), findsOneWidget);
      await tester.enterText(barTextFields.last, "a");
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);
      await tester.tap(find.text(tr.editorReplaceAllAction));
      await tester.pumpAndSettle();

      // The confirm dialog is on screen, and nothing has been replaced yet.
      expect(find.text(tr.editorReplaceAllConfirmTitle), findsOneWidget);
      expect(nodeContaining("in the dark").text.toPlainText(), "Something moves in the dark.");

      // Both the bar's own "Replace all" button and the dialog's confirm button share the same
      // label; the dialog's is the last one on screen.
      await tester.tap(find.text(tr.editorReplaceAllConfirmAction).last);
      await tester.pumpAndSettle();

      expect(nodeContaining("in a dark").text.toPlainText(), "Something moves in a dark.");
    });
  });

  group('undo/redo (⋮ menu)', () {
    /// Lets the raw field's own undo history record what it holds: `UndoHistory` pushes onto its
    /// stack through a 500 ms throttle, and a `pumpAndSettle` alone only advances the clock while
    /// frames stay scheduled, which is far less than that.
    Future<void> settleUndoThrottle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    /// Opens the toolbar's `⋮` menu and settles, so a test can read what it currently offers.
    Future<void> openOverflowMenu(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();
    }

    /// The raw source field's current text.
    String rawText(WidgetTester tester) => tester
        .widget<TextField>(
          find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
        )
        .controller!
        .text;

    testWidgets('raw mode: withheld until there is an edit, then takes it back and puts it back', (
      tester,
    ) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

      // Placing the caret is what makes the loaded text the field's own first history entry;
      // nothing has been *edited* yet, so neither entry is offered — withheld, not disabled.
      await tester.tap(find.byType(OcptEditorSourceField));
      await settleUndoThrottle(tester);

      await openOverflowMenu(tester);
      expect(find.text(tr.editorUndoAction), findsNothing);
      expect(find.text(tr.editorRedoAction), findsNothing);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
        "$sampleText\nA fresh action line.",
      );
      await settleUndoThrottle(tester);
      expect(rawText(tester), contains("A fresh action line."));

      // `Undo` is offered now, stating its own shortcut, and takes the edit back.
      await openOverflowMenu(tester);
      expect(find.text('Ctrl+Z'), findsOneWidget);
      await tester.tap(find.text(tr.editorUndoAction));
      await tester.pumpAndSettle();

      expect(rawText(tester), sampleText);

      // `Redo` is offered in turn, and puts the very same edit back.
      await openOverflowMenu(tester);
      expect(find.text('Ctrl+Shift+Z'), findsOneWidget);
      await tester.tap(find.text(tr.editorRedoAction));
      await tester.pumpAndSettle();

      expect(rawText(tester), contains("A fresh action line."));
    });

    testWidgets("raw mode: Ctrl+Z still reaches the field's own history", (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OcptEditorSourceField));
      await settleUndoThrottle(tester);

      await tester.enterText(
        find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
        "$sampleText\nA fresh action line.",
      );
      await settleUndoThrottle(tester);

      // The page's own `Shortcuts` claims neither Ctrl+Z nor Ctrl+Shift+Z, so both keep reaching
      // `EditableText`'s own `UndoHistory` — this is the regression guard against a future
      // page-level shortcut silently stealing them.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(rawText(tester), sampleText);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(rawText(tester), contains("A fresh action line."));
    });

    testWidgets('styled mode: withheld on a freshly loaded screenplay, then undoes the gesture', (
      tester,
    ) async {
      await propertiesManager.editorMode.store(OcptEditorMode.styled);
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

      // Mounting the styled editor numbers the scene headings on its own; that normalization is
      // not a gesture of the writer's, so the menu has nothing to offer yet.
      await openOverflowMenu(tester);
      expect(find.text(tr.editorUndoAction), findsNothing);
      expect(find.text(tr.editorRedoAction), findsNothing);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final lastNode = document.getNodeAt(document.nodeCount - 1)! as ParagraphNode;
      final originalText = lastNode.text.toPlainText();
      await tester.placeCaretInParagraph(lastNode.id, originalText.length);
      await tester.typeImeText(" Indeed.");
      await tester.pumpAndSettle();

      /// The current text of the node the edit was made in, re-read fresh: a text edit swaps the
      /// `ParagraphNode` for a new instance, so the reference above goes stale.
      String editedNodeText() {
        final document = SuperEditorInspector.findDocument()!;
        return (document.getNodeById(lastNode.id)! as ParagraphNode).text.toPlainText();
      }

      expect(editedNodeText(), "$originalText Indeed.");

      await openOverflowMenu(tester);
      expect(find.text('Ctrl+Z'), findsOneWidget);
      await tester.tap(find.text(tr.editorUndoAction));
      await tester.pumpAndSettle();

      expect(editedNodeText(), originalText);

      await openOverflowMenu(tester);
      expect(find.text('Ctrl+Shift+Z'), findsOneWidget);
      await tester.tap(find.text(tr.editorRedoAction));
      await tester.pumpAndSettle();

      expect(editedNodeText(), "$originalText Indeed.");
    });

    testWidgets('withheld entirely under a read-only preview', (tester) async {
      final version = await projectsManager.createProjectVersion(name: "v1", note: "note");
      expect(version, isNotNull);

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      // Something to take back exists before the preview is entered, so the entries' absence
      // below is the preview's doing rather than an empty history's.
      await tester.tap(find.byType(OcptEditorSourceField));
      await settleUndoThrottle(tester);
      await tester.enterText(
        find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
        "$sampleText\nA fresh action line.",
      );
      await settleUndoThrottle(tester);

      final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));
      await openOverflowMenu(tester);
      expect(find.text(tr.editorUndoAction), findsOneWidget);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();

      final bloc = BlocProvider.of<OcptEditorBloc>(tester.element(find.byType(OcptWorkspaceShell)));
      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
      await tester.pumpAndSettle();

      // There is no editing surface at all under a preview, so there is nothing to undo *into*.
      await openOverflowMenu(tester);
      expect(find.text(tr.editorUndoAction), findsNothing);
      expect(find.text(tr.editorRedoAction), findsNothing);
    });
  });
}
