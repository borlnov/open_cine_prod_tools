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
  /// The sequence's only sequence layer: the set's walls, furniture and every other fixed piece of
  /// geometry, drawn once for the whole sequence. Collapses the earlier `decor`, `furniture` and
  /// `fixedProps` layers into one — a set-element symbol's own type (a wall, a door, a piece of
  /// furniture, a free-hand shape) is already carried by `floor_plan_symbols.setElementShape`, so
  /// the layer itself no longer needs to distinguish them.
  set,

  /// A shot layer: a camera position, one per shot (several per shot when the sequence multi-cams).
  cameras,

  /// A shot layer: a character's position for one shot, independent of the shot's own characters
  /// field (`docs/plans/storyboard.md`, §1).
  characters,

  /// A shot layer: a light's position for one shot.
  lights,

  /// A shot layer: a hand prop's position for one shot — as opposed to a [set] element, which never
  /// moves between shots. Renamed from `handProps`.
  props,
}

/// Whether a layer belongs to the floor plan's **sequence** scope (drawn once, per set) or its
/// **shot** scope (one position per shot) — see [OcptFloorPlanLayer]'s own doc comment.
extension OcptFloorPlanLayerScope on OcptFloorPlanLayer {
  /// True for [OcptFloorPlanLayer.set]; false for every shot layer.
  ///
  /// A `switch` with no `default`: a sixth layer must be placed on one side or the other here
  /// rather than silently landing in whichever scope happens to be the fallback.
  bool get isSequenceScoped => switch (this) {
    OcptFloorPlanLayer.set => true,
    OcptFloorPlanLayer.cameras => false,
    OcptFloorPlanLayer.characters => false,
    OcptFloorPlanLayer.lights => false,
    OcptFloorPlanLayer.props => false,
  };
}
