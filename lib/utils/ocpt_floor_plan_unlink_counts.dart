// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// How many cameras, characters and props leave sequence [sceneId]'s own view of [floorPlanSet]
/// once it is unlinked from it — what the unlink confirmation dialog counts: "The set's plan is
/// kept", but every one of these placements
/// stops showing under this sequence until the set is linked again.
///
/// The count is **live symbols on [floorPlanSet] whose `shotId` belongs to one of [shotIdsOfScene]**
/// (this sequence's own shots' blocking) **plus [sceneId]'s own scene-scope symbols** (the props and
/// the re-dressed furniture placed for this sequence alone) — a set-scope symbol (the set's own
/// walls, doors and fixed furniture, shared by every sequence the set is linked to) is never
/// counted, since unlinking never touches it. Props counts both a shot-scope prop and a scene-scope
/// one, exactly as the plan's own wording ("props") makes no distinction between the two.
///
/// Lights are deliberately left out: the dialog only ever names cameras, characters and props.
({int cameras, int characters, int props}) ocptFloorPlanUnlinkCountsOf({
  required OcptFloorPlanSet floorPlanSet,
  required String sceneId,
  required Set<String> shotIdsOfScene,
}) {
  var cameras = 0;
  var characters = 0;
  var props = 0;

  for (final symbol in floorPlanSet.symbols) {
    final isShotOfScene = symbol.shotId != null && shotIdsOfScene.contains(symbol.shotId);
    final isSceneScope = symbol.sceneId == sceneId;
    if (!isShotOfScene && !isSceneScope) {
      continue;
    }

    switch (symbol.layer) {
      case OcptFloorPlanLayer.cameras:
        cameras++;
      case OcptFloorPlanLayer.characters:
        characters++;
      case OcptFloorPlanLayer.props:
        props++;
      case OcptFloorPlanLayer.lights:
      case OcptFloorPlanLayer.set:
        break;
    }
  }

  return (cameras: cameras, characters: characters, props: props);
}
