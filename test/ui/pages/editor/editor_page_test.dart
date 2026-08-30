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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_block.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_syntax_guide_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

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

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the export panel, the PDF options dialog) exactly as the
/// real `GoRouter.pop` would — both push onto the very same root `Navigator`.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records every call and then pops [_navigatorKey]'s own navigator,
/// so a dialog opened through `showDialog` genuinely closes: these page tests pump the editor page
/// directly, without a real GoRouter for `pop` to delegate to.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  /// Records the call, then pops the navigator's own topmost route (the dialog it was called
  /// from) instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests,
/// [ocptTheme]'s light theme so widgets reading its `OcptSpecificColors` extension (the raw-mode
/// preview's backdrop) resolve one, just like the real app always does, and [_navigatorKey] so
/// [_RecordingRouterManager.pop] can close a dialog opened through `showDialog`.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  // The real WorkspacePage always provides this ancestor: EditorPage now reads it for the
  // episode selector's episodes/selection, exactly as it already reads OcptEditorBloc.
  home: BlocProvider<OcptWorkspaceBloc>(
    create: (context) => OcptWorkspaceBloc(),
    child: child,
  ),
);

/// An export manager whose [exportFountain] is stubbed and records the episode tag it was handed,
/// so a test can tell what `EditorPage` itself computed and dispatched — the page's own
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

