// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A `floor_plan_symbols` row's scope: what it is shared by. Derived from its own `sceneId`/
/// `shotId` nullness (`ocptFloorPlanScopeOf`) rather than kept as a column of its own
/// (`docs/plans/storyboard.md`, §10) — see `OcptFloorPlanSymbolsTable`'s own doc comment for the
/// scope matrix `OcptFloorPlanService` enforces per `OcptFloorPlanLayer`.
enum OcptFloorPlanScope {
  /// Shared by every sequence the plan's own Resources set is linked to (`scene_sets`): neither
  /// `sceneId` nor `shotId` is set.
  set,

  /// This sequence only: `sceneId` is set, `shotId` is null — a re-dressed set element (a
  /// [OcptFloorPlanScope.set]-scope symbol's scene-scope override, see
  /// `OcptFloorPlanSymbolsTable.overridesSymbolId`) or a prop placed for this sequence's own
  /// coverage.
  scene,

  /// This shot only: `shotId` is set — a camera, a character, a light or a hand prop placed for
  /// one shot's own blocking. `sceneId` is never stored alongside it: a shot-scope symbol's own
  /// sequence is read off the shot itself.
  shot,
}

/// Derives a `floor_plan_symbols` row's [OcptFloorPlanScope] from its own `sceneId`/`shotId`.
OcptFloorPlanScope ocptFloorPlanScopeOf({required String? sceneId, required String? shotId}) {
  if (shotId != null) {
    return OcptFloorPlanScope.shot;
  }
  return sceneId != null ? OcptFloorPlanScope.scene : OcptFloorPlanScope.set;
}
