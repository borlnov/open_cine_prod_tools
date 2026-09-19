// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which layer a `floor_plan_symbols` row is drawn on, and — through [OcptFloorPlanLayerScope]'s
/// [OcptFloorPlanLayerScope.isSequenceScoped] — which of the floor plan's two scopes that layer
/// belongs to (`docs/plans/storyboard.md`, §1, §2).
///
/// `floor_plan_symbols.shotId` is null exactly when a symbol's layer is sequence-scoped: the layer
/// is what decides the scope, and the floor plan service enforces that invariant at every write.
enum OcptFloorPlanLayer {
  /// A sequence layer: the décor's walls and fixed geometry, drawn once for the whole sequence.
  decor,

  /// A sequence layer: the movable furniture of the décor, drawn once for the whole sequence.
  furniture,

  /// A sequence layer: a fixed prop that stays put across every shot of the sequence.
  fixedProps,

  /// A shot layer: a camera position, one per shot (several per shot when the sequence multi-cams).
  cameras,

  /// A shot layer: a character's position for one shot, independent of the shot's own characters
  /// field (`docs/plans/storyboard.md`, §1).
  characters,

  /// A shot layer: a light's position for one shot.
  lights,

  /// A shot layer: a hand prop's position for one shot — as opposed to [fixedProps], which never
  /// moves between shots.
  handProps,
}

/// Whether a layer belongs to the floor plan's **sequence** scope (drawn once, per décor) or its
/// **shot** scope (one position per shot) — see [OcptFloorPlanLayer]'s own doc comment.
extension OcptFloorPlanLayerScope on OcptFloorPlanLayer {
  /// True for [OcptFloorPlanLayer.decor], [OcptFloorPlanLayer.furniture] and
  /// [OcptFloorPlanLayer.fixedProps]; false for every shot layer.
  ///
  /// A `switch` with no `default`: an eighth layer must be placed on one side or the other here
  /// rather than silently landing in whichever scope happens to be the fallback.
  bool get isSequenceScoped => switch (this) {
    OcptFloorPlanLayer.decor => true,
    OcptFloorPlanLayer.furniture => true,
    OcptFloorPlanLayer.fixedProps => true,
    OcptFloorPlanLayer.cameras => false,
    OcptFloorPlanLayer.characters => false,
    OcptFloorPlanLayer.lights => false,
    OcptFloorPlanLayer.handProps => false,
  };
}
