// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What kind of character a `roles` row is, and where its name comes from.
enum OcptRoleKind {
  /// A speaking character: reconciled from the screenplay's own speaking characters
  /// (`OcptRoleIndexService`), never typed from nothing.
  speaking,

  /// A silent (non-speaking) character, added by hand: the screenplay never names it as a cue, so
  /// reconciliation cannot find it on its own.
  silent,

  /// An extra or a group of extras, added by hand.
  extra,
}
