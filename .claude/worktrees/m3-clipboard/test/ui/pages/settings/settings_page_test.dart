// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_app_theme.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_page.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_about_section.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_appearance_section.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/widgets/ocpt_settings_language_section.dart';

/// A locales manager whose current/wanted locale are held in plain fields: see the bloc test for
/// why this fake exists instead of a real [LocalesManager].
class _FakeLocalesManager extends LocalesManager {
  /// Class constructor
  _FakeLocalesManager()
    : super(
        getSupportedLocales: () => const <Locale>[Locale("en", "GB"), Locale("fr")],
        propertiesGetter: () => throw UnimplementedError(),
        configGetter: () => throw UnimplementedError(),
      );

  /// The stream backing [currentLocaleStream]; never emits in this fake.
  final _currentLocaleCtrl = StreamController<Locale>.broadcast();

  /// The locale returned by [currentLocale].
  final Locale _current = const Locale("en", "GB");

  /// The locale returned by [wantedLocale].
  Locale? _wanted;

  @override
  Locale get currentLocale => _current;

  @override
  Stream<Locale> get currentLocaleStream => _currentLocaleCtrl.stream;

  @override
  Locale? get wantedLocale => _wanted;

  @override
  set wantedLocale(Locale? newLocale) => _wanted = newLocale;

  /// Closes the stream backing this fake, for tidy test teardown.
  Future<void> disposeFake() => _currentLocaleCtrl.close();
}

/// A themes manager whose current theme/brightness are held in plain fields: see the bloc test
/// for why this fake exists instead of a real [ActThemesManager].
class _FakeActThemesManager extends ActThemesManager {
  /// Class constructor
  _FakeActThemesManager()
    : super(
        propertiesGetter: () => throw UnimplementedError(),
        configGetter: () => throw UnimplementedError(),
        appThemes: OcptAppTheme.values,
      );

  /// The stream backing [currentThemeStream]; never emits in this fake.
  final _themeCtrl = StreamController<MixinActThemes>.broadcast();

  /// The stream backing [brightnessStream], fed by [setBrightness].
  final _brightnessCtrl = StreamController<Brightness?>.broadcast();

  /// The theme returned by [currentTheme].
  MixinActThemes _theme = OcptAppTheme.standard;

  /// The brightness returned by [brightness].
  Brightness? _brightness;

  @override
  MixinActThemes get currentTheme => _theme;

  @override
  Stream<MixinActThemes> get currentThemeStream => _themeCtrl.stream;

  @override
  Brightness? get brightness => _brightness;

  @override
  Stream<Brightness?> get brightnessStream => _brightnessCtrl.stream;

  @override
  Future<void> setBrightness({required Brightness? newBrightness}) async {
    _brightness = newBrightness;
    _brightnessCtrl.add(newBrightness);
  }

  @override
  Future<void> setCurrentTheme({required MixinActThemes newTheme}) async {
    _theme = newTheme;
    _themeCtrl.add(newTheme);
  }

  /// Closes the streams backing this fake, for tidy test teardown.
  Future<void> disposeFake() async {
    await _themeCtrl.close();
    await _brightnessCtrl.close();
  }
}

/// A router manager whose [push]/[pop] only record the call: this page test pumps
/// [OcptSettingsView] directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// The last route [push] was called with, or null if it never was.
  OcptRoute? pushedRoute;

  /// Whether [pop] was called.
  bool popped = false;

  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushedRoute = route;
    return null;
  }

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
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
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<LocalesManager>()) {
      await managers.unregister<LocalesManager>();
    }
    if (managers.isRegistered<ActThemesManager>()) {
      await managers.unregister<ActThemesManager>();
    }
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    final locales = _FakeLocalesManager();
    final themes = _FakeActThemesManager();
    addTearDown(locales.disposeFake);
    addTearDown(themes.disposeFake);

    routerManager = _RecordingRouterManager();
    managers
      ..registerSingleton<LocalesManager>(locales)
      ..registerSingleton<ActThemesManager>(themes)
      ..registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [OcptSettingsView] backed by a fresh [OcptSettingsBloc] with the injected
  /// [appVersion], returning the bloc so tests can inspect its state.
  Future<OcptSettingsBloc> pumpSettingsView(WidgetTester tester, {String appVersion = "1.2.3"}) async {
    final bloc = OcptSettingsBloc(appVersion: appVersion);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptSettingsBloc>.value(value: bloc, child: const OcptSettingsView()),
      ),
    );
    await tester.pumpAndSettle();

    return bloc;
  }

  testWidgets("renders the three sections with the injected app version", (tester) async {
    await pumpSettingsView(tester, appVersion: "9.9.9");

    expect(find.byType(OcptSettingsAppearanceSection), findsOneWidget);
    expect(find.byType(OcptSettingsLanguageSection), findsOneWidget);
    expect(find.byType(OcptSettingsAboutSection), findsOneWidget);

    final context = tester.element(find.byType(OcptSettingsView));
    final tr = Tr.of(context);
    expect(find.text(tr.settingsAppearanceSectionTitle), findsOneWidget);
    // The language section's title and its dropdown's row label are both "Language" by design
    // (see the settings page layout), so both instances are expected here.
    expect(find.text(tr.settingsLanguageSectionTitle), findsNWidgets(2));
    expect(find.text(tr.settingsAboutSectionTitle), findsOneWidget);
    expect(find.text(tr.settingsAboutVersionLabel("9.9.9")), findsOneWidget);
  });

  testWidgets("picking a brightness option dispatches the update to the bloc", (tester) async {
    final bloc = await pumpSettingsView(tester);
    final context = tester.element(find.byType(OcptSettingsView));
    final tr = Tr.of(context);

    await tester.tap(find.byType(DropdownButton<Brightness?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.settingsThemeDarkOption).last);
    await tester.pumpAndSettle();

    expect(bloc.state.brightness, Brightness.dark);
  });

  testWidgets("picking a language option dispatches the update to the bloc", (tester) async {
    final bloc = await pumpSettingsView(tester);

    await tester.tap(find.byType(DropdownButton<Locale?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Français").last);
    await tester.pumpAndSettle();

    expect(bloc.state.wantedLocale, const Locale("fr"));
  });

  testWidgets("tapping the third-party licenses row pushes the licenses route", (tester) async {
    await pumpSettingsView(tester);
    final context = tester.element(find.byType(OcptSettingsView));

    await tester.tap(find.text(Tr.of(context).settingsAboutLicensesAction));
    await tester.pumpAndSettle();

    expect(routerManager.pushedRoute, OcptRoute.licenses);
  });

  testWidgets("tapping the back arrow pops through the router manager", (tester) async {
    await pumpSettingsView(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
  });
}
