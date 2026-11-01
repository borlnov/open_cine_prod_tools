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
