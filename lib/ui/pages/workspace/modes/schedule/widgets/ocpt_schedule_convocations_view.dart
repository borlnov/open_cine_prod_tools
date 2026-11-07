// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_convocations_panel.dart';

/// The `Convocations` tab's own content: the selected day's whole call, or nothing while no day is
/// selected — [OcptScheduleConvocationsPanel] tells the two apart through whether
/// [OcptScheduleState.selectedDayId] itself is null, rather than through the emptiness of the list,
/// a day with no convocation yet being a different fact from no day chosen at all.
class OcptScheduleConvocationsView extends StatelessWidget {
  /// The mode's state, which the selected day's convocations are read from.
  final OcptScheduleState state;

  /// Class constructor
  const OcptScheduleConvocationsView({super.key, required this.state});

  /// Build the schedule convocations view as an [OcptScheduleConvocationsPanel].
  @override
  Widget build(BuildContext context) {
    final selectedDayId = state.selectedDayId;

    return OcptScheduleConvocationsPanel(
      convocations: selectedDayId == null ? null : state.convocationsOfDay(selectedDayId),
      personById: state.personById,
      roleById: state.roleById,
      slotById: {for (final slot in state.selectedDaySlots) slot.id: slot},
    );
  }
}
