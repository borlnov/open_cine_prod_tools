// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListBloc` about floor plan sets and view settings.
sealed class OcptShotListFloorPlanViewEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListFloorPlanViewEvent();
}

/// Picks the floor plans canvas's own active tool, dispatched by the tool bar.
class OcptShotListFloorPlanToolSelectedEvent extends OcptShotListFloorPlanViewEvent {
  /// The tool just picked.
  final OcptFloorPlanTool tool;

  /// Class constructor
  const OcptShotListFloorPlanToolSelectedEvent({required this.tool});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tool];
}

/// Clears `OcptShotListState.pendingCharacterNamePromptSymbolId`, dispatched by the mode's own
/// `BlocConsumer` listener the moment it opens `OcptFloorPlanCharacterNamePickerDialog` for it —
/// see that field's own doc comment for why the clear happens before the dialog's own result is
/// known.
class OcptShotListFloorPlanCharacterNamePromptDismissedEvent
    extends OcptShotListFloorPlanViewEvent {
  /// Class constructor
  const OcptShotListFloorPlanCharacterNamePromptDismissedEvent();
}
