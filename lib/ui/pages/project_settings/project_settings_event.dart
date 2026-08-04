// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The events handled by `OcptProjectSettingsBloc`.
sealed class OcptProjectSettingsEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectSettingsEvent();
}

/// Requests loading the current project's currency and page format into the page.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptProjectSettingsLoadRequestedEvent extends OcptProjectSettingsEvent {
  /// Class constructor
  const OcptProjectSettingsLoadRequestedEvent();
}

/// Reports that the user picked a different currency in the picker.
class OcptProjectSettingsCurrencyChangedEvent extends OcptProjectSettingsEvent {
  /// The ISO 4217 code the user picked.
  final String currencyCode;

  /// Class constructor
  const OcptProjectSettingsCurrencyChangedEvent({required this.currencyCode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, currencyCode];
}

/// Reports that the user picked a different page format in the dropdown.
class OcptProjectSettingsPageFormatChangedEvent extends OcptProjectSettingsEvent {
  /// The page format the user picked.
  final OcptPageFormat pageFormat;

  /// Class constructor
  const OcptProjectSettingsPageFormatChangedEvent({required this.pageFormat});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pageFormat];
}
