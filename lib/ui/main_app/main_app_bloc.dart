// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
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
  /// Class constructor
  OcptMainAppBloc() : super(const OcptMainAppState.init());
}
