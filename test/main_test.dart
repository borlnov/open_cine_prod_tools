// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  // EditorPage reads the current project's name from OcptProjectsManager, and its preferred
  // editing mode from OcptPropertiesManager, both through globalGetIt(); both need a global
  // manager instance to exist and be registered in it. We register manually constructed ones
  // (bypassing the app's normal manager wiring).
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
    // This test's focus is the raw source field rendering an empty screenplay, not the editing
    // mode: force raw mode so it stays green regardless of the app's default editing mode.
    await propertiesManager.editorMode.store(OcptEditorMode.raw);

    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(OcptRouterManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(
          fileSaverManager: const FileSaverManager(),
          fileSelectorManager: const FileSelectorManager(),
        ),
      );
  });

  testWidgets('EditorPage builds an empty editor when no project is open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithLocalization(const EditorPage()));
    await tester.pumpAndSettle();

    // The router guard normally prevents reaching the editor without an open project; when it's
    // pumped directly anyway, the editor still builds, just empty: the source field is shown and
    // the preview shows its empty hint.
    expect(find.byType(TextField), findsOneWidget);

    final context = tester.element(find.byType(EditorPage));
    expect(find.text(Tr.of(context).editorPreviewEmptyHint), findsOneWidget);
  });

  testWidgets('SettingsPage builds', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const SettingsPage()));
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
