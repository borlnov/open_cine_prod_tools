// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What a `floor_plan_arrows` row means, drawn between two symbols of the same case.
enum OcptFloorPlanArrowKind {
  /// A movement between two symbols — an actor walking to a door, an object being carried across
  /// the room.
  movement,

  /// A camera move — from a camera symbol to what it pans, tilts or dollies to.
  cameraMove,
}