/// The miniature hunspell pair every test in this file spell-checks against, standing in for the
/// two ~1 MB dictionaries the real app bundles.
///
/// `EditorPage` builds its own `OcptEditorBloc` with no test seam, so that bloc resolves the real
/// `OcptSpellCheckManager` from `globalGetIt()` and asks it to load whichever language the project
/// fixture was created with — which, against the real assets, would mean parsing a megabyte of
/// dictionary in an isolate before any of these tests could get on with what they are actually
/// about. The manager's own `loadAsset` seam takes this instead: the file names it asks for are
/// ignored, the words below are all it ever knows, and nothing in this file asserts on a
/// misspelling anyway.
Future<String> _loadMiniatureDictionaryAsset(String assetKey) async =>
    assetKey.endsWith(".aff") ? "SET UTF-8\n" : "2\nthe\nscene\n";

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

    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    routerManager = _RecordingRouterManager();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(routerManager)
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      )
      ..registerSingleton<OcptSpellCheckManager>(
        OcptSpellCheckManager(loadAsset: _loadMiniatureDictionaryAsset),
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
    // on in the real app, which would push a `_sampleText`-sized document's nodes far enough down
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
      fountainText: _sampleText,
      snapshotReason: OcptSnapshotReason.manual,
    );
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  /// Pumps [EditorPage] on a desktop-sized surface.
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

    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
  }

  /// Swaps the registered `OcptExportManager` for [manager] for the rest of the current test,
  /// restoring the shared real one afterward — `OcptEditorBloc` resolves its export manager from
  /// `globalGetIt()` (it's built by `EditorPage` itself, with no test seam of its own), so this is
  /// what lets a test observe what a real export call was handed.
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
    expect(textField.controller?.text, _sampleText);

    // The panel and the preview both show the heading uppercased, even though the source line is
    // lowercase: findRichText also matches the preview's styled text.
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
    expect(find.byType(OcptEditorPreview), findsOneWidget);
    expect(find.text("INT. KITCHEN - DAY", findRichText: true), findsNWidgets(2));
    expect(find.text("Smells like Sunday.", findRichText: true), findsOneWidget);

    // The status bar reflects the sample's two scenes and one speaking character (SARAH), once
    // the parse and statistics debounces have both cleared.
    final tr = Tr.of(tester.element(find.byType(EditorPage)));
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
    expect(
      textField.controller?.selection.baseOffset,
      _sampleText.indexOf("EXT. GARDEN - NIGHT"),
    );
  });

  testWidgets('the preview and the scene panel can be hidden from the toolbar', (tester) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
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

  testWidgets(
    'the syntax guide panel stays available in styled mode, without its toolbar button',
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
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
    },
  );

  testWidgets(
    "the toolbar's right dock toggle closes the dock and reopens it on the tab it showed",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
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

    final context = tester.element(find.byType(EditorPage));
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

  testWidgets(
    'a dock closed by hand in raw mode stays closed across a raw/styled/raw round trip',
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
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
    },
  );

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

    final context = tester.element(find.byType(EditorPage));
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
      // `_EditorViewState._liveMode`/`docs/plans/tablet.md`) — only what actually renders is.
      await propertiesManager.editorMode.store(OcptEditorMode.raw);
      await propertiesManager.isPageSimulationEnabled.store(true);

      // `flutter test` forces `defaultTargetPlatform` to `TargetPlatform.android` (see
      // `ocpt_styled_screenplay_editor_test.dart`'s own `_testWidgetsAsDesktop`), which makes
      // `SuperEditor` build its Android touch interactor instead of the desktop
      // `DocumentMouseInteractor` this app actually ships with. That interactor's own handle/
      // magnifier machinery reaches `View.of` from a `didChangeMetrics` callback, which crashes
      // once this test's own `resetPhysicalSize` teardown changes the view's metrics while the
      // styled editor this test forces onto the phone-width screen is still mounted — every other
      // test that merely switches to styled mode on a stable, desktop-sized view never resizes out
      // from under it, so it never has occasion to hit this. Set and reset from inside the test
      // body, in a `try`/`finally`, not through `addTearDown`: `testWidgets` asserts every
      // foundation debug variable is back to its default before the `test` package's own
      // `tearDown` queue runs, so resetting it there fires that assertion too late.
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

        await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
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
        final context = tester.element(find.byType(EditorPage));
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
    await pumpEditorPage(tester);
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

    await pumpEditorPage(tester);
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

      await pumpEditorPage(tester);
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
    await pumpEditorPage(tester);
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

  testWidgets('the ⋮ menu opens and shows the import-and-replace action', (tester) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(EditorPage));
    final tr = Tr.of(context);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(context).showMenuTooltip));
    await tester.pumpAndSettle();

    // The two exports moved to the toolbar's own `Export` button; the ⋮ menu keeps the rest.
    expect(find.text(tr.editorImportAndReplaceAction), findsOneWidget);
    expect(find.text(tr.editorTogglePageSimulationAction), findsOneWidget);
  });

  testWidgets(
    "the toolbar's Export button opens a panel listing the screenplay's two documents",
    (tester) async {
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(EditorPage)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(find.text(tr.editorExportPanelTitle), findsOneWidget);
      expect(find.text(tr.editorExportFountainTitle), findsOneWidget);
      expect(find.text(tr.editorExportPdfTitle), findsOneWidget);
      expect(find.text(".fountain"), findsOneWidget);
      expect(find.text("PDF"), findsOneWidget);
    },
  );

  testWidgets("picking the screenplay PDF card opens its own export options dialog", (
    tester,
  ) async {
    await pumpEditorPage(tester);
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(EditorPage)));

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

      final tr = Tr.of(tester.element(find.byType(EditorPage)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.editorExportFountainTitle));
      await tester.pumpAndSettle();

      // The panel closed, unlike the PDF card, straight onto the editor with nothing else on
      // screen: `.fountain` opens no options dialog of its own, the export request going straight
      // through instead.
      expect(find.text(tr.editorExportPanelTitle), findsNothing);
      expect(find.byType(OcptEditorExportPdfOptionsDialog), findsNothing);
      expect(find.byType(EditorPage), findsOneWidget);
    },
  );

  testWidgets(
    "a project holding one episode dispatches a null episode tag when exporting to Fountain",
    (tester) async {
      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(EditorPage)));

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

      final context = tester.element(find.byType(EditorPage));
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

  testWidgets(
    'toggling page simulation from the ⋮ menu flips it and persists the new value',
    (tester) async {
      await propertiesManager.isPageSimulationEnabled.store(true);
      await pumpEditorPage(tester);
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

  testWidgets(
    'toggling scene numbers from the ⋮ menu flips it and persists the new value',
    (tester) async {
      await propertiesManager.styledSceneNumbersVisible.store(true);
      await pumpEditorPage(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EditorPage));
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
    },
  );

  testWidgets(
    "scrolling the styled editor with page simulation on does not move the toolbar",
    (tester) async {
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
      expect(toolbarTopAfter, toolbarTopBefore, reason: "toolbar must not move when the editor scrolls");
    },
  );

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

      final tr = Tr.of(tester.element(find.byType(EditorPage)));

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

      final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
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
          find.descendant(
            of: find.byType(OcptEditorSourceField),
            matching: find.byType(TextField),
          ),
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
        // this is the plan's own headline scenario for putting replace in scope at all.
        await tester.enterText(barTextFields.last, "MARIE-JEANNE");
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
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

      final context = tester.element(find.byType(EditorPage));
      final tr = Tr.of(context);
      await tester.tap(find.text(tr.editorReplaceAction));
      await tester.pumpAndSettle();

      expect(nodeContaining("Monday").text.toPlainText(), "Smells like Monday.");
    });

    testWidgets('Replace all goes through the confirm dialog, exactly like raw mode', (tester) async {
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

      final context = tester.element(find.byType(EditorPage));
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

      final tr = Tr.of(tester.element(find.byType(EditorPage)));

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
        "$_sampleText\nA fresh action line.",
      );
      await settleUndoThrottle(tester);
      expect(rawText(tester), contains("A fresh action line."));

      // `Undo` is offered now, stating its own shortcut, and takes the edit back.
      await openOverflowMenu(tester);
      expect(find.text('Ctrl+Z'), findsOneWidget);
      await tester.tap(find.text(tr.editorUndoAction));
      await tester.pumpAndSettle();

      expect(rawText(tester), _sampleText);

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
        "$_sampleText\nA fresh action line.",
      );
      await settleUndoThrottle(tester);

      // The page's own `Shortcuts` claims neither Ctrl+Z nor Ctrl+Shift+Z, so both keep reaching
      // `EditableText`'s own `UndoHistory` — this is the regression guard against a future
      // page-level shortcut silently stealing them.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(rawText(tester), _sampleText);

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

      final tr = Tr.of(tester.element(find.byType(EditorPage)));

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
        "$_sampleText\nA fresh action line.",
      );
      await settleUndoThrottle(tester);

      final tr = Tr.of(tester.element(find.byType(EditorPage)));
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
