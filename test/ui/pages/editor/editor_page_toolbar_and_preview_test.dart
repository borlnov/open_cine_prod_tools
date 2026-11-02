// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/foundation.dart';
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
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_block.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_syntax_guide_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_divider.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'editor_page_test_doubles.dart';

/// Run the tests of the editor page toolbar and preview.
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
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: sampleText,
      snapshotReason: OcptSnapshotReason.manual,
    );
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

  testWidgets('renders the toolbar, the source text, the scene panel and the paper preview', (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(OcptWorkspaceToolbar), findsOneWidget);
    expect(find.text("My Movie"), findsOneWidget);

    final textField = tester.widget<TextField>(
      find.descendant(of: find.byType(OcptEditorSourceField), matching: find.byType(TextField)),
    );
    expect(textField.controller?.text, sampleText);

    // The panel and the preview both show the heading uppercased, even though the source line is
    // lowercase: findRichText also matches the preview's styled text.
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
    expect(find.byType(OcptEditorPreview), findsOneWidget);
    expect(find.text("INT. KITCHEN - DAY", findRichText: true), findsNWidgets(2));
    expect(find.text("Smells like Sunday.", findRichText: true), findsOneWidget);

    // The status bar reflects the sample's two scenes and one speaking character (SARAH), once
    // the parse and statistics debounces have both cleared.
    final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));
    // The toolbar names the active mode, and carries the shell's own chrome: both dock toggles
    // and the save action.
    expect(find.text(tr.workspaceModeLabelScreenplay), findsOneWidget);
    expect(find.byTooltip(tr.workspaceToggleLeftDockTooltip), findsOneWidget);
    expect(find.byTooltip(tr.workspaceToggleRightDockTooltip), findsOneWidget);
    expect(find.byTooltip(tr.editorSaveTooltip), findsOneWidget);

    expect(find.byType(OcptWorkspaceStatusBar), findsOneWidget);
    expect(find.textContaining(tr.editorStatsScenes(2)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsCharacters(1)), findsOneWidget);
  });

  testWidgets('the preview typesets character and dialogue at their screenplay indents', (
    tester,
  ) async {
    await pumpEditorPage(tester);
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
    await pumpEditorPage(tester);
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
    expect(textField.controller?.selection.baseOffset, sampleText.indexOf("EXT. GARDEN - NIGHT"));
  });

  testWidgets(
    "clicking a far scene in raw mode lands its heading a third of the way down, even past "
    "wrapped paragraphs",
    (tester) async {
      // Every action paragraph wraps over several visual lines of the source field: counting
      // newlines would put the target thousands of pixels short of where the heading really is.
      final buffer = StringBuffer();
      for (var scene = 1; scene <= 20; scene++) {
        buffer.write("INT. ROOM $scene - DAY\n\n${"Something happens in room $scene. " * 20}\n\n");
      }
      final text = buffer.toString();
      final project = projectsManager.currentProject!;
      await tester.runAsync(
        () => projectsManager.screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        ),
      );

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final heading = find.descendant(
        of: find.byType(OcptEditorScenePanel),
        matching: find.text("INT. ROOM 15 - DAY"),
      );
      await tester.scrollUntilVisible(
        heading,
        100,
        scrollable: find
            .descendant(of: find.byType(OcptEditorScenePanel), matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(heading);
      await tester.pumpAndSettle();

      final editableText = find.descendant(
        of: find.byType(OcptEditorSourceField),
        matching: find.byType(EditableText),
      );
      final renderEditable = tester.state<EditableTextState>(editableText).renderEditable;
      final caret = renderEditable.getLocalRectForCaret(
        TextPosition(offset: text.indexOf("INT. ROOM 15 - DAY")),
      );
      final caretTop = renderEditable.localToGlobal(caret.topLeft).dy;
      final field = tester.getRect(editableText);
      expect((caretTop - field.top) / field.height, inInclusiveRange(0.2, 0.45));
    },
  );

  testWidgets('the preview and the scene panel can be hidden from the toolbar', (tester) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.editorTogglePreviewTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorPreview), findsNothing);

    await tester.tap(find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorScenePanel), findsNothing);

    // Toggling again brings both back.
    await tester.tap(find.byTooltip(tr.editorTogglePreviewTooltip));
    await tester.tap(find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorPreview), findsOneWidget);
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
  });

  testWidgets(
    "the toolbar's preview and syntax buttons show as selected only while their own tab is "
    "active, and clicking the other tab switches the dock to it",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      IconButton previewButton() => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tr.editorTogglePreviewTooltip),
          matching: find.byType(IconButton),
        ),
      );
      IconButton syntaxButton() => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tr.editorToggleSyntaxGuideTooltip),
          matching: find.byType(IconButton),
        ),
      );

      // The preview tab is open by default (raw mode, forced by this file's setUp).
      expect(previewButton().isSelected, isTrue);
      expect(syntaxButton().isSelected, isFalse);
      expect(find.byType(OcptEditorPreview), findsOneWidget);

      await tester.tap(find.byTooltip(tr.editorToggleSyntaxGuideTooltip));
      await tester.pumpAndSettle();

      expect(previewButton().isSelected, isFalse);
      expect(syntaxButton().isSelected, isTrue);
      expect(find.byType(OcptEditorPreview), findsNothing);
      expect(find.byType(OcptEditorSyntaxGuidePanel), findsOneWidget);
    },
  );

  testWidgets(
    "clicking the active tab's own toolbar button closes the dock, and the dock's own × does too",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      expect(find.byType(OcptEditorRightDock), findsOneWidget);

      await tester.tap(find.byTooltip(tr.editorTogglePreviewTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorRightDock), findsNothing);

      await tester.tap(find.byTooltip(tr.editorTogglePreviewTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorRightDock), findsOneWidget);

      await tester.tap(find.byTooltip(tr.editorRightDockCloseTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorRightDock), findsNothing);
    },
  );

  testWidgets('the syntax guide panel stays available in styled mode, without its toolbar button', (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(tr.editorToggleSyntaxGuideTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorSyntaxGuidePanel), findsOneWidget);

    await tester.tap(find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await tester.pumpAndSettle();
    // Mounting the styled editor auto-numbers every scene heading, which reports the corrected
    // text to the bloc and restarts its 150 ms parse debounce — longer than `pumpAndSettle`'s
    // own 100 ms step, so it needs this extra pump to be let go of before the test ends.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Styled mode still offers the syntax tab (only the preview tab is mode-gated): the dock
    // stays open on the same guide panel, reachable from the dock's own tab row alone — the
    // toolbar carries no tab shortcut at all in that mode.
    expect(find.byType(OcptEditorSyntaxGuidePanel), findsOneWidget);
    expect(find.byTooltip(tr.editorToggleSyntaxGuideTooltip), findsNothing);
    expect(find.byTooltip(tr.editorTogglePreviewTooltip), findsNothing);
  });

  testWidgets(
    "the toolbar's right dock toggle closes the dock and reopens it on the tab it showed",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      await tester.tap(find.byTooltip(tr.editorToggleSyntaxGuideTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorSyntaxGuidePanel), findsOneWidget);

      await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorRightDock), findsNothing);

      await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(OcptEditorSyntaxGuidePanel), findsOneWidget);
    },
  );

  testWidgets("the toolbar's dock toggles read as selected only while their dock is open", (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    IconButton toggleOf(String tooltip) => tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)),
    );

    // Both docks are open when the editor opens (scene panel visible, preview tab active).
    expect(toggleOf(tr.workspaceToggleLeftDockTooltip).isSelected, isTrue);
    expect(toggleOf(tr.workspaceToggleRightDockTooltip).isSelected, isTrue);

    await tester.tap(find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await tester.pumpAndSettle();

    expect(toggleOf(tr.workspaceToggleLeftDockTooltip).isSelected, isFalse);
    expect(toggleOf(tr.workspaceToggleRightDockTooltip).isSelected, isFalse);
  });

  testWidgets('a dock closed by hand in raw mode stays closed across a raw/styled/raw round trip', (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    expect(find.byType(OcptEditorPreview), findsOneWidget);

    await tester.tap(find.byTooltip(tr.editorRightDockCloseTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorRightDock), findsNothing);

    await tester.tap(find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptEditorRightDock), findsNothing);

    await tester.tap(find.byTooltip(tr.editorSwitchToRawModeTooltip));
    await tester.pumpAndSettle();
    // Explicitly closed, so the mode round trip never reopens it, unlike the default dance.
    expect(find.byType(OcptEditorRightDock), findsNothing);
    expect(find.byType(OcptEditorPreview), findsNothing);
  });

  testWidgets(
    "dragging the left divider live-resizes the scene panel dock without touching the bloc "
    "state, and releasing dispatches exactly one event that persists the final fraction",
    (tester) async {
      // Wide enough that the centre floor never engages: at the default 800x600 test window, the
      // right dock is already squeezed down by the floor, which would otherwise silently absorb
      // the drag's effect on width (see the identical setup in the "scrolling..." test below).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await propertiesManager.editorLeftDockFraction.delete();
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final dockFinder = find.byType(OcptWorkspaceDock).first;
      final widthBefore = tester.getSize(dockFinder).width;

      final blocContext = tester.element(find.byType(OcptWorkspaceToolbar));
      final bloc = blocContext.read<OcptEditorBloc>();
      final fractionBefore = bloc.state.leftDockFraction;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(OcptWorkspaceDockDivider).first),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      // Mid-drag: the panel already grew, but the bloc's own state (and the persisted value)
      // haven't moved yet — only the live `OcptWorkspaceDockLayoutController` did.
      final widthDuringDrag = tester.getSize(dockFinder).width;
      expect(widthDuringDrag, greaterThan(widthBefore));
      expect(bloc.state.leftDockFraction, fractionBefore);
      expect(await propertiesManager.editorLeftDockFraction.load(), isNull);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(bloc.state.leftDockFraction, greaterThan(fractionBefore));
      expect(
        await propertiesManager.editorLeftDockFraction.load(),
        closeTo(bloc.state.leftDockFraction, 0.0001),
      );
    },
  );

  testWidgets("dragging the right divider left grows the preview dock", (tester) async {
    // See the identical setup in the left-divider test above: wide enough that the centre floor
    // never engages and silently absorbs the drag's effect on width.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final dockFinder = find.byType(OcptWorkspaceDock).last;
    final widthBefore = tester.getSize(dockFinder).width;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(OcptWorkspaceDockDivider).last),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getSize(dockFinder).width, greaterThan(widthBefore));
  });

  testWidgets('"Reset panel layout" restores both dock fractions to their defaults', (
    tester,
  ) async {
    await propertiesManager.editorLeftDockFraction.store(0.3);
    await propertiesManager.editorRightDockFraction.store(0.6);

    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.editorResetPanelLayoutAction));
    await tester.pumpAndSettle();

    expect(
      await propertiesManager.editorLeftDockFraction.load(),
      OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(
      await propertiesManager.editorRightDockFraction.load(),
      OcptWorkspaceDock.rightDefaultFraction,
    );
  });

  testWidgets(
    "the mode toggle switches from raw to styled editing (no preview panel) and persists the "
    "preference, and back",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      // Starts in raw mode (forced by this file's setUp): the raw source field and its preview
      // are shown, the styled editor isn't.
      expect(find.byType(OcptEditorSourceField), findsOneWidget);
      expect(find.byType(OcptEditorPreview), findsOneWidget);
      expect(find.byType(OcptStyledScreenplayEditor), findsNothing);

      final context = tester.element(find.byType(OcptEditorPage));
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
      // The dock re-opens on the preview tab it was auto-closed on: nothing here explicitly
      // closed it, so the raw/styled dance restores it rather than leaving it closed.
      expect(find.byType(OcptEditorPreview), findsOneWidget);
    },
  );

  testWidgets(
    "a phone width forces the styled editor even when raw mode and page simulation are the "
    "persisted preference",
    (tester) async {
      // The persisted preference is deliberately the opposite of what a phone width should show:
      // raw mode, with page simulation on. Neither is touched by the override (see
      // `_EditorViewState._liveMode`) — only what actually renders is.
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await propertiesManager.isPageSimulationEnabled.store(true);

      // `flutter test` forces `defaultTargetPlatform` to `TargetPlatform.android` (see
      // `ocpt_styled_screenplay_editor_spell_check_and_context_menu_test.dart`'s own
      // `_testWidgetsAsDesktop`), which makes `SuperEditor` build its Android touch interactor
      // instead of the desktop `DocumentMouseInteractor` this app actually ships with. That
      // interactor's own handle/ magnifier machinery reaches `View.of` from a `didChangeMetrics`
      // callback, which crashes once this test's own `resetPhysicalSize` teardown changes the
      // view's metrics while the styled editor this test forces onto the phone-width screen is
      // still mounted — every other test that merely switches to styled mode on a stable,
      // desktop-sized view never resizes out from under it, so it never has occasion to hit this.
      // Set and reset from inside the test body, in a `try`/`finally`, not through `addTearDown`:
      // `testWidgets` asserts every foundation debug variable is back to its default before the
      // `test` package's own `tearDown` queue runs, so resetting it there fires that assertion too
      // late.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        // The exact top of the phone range (`ocptIsPhoneWidth` is inclusive), rather than a
        // narrower, more phone-typical width: this fixture's project holds a single episode, so
        // the toolbar draws its `Add an episode…` button, and that button's own ellipsis-capable
        // label measures a few pixels wider on the very first laid-out frame than it settles to a
        // frame later — reproducible in plain (unforced) raw mode too, so it is a pre-existing
        // fragility of that button at a narrow width, unrelated to what this test is about. The
        // width here stays comfortably inside `ocptIsPhoneWidth` while giving that frame slack.
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrapWithLocalization(const OcptEditorPage()));
        await tester.pumpAndSettle();
        // One more settle past the styled editor's own 120ms reclassify debounce: mounting it
        // over this fixture's headingless scene heading assigns it a number on load
        // (`sceneNumberNormalizationRequests`), which itself is a document change and restarts
        // that debounce once more. `pumpAndSettle` only waits out scheduled *frames*, not a timer
        // that hasn't fired yet, so without this a still-pending one fires later, during this
        // test's own teardown, and `_OcptStyledScreenplayEditorState.deactivate`'s flush then
        // reaches for a `BuildContext` the tree has already started tearing down.
        await tester.pump(const Duration(milliseconds: 200));

        // Neither raw source nor the read-only preview is the surface on a phone: the styled
        // editor is, editable, with page simulation forced off.
        expect(find.byType(OcptEditorSourceField), findsNothing);
        expect(find.byType(OcptEditorPreview), findsNothing);
        expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);

        final styledEditor = tester.widget<OcptStyledScreenplayEditor>(
          find.byType(OcptStyledScreenplayEditor),
        );
        expect(styledEditor.isPageSimulationEnabled, isFalse);
        expect(styledEditor.isCompact, isTrue);

        // The toolbar's own toggle still states the persisted preference (raw, so "switch to
        // styled" is what it offers) rather than the compact-width override: widening the window
        // back out is what would actually apply it.
        final context = tester.element(find.byType(OcptEditorPage));
        final tr = Tr.of(context);
        expect(find.byTooltip(tr.editorSwitchToStyledModeTooltip), findsOneWidget);
        expect(await propertiesManager.editorMode.load(), OcptEditorMode.raw);
        expect(await propertiesManager.isPageSimulationEnabled.load(), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets("an edit made in raw mode survives switching to styled mode", (tester) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final textFieldFinder = find.descendant(
      of: find.byType(OcptEditorSourceField),
      matching: find.byType(TextField),
    );
    await tester.enterText(textFieldFinder, "$sampleText\nA fresh action line.");
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);
    await tester.tap(find.byTooltip(tr.editorSwitchToStyledModeTooltip));
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    final lastNode = document.getNodeAt(document.nodeCount - 1)! as ParagraphNode;
    expect(lastNode.text.toPlainText(), "A fresh action line.");
  });

  testWidgets("an edit made in styled mode survives switching back to raw mode", (tester) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    final lastNode = document.getNodeAt(document.nodeCount - 1)! as ParagraphNode;
    await tester.placeCaretInParagraph(lastNode.id, lastNode.text.toPlainText().length);
    await tester.typeImeText(" indeed.");
    // `typeImeText` already settles fully after every character it sends (see the doc comment on
    // the equivalent call in
    // `ocpt_styled_screenplay_editor_spell_check_and_context_menu_test.dart`), draining the
    // sync/parse/ autosave debounces along the way; this test only cares that the edit survives a
    // mode switch, not about the flush-on-removal path itself (see the dedicated test below for
    // that).
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
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
      await pumpEditorPage(tester);
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

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);
      // Removing the styled editor from the tree is what runs
      // `_OcptStyledScreenplayEditorState.deactivate()`; in this page test (no live GoRouter
      // under `RecordingRouterManager`) tapping the back button doesn't itself unmount the page,
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
      // forcing marker once locked as one, and a character cue is always uppercased. If
      // `deactivate()` hadn't flushed the still-pending sync before `dispose()` cancelled its
      // timer (which never fires once cancelled), this edit would have been lost entirely and the
      // line below would still read unprefixed and lowercase.
      expect(textField.controller?.text, contains("@SOMETHING MOVES IN THE DARK."));
    },
  );

  testWidgets("Ctrl+Shift+M also toggles the editing mode", (tester) async {
    await pumpEditorPage(tester);
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

    await pumpEditorPage(tester);
    await tester.pumpAndSettle();
    // Mounting the styled editor auto-numbers every scene heading (see `_syncSceneNumbers`),
    // which reports the corrected text to the bloc and restarts its (real, default-length) parse
    // debounce; `pumpAndSettle`'s own 100 ms step is shorter than that 150 ms debounce, so without
    // this extra pump the scene panel below would still be built from the *pre-correction* parse,
    // one scene heading's `#1#` tag short of the final offsets — exactly the kind of staleness
    // `OcptEditorBloc.defaultParseDebounce` is long enough to expose here.
    await tester.pump(const Duration(milliseconds: 200));
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
    // "EXT. GARDEN - NIGHT" in `sampleText`, making it the 5th node (index 4).
    const expectedNodeIndex = 4;
    final selection = SuperEditorInspector.findDocumentSelection();

    expect(selection, isNotNull);
    expect(document.getNodeIndexById(selection!.extent.nodeId), expectedNodeIndex);
  });

  testWidgets("Ctrl+S saves when the styled editor (not the page's own Shortcuts) has focus", (
    tester,
  ) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final document = SuperEditorInspector.findDocument()!;
    final firstNodeId = document.getNodeAt(0)!.id;
    await tester.placeCaretInParagraph(firstNodeId, 0);
    await tester.typeImeText("X");
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
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
}
