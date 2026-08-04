// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported roles sheet, in the order the sheet lays them out, following the
/// role sheet's own top-down reading.
enum OcptRolesXlsxColumn {
  /// The role's 1-based rank in `sortKey` order.
  number,

  /// The character's name.
  name,

  /// Whether the role is a speaking role, a silent role or an extra.
  kind,

  /// The display name of the person cast in the role, or empty while it is uncast.
  castMember,

  /// Whether the role's name is owned by the screenplay reconciliation.
  fromScreenplay,

  /// Whether the role's character has disappeared from the screenplay since it was created.
  removedFromScreenplay,

  /// Casting notes for the role.
  castingNotes,
}
