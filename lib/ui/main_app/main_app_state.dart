// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui' show Brightness, Locale;

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_intl_ui/act_intl_ui.dart';
import 'package:act_themes_manager/act_themes_manager.dart';

/// The state of the main app bloc, carrying everything the root app shell needs to rebuild when
/// the persisted locale or theme preference changes.
class OcptMainAppState extends BlocStateForMixin<OcptMainAppState>
    with MixinGetWantedLocaleState<OcptMainAppState>, MixinActThemesState<OcptMainAppState> {
  /// {@macro act_intl_ui.MixinGetWantedLocaleState.wantedLocale}
  @override
  final Locale? wantedLocale;

  /// {@macro act_themes_manager.MixinActThemesState.currentTheme}
  @override
  final MixinActThemes currentTheme;

  /// {@macro act_themes_manager.MixinActThemesState.brightness}
  @override
  final Brightness? brightness;

  /// Class constructor
  const OcptMainAppState({
    required this.wantedLocale,
    required this.currentTheme,
    required this.brightness,
  });

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptMainAppState copyWith({
    Locale? wantedLocale,
    bool forceWantedLocaleValue = false,
    MixinActThemes? currentTheme,
    Brightness? brightness,
    bool forceBrightnessValue = false,
  }) => OcptMainAppState(
    wantedLocale: wantedLocale ?? (forceWantedLocaleValue ? null : this.wantedLocale),
    currentTheme: currentTheme ?? this.currentTheme,
    brightness: brightness ?? (forceBrightnessValue ? null : this.brightness),
  );

  /// {@macro act_intl_ui.MixinGetWantedLocaleState.copyGetWantedLocaleState}
  @override
  OcptMainAppState copyGetWantedLocaleState({
    Locale? wantedLocale,
    bool forceWantedLocaleValue = false,
  }) => copyWith(wantedLocale: wantedLocale, forceWantedLocaleValue: forceWantedLocaleValue);

  /// {@macro act_themes_manager.MixinActThemesState.copyActThemesState}
  @override
  OcptMainAppState copyActThemesState({
    MixinActThemes? currentTheme,
    Brightness? brightness,
    bool forceBrightnessValue = false,
  }) => copyWith(
    currentTheme: currentTheme,
    brightness: brightness,
    forceBrightnessValue: forceBrightnessValue,
  );
}
