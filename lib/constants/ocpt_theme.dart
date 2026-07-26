// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

library;

import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';

/// The seed color used to derive the whole light and dark color schemes.
///
/// This app is a "studio" tool (screenwriting/production), so the intent is to read like the
/// professional creative software it sits alongside (DaVinci Resolve, Frame.io): calm, near-black
/// neutral surfaces most of the time, with a single vivid, unmistakable accent reserved for
/// primary actions and selection. This particular blue-violet was picked because it stays legible
/// and clearly "electric" on both a near-black dark surface and a near-white light one, so the
/// same seed can honestly drive both [_lightColorScheme] and [_darkColorScheme].
const _seedColor = Color(0xFF6C5CE7);

/// The light color scheme: a standard Material 3 scheme derived from [_seedColor], with no
/// further overrides. It stays close to the Material defaults so the app reads as a normal, calm
/// productivity tool in bright environments.
final _lightColorScheme = ColorScheme.fromSeed(seedColor: _seedColor);

/// The dark color scheme: derived from [_seedColor] like [_lightColorScheme], but with its
/// neutral surface tones pulled down to near-black.
///
/// [ColorScheme.fromSeed]'s default dark surfaces are a mid-tone grey, which reads as generic
/// Material Design rather than as the deep, focused "studio" look the product wants (think of how
/// dark professional video/creative tools stay almost black outside of their accent color). The
/// surface family is overridden here for that reason, while [_seedColor]'s hue is kept for every
/// tonal surface so they still feel like part of the same coherent scheme, only darker.
final _darkColorScheme = ColorScheme.fromSeed(
  seedColor: _seedColor,
  brightness: Brightness.dark,
).copyWith(
  surface: const Color(0xFF121114),
  onSurface: const Color(0xFFE7E5EA),
  surfaceContainerLowest: const Color(0xFF09090B),
  surfaceContainerLow: const Color(0xFF17161A),
  surfaceContainer: const Color(0xFF1C1B20),
  surfaceContainerHigh: const Color(0xFF242329),
  surfaceContainerHighest: const Color(0xFF2C2B32),
  outline: const Color(0xFF3D3B45),
  outlineVariant: const Color(0xFF29282E),
);

/// This defines the light and dark themes of the app.
///
/// [OcptSpecificColors.previewBackdrop] is the one application-specific color that falls outside
/// the standard Material 3 [ColorScheme]: the light value matches [_lightColorScheme]'s own
/// `surfaceContainerLow` (so light mode stays byte-identical to the shared dock background), while
/// the dark value is forced to white so the raw-mode preview still reads as paper in dark theme.
final ocptTheme = ActThemeModel<OcptSpecificColors>(
  lightColors: ActThemeColors<OcptSpecificColors>(
    colorScheme: _lightColorScheme,
    colorExtensions: OcptSpecificColors(previewBackdrop: _lightColorScheme.surfaceContainerLow),
  ),
  darkColors: ActThemeColors<OcptSpecificColors>(
    colorScheme: _darkColorScheme,
    colorExtensions: const OcptSpecificColors(previewBackdrop: Colors.white),
  ),
);
