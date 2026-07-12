// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

library;

import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';

/// The seed color used to derive the whole light and dark color schemes.
const _seedColor = Colors.indigo;

/// This defines the light and dark themes of the app.
///
/// There is no application-specific color that falls outside of the standard Material 3
/// [ColorScheme], so [OcptSpecificColors] carries no field; it only exists to satisfy the
/// [ActThemeModel] generic contract.
final ocptTheme = ActThemeModel<OcptSpecificColors>(
  lightColors: ActThemeColors<OcptSpecificColors>(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
  ),
  darkColors: ActThemeColors<OcptSpecificColors>(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
  ),
);

/// This class is used to define the specific colors of the app that are not defined in the color
/// scheme.
///
/// The app doesn't need any color outside of the standard Material 3 [ColorScheme] yet, so this
/// class is intentionally empty.
class OcptSpecificColors extends AbsAppSpecificColors<OcptSpecificColors> {
  /// Class constructor
  const OcptSpecificColors();

  /// Implement the copyWith method required by [ThemeExtension]
  @override
  ThemeExtension<OcptSpecificColors> copyWith() => const OcptSpecificColors();

  /// Implement the lerp method required by [ThemeExtension]
  @override
  ThemeExtension<OcptSpecificColors> lerp(OcptSpecificColors? other, double t) => this;
}
