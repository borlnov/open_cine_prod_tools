// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The state of `OcptProjectSettingsBloc`.
class OcptProjectSettingsState extends BlocStateForMixin<OcptProjectSettingsState> {
  /// Whether the project's currency and page format are still being loaded from the database.
  final bool isLoading;

  /// The current project's currency, as an ISO 4217 code.
  final String currencyCode;

  /// The current project's page format.
  final OcptPageFormat pageFormat;

  /// Whether at least one field was changed since the page opened.
  ///
  /// This is what the page hands back to whichever mode pushed it, through
  /// `OcptRouterManager.pop<bool>`, so that mode knows whether it is worth reloading anything of
  /// its own (the screenplay repaginating on a page-format change, say) — every field here writes
  /// the moment it changes, so there is nothing left to flush on the way out.
  final bool hasChanged;

  /// Class constructor
  const OcptProjectSettingsState({
    required this.isLoading,
    required this.currencyCode,
    required this.pageFormat,
    required this.hasChanged,
  });

  /// The initial state, shown for the brief moment before the load completes: [currencyCode] and
  /// [pageFormat] are placeholders never actually rendered, since the page shows a spinner while
  /// [isLoading].
  const OcptProjectSettingsState.init()
    : isLoading = true,
      currencyCode = "",
      pageFormat = OcptPageFormat.usLetter,
      hasChanged = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptProjectSettingsState copyWith({
    bool? isLoading,
    String? currencyCode,
    OcptPageFormat? pageFormat,
    bool? hasChanged,
  }) => OcptProjectSettingsState(
    isLoading: isLoading ?? this.isLoading,
    currencyCode: currencyCode ?? this.currencyCode,
    pageFormat: pageFormat ?? this.pageFormat,
    hasChanged: hasChanged ?? this.hasChanged,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, isLoading, currencyCode, pageFormat, hasChanged];
}
