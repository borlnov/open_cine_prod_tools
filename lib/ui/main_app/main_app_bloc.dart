// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_intl_ui/act_intl_ui.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:open_cine_prod_tools/ui/main_app/main_app_state.dart';

/// This is the bloc class for the main app ui.
///
/// It keeps the [OcptMainAppState] in sync with the wanted locale persisted through the
/// [LocalesManager] and the theme/brightness persisted through the [ActThemesManager], so the
/// root app shell can react live to both.
class OcptMainAppBloc extends BlocForMixin<OcptMainAppState>
    with
        MixinGetWantedLocaleBloc<OcptMainAppState>,
        MixinActThemesBloc<ActThemesManager, OcptMainAppState> {
  /// Creates the main app bloc, with an initial state carrying the preferences the
  /// [LocalesManager] and the [ActThemesManager] currently hold.
  ///
  /// [ActThemesManager]'s streams emit on change and never replay their current value to a new
  /// listener, so a state starting at "follow the system" would keep the app on the system
  /// brightness for the whole run, ignoring the brightness the user had persisted.
  factory OcptMainAppBloc() {
    final themesManager = globalGetIt().get<ActThemesManager>();

    return OcptMainAppBloc._(
      OcptMainAppState(
        wantedLocale: globalGetIt().get<LocalesManager>().wantedLocale,
        currentTheme: themesManager.currentTheme,
        brightness: themesManager.brightness,
      ),
    );
  }

  /// Private constructor taking the state the factory seeded from the managers.
  OcptMainAppBloc._(super.initialState);
}
