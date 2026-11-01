// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_open_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_presence_grid.dart';

/// The schedule's presence centre view: who is working or unavailable, day by day, across the whole
/// shoot, an [OcptSchedulePresenceGrid].
///
/// [OcptSchedulePersonUnavailableAlert] is read straight out of the plan snapshot's own alerts
/// (rule 1 of `lib/models/rules/ocpt_schedule_alerts.dart`) rather than recomputed here.
class OcptSchedulePresenceView extends StatelessWidget {
  /// The mode's state, which the days, the people and the plan snapshot are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptSchedulePresenceView({super.key, required this.state});

  /// Build the schedule presence view as an [OcptSchedulePresenceGrid].
  @override
  Widget build(BuildContext context) {
    final planSnapshot = state.planSnapshot;

    return OcptSchedulePresenceGrid(
      days: state.days,
      people: state.people,
      roles: state.roles,
      presenceCellOf: (dayId, personId) =>
          planSnapshot?.presenceCellOf(dayId: dayId, personId: personId),
      unavailableAlerts: [
        for (final alert in planSnapshot?.alerts ?? const <OcptScheduleAlert>[])
          if (alert is OcptSchedulePersonUnavailableAlert) alert,
      ],
      onDayOpenRequested: (dayId) => ocptScheduleOpenDay(context, dayId),
    );
  }
}
