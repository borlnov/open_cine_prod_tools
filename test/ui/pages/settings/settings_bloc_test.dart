// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:ui' show Brightness, Locale;

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_intl_ui/act_intl_ui.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_app_theme.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A locales manager whose current/wanted locale are held in plain fields instead of being
/// backed by real config/properties managers: this test only exercises
/// [MixinSetWantedLocaleBloc]'s reaction to [NewLocaleWantedByUserEvent], never the manager's own
/// persistence or system-locale resolution.
class _FakeLocalesManager extends LocalesManager {
  /// Class constructor, [wantedLocale] standing for a locale the user had already picked in a
  /// previous session.
  _FakeLocalesManager({Locale? wantedLocale})
    : _wanted = wantedLocale,
      super(
        getSupportedLocales: () => const <Locale>[Locale("en", "GB"), Locale("fr")],
        propertiesGetter: () => throw UnimplementedError(),
        configGetter: () => throw UnimplementedError(),
      );

  /// The stream backing [currentLocaleStream]; never emits in this fake since no test exercises a
  /// system-locale change.
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

/// A themes manager whose current theme/brightness are held in plain fields instead of being
/// backed by real config/properties managers: this test only exercises
/// [MixinActThemesBloc]'s reaction to [AskToUpdateBrightnessEvent].
class _FakeActThemesManager extends ActThemesManager {
  /// Class constructor, [brightness] standing for a preference the user had already persisted in a
  /// previous session.
  _FakeActThemesManager({Brightness? brightness})
    : _brightness = brightness,
      super(
        propertiesGetter: () => throw UnimplementedError(),
        configGetter: () => throw UnimplementedError(),
        appThemes: OcptAppTheme.values,
      );

  /// The stream backing [currentThemeStream]; never emits in this fake since no test exercises a
  /// theme change (the app has a single theme).
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

  /// Stores [newBrightness] and, like the real manager's value keeper, only notifies the stream
  /// when the value actually changes.
  @override
  Future<void> setBrightness({required Brightness? newBrightness}) async {
    if (newBrightness == _brightness) {
      return;
    }

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

void main() {
  late OcptPropertiesManager propertiesManager;

  setUpAll(() async {
    // Makes appLogger() (used by the bloc's mixins) resolvable, like the home bloc test does.
    OcptGlobalManager.instance;

    // The bloc reads the preferences this app persists itself through a real properties manager
    // over in-memory shared preferences — there is nothing to fake in it, unlike the two ACT
    // managers above, whose real ones would reach for config files.
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Registers fresh fake managers, replacing any already registered, with [brightness] and
  /// [wantedLocale] standing for preferences the user had persisted in a previous session.
  ///
  /// [OcptSettingsBloc] and its mixins resolve their managers directly from globalGetIt() (no
  /// constructor injection), so this runs before every test to keep them isolated from one
  /// another, and again in the tests that need a stored preference in place.
  Future<void> registerFakeManagers({Brightness? brightness, Locale? wantedLocale}) async {
    final managers = globalGetIt();
    if (managers.isRegistered<LocalesManager>()) {
      await managers.unregister<LocalesManager>();
    }
    if (managers.isRegistered<ActThemesManager>()) {
      await managers.unregister<ActThemesManager>();
    }

    final locales = _FakeLocalesManager(wantedLocale: wantedLocale);
    final themes = _FakeActThemesManager(brightness: brightness);
    addTearDown(locales.disposeFake);
    addTearDown(themes.disposeFake);

    managers.registerSingleton<LocalesManager>(locales);
    managers.registerSingleton<ActThemesManager>(themes);

    if (managers.isRegistered<OcptPropertiesManager>()) {
      await managers.unregister<OcptPropertiesManager>(disposingFunction: (_) async {});
    }
    managers.registerSingleton<OcptPropertiesManager>(propertiesManager);
  }

  setUp(registerFakeManagers);

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptSettingsState> waitForState(
    OcptSettingsBloc bloc,
    bool Function(OcptSettingsState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test("carries the injected app version instead of resolving PackageInfo.fromPlatform()", () async {
    final bloc = OcptSettingsBloc(appVersion: "9.9.9");

    expect(bloc.state.appVersion, "9.9.9");

    await bloc.close();
  });

  test("dispatching AskToUpdateBrightnessEvent updates state.brightness", () async {
    final bloc = OcptSettingsBloc(appVersion: "1.0.0");
    expect(bloc.state.brightness, isNull);

    bloc.add(const AskToUpdateBrightnessEvent(newBrightness: Brightness.dark));
    final state = await waitForState(bloc, (state) => state.brightness == Brightness.dark);

    expect(state.brightness, Brightness.dark);

    await bloc.close();
  });

  test("starts on the preferences the managers already hold", () async {
    await registerFakeManagers(brightness: Brightness.dark, wantedLocale: const Locale("fr"));

    final bloc = OcptSettingsBloc(appVersion: "1.0.0");

    expect(bloc.state.brightness, Brightness.dark);
    expect(bloc.state.wantedLocale, const Locale("fr"));

    await bloc.close();
  });

  test("keeps the stored brightness when it is the one picked again", () async {
    // The managers' streams only emit on change, so picking the brightness already stored notifies
    // nothing: the state must already carry it rather than wait for an emission that never comes.
    await registerFakeManagers(brightness: Brightness.dark);

    final bloc = OcptSettingsBloc(appVersion: "1.0.0");
    bloc.add(const AskToUpdateBrightnessEvent(newBrightness: Brightness.dark));
    await pumpEventQueue();

    expect(bloc.state.brightness, Brightness.dark);

    await bloc.close();
  });

  test("dispatching NewLocaleWantedByUserEvent updates state.wantedLocale", () async {
    final bloc = OcptSettingsBloc(appVersion: "1.0.0");
    expect(bloc.state.wantedLocale, isNull);

    bloc.add(const NewLocaleWantedByUserEvent(wantedLocale: Locale("fr")));
    final state = await waitForState(bloc, (state) => state.wantedLocale == const Locale("fr"));

    expect(state.wantedLocale, const Locale("fr"));

    await bloc.close();
  });

  test("the week starts on Monday until the user says otherwise", () async {
    final bloc = OcptSettingsBloc(appVersion: "1.0.0");
    await pumpEventQueue();

    expect(bloc.state.firstWeekday, OcptFirstWeekday.monday);

    await bloc.close();
  });

  test("picking a first weekday stores it and shows it", () async {
    final bloc = OcptSettingsBloc(appVersion: "1.0.0");

    bloc.add(
      const OcptSettingsFirstWeekdayChangedEvent(firstWeekday: OcptFirstWeekday.sunday),
    );
    final state = await waitForState(
      bloc,
      (state) => state.firstWeekday == OcptFirstWeekday.sunday,
    );

    expect(state.firstWeekday, OcptFirstWeekday.sunday);
    expect(await propertiesManager.firstWeekday.load(), OcptFirstWeekday.sunday);

    await bloc.close();
  });

  test("a stored first weekday is read back into the state on open", () async {
    // The preference outlives the page, so a bloc built afterwards must show what was stored
    // rather than the default — the whole point of the asynchronous load the constructor asks for.
    await propertiesManager.firstWeekday.store(OcptFirstWeekday.sunday);

    final bloc = OcptSettingsBloc(appVersion: "1.0.0");
    final state = await waitForState(
      bloc,
      (state) => state.firstWeekday == OcptFirstWeekday.sunday,
    );

    expect(state.firstWeekday, OcptFirstWeekday.sunday);

    await bloc.close();
    await propertiesManager.firstWeekday.store(OcptFirstWeekday.monday);
  });
}
