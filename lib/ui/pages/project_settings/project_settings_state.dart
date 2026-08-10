// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The state of `OcptProjectSettingsBloc`.
class OcptProjectSettingsState extends BlocStateForMixin<OcptProjectSettingsState> {
  /// Whether the project's currency and page format are still being loaded from the database.
  final bool isLoading;

  /// The current project's currency, as an ISO 4217 code.
  final String currencyCode;

  /// The current project's page format.
  final OcptPageFormat pageFormat;

  /// The current project's minimum rest between two shooting days, in minutes
  /// (`project_info.minimumRestMinutes`), or null while nobody has recorded one.
  final int? minimumRestMinutes;

  /// The project's live episodes, in `sortKey` order — what the `Episodes` card lists, re-read
  /// after every mutation it makes so the card always shows what the database holds.
  final List<OcptEpisode> episodes;

  /// Whether at least one field was changed since the page opened.
  ///
  /// This is what the page hands back to whichever mode pushed it, through
  /// `OcptRouterManager.pop<bool>`, so that mode knows whether it is worth reloading anything of
  /// its own (the screenplay repaginating on a page-format change, say) — every field here writes
  /// the moment it changes, so there is nothing left to flush on the way out. **The schedule mode
  /// depends on this flag for [minimumRestMinutes] specifically**: it re-reads the project's own
  /// minimum on `OcptScheduleProjectSettingsChangedEvent`, which fires exactly when this page pops
  /// with `hasChanged` true, so a rest-minimum edit that failed to set it would leave the rest-time
  /// alert stale until the next full load.
  final bool hasChanged;

  /// Class constructor
  const OcptProjectSettingsState({
    required this.isLoading,
    required this.currencyCode,
    required this.pageFormat,
    required this.minimumRestMinutes,
    required this.episodes,
    required this.hasChanged,
  });

  /// The initial state, shown for the brief moment before the load completes: [currencyCode] and
  /// [pageFormat] are placeholders never actually rendered, since the page shows a spinner while
  /// [isLoading].
  const OcptProjectSettingsState.init()
    : isLoading = true,
      currencyCode = "",
      pageFormat = OcptPageFormat.usLetter,
      minimumRestMinutes = null,
      episodes = const [],
      hasChanged = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [minimumRestMinutes] legitimately goes back to null while the page is open (the field is
  /// cleared), so it has its own [clearMinimumRestMinutes] flag rather than a bare nullable
  /// parameter, which could never tell "leave it alone" apart from "clear it".
  @override
  OcptProjectSettingsState copyWith({
    bool? isLoading,
    String? currencyCode,
    OcptPageFormat? pageFormat,
    int? minimumRestMinutes,
    bool clearMinimumRestMinutes = false,
    List<OcptEpisode>? episodes,
    bool? hasChanged,
  }) => OcptProjectSettingsState(
    isLoading: isLoading ?? this.isLoading,
    currencyCode: currencyCode ?? this.currencyCode,
    pageFormat: pageFormat ?? this.pageFormat,
    minimumRestMinutes: clearMinimumRestMinutes
        ? null
        : (minimumRestMinutes ?? this.minimumRestMinutes),
    episodes: episodes ?? this.episodes,
    hasChanged: hasChanged ?? this.hasChanged,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    currencyCode,
    pageFormat,
    minimumRestMinutes,
    episodes,
    hasChanged,
  ];
}
