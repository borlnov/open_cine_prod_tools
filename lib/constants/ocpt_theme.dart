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

/// The project poster tint family for dark theme: violet, blue, pink, green and amber, vivid
/// enough to read as distinct posters against the dark scheme's near-black card background.
/// `OcptProjectCard` indexes into this list by a stable hash of the project path.
const _darkProjectPosterTints = <Color>[
  Color(0xFF8B7FF0),
  Color(0xFF5B8DEF),
  Color(0xFFE0629B),
  Color(0xFF4CAF7D),
  Color(0xFFE0A73E),
];

/// The light-theme counterpart of [_darkProjectPosterTints]: the same five hues, lightened and
/// desaturated so they stay calm against the light scheme's near-white card background.
const _lightProjectPosterTints = <Color>[
  Color(0xFFC9C0F5),
  Color(0xFFBFD4F5),
  Color(0xFFF2C7DB),
  Color(0xFFC3E3D1),
  Color(0xFFF2DDB0),
];

/// The small corner radius: dropdowns/text fields, the scrollbar thumb and icon buttons.
///
/// Single source of truth for the shell widgets built in later milestones, which read this
/// constant instead of re-declaring their own radius.
const double ocptRadiusSmall = 6;

/// The medium corner radius: filled/outlined/text buttons and every menu surface (popup menu,
/// dropdown menu popup, `MenuAnchor`).
const double ocptRadiusMedium = 8;

/// The large corner radius: cards.
const double ocptRadiusLarge = 10;

/// The height of the shell's top toolbar band.
const double ocptToolbarHeight = 44;

/// The size of the toolbar's chrome buttons (the dock toggles, save and the `⋮` overflow), a
/// notch above the 28 px minimum the `iconButtonTheme` gives a mode's own controls, so the chrome
/// group reads as slightly weightier than whatever the active mode puts before it.
const double ocptToolbarChromeButtonSize = 30;

/// The height of the shell's bottom status bar band.
const double ocptStatusBarHeight = 26;

/// The height of the shell's bottom mode-switcher band.
const double ocptModeSwitcherHeight = 64;

/// The opacity applied to [ColorScheme.primary] for a selected control's background (an icon
/// button toggled on, the active entry of the mode switcher), so the tint reads as a soft wash
/// rather than a solid fill.
const double ocptSelectedStateAlpha = 0.16;

/// Builds the dense UI type scale of the studio design system from [baseThemeData]'s own
/// [ThemeData.textTheme], via [TextTheme.copyWith] so every slot keeps the brightness-correct
/// default color Material 3 computed for it (a hand-written [TextTheme] would lose that).
///
/// Only [TextStyle.fontSize] changes; weights, letter spacing and colors are left exactly as
/// Material 3 derived them, so the Material slot semantics existing call sites rely on (e.g.
/// `theme.textTheme.labelSmall` for the status bar) keep meaning what they mean today, just
/// smaller/denser.
///
/// The mapping from stock Material 3 sizes to the studio scale's five sizes (22, 13, 12, 11, 10)
/// follows the two data points the design gives explicitly — the app's biggest heading
/// ([TextTheme.headlineSmall], stock 24) becomes the scale's 22 px "title", and its smallest
/// label ([TextTheme.labelSmall], stock 11) becomes the scale's smallest 10 px — and interpolates
/// the remaining slots in between, one notch per Material tier, keeping each family's stock
/// ordering (title > body > label) intact:
///
/// | Slot | Stock size | Dense size |
/// | --- | --- | --- |
/// | `headlineSmall` | 24 | 22 (the "title") |
/// | `titleMedium` | 16 | 13 |
/// | `titleSmall` | 14 | 12 |
/// | `bodyLarge` | 16 | 13 |
/// | `bodyMedium` | 14 | 12 |
/// | `bodySmall` | 12 | 11 |
/// | `labelLarge` | 14 | 11 |
/// | `labelMedium` | 12 | 10 |
/// | `labelSmall` | 11 | 10 |
///
/// `displayLarge`/`displayMedium`/`displaySmall`, `headlineLarge`/`headlineMedium` and
/// `titleLarge` are left untouched: nothing in the app renders through them today, so there is no
/// existing call site to keep dense and no data point in the design to place them against.
TextTheme _buildTextTheme({required ThemeData baseThemeData}) {
  final base = baseThemeData.textTheme;
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(fontSize: 22),
    titleMedium: base.titleMedium?.copyWith(fontSize: 13),
    titleSmall: base.titleSmall?.copyWith(fontSize: 12),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 13),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 12),
    bodySmall: base.bodySmall?.copyWith(fontSize: 11),
    labelLarge: base.labelLarge?.copyWith(fontSize: 11),
    labelMedium: base.labelMedium?.copyWith(fontSize: 10),
    labelSmall: base.labelSmall?.copyWith(fontSize: 10),
  );
}

