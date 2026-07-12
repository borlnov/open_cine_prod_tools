// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_page.dart';

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
  // EditorPage reads the current project's name from OcptProjectsManager through globalGetIt(),
  // which requires a global manager instance to exist and an OcptProjectsManager to be registered
  // in it. We register a manually constructed one (bypassing the app's normal manager wiring, and
  // its own OcptPropertiesManager dependency, which this test never exercises).
  late OcptProjectsManager projectsManager;

  setUpAll(() async {
    OcptGlobalManager.instance;

    projectsManager = OcptProjectsManager(propertiesManager: OcptPropertiesManager());
    await projectsManager.initLifeCycle();
    OcptGlobalManager.instance.managers.registerSingleton<OcptProjectsManager>(projectsManager);
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
