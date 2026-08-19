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
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_empty_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_header.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_card.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, and with
/// [ocptTheme]'s light theme so widgets reading its `OcptSpecificColors` extension (the project
/// card's poster tint) resolve one, just like the real app always does.
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

/// Pumps [child], localized, on a desktop-sized surface: the default test surface (800x600) is
/// too narrow for the home page header's three actions side by side, which this app never runs
/// at in practice (a resizable desktop window, not a fixed small canvas).
Future<void> _pumpHome(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrapWithLocalization(child));
}

void main() {
  // HomePage builds its OcptHomeBloc internally via `OcptHomeBloc()`, which resolves every
  // manager it needs from globalGetIt() by default. We register real (but test-controlled)
  // instances of those managers in the app's actual GetIt instance once, matching how
  // OcptPropertiesManager's own test backs it with an in-memory store instead of mocking it.
  late OcptPropertiesManager propertiesManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();

    final projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    OcptGlobalManager.instance.managers
      ..registerSingleton<OcptPropertiesManager>(propertiesManager)
      ..registerSingleton<OcptProjectsManager>(projectsManager)
      ..registerSingleton<OcptRouterManager>(OcptRouterManager())
      ..registerSingleton<FileSaverManager>(const FileSaverManager())
      ..registerSingleton<FileSelectorManager>(const FileSelectorManager())
      ..registerSingleton<OcptExportManager>(
        OcptExportManager(fileSelectorManager: const FileSelectorManager()),
      );
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_home_page_test_");
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows the empty state when there are no recent projects', (tester) async {
    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(OcptHomeEmptyState), findsOneWidget);
    expect(find.byType(OcptProjectCard), findsNothing);

    final context = tester.element(find.byType(HomePage));
    expect(find.text(Tr.of(context).homeEmptyStateTitle), findsOneWidget);
  });

  testWidgets('shows a card per recent project once loaded', (tester) async {
    final existingFile = File(p.join(tempDir.path, "movie.ocpt"))..writeAsStringSync("");
    await propertiesManager.addRecentProject(
      OcptRecentProjectModel(
        path: existingFile.path,
        name: "My Movie",
        lastOpenedAt: DateTime.now(),
      ),
    );

    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(OcptHomeEmptyState), findsNothing);
    expect(find.byType(OcptProjectCard), findsOneWidget);
    expect(find.text("My Movie"), findsOneWidget);
  });

  testWidgets("a recent project whose file is missing is shown greyed out and can't be opened", (
    tester,
  ) async {
    final missingPath = p.join(tempDir.path, "missing.ocpt");
    await propertiesManager.addRecentProject(
      OcptRecentProjectModel(path: missingPath, name: "Missing Movie", lastOpenedAt: DateTime.now()),
    );

    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(OcptProjectCard), findsOneWidget);

    final cardWidget = tester.widget<OcptProjectCard>(find.byType(OcptProjectCard));
    expect(cardWidget.entry.exists, isFalse);

    // The card is wrapped in a Tooltip explaining why it's disabled, instead of being tappable.
    final context = tester.element(find.byType(HomePage));
    expect(find.byTooltip(Tr.of(context).homeMissingFileTooltip), findsOneWidget);
    final inkWell = tester.widget<InkWell>(find.byKey(ValueKey(missingPath)));
    expect(inkWell.onTap, isNull);
  });

  testWidgets('the import-a-screenplay action is shown in the header and the empty state', (
    tester,
  ) async {
    await _pumpHome(tester, const HomePage());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomePage));
    expect(find.text(Tr.of(context).homeImportScreenplayAction), findsNWidgets(2));
  });

  testWidgets('tapping the import-a-screenplay action starts the import flow', (tester) async {
    var tapped = false;
    await _pumpHome(
      tester,
      OcptHomeHeader(
        onNewProject: () {},
        onOpenProject: () {},
        onImportScreenplay: () => tapped = true,
        onOpenSettings: () {},
      ),
    );

    final context = tester.element(find.byType(OcptHomeHeader));
    await tester.tap(find.text(Tr.of(context).homeImportScreenplayAction));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
