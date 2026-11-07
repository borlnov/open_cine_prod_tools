// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_alerts_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_open_day.dart';

/// The `Alerts` tab's own content: every alert the whole shoot currently raises, with the
/// whole-schedule slot and block maps its cards need to resolve a card that isn't scoped to the
/// selected day — unlike the `Convocations` tab's own `slotById`, which only ever needs the
/// selected day's slots.
class OcptScheduleAlertsView extends StatelessWidget {
  /// The mode's state, which the alerts and the maps their cards resolve through are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptScheduleAlertsView({super.key, required this.state});

  /// Build the schedule alerts view as an [OcptScheduleAlertsPanel].
  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;

    final slotById = <String, OcptShootingSlot>{
      for (final slots in snapshot?.slotsByDayId.values ?? const <List<OcptShootingSlot>>[])
        for (final slot in slots) slot.id: slot,
    };
    final blockById = <String, OcptShootingDayBlock>{
      for (final blocks in snapshot?.blocksByDayId.values ?? const <List<OcptShootingDayBlock>>[])
        for (final block in blocks) block.id: block,
    };

    return OcptScheduleAlertsPanel(
      alerts: state.planSnapshot?.alerts ?? const <OcptScheduleAlert>[],
      personById: state.personById,
      roleById: state.roleById,
      locationById: state.locationById,
      daysById: state.daysById,
      slotById: slotById,
      blockById: blockById,
      shotOf: state.shotById,
      onDayOpenRequested: (dayId) => ocptScheduleOpenDay(context, dayId),
    );
  }
}
