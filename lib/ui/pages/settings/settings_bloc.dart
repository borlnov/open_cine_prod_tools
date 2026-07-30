// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_intl_ui/act_intl_ui.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_state.dart';

/// This is the bloc class for the settings page.
///
/// It keeps the [OcptSettingsState] in sync with the wanted locale persisted through the
/// [LocalesManager] and the theme/brightness persisted through the [ActThemesManager] (both ACT
/// mixins apply their changes live, app-wide), and carries the app version injected at
/// construction.
class OcptSettingsBloc extends BlocForMixin<OcptSettingsState>
    with
        MixinSetWantedLocaleBloc<OcptSettingsState>,
        MixinActThemesBloc<ActThemesManager, OcptSettingsState> {
  /// Creates the settings bloc, with an initial state carrying the preferences the [LocalesManager]
  /// and the [ActThemesManager] currently hold, so the page opens on the options actually in use.
  ///
  /// Those managers' streams emit on change and never replay their current value to a new
  /// listener, so neither mixin can push the stored preferences into a freshly built state: a
  /// state starting at "follow the system" would keep claiming so until the user changes
  /// something, and would silently swallow the first pick matching the stored value (choosing
  /// "Dark" while dark is already the persisted preference emits nothing).
  ///
  /// [appVersion] lets tests inject a fixed version instead of resolving
  /// [OcptGlobalManager.packageInfo], whose value is only available once every manager is ready
  /// and, in production, comes from the unmocked `PackageInfo.fromPlatform()` platform channel.
  factory OcptSettingsBloc({String? appVersion}) {
    final localesManager = globalGetIt().get<LocalesManager>();
    final themesManager = globalGetIt().get<ActThemesManager>();

    return OcptSettingsBloc._(
      OcptSettingsState(
        appVersion: appVersion ?? OcptGlobalManager.instance.packageInfo.version,
        currentLocale: localesManager.currentLocale,
        wantedLocale: localesManager.wantedLocale,
        currentTheme: themesManager.currentTheme,
        brightness: themesManager.brightness,
      ),
    );
  }

  /// Private constructor taking the state the factory seeded from the managers.
  OcptSettingsBloc._(super.initialState);
}
