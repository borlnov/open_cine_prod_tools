// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What kind of catalogue row a `breakdown_tags` row points at.
///
/// A tag never invents a parallel record for a character or a block of extras: those are already
/// answered by `roles`, reconciled from the screenplay, so this discriminator names one of the
/// three tables a tag can point at — `elements`, `roles` or `sets` — rather than letting the mode
/// mix a fourth, purpose-built kind of target in.
enum OcptBreakdownTargetKind {
  /// The tag points at an `elements` row: a prop, a costume, a vehicle, or anything else the shoot
  /// must provide that is not a person or a set.
  element,

  /// The tag points at a `roles` row: a character or a block of extras.
  role,

  /// The tag points at a `sets` row: the set the tagged passage is set in.
  set,
}
