// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_copy_blocking_dialog.dart'
    show OcptFloorPlanCopyBlockingDialog;

/// One candidate shot [OcptFloorPlanCopyBlockingDialog] offers as the source of a
/// `OcptFloorPlanService.copyShotBlocking` call.
class OcptFloorPlanCopyBlockingCandidate {
  /// The candidate shot's own id.
  final String shotId;

  /// The candidate shot's own display code (`12/3`).
  final String shotCode;

  /// Class constructor
  const OcptFloorPlanCopyBlockingCandidate({required this.shotId, required this.shotCode});
}
