// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_overflow_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'editor_page_test_doubles.dart';

/// An export manager whose [exportFountain] is stubbed and records the episode tag it was handed,
/// so a test can tell what `OcptEditorPage` itself computed and dispatched — the page's own
/// `_episodeExportTag`, not the bloc's own scoped episode, is under test here.
class _RecordingExportManager extends OcptExportManager {
  /// Class constructor
  _RecordingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// The episode tag of the last [exportFountain] call.
  String? lastExportedEpisodeTag;

  @override
  Future<OcptExportOutcome?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedEpisodeTag = episodeTag;
    return OcptExportSaved("/tmp/$projectName.fountain");
  }
}

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

  /// Swaps the registered `OcptExportManager` for [manager] for the rest of the current test,
  /// restoring the shared real one afterward — `OcptEditorBloc` resolves its export manager from
  /// `globalGetIt()` (it's built by `OcptEditorPage` itself, with no test seam of its own), so this
  /// is what lets a test observe what a real export call was handed.
  void useExportManager(OcptExportManager manager) {
    final managers = OcptGlobalManager.instance.managers;
    final previous = managers.get<OcptExportManager>();
    managers
      // `unregister` returns `FutureOr` only because it may await a disposing function; none is
      // registered here, so it never actually returns anything to wait for.
      // ignore: discarded_futures
      ..unregister<OcptExportManager>()
      ..registerSingleton<OcptExportManager>(manager);
    addTearDown(() {
      managers
        // See the identical `unregister` call above for why this is safe to leave un-awaited.
        // ignore: discarded_futures
        ..unregister<OcptExportManager>()
        ..registerSingleton<OcptExportManager>(previous);
    });
  }

  testWidgets("Ctrl+Shift+M also toggles the editing mode when the styled editor has focus", (
    tester,
  ) async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    await pumpEditorPage(tester);
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
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
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

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final document = SuperEditorInspector.findDocument()!;
      final firstNodeId = document.getNodeAt(0)!.id;
      await tester.placeCaretInParagraph(firstNodeId, 0);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
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

  group('the compact-width toolbar (below ocptCompactWidthBreakpoint, above the phone width)', () {
    /// Pumps [OcptEditorPage] at a width inside the compact range but above the phone one — the
    /// exact window the owner reported the format controls overflowing the toolbar's right side at
    /// (601-652 px).
    Future<void> pumpAtCompactWidth(WidgetTester tester) async {
      tester.view.physicalSize = const Size(620, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithLocalization(const OcptEditorPage()));
    }

    testWidgets(
      'folds the format controls into a single ⋮ menu, in place of the inline dropdown and '
      'toggle buttons, and draws no overflow',
      (tester) async {
        await propertiesManager.editorMode.store(OcptEditorMode.styled);

        // See the identical guard in "a phone width forces the styled editor…" above: mounting the
        // styled editor at a forced width and then resizing the view back out in this test's own
        // `resetPhysicalSize` teardown crashes its Android touch interactor (the default target
        // platform under `flutter test`) unless the desktop one is forced instead.
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        try {
          await pumpAtCompactWidth(tester);
          await tester.pumpAndSettle();
          // One more settle past the styled editor's own reclassify debounce — see the identical
          // comment in "a phone width forces the styled editor…" above for why this is needed.
          await tester.pump(const Duration(milliseconds: 200));

          expect(find.byType(OcptEditorFormatControls), findsNothing);
          expect(find.byType(OcptEditorFormatOverflowMenu), findsOneWidget);
          expect(find.byType(OcptEditorBlockTypeDropdown), findsNothing);

          final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));
          expect(find.byTooltip(tr.editorFormatMenuTooltip), findsOneWidget);

          // The styled/raw mode toggle stays reachable beside the folded format menu.
          expect(find.byTooltip(tr.editorSwitchToRawModeTooltip), findsOneWidget);

          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'the folded format menu exposes the same block-type submenu and bold toggle as the inline '
      'controls, wired to the very same controller',
      (tester) async {
        await propertiesManager.editorMode.store(OcptEditorMode.styled);

        // See the identical guard in the test above.
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        try {
          await pumpAtCompactWidth(tester);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 200));

          final document = SuperEditorInspector.findDocument()!;
          final firstNodeId = document.getNodeAt(0)!.id;
          await tester.placeCaretInParagraph(firstNodeId, 0);
          await tester.pumpAndSettle();

          final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

          // The block-type submenu changes the caret's block type exactly like the inline dropdown
          // does ("using the toolbar's dropdown changes the caret's block type…" above).
          await tester.tap(find.byTooltip(tr.editorFormatMenuTooltip));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tr.editorContextMenuBlockTypeSubmenu));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tr.editorBlockTypeTransition));
          await tester.pumpAndSettle();

          final node = document.getNodeAt(0)! as ParagraphNode;
          expect(
            OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")),
            FountainLineType.transition,
          );

          // Bold toggles the very same controller the inline row would — reading it back off the
          // live styled editor's own `styledController` is what proves the two widgets share one
          // flow rather than each carrying its own.
          final styledEditor = tester.widget<OcptStyledScreenplayEditor>(
            find.byType(OcptStyledScreenplayEditor),
          );
          final controller = styledEditor.styledController!;
          expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isFalse);

          await tester.tap(find.byTooltip(tr.editorFormatMenuTooltip));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tr.editorToggleBoldTooltip));
          await tester.pumpAndSettle();

          expect(controller.activeInlineStyles.contains(OcptInlineStyle.bold), isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'draws no right-side overflow in raw mode either, with the preview/syntax toggles still '
      'shown beside the folded format menu',
      (tester) async {
        // Raw mode (forced by this file's setUp) at a width still above the phone breakpoint keeps
        // the preview/syntax tab selectors in the toolbar (`_buildToolbarActions`'s own `isRawMode`
        // branch) beside the folded format menu — the exact combination the owner reported
        // overflowing before this fix.
        await pumpAtCompactWidth(tester);
        await tester.pumpAndSettle();

        final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));
        expect(find.byTooltip(tr.editorTogglePreviewTooltip), findsOneWidget);
        expect(find.byTooltip(tr.editorToggleSyntaxGuideTooltip), findsOneWidget);
        expect(find.byTooltip(tr.editorSwitchToStyledModeTooltip), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('the toolbar back button closes the project and navigates back', (tester) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    final backButton = find.byTooltip(tr.editorBackToProjectsTooltip);
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(projectsManager.currentProject, isNull);
    expect(routerManager.popped, isTrue);
  });

  testWidgets('the ⋮ menu opens and shows the import-and-replace action', (tester) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
    await tester.pumpAndSettle();

    // The two exports moved to the toolbar's own `Export` button; the ⋮ menu keeps the rest.
    expect(find.text(tr.editorImportAndReplaceAction), findsOneWidget);
    expect(find.text(tr.editorTogglePageSimulationAction), findsOneWidget);
  });

  testWidgets("the toolbar's Export button opens a panel listing the screenplay's two documents", (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

    await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.editorExportPanelTitle), findsOneWidget);
    expect(find.text(tr.editorExportFountainTitle), findsOneWidget);
    expect(find.text(tr.editorExportPdfTitle), findsOneWidget);
    expect(find.text(".fountain"), findsOneWidget);
    expect(find.text("PDF"), findsOneWidget);
  });

  testWidgets("picking the screenplay PDF card opens its own export options dialog", (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

    await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.editorExportPdfTitle));
    await tester.pumpAndSettle();

    // The panel closed (the card's own value was popped) and the PDF options dialog it hands off
    // to is the one now on screen.
    expect(find.text(tr.editorExportPanelTitle), findsNothing);
    expect(find.byType(OcptEditorExportPdfOptionsDialog), findsOneWidget);
  });

  testWidgets(
    "picking the Fountain card dispatches the export request directly, with no options dialog "
    "of its own",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.editorExportFountainTitle));
      await tester.pumpAndSettle();

      // The panel closed, unlike the PDF card, straight onto the editor with nothing else on
      // screen: `.fountain` opens no options dialog of its own, the export request going straight
      // through instead.
      expect(find.text(tr.editorExportPanelTitle), findsNothing);
      expect(find.byType(OcptEditorExportPdfOptionsDialog), findsNothing);
      expect(find.byType(OcptEditorPage), findsOneWidget);
    },
  );

  testWidgets(
    "a project holding one episode dispatches a null episode tag when exporting to Fountain",
    (tester) async {
      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.editorExportFountainTitle));
      await tester.pumpAndSettle();

      expect(exportManager.lastExportedEpisodeTag, isNull);
    },
  );

  testWidgets(
    "a project holding two episodes dispatches the selected one's tag when exporting to Fountain",
    (tester) async {
      final project = projectsManager.currentProject!;
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );

      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptEditorPage));
      final tr = Tr.of(context);

      // The workspace bloc lands on the first episode by default; select the second one so the
      // exported tag can be told apart from what a single-episode project would produce.
      context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.editorExportFountainTitle));
      await tester.pumpAndSettle();

      expect(exportManager.lastExportedEpisodeTag, tr.workspaceEpisodeTag(2));
    },
  );

  testWidgets('toggling page simulation from the ⋮ menu flips it and persists the new value', (
    tester,
  ) async {
    await propertiesManager.isPageSimulationEnabled.store(true);
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
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
  });

  testWidgets('toggling scene numbers from the ⋮ menu flips it and persists the new value', (
    tester,
  ) async {
    await propertiesManager.styledSceneNumbersVisible.store(true);
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptEditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text(tr.editorToggleSceneNumbersAction),
        matching: find.byType(CheckedPopupMenuItem<void>),
      ),
    );
    await tester.pumpAndSettle();

    expect(await propertiesManager.styledSceneNumbersVisible.load(), isFalse);
  });

  testWidgets("scrolling the styled editor with page simulation on does not move the toolbar", (
    tester,
  ) async {
    // Wide enough for the full page-simulation width (`pageWidth` reaches ~975 logical pixels
    // at US Letter) and tall enough that the long document below genuinely overflows the
    // viewport, giving real distance to scroll.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await propertiesManager.editorMode.store(OcptEditorMode.styled);
    await propertiesManager.isPageSimulationEnabled.store(true);

    final longText = List.generate(
      80,
      (index) => "Action line number $index goes here.",
    ).join("\n\n");
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: longText,
      snapshotReason: OcptSnapshotReason.manual,
    );

    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);

    // The styled editor's own scrollable (via `_pageScrollController`) must be the only
    // `Scrollable` in the tree: no ancestor `Scrollable` should exist for a wheel scroll to
    // leak into and move a sibling widget (the toolbar) instead.
    expect(find.byType(Scrollable), findsOneWidget);
    final scrollableState = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollableState.position.pixels, 0);

    final toolbarTopBefore = tester.getTopLeft(find.byType(OcptWorkspaceToolbar));
    final editorCenter = tester.getCenter(find.byType(SuperEditor));

    final testPointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(testPointer.addPointer(location: editorCenter));
    await tester.sendEventToBinding(testPointer.scroll(const Offset(0, 400)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The scroll must have actually happened (otherwise the "toolbar didn't move" assertion
    // below would be vacuously true).
    expect(scrollableState.position.pixels, greaterThan(0));

    final toolbarTopAfter = tester.getTopLeft(find.byType(OcptWorkspaceToolbar));
    expect(
      toolbarTopAfter,
      toolbarTopBefore,
      reason: "toolbar must not move when the editor scrolls",
    );
  });

  testWidgets(
    "a previewed version is shown read-only: no editor, no save, no entry that would rewrite it",
    (tester) async {
      // Wide enough for the whole toolbar, so the ⋮ menu and the chrome around it are all built.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final version = await projectsManager.createProjectVersion(
        name: "v1",
        note: "Before the rewrite",
      );
      expect(version, isNotNull);

      // The working copy moves on, so what the preview shows and what the project holds differ.
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "EXT. ROOFTOP - DAWN\n\nThe rewrite.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptEditorPage)));

      // The working copy is what the editor edits, until a version is previewed.
      expect(find.byType(OcptEditorSourceField), findsOneWidget);
      expect(find.text(tr.workspaceReadOnlyPill), findsNothing);

      final bloc = BlocProvider.of<OcptEditorBloc>(tester.element(find.byType(OcptWorkspaceShell)));
      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: version!.id));
      await tester.pumpAndSettle();

      // Decision 7: the centre is the formatted preview of the version, not an editor of any kind.
      expect(find.byType(OcptEditorSourceField), findsNothing);
      expect(find.byType(OcptStyledScreenplayEditor), findsNothing);
      expect(find.byType(OcptEditorPreview), findsOneWidget);
      expect(find.text("INT. KITCHEN - DAY", findRichText: true), findsWidgets);
      expect(find.text("The rewrite.", findRichText: true), findsNothing);

      // The shell says so, and has nothing left to save or to open project settings from.
      expect(find.text(tr.workspaceReadOnlyPill), findsOneWidget);
      expect(find.byTooltip(tr.editorSaveTooltip), findsNothing);
      expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
      expect(find.byType(OcptWorkspaceReadOnlyBanner), findsOneWidget);
      expect(find.textContaining("Before the rewrite"), findsOneWidget);

      // The export button stays offered — an export only ever reads — while the ⋮ menu keeps only
      // what reads the screenplay and drops what would rewrite it.
      expect(find.byTooltip(tr.workspaceExportTooltip), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<void>));
      await tester.pumpAndSettle();

      expect(find.text(tr.editorImportAndReplaceAction), findsNothing);
      expect(find.text(tr.editorPageSetupAction), findsNothing);
      expect(find.text(tr.editorTitlePageAction), findsNothing);

      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();

      // The banner is the way back to the working copy, which is editable again.
      await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
      await tester.pumpAndSettle();

      expect(find.byType(OcptWorkspaceReadOnlyBanner), findsNothing);
      expect(find.text(tr.workspaceReadOnlyPill), findsNothing);
      expect(find.byType(OcptEditorSourceField), findsOneWidget);
      expect(find.byTooltip(tr.editorSaveTooltip), findsOneWidget);
    },
  );
}
