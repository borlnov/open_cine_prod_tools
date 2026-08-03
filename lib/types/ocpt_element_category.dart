// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What kind of physical thing an `elements` row is: the top-level grouping the elements board is
/// organised by, aligned with standard breakdown ("dépouillement") practice.
enum OcptElementCategory {
  /// A prop: an object a character handles or that the action requires.
  prop,

  /// Set dressing: an object that furnishes or decorates a set without a character handling it.
  setDressing,

  /// A costume, worn by a character.
  costume,

  /// Make-up, prosthetics or hair material.
  makeup,

  /// A vehicle appearing on screen or used to move the production.
  vehicle,

  /// An animal appearing on screen.
  animal,

  /// Special/rigging equipment: harnesses, wires, pyrotechnics, weapons.
  specialEquipment,

  /// Camera department equipment beyond what a shot's own fields already describe: bodies, tripods,
  /// stabilisers, monitors.
  camera,

  /// Lighting and grip equipment.
  lighting,

  /// Sound recording equipment.
  sound,

  /// Production equipment: walkies, generators, tents, signage.
  production,

  /// Catering and craft services material.
  catering,

  /// A block of extras, tracked as a single element rather than as individual people.
  extras,

  /// Anything the categories above don't fit.
  other,
}
