// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui' show Brightness, Locale;

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_intl_ui/act_intl_ui.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_app_theme.dart';

/// The state of the settings page bloc.
///
/// Carries the current/wanted locale and the current theme/brightness (both applied live,
/// app-wide, through [MixinSetWantedLocaleState] and [MixinActThemesState]), plus the injected app
/// version shown in the about section.
class OcptSettingsState extends BlocStateForMixin<OcptSettingsState>
    with MixinSetWantedLocaleState<OcptSettingsState>, MixinActThemesState<OcptSettingsState> {
  /// {@macro act_intl_ui.MixinSetWantedLocaleState.currentLocale}
  @override
  final Locale currentLocale;

  /// {@macro act_intl_ui.MixinSetWantedLocaleState.wantedLocale}
  @override
  final Locale? wantedLocale;

  /// {@macro act_themes_manager.MixinActThemesState.currentTheme}
  @override
  final MixinActThemes currentTheme;

  /// {@macro act_themes_manager.MixinActThemesState.brightness}
  @override
  final Brightness? brightness;

  /// The application version shown in the about section, injected at bloc creation.
  final String appVersion;

  /// Class constructor
  const OcptSettingsState({
    required this.currentLocale,
    required this.wantedLocale,
    required this.currentTheme,
    required this.brightness,
    required this.appVersion,
  });

  /// Init class constructor
  const OcptSettingsState.init({required this.appVersion})
    : currentLocale = const Locale.fromSubtags(),
      wantedLocale = null,
      currentTheme = OcptAppTheme.standard,
      brightness = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptSettingsState copyWith({
    Locale? currentLocale,
    Locale? wantedLocale,
    bool forceWantedLocaleValue = false,
    MixinActThemes? currentTheme,
    Brightness? brightness,
    bool forceBrightnessValue = false,
    String? appVersion,
  }) => OcptSettingsState(
    currentLocale: currentLocale ?? this.currentLocale,
    wantedLocale: wantedLocale ?? (forceWantedLocaleValue ? null : this.wantedLocale),
    currentTheme: currentTheme ?? this.currentTheme,
    brightness: brightness ?? (forceBrightnessValue ? null : this.brightness),
    appVersion: appVersion ?? this.appVersion,
  );

  /// {@macro act_intl_ui.MixinSetWantedLocaleState.copySetWantedLocaleState}
  @override
  OcptSettingsState copySetWantedLocaleState({
    Locale? currentLocale,
    Locale? wantedLocale,
    bool forceWantedLocaleValue = false,
  }) => copyWith(
    currentLocale: currentLocale,
    wantedLocale: wantedLocale,
    forceWantedLocaleValue: forceWantedLocaleValue,
  );

  /// {@macro act_themes_manager.MixinActThemesState.copyActThemesState}
  @override
  OcptSettingsState copyActThemesState({
    MixinActThemes? currentTheme,
    Brightness? brightness,
    bool forceBrightnessValue = false,
  }) => copyWith(
    currentTheme: currentTheme,
    brightness: brightness,
    forceBrightnessValue: forceBrightnessValue,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, appVersion];
}
