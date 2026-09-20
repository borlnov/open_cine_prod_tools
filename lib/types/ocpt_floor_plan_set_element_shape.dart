// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The visual primitive a `floor_plan_symbols` set-element (sequence-layer) symbol is drawn as —
/// `floor_plan_symbols.setElementShape`. Null on a camera, character or light symbol, which don't
/// use it: only a symbol on `OcptFloorPlanLayer.set` carries one.
enum OcptFloorPlanSetElementShape {
  /// A straight wall segment.
  wall,

  /// A door opening.
  door,

  /// A piece of furniture.
  furniture,

  /// Any other décor shape, drawn free-hand.
  freeform,
}
