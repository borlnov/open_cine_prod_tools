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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close the
/// export panel opened through `showDialog` exactly as the real `GoRouter.pop` would — both push
/// onto the very same root `Navigator`. See `test/ui/pages/editor/editor_page_test.dart`'s own
/// instance of the same pattern.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_mode_test_");
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

  /// A finder scoped to the export panel's own `AlertDialog`, so its card title (`Resources`)
  /// can't collide with anything else on screen.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  testWidgets(
    "with an empty catalogue, the export panel's own card is unavailable and says why",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptResourcesMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptResourcesMode)));

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(find.text(tr.resourcesExportPanelTitle), findsOneWidget);
      expect(inPanel(find.text(tr.resourcesExportXlsxTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.resourcesExportContactListTitle)), findsOneWidget);
      expect(inPanel(find.text(tr.resourcesExportUnavailableReason)), findsOneWidget);
      expect(inPanel(find.text(tr.resourcesExportContactListUnavailableReason)), findsOneWidget);
      expect(inPanel(find.text(tr.resourcesExportXlsxDescription)), findsNothing);
      expect(inPanel(find.text(tr.resourcesExportContactListDescription)), findsNothing);

      // Unavailable: tapping either card pops nothing, so the panel stays open.
      await tester.tap(inPanel(find.text(tr.resourcesExportXlsxTitle)));
      await tester.pumpAndSettle();
      expect(find.text(tr.resourcesExportPanelTitle), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.resourcesExportContactListTitle)));
      await tester.pumpAndSettle();
      expect(find.text(tr.resourcesExportPanelTitle), findsOneWidget);
    },
  );

  testWidgets(
    "once a person exists, picking the workbook card dispatches the export request directly",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptResourcesMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptResourcesMode)));

      await tester.tap(find.text(tr.resourcesAddPersonAction));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(inPanel(find.text(tr.resourcesExportUnavailableReason)), findsNothing);
      expect(inPanel(find.text(tr.resourcesExportXlsxDescription)), findsOneWidget);
      // A bare person with no position and no role is still not a line the contact list can
      // print: its own card stays unavailable while the workbook's own is available.
      expect(inPanel(find.text(tr.resourcesExportContactListUnavailableReason)), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.resourcesExportXlsxTitle)));
      await tester.pumpAndSettle();

      // The panel closed, with no options dialog of its own offered: the export request went
      // straight through.
      expect(find.text(tr.resourcesExportPanelTitle), findsNothing);
      expect(find.byType(OcptResourcesMode), findsOneWidget);
    },
  );

  testWidgets(
    "once a role exists, picking the contact list card opens its own options dialog",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithLocalization(const OcptResourcesMode()));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptResourcesMode)));

      // A role is enough on its own to make the contact list printable: the cast side of it
      // needs no crew position at all. A hand-added role is only ever silent or an extra — a
      // speaking one is reconciled from the screenplay, which this project holds none of.
      await tester.tap(find.text(tr.resourcesTabRoles));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.resourcesAddRoleAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.resourcesAddRoleSilentOption));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();

      expect(inPanel(find.text(tr.resourcesExportContactListUnavailableReason)), findsNothing);
      expect(inPanel(find.text(tr.resourcesExportContactListDescription)), findsOneWidget);

      await tester.tap(inPanel(find.text(tr.resourcesExportContactListTitle)));
      await tester.pumpAndSettle();

      expect(find.text(tr.resourcesExportPanelTitle), findsNothing);
      expect(find.text(tr.resourcesExportContactListDialogTitle), findsOneWidget);
    },
  );
}
