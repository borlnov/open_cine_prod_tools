// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';

/// Every floor plan set of a screenplay's sequences, as `OcptFloorPlanService.loadFloorPlans`
/// builds it — the floor plans view's counterpart to `OcptShotListSnapshot`.
///
/// [setsBySceneId] groups every live set under the sequence (scene) it belongs to, each group
/// already in [OcptFloorPlanSet.sortKey] order (its tab order); [setsById] is the flat lookup
/// built once alongside it, mirroring `OcptShotListSnapshot.shotsById`.
class OcptFloorPlanSnapshot extends Equatable {
  /// The screenplay this floor plan snapshot belongs to.
  final String screenplayId;

  /// Every live set, keyed by [OcptFloorPlanSet.sceneId].
  final Map<String, List<OcptFloorPlanSet>> setsBySceneId;

  /// Every live set of [setsBySceneId], keyed by its own id.
  final Map<String, OcptFloorPlanSet> setsById;

  /// Class constructor
  const OcptFloorPlanSnapshot({
    required this.screenplayId,
    required this.setsBySceneId,
    required this.setsById,
  });

  /// Builds an [OcptFloorPlanSnapshot] for [screenplayId] from [setsBySceneId], deriving
  /// [setsById] from it.
  factory OcptFloorPlanSnapshot.build({
    required String screenplayId,
    required Map<String, List<OcptFloorPlanSet>> setsBySceneId,
  }) {
    final setsById = <String, OcptFloorPlanSet>{
      for (final sets in setsBySceneId.values)
        for (final floorPlanSet in sets) floorPlanSet.id: floorPlanSet,
    };

    return OcptFloorPlanSnapshot(
      screenplayId: screenplayId,
      setsBySceneId: setsBySceneId,
      setsById: Map.unmodifiable(setsById),
    );
  }

  /// [sceneId]'s sets, in tab order, or an empty list if it has none.
  List<OcptFloorPlanSet> setsOfScene(String sceneId) =>
      setsBySceneId[sceneId] ?? const <OcptFloorPlanSet>[];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSnapshot(screenplayId: $screenplayId, setCount: ${setsById.length})";

  /// Object properties
  @override
  List<Object?> get props => [screenplayId, setsBySceneId, setsById];
}
