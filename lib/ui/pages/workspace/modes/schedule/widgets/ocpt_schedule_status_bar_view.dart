// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_status_bar.dart';

/// The schedule mode's status bar: the counters of the whole shoot and where the selected day
/// ends, an [OcptScheduleStatusBar].
class OcptScheduleStatusBarView extends StatelessWidget {
  /// The mode's state, which the counters and the selected day are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptScheduleStatusBarView({super.key, required this.state});

  @override
  Widget build(BuildContext context) => OcptScheduleStatusBar(
    alertCount: state.planSnapshot?.alerts.length ?? 0,
    // Null on a single-episode project, which draws no counter for it at all — see
    // `OcptScheduleStatusBar`'s own doc comment.
    episodeCount: state.episodes.length > 1 ? state.episodes.length : null,
    dayCount: state.dayCount,
    placedShotCount: state.placedShotCount,
    shotsLeftToPlaceCount: state.shotsLeftToPlaceCount,
    isDaySelected: state.selectedDayId != null,
    selectedDayEndMinute: state.selectedDayId == null
        ? null
        : state.timelinesOfDay(state.selectedDayId!)?.dayEndMinute,
  );
}
