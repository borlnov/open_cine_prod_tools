// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
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
  /// Creates the settings bloc.
  ///
  /// [appVersion] lets tests inject a fixed version instead of resolving
  /// [OcptGlobalManager.packageInfo], whose value is only available once every manager is ready
  /// and, in production, comes from the unmocked `PackageInfo.fromPlatform()` platform channel.
  factory OcptSettingsBloc({String? appVersion}) =>
      OcptSettingsBloc._(appVersion ?? OcptGlobalManager.instance.packageInfo.version);

  /// Private constructor building the initial state from the resolved [appVersion].
  OcptSettingsBloc._(String appVersion) : super(OcptSettingsState.init(appVersion: appVersion));
}
