// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_page.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_currency_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_minimum_rest_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_page_format_section.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] only records the call: this page test pumps
/// [OcptProjectSettingsView] directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called at all.
  bool wasPopped = false;

  /// The value [pop] was last called with.
  Object? poppedResult;

  @override
  void pop<Y extends Object?>([Y? result]) {
    wasPopped = true;
    poppedResult = result;
  }
}

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
  late OcptPropertiesManager propertiesManager;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;
  late _RecordingRouterManager routerManager;

  setUpAll(() async {
    // OcptProjectsManager logs through appLogger(), which requires a global manager instance to
    // be set; merely accessing it creates the (otherwise unused) singleton.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_page_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );

    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Pumps [OcptProjectSettingsView] backed by a fresh [OcptProjectSettingsBloc] reading/writing
  /// through [projectsManager], returning the bloc so tests can inspect its state.
  Future<OcptProjectSettingsBloc> pumpView(WidgetTester tester) async {
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptProjectSettingsBloc>.value(
          value: bloc,
          child: const OcptProjectSettingsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return bloc;
  }

  testWidgets("renders both sections with the project's current settings", (tester) async {
    await pumpView(tester);

    expect(find.byType(OcptProjectSettingsCurrencySection), findsOneWidget);
    expect(find.byType(OcptProjectSettingsPageFormatSection), findsOneWidget);
    expect(find.byType(OcptProjectSettingsMinimumRestSection), findsOneWidget);

    final context = tester.element(find.byType(OcptProjectSettingsView));
    final tr = Tr.of(context);
    expect(find.text(tr.projectSettingsPageTitle), findsOneWidget);

    // Asserts against whatever the manager actually seeded, not a hardcoded EUR: the device
    // locale running the test may suggest a different one.
    final currencyCode = await projectsManager.loadCurrentProjectCurrencyCode();
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    expect(find.text("$currencyCode — $currencySymbol"), findsOneWidget);
  });

  testWidgets("picking a currency writes it to the project and marks the state changed", (
    tester,
  ) async {
    final bloc = await pumpView(tester);
    final initialCode = await projectsManager.loadCurrentProjectCurrencyCode();
    final otherCode = initialCode == "USD" ? "GBP" : "USD";
    final otherSymbol = NumberFormat.simpleCurrency(name: otherCode).currencySymbol;

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("$otherCode — $otherSymbol").last);
    await tester.pumpAndSettle();

    expect(bloc.state.currencyCode, otherCode);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectCurrencyCode(), otherCode);
  });

  testWidgets("picking a page format writes it to the project and marks the state changed", (
    tester,
  ) async {
    final bloc = await pumpView(tester);
    final initialFormat = await projectsManager.loadCurrentProjectPageFormat();
    final otherFormat = initialFormat == OcptPageFormat.usLetter
        ? OcptPageFormat.a4
        : OcptPageFormat.usLetter;

    await tester.tap(find.byType(DropdownButton<OcptPageFormat>));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(OcptProjectSettingsView));
    final tr = Tr.of(context);
    final otherLabel = otherFormat == OcptPageFormat.a4
        ? tr.editorPageSetupA4Option
        : tr.editorPageSetupUsLetterOption;
    await tester.tap(find.text(otherLabel).last);
    await tester.pumpAndSettle();

    expect(bloc.state.pageFormat, otherFormat);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectPageFormat(), otherFormat);
  });

  testWidgets("shows the project's currently recorded minimum rest", (tester) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(90);

    await pumpView(tester);

    expect(find.text(ocptFormatMinuteDuration(90)), findsOneWidget);
  });

  testWidgets("typing a minimum rest writes it to the project and marks the state changed", (
    tester,
  ) async {
    final bloc = await pumpView(tester);

    await tester.enterText(find.byType(TextField), "660");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, 660);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), 660);
    // Read back as a formatted duration, not the raw digits just typed.
    expect(find.text(ocptFormatMinuteDuration(660)), findsOneWidget);
  });

  testWidgets("clearing the minimum rest writes null to the project", (tester) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(660);
    final bloc = await pumpView(tester);

    await tester.enterText(find.byType(TextField), "");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, isNull);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), isNull);
  });

  testWidgets("a zero or negative minimum rest is rejected and nothing is written", (
    tester,
  ) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(90);
    final bloc = await pumpView(tester);

    await tester.enterText(find.byType(TextField), "-5");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, 90);
    expect(bloc.state.hasChanged, isFalse);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), 90);
    // The field reverts to the last committed value's own formatted reading.
    expect(find.text(ocptFormatMinuteDuration(90)), findsOneWidget);
  });

  testWidgets("tapping the back arrow pops with whether anything changed", (tester) async {
    final bloc = await pumpView(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(routerManager.wasPopped, isTrue);
    expect(routerManager.poppedResult, bloc.state.hasChanged);
    expect(routerManager.poppedResult, isFalse);
  });

  testWidgets("popping after a change hands back true", (tester) async {
    await pumpView(tester);
    final initialFormat = await projectsManager.loadCurrentProjectPageFormat();
    final otherFormat = initialFormat == OcptPageFormat.usLetter
        ? OcptPageFormat.a4
        : OcptPageFormat.usLetter;

    await tester.tap(find.byType(DropdownButton<OcptPageFormat>));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(OcptProjectSettingsView));
    final tr = Tr.of(context);
    final otherLabel = otherFormat == OcptPageFormat.a4
        ? tr.editorPageSetupA4Option
        : tr.editorPageSetupUsLetterOption;
    await tester.tap(find.text(otherLabel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(routerManager.poppedResult, isTrue);
  });
}
