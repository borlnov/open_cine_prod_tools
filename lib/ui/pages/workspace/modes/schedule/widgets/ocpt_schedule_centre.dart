// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_agenda_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_positions_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_presence_view.dart';

/// The schedule's centre, the shell's `centre`: the header band, then whichever of the day view,
/// the agenda, the positions matrix or the presence grid [OcptScheduleState.centreView] names.
///
/// Everything irreversible the day view offers is only *asked*, through the `on…Requested`
/// callbacks below: the mode owns the confirmation dialogs, and the shot picker it opens.
class OcptScheduleCentre extends StatelessWidget {
  /// The mode's state, which the centre view and the header's presentation are read from.
  final OcptScheduleState state;

  /// Called with the id of the slot the user asked to delete.
  final ValueChanged<String> onSlotDeletionRequested;

  /// Called with the id of the block the user asked to delete.
  final ValueChanged<String> onBlockDeletionRequested;

  /// Called with the id of the day event the user asked to delete.
  final ValueChanged<String> onEventDeletionRequested;

  /// Called with the id of the slot the user asked to place a shot on.
  final ValueChanged<String> onShotBlockRequested;

  /// Class constructor
  const OcptScheduleCentre({
    super.key,
    required this.state,
    required this.onSlotDeletionRequested,
    required this.onBlockDeletionRequested,
    required this.onEventDeletionRequested,
    required this.onShotBlockRequested,
  });

  /// Build the schedule centre as a [Column].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptScheduleBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptScheduleHeader(
          centreView: state.centreView,
          onCentreViewSelected: (view) => bloc.add(OcptScheduleCentreViewSelectedEvent(view: view)),
          agendaMode: state.agendaMode,
          onAgendaModeSelected: (mode) => bloc.add(OcptScheduleAgendaModeSelectedEvent(mode: mode)),
          agendaColorMode: state.agendaColorMode,
          onAgendaColorModeSelected: (mode) =>
              bloc.add(OcptScheduleAgendaColorModeSelectedEvent(mode: mode)),
          agendaAnchorDate: state.agendaAnchorDate,
          onAgendaAnchorDateChanged: (date) =>
              bloc.add(OcptScheduleAgendaAnchorDateChangedEvent(date: date)),
          firstWeekday: state.firstWeekday,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: switch (state.centreView) {
              OcptScheduleCentreView.day => OcptScheduleDayCentreView(
                state: state,
                onSlotDeletionRequested: onSlotDeletionRequested,
                onBlockDeletionRequested: onBlockDeletionRequested,
                onEventDeletionRequested: onEventDeletionRequested,
                onShotBlockRequested: onShotBlockRequested,
              ),
              OcptScheduleCentreView.agenda => OcptScheduleAgendaView(state: state),
              OcptScheduleCentreView.positions => OcptSchedulePositionsView(state: state),
              OcptScheduleCentreView.presence => OcptSchedulePresenceView(state: state),
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
