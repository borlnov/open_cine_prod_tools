// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';

/// Every floor plan case of a screenplay's sequences, as `OcptFloorPlanService.loadFloorPlans`
/// builds it — the floor plans view's counterpart to `OcptShotListSnapshot`.
///
/// [casesBySceneId] groups every live case under the sequence (scene) it belongs to, each group
/// already in [OcptFloorPlanCase.sortKey] order (its tab order); [casesById] is the flat lookup
/// built once alongside it, mirroring `OcptShotListSnapshot.shotsById`.
class OcptFloorPlanSnapshot extends Equatable {
  /// The screenplay this floor plan snapshot belongs to.
  final String screenplayId;

  /// Every live case, keyed by [OcptFloorPlanCase.sceneId].
  final Map<String, List<OcptFloorPlanCase>> casesBySceneId;

  /// Every live case of [casesBySceneId], keyed by its own id.
  final Map<String, OcptFloorPlanCase> casesById;

  /// Class constructor
  const OcptFloorPlanSnapshot({
    required this.screenplayId,
    required this.casesBySceneId,
    required this.casesById,
  });

  /// Builds an [OcptFloorPlanSnapshot] for [screenplayId] from [casesBySceneId], deriving
  /// [casesById] from it.
  factory OcptFloorPlanSnapshot.build({
    required String screenplayId,
    required Map<String, List<OcptFloorPlanCase>> casesBySceneId,
  }) {
    final casesById = <String, OcptFloorPlanCase>{
      for (final cases in casesBySceneId.values)
        for (final floorPlanCase in cases) floorPlanCase.id: floorPlanCase,
    };

    return OcptFloorPlanSnapshot(
      screenplayId: screenplayId,
      casesBySceneId: casesBySceneId,
      casesById: Map.unmodifiable(casesById),
    );
  }

  /// [sceneId]'s cases, in tab order, or an empty list if it has none.
  List<OcptFloorPlanCase> casesOfScene(String sceneId) =>
      casesBySceneId[sceneId] ?? const <OcptFloorPlanCase>[];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFloorPlanSnapshot(screenplayId: $screenplayId, caseCount: ${casesById.length})";

  /// Object properties
  @override
  List<Object?> get props => [screenplayId, casesBySceneId, casesById];
}
