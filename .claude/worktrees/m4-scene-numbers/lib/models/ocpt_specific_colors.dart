// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';

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
