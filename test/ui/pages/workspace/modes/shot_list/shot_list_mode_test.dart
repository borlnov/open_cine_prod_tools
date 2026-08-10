// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_scenario_coverage_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the export panel, the scenario coverage options dialog)
/// exactly as the real `GoRouter.pop` would — both push onto the very same root `Navigator`. See
/// `test/ui/pages/editor/editor_page_test.dart`'s own instance of the same pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records every call and then pops [_navigatorKey]'s own navigator,
/// so a dialog opened through `showDialog` genuinely closes: this mode's own bloc resolves its
/// router manager from `globalGetIt()`, with no real GoRouter for `pop` to delegate to.
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
/// `showDialog`, a bare [Scaffold]: unlike `EditorPage`, a production mode expects the real
/// `WorkspacePage` to provide one, and an `OcptWorkspaceBloc` ancestor — `WorkspacePage` always
/// provides one too, and this mode now reads it for the toolbar episode selector's
/// episodes/selection.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: BlocProvider<OcptWorkspaceBloc>(
    create: (context) => OcptWorkspaceBloc(),
    child: Scaffold(body: child),
  ),
);

/// An export manager whose [exportShotListXlsx] is stubbed and records the episode tag it was
/// handed, so a test can tell what `OcptShotListMode` itself computed and dispatched — the mode's
/// own `_episodeExportTag`, not the bloc's own scoped episode, is under test here.
class _RecordingExportManager extends OcptExportManager {
  /// Class constructor
  _RecordingExportManager() : super(fileSelectorManager: const FileSelectorManager());

  /// The episode tag of the last [exportShotListXlsx] call.
  String? lastExportedEpisodeTag;

  @override
  Future<String?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
  }) async {
    lastExportedEpisodeTag = episodeTag;
    return "/tmp/$projectName.xlsx";
  }
}

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_mode_test_");
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: "INT. KITCHEN - DAY\n\nAction.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
  });

  tearDown(() async {
    await projectsManager.closeCurrentProject();
    await tempDir.delete(recursive: true);
  });

  /// A finder scoped to the export panel's own `AlertDialog`: the panel's card titles
  /// (`Shot list`) can otherwise collide with the toolbar's own muted mode label, which reads the
  /// same word.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  /// Swaps the registered `OcptExportManager` for [manager] for the rest of the current test,
  /// restoring the shared real one afterward — `OcptShotListBloc` resolves its export manager from
  /// `globalGetIt()` (it's built by the mode itself, with no test seam of its own), so this is what
  /// lets a test observe what a real export call was handed.
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

  testWidgets(
    "with no shot placed, the export panel lists both documents as unavailable and says why",
    (tester) async {
      // Wide enough for the whole shell, so the toolbar's own `Export` button is on screen.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(find.text(tr.shotListExportPanelTitle), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportXlsxTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportCoverageTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportUnavailableReason)), findsNWidgets(2));
      expect(inPanel(find.text(tr.shotListExportXlsxDescription)), findsNothing);
      expect(inPanel(find.text(tr.shotListExportCoverageDescription)), findsNothing);

      // An unavailable card is inert: tapping it pops nothing, so the panel stays open.
      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();
      expect(find.text(tr.shotListExportPanelTitle), findsOneWidget);
    },
  );

  testWidgets(
    "once a shot is placed, picking the scenario coverage card opens its own export options "
    "dialog",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(inPanel(find.text(tr.shotListExportUnavailableReason)), findsNothing);
      expect(inPanel(find.text(tr.shotListExportXlsxDescription)), findsOneWidget);
      expect(inPanel(find.text(tr.shotListExportCoverageDescription)), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.shotListExportCoverageTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.shotListExportPanelTitle), findsNothing);
      expect(find.byType(OcptScenarioCoverageExportDialog), findsOneWidget);
    },
  );

  testWidgets(
    "picking the shot list card dispatches the export request directly, with no options dialog "
    "of its own",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.shotListExportPanelTitle), findsNothing);
      expect(find.byType(OcptScenarioCoverageExportDialog), findsNothing);
      expect(find.byType(OcptShotListMode), findsOneWidget);
    },
  );

  testWidgets(
    "a project holding one episode dispatches a null episode tag when exporting the workbook",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptShotListMode)));

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();

      expect(exportManager.lastExportedEpisodeTag, isNull);
    },
  );

  testWidgets(
    "a project holding two episodes dispatches the selected one's tag when exporting the "
    "workbook",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = projectsManager.currentProject!;
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );

      final exportManager = _RecordingExportManager();
      useExportManager(exportManager);

      await tester.pumpWidget(_wrapWithLocalization(const OcptShotListMode()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcptShotListMode));
      final tr = Tr.of(context);

      // The workspace bloc lands on the first episode by default; select the second one so the
      // exported tag can be told apart from what a single-episode project would produce.
      context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceEpisodeSelectedEvent(episodeId: secondEpisodeId!),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr.shotListAddShotAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      await tester.tap(inPanel(find.text(tr.shotListExportXlsxTitle)));
      await tester.pumpAndSettle();

      expect(exportManager.lastExportedEpisodeTag, tr.workspaceEpisodeTag(2));
    },
  );
}
