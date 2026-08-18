// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What kind of character a `roles` row is, and where its name comes from.
enum OcptRoleKind {
  /// A speaking character: reconciled from a dialogue cue (`OcptRoleIndexService`), never typed
  /// from nothing.
  speaking,

  /// A silent (non-speaking) character: reconciled from a name standing in capitals in the action,
  /// or added by hand for one the screenplay names no other way — see
  /// `OcptRolesTable.isFromScreenplay` for how the two are told apart.
  silent,

  /// An extra or a group of extras, added by hand.
  extra,
}
