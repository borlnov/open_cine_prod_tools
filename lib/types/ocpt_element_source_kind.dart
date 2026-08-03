// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where an element comes from: how the production got it, or is going to.
enum OcptElementSourceKind {
  /// The production, or one of its crew, already owns it.
  owned,

  /// Borrowed from someone for the shoot, expected back afterwards.
  borrowed,

  /// Rented for the shoot, from a rental house or a shop.
  rented,

  /// Still needs to be bought.
  toBuy,

  /// Still needs to be made or built.
  toMake,

  /// Already on the set/location itself: nothing to bring.
  alreadyOnSet,
}
