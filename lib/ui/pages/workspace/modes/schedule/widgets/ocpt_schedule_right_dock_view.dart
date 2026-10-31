// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_alerts_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_convocations_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_versions_panel.dart';

/// The schedule's tabbed right dock, the shell's `rightPanel`: the inspector, the selected day's
/// convocations, the alerts of the whole shoot and the `Versions` tab, an [OcptScheduleRightDock]
/// drawing nothing while the dock is closed.
///
/// Deleting a day event is only *asked*, through [onEventDeletionRequested]: the mode owns the
/// confirmation dialog.
class OcptScheduleRightDockView extends StatelessWidget {
  /// The mode's state, which the dock's tab is read from and the tabs' content is built out of.
  final OcptScheduleState state;

  /// Called with the id of the day event the user asked to delete.
  final ValueChanged<String> onEventDeletionRequested;

  /// Class constructor
  const OcptScheduleRightDockView({
    super.key,
    required this.state,
    required this.onEventDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return const SizedBox.shrink();
    }

    return OcptScheduleRightDock(
      activeTab: rightDockTab,
      inspectorChild: OcptScheduleInspectorView(
        state: state,
        onEventDeletionRequested: onEventDeletionRequested,
      ),
      convocationsChild: OcptScheduleConvocationsView(state: state),
      alertsChild: OcptScheduleAlertsView(state: state),
      versionsChild: OcptScheduleVersionsPanel(state: state),
      onTabSelected: (tab) =>
          context.read<OcptScheduleBloc>().add(OcptScheduleRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptScheduleBloc>().add(const OcptScheduleRightDockClosedEvent()),
    );
  }
}
