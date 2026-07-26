// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_utility/act_dart_utility.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// The themes handled by [ActThemesManager] for this application.
///
/// The application currently defines a single theme, built from [ocpt_theme.ocptTheme], with a
/// light and a dark variant. The variant actually shown to the user is driven by the brightness
/// preference persisted by [ActThemesManager], defaulting to the system brightness.
enum OcptAppTheme with MixinStringValueType, MixinActThemes {
  /// The single theme of the application, combining its light and dark variants.
  standard;

  /// {@macro act_themes_manager.MixinActThemes.themeData}
  @override
  ActThemeModel get themeData => ocpt_theme.ocptTheme;
}
