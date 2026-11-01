// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_month_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_open_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_strip_agenda.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_week_grid.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';

/// The schedule's agenda centre view: whichever of the three presentations
/// [OcptScheduleState.agendaMode] names — [OcptScheduleStripAgenda], [OcptScheduleWeekGrid] or
/// [OcptScheduleMonthGrid] — wired to the mode bloc.
class OcptScheduleAgendaView extends StatelessWidget {
  /// The mode's state, which the days, the agenda's presentation and its colouring are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptScheduleAgendaView({super.key, required this.state});

  /// Build the schedule agenda view.
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptScheduleBloc>();
    final firstLocationByDayId = {
      for (final day in state.days) day.id: state.firstLocationOfDay(day.id),
    };
    final dayTintOf = _dayTintOf(context);
    final blocksByDayId =
        state.snapshot?.blocksByDayId ?? const <String, List<OcptShootingDayBlock>>{};
    final slotsByDayId = state.snapshot?.slotsByDayId ?? const <String, List<OcptShootingSlot>>{};
    final eventsByDayId =
        state.snapshot?.eventsByDayId ?? const <String, List<OcptShootingDayEvent>>{};

    return switch (state.agendaMode) {
      OcptScheduleAgendaMode.strip => OcptScheduleStripAgenda(
        days: state.days,
        selectedDayId: state.selectedDayId,
        firstLocationByDayId: firstLocationByDayId,
        dayTintOf: dayTintOf,
        blocksByDayId: blocksByDayId,
        shotOf: state.shotById,
        timelineOf: state.timelinesOfDay,
        arrivalMinuteOf: state.dayArrivalMinute,
        alertsOfDay: state.alertsOfDay,
        onDayOpenRequested: (dayId) => ocptScheduleOpenDay(context, dayId),
        onBlockSelected: (blockId, dayId) =>
            bloc.add(OcptScheduleBlockSelectedEvent(blockId: blockId, dayId: dayId)),
      ),
      OcptScheduleAgendaMode.week => OcptScheduleWeekGrid(
        anchorDate: state.agendaAnchorDate,
        firstWeekday: state.firstWeekday,
        days: state.days,
        dayTintOf: dayTintOf,
        slotsByDayId: slotsByDayId,
        blocksByDayId: blocksByDayId,
        eventsByDayId: eventsByDayId,
        shotOf: state.shotById,
        timelineOf: state.timelinesOfDay,
        sunTimesOf: state.sunTimesOfDay,
        selectedDayId: state.selectedDayId,
        alertsOfDay: state.alertsOfDay,
        onDayOpenRequested: (dayId) => ocptScheduleOpenDay(context, dayId),
      ),
      OcptScheduleAgendaMode.month => OcptScheduleMonthGrid(
        anchorDate: state.agendaAnchorDate,
        firstWeekday: state.firstWeekday,
        days: state.days,
        slotsByDayId: slotsByDayId,
        firstLocationByDayId: firstLocationByDayId,
        dayTintOf: dayTintOf,
        timelineOf: state.timelinesOfDay,
        sunTimesOf: state.sunTimesOfDay,
        selectedDayId: state.selectedDayId,
        alertsOfDay: state.alertsOfDay,
        onDayOpenRequested: (dayId) => ocptScheduleOpenDay(context, dayId),
      ),
    };
  }

  /// Get the resolver every one of the three agendas' own tint reads through — a day's own
  /// [OcptScheduleState.firstLocationOfDay] under [OcptScheduleAgendaColorMode.location], or its
  /// `OcptSchedulePlanSnapshot.effectCategoryOfDay` under [OcptScheduleAgendaColorMode.effect] —
  /// built once per build so switching the "Colour by" control re-tints all three presentations at
  /// once without any of them knowing which fact they are currently reading.
  Color Function(String dayId) _dayTintOf(BuildContext context) => switch (state.agendaColorMode) {
    OcptScheduleAgendaColorMode.location => (dayId) => ocptScheduleDayLocationTint(
      context,
      state.firstLocationOfDay(dayId),
    ),
    OcptScheduleAgendaColorMode.effect => (dayId) => ocptScheduleDayEffectTint(
      context,
      state.planSnapshot?.effectCategoryOfDay(dayId),
    ),
  };
}
