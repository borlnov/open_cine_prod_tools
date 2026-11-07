// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which gesture the floor plan underlay's own drag currently means.
enum OcptFloorPlanUnderlayDragKind {
  /// The underlay is being moved.
  move,

  /// The underlay is being resized around its own centre.
  resize,
}
