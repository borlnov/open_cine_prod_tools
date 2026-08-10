// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_mode_switcher.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_page.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:super_editor/super_editor.dart';

/// A router manager whose [pop] only records that it was called: these page tests pump the
/// workspace page directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and [ocptTheme]'s
/// light theme so widgets reading its `OcptSpecificColors` extension resolve one, just like the
/// real app always does.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  theme: ocptTheme.lightThemeData,
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
  // a selection, which never lets `pumpAndSettle` settle; this file never gives the styled editor
  // a selection, but the raw source field's own `TextField` shares the same concern.
  BlinkController.indeterminateAnimationsEnabled = false;

  // WorkspacePage builds its OcptWorkspaceBloc (and, in screenplay mode, EditorPage's own
  // OcptEditorBloc) internally, both resolving their managers from globalGetIt() by default; real
  // (but test-controlled) instances are registered in the app's actual GetIt instance once, like
  // the editor page test does.
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
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    // Most of the tests below exercise the raw mode's own `TextField`, and disable page
    // simulation so the source field takes the full centre width regardless of the window size
    // `flutter_test` gives this suite.
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    await propertiesManager.isPageSimulationEnabled.store(false);
    routerManager.popped = false;

    tempDir = await Directory.systemTemp.createTemp("ocpt_workspace_page_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  testWidgets('defaults to the screenplay mode, with the mode switcher always shown', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithLocalization(const WorkspacePage()));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.byType(OcptWorkspaceModeSwitcher), findsOneWidget);
  });

  testWidgets(
    'switching to Budget shows its empty state and no dock; switching back shows the editor',
    (tester) async {
      await tester.pumpWidget(_wrapWithLocalization(const WorkspacePage()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(WorkspacePage)));

      await tester.tap(find.text(tr.workspaceModeBudget));
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsNothing);
      expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
      expect(find.byType(OcptEditorSourceField), findsNothing);

      await tester.tap(find.text(tr.workspaceModeScreenplay));
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsOneWidget);
      expect(find.byType(OcptWorkspaceEmptyMode), findsNothing);
    },
  );

  testWidgets('an edit survives a round trip through another mode', (tester) async {
    const editedText = "INT. HOUSE - DAY\n\nAction.\n";

    await tester.pumpWidget(_wrapWithLocalization(const WorkspacePage()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(WorkspacePage)));

    final textFieldFinder = find.descendant(
      of: find.byType(OcptEditorSourceField),
      matching: find.byType(TextField),
    );
    await tester.enterText(textFieldFinder, editedText);
    // Well short of the real 2 s autosave debounce: leaving the screenplay mode right after must
    // still flush the edit on its own, not rely on the debounce having fired already.
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text(tr.workspaceModeBudget));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.workspaceModeScreenplay));
    await tester.pumpAndSettle();

    final project = projectsManager.currentProject!;
    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, editedText);
    // The project itself must have stayed open across the mode switch: only the workspace's own
    // back action closes it.
    expect(routerManager.popped, isFalse);
  });

  testWidgets('switching episode remounts the mode', (tester) async {
    final project = projectsManager.currentProject!;
    final firstEpisodeId = project.primaryScreenplayId;
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    );
    expect(secondEpisodeId, isNotNull);

    await tester.pumpWidget(_wrapWithLocalization(const WorkspacePage()));
    await tester.pumpAndSettle();

    // The keyed remount (`WorkspacePage._buildActiveMode`) is what this test is actually about: a
    // fresh key means a fresh `EditorPage` element, and therefore a fresh `OcptEditorBloc` loading
    // from scratch, rather than the very same widget instance simply being rebuilt in place.
    expect(
      tester.widget<EditorPage>(find.byType(EditorPage)).key,
      ValueKey<String?>(firstEpisodeId),
    );

    final tr = Tr.of(tester.element(find.byType(WorkspacePage)));
    await tester.tap(find.byTooltip(tr.workspaceEpisodeSelectorTooltip));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.workspaceEpisodeTitledLabel(2, "Episode two")));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditorPage>(find.byType(EditorPage)).key,
      ValueKey<String?>(secondEpisodeId),
    );
  });
}
