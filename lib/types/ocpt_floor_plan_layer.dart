// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which layer a `floor_plan_symbols` row is drawn on (`docs/plans/storyboard.md`, §1, §10).
///
/// A layer no longer decides a symbol's scope by itself — see `OcptFloorPlanScope` and
/// `OcptFloorPlanSymbolsTable`'s own doc comment for the scope matrix `OcptFloorPlanService`
/// enforces per layer at every write.
enum OcptFloorPlanLayer {
  /// The set's own walls, furniture and every other fixed piece of geometry — set scope (shared by
  /// every sequence the set is linked to) or scene scope (re-dressed for one sequence, through a
  /// `floor_plan_symbols.overridesSymbolId` override). Collapses the earlier `decor`,
  /// `furniture` and `fixedProps` layers into one — a set-element symbol's own type (a wall, a
  /// door, a piece of furniture, a free-hand shape) is already carried by
  /// `floor_plan_symbols.setElementShape`, so the layer itself no longer needs to distinguish them.
  set,

  /// A shot-scope layer: a camera position, one per shot (several per shot when the sequence
  /// multi-cams).
  cameras,

  /// A shot-scope layer: a character's position for one shot, independent of the shot's own
  /// characters field (`docs/plans/storyboard.md`, §1).
  characters,

  /// A shot-scope layer: a light's position for one shot.
  lights,

  /// A hand prop's position — scene scope (this sequence's own coverage) or shot scope (for now,
  /// `docs/plans/storyboard.md`, §10) — as opposed to a [set] element, which never moves between
  /// shots. Renamed from `handProps`.
  props,
}
