// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which gesture a floor plan symbol's own drag currently means.
enum OcptFloorPlanSymbolDragKind {
  /// The symbol itself is being moved.
  move,

  /// The symbol's own footprint is being resized.
  resize,

  /// The symbol is being aimed (rotated) around its own centre.
  rotate,

  /// A camera's own field-of-view angle is being changed.
  fov,

  /// A camera's own field-of-view reach (depth) is being changed.
  fovReach,
}