/// Builds the studio design system's component themes from [baseThemeData] (already carrying the
/// dense [TextTheme] [_buildTextTheme] produced, since [ActThemeModel] applies
/// `overrideDefaultTextTheme` before `overrideDefaultThemeData`).
///
/// Every color read below comes from `baseThemeData.colorScheme`, never a literal hex, so this one
/// builder serves both [_lightColorScheme] and [_darkColorScheme] correctly.
ThemeData _buildThemeData({required ThemeData baseThemeData}) {
  final colorScheme = baseThemeData.colorScheme;
  final textTheme = baseThemeData.textTheme;

  return baseThemeData.copyWith(
    // Flat, bordered card: `surfaceContainerLow` fill, a 1 px `outlineVariant` border instead of
    // the stock elevation tint, and the large radius.
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    // Medium radius instead of the stock stadium shape, a denser 9x16 padding and a smaller,
    // semibold label. Colors are left to Material 3's own default resolution (`primary`/
    // `onPrimary`), which is already colorScheme-driven.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusMedium)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    // Medium radius instead of the stock stadium shape. The border stays `outline` and the fill
    // stays transparent, exactly as stock Material 3 already resolves them, so only the shape
    // changes; `side` is still spelled out explicitly (rather than left to the default) so this
    // theme is the one legible place that color comes from.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusMedium)),
        side: BorderSide(color: colorScheme.outline),
        backgroundColor: Colors.transparent,
      ),
    ),
    // Not itemized in the design table on its own, but kept visually consistent with its filled
    // and outlined siblings: same medium radius, default colors untouched.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusMedium)),
      ),
    ),
    // Square-ish, small-radius icon buttons instead of the stock 40 px circle, with a soft
    // `primary` wash at [ocptSelectedStateAlpha] when toggled on (the format/preview/syntax
    // toggles all use `IconButton.isSelected`) instead of the stock behavior.
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusSmall)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(28, 28)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    // Filled, bordered, dense text fields instead of the stock underline: `surfaceContainer` fill,
    // a 1 px `outline` border (thicker and `primary` when focused, `error` on error), small
    // radius.
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    ),
    // The app has no `DropdownMenu` call site yet (today's dropdowns use the older
    // `DropdownButton`, which has no dedicated component theme), but the design table's "dropdown
    // / text field" row is wired up here too so a future `DropdownMenu` inherits it for free: the
    // same dense field styling as [inputDecorationTheme], with its popup list styled like
    // [popupMenuTheme] below.
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyMedium,
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusMedium)),
        ),
      ),
    ),
    // `surfaceContainerHigh`, medium radius, a soft (low) shadow instead of the stock small radius
    // and mid elevation, and the design's 6 px menu padding (the space around the item list, top
    // and bottom).
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusMedium)),
      elevation: 3,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
    ),
    // Not itemized in the design table on its own (nothing in the app builds a `MenuAnchor` yet),
    // kept visually consistent with [popupMenuTheme] so a future one inherits the same surface.
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(ocptRadiusMedium)),
        ),
      ),
    ),
    // A thin `outlineVariant` line with no surrounding space, instead of the stock 16 px of
    // vertical breathing room.
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1, space: 1),
    // A thin, always-visible `outline` thumb over a transparent track, instead of the platform
    // default.
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(colorScheme.outline),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      thickness: const WidgetStatePropertyAll(10),
      radius: const Radius.circular(ocptRadiusSmall),
      crossAxisMargin: 2,
      mainAxisMargin: 2,
    ),
    // Not itemized in the design table on its own; kept at Material 3's own `inverseSurface` /
    // `onInverseSurface` colors (already colorScheme-driven), only tightened to the small radius
    // for consistency with every other surface this theme defines.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
    ),
  );
}

/// This defines the light and dark themes of the app.
///
/// [OcptSpecificColors] carries the two application-specific colors that fall outside the
/// standard Material 3 [ColorScheme]: `previewBackdrop` (the light value matches
/// [_lightColorScheme]'s own `surfaceContainerLow`, so light mode stays byte-identical to the
/// shared dock background, while the dark value is forced to white so the raw-mode preview still
/// reads as paper in dark theme) and `projectPosterTints` ([_lightProjectPosterTints] /
/// [_darkProjectPosterTints]).
///
/// [_buildTextTheme] and [_buildThemeData] carry the studio design system's density, shapes and
/// type scale; both read every color from the [ThemeData] they are handed, so the same pair of
/// builders serves [_lightColorScheme] and [_darkColorScheme] correctly.
///
/// `fontFamily` is bundled explicitly (`assets/fonts/roboto/`) rather than left to the platform
/// default: Flutter's Material default already resolves to Roboto, but only Linux ships it
/// out of the box, so leaving it unset would make Windows fall back to a different system font.
final ocptTheme = ActThemeModel<OcptSpecificColors>(
  lightColors: ActThemeColors<OcptSpecificColors>(
    colorScheme: _lightColorScheme,
    colorExtensions: OcptSpecificColors(
      previewBackdrop: _lightColorScheme.surfaceContainerLow,
      projectPosterTints: _lightProjectPosterTints,
    ),
  ),
  darkColors: ActThemeColors<OcptSpecificColors>(
    colorScheme: _darkColorScheme,
    colorExtensions: const OcptSpecificColors(
      previewBackdrop: Colors.white,
      projectPosterTints: _darkProjectPosterTints,
    ),
  ),
  fontFamily: 'Roboto',
  overrideDefaultTextTheme: _buildTextTheme,
  overrideDefaultThemeData: _buildThemeData,
);
