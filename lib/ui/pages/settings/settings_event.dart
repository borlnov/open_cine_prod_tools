// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';

/// The events handled by `OcptSettingsBloc` on its own account.
///
/// The locale and the brightness are **not** among them: both ride the ACT mixins the bloc mixes
/// in (`MixinSetWantedLocaleBloc`, `MixinActThemesBloc`), which carry their own events and apply
/// their changes app-wide. Only the preferences this app persists itself go through here.
sealed class OcptSettingsEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptSettingsEvent();
}

/// Requests reading the preferences `OcptPropertiesManager` holds into the state.
///
/// Dispatched once by the bloc's own constructor: unlike the locale and the theme, which their
/// managers already hold in memory and the bloc's factory reads synchronously, a stored preference
/// is loaded asynchronously, so the page opens on the default and corrects itself a frame later.
class OcptSettingsPreferencesLoadRequestedEvent extends OcptSettingsEvent {
  /// Class constructor
  const OcptSettingsPreferencesLoadRequestedEvent();
}

/// Requests storing [firstWeekday] as the app-wide day a week starts on.
class OcptSettingsFirstWeekdayChangedEvent extends OcptSettingsEvent {
  /// The day a week is to start on from now on.
  final OcptFirstWeekday firstWeekday;

  /// Class constructor
  const OcptSettingsFirstWeekdayChangedEvent({required this.firstWeekday});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, firstWeekday];
}
