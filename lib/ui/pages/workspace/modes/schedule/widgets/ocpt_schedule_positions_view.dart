// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_open_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_positions_matrix.dart';

/// The schedule's positions centre view: who holds which crew position, slot by slot, across the
/// whole shoot, an [OcptSchedulePositionsMatrix].
///
/// A position held on one slot and by nobody on the next is read straight off two neighbouring
/// columns, and raises no alert of its own — a crew that changes between two units is what a slot
/// is for.
class OcptSchedulePositionsView extends StatelessWidget {
  /// The mode's state, which the days, the slots and the people are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptSchedulePositionsView({super.key, required this.state});

  @override
  Widget build(BuildContext context) => OcptSchedulePositionsMatrix(
    days: state.days,
    slotsByDayId: state.snapshot?.slotsByDayId ?? const <String, List<OcptShootingSlot>>{},
    personById: state.personById,
    timelinesOfDay: state.timelinesOfDay,
    onDayOpenRequested: (dayId) => ocptScheduleOpenDay(context, dayId),
  );
}
