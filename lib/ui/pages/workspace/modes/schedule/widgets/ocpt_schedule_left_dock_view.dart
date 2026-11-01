// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';

/// The schedule mode's left dock, the shell's `leftPanel`: the shooting days over the shots still
/// to place, an [OcptScheduleLeftDock] wired to the mode bloc.
///
/// Every write a day offers is withheld while a version is previewed. Deleting a day is only
/// *asked*, through [onDayDeletionRequested]: the mode owns the confirmation dialog.
class OcptScheduleLeftDockView extends StatelessWidget {
  /// The mode's state, which the days, the selection and the unplaced shots are read from.
  final OcptScheduleState state;

  /// Called with the id of the day the user asked to delete.
  final ValueChanged<String> onDayDeletionRequested;

  /// Class constructor
  const OcptScheduleLeftDockView({
    super.key,
    required this.state,
    required this.onDayDeletionRequested,
  });

  /// Build the schedule left dock view as an [OcptScheduleLeftDock].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptScheduleBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptScheduleLeftDock(
      days: state.days,
      selectedDayId: state.selectedDayId,
      blockCountByDayId: {
        for (final day in state.days) day.id: state.snapshot?.blocksByDayId[day.id]?.length ?? 0,
      },
      firstLocationByDayId: {
        for (final day in state.days) day.id: state.firstLocationOfDay(day.id),
      },
      alertsOfDay: state.alertsOfDay,
      onDaySelected: (dayId) => bloc.add(OcptScheduleDaySelectedEvent(dayId: dayId)),
      onDayCreated: isReadOnly ? null : (date) => bloc.add(OcptScheduleDayCreatedEvent(date: date)),
      onDayDateChangeRequested: isReadOnly
          ? null
          : (dayId, date) => bloc.add(OcptScheduleDayDateChangedEvent(dayId: dayId, date: date)),
      onDayDuplicationRequested: isReadOnly
          ? null
          : (dayId, date) =>
                bloc.add(OcptScheduleDayDuplicationRequestedEvent(sourceDayId: dayId, date: date)),
      onDayDeletionRequested: isReadOnly ? null : onDayDeletionRequested,
      unplacedGroups: state.unplacedGroups,
      episodes: state.episodes,
      selectedShotId: state.selectedShotId,
      onShotSelected: (shotId) => bloc.add(OcptScheduleShotSelectedEvent(shotId: shotId)),
    );
  }
}
