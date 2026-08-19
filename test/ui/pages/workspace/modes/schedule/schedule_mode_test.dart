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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shooting_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shooting_plan_xlsx_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_status_bar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the export panel, the shooting plan options dialog)
/// exactly as the real `GoRouter.pop` would — both push onto the very same root `Navigator`. See
/// `test/ui/pages/editor/editor_page_test.dart`'s own instance of the same pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [_navigatorKey]'s own navigator, so a dialog opened through
/// `showDialog` genuinely closes: this mode's own bloc resolves its router manager from
/// `globalGetIt()`, with no real GoRouter for `pop` to delegate to.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests,
/// [_navigatorKey] so [_RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog`, [ocptTheme]'s light theme so widgets reading its `OcptSpecificColors` extension
/// resolve one, and a bare [Scaffold]: unlike `EditorPage`, a production mode expects the real
/// `WorkspacePage` to provide one.
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
  home: Scaffold(body: child),
);

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
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

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(_RecordingRouterManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_mode_test_");
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

  /// A finder scoped to the export panel's own `AlertDialog`, so its card titles can't collide
  /// with anything else on screen.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  testWidgets(
    "with no day planned, every card of the export panel is unavailable and says why",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptScheduleMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleMode)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(find.text(tr.scheduleExportPanelTitle), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelCallSheetsTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelNamedCallSheetsTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelShootingPlanTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelShootingPlanXlsxTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelDayOutOfDaysTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelOneLineScheduleTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportPanelSidesTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.scheduleExportUnavailableReason)), findsNWidgets(7));
      expect(inPanel(find.text(tr.scheduleExportPanelShootingPlanDescription)), findsNothing);

      // Unavailable: tapping it pops nothing, so the panel stays open.
      await tester.tap(inPanel(find.text(tr.scheduleExportPanelShootingPlanTitle)));
      await tester.pumpAndSettle();
      expect(find.text(tr.scheduleExportPanelTitle), findsOneWidget);
    },
  );

  testWidgets(
    "once a day is planned, picking the shooting plan card opens its own export options dialog",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final dayId = await projectsManager.scheduleService.createDay(
        database: project.database,
        date: DateTime(2026, 8, 10),
      );
      expect(dayId, isNotNull);

      await tester.pumpWidget(_wrapWithLocalization(const OcptScheduleMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleMode)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(inPanel(find.text(tr.scheduleExportUnavailableReason)), findsNothing);
      expect(inPanel(find.text(tr.scheduleExportPanelShootingPlanDescription)), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.scheduleExportPanelShootingPlanTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.scheduleExportPanelTitle), findsNothing);
      expect(find.byType(OcptScheduleShootingPlanExportDialog), findsOneWidget);
    },
  );

  testWidgets(
    "once a day is planned, picking the shooting plan workbook card opens its own export options "
    "dialog",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final dayId = await projectsManager.scheduleService.createDay(
        database: project.database,
        date: DateTime(2026, 8, 10),
      );
      expect(dayId, isNotNull);

      await tester.pumpWidget(_wrapWithLocalization(const OcptScheduleMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleMode)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(inPanel(find.text(tr.scheduleExportPanelShootingPlanXlsxDescription)), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.scheduleExportPanelShootingPlanXlsxTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.scheduleExportPanelTitle), findsNothing);
      expect(find.byType(OcptScheduleShootingPlanXlsxExportDialog), findsOneWidget);
    },
  );

  testWidgets("a single-episode project's status bar names no episode", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWithLocalization(const OcptScheduleMode()));
    await tester.pumpAndSettle();

    final statusBar = tester.widget<OcptScheduleStatusBar>(find.byType(OcptScheduleStatusBar));
    expect(statusBar.episodeCount, isNull);
  });

  testWidgets(
    "a multi-episode project's status bar counts the episodes, off OcptScheduleState.episodes",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.createEpisode(database: project.database);

      await tester.pumpWidget(_wrapWithLocalization(const OcptScheduleMode()));
      await tester.pumpAndSettle();

      final statusBar = tester.widget<OcptScheduleStatusBar>(find.byType(OcptScheduleStatusBar));
      expect(statusBar.episodeCount, 2);
    },
  );
}
