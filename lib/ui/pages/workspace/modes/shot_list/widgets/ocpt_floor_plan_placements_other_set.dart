// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_placements_group.dart'
    show OcptFloorPlanPlacementsGroup;

/// One other set of the sequence, for [OcptFloorPlanPlacementsGroup]'s own trailing list — whether
/// the selected shot has a camera placed there too (`Hallway · no camera for this shot`).
class OcptFloorPlanPlacementsOtherSet {
  /// The other set's own name.
  final String setName;

  /// How many of the shot's own cameras are placed on that set.
  final int cameraCount;

  /// Class constructor
  const OcptFloorPlanPlacementsOtherSet({required this.setName, required this.cameraCount});
}
