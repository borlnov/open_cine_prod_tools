// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the roles table's typed, free-text fields, whose edits go through the resources bloc's
/// 2 s autosave debounce (`OcptResourcesState.pendingRoleFieldEdits`) rather than being written
/// immediately — mirroring `OcptPersonField`'s own split between typed and discrete fields.
///
/// Every case maps onto one `OcptRoleIndexService.updateRole` argument of the same name. The
/// discrete fields of `roles` — `personId` (the cast member) and `kind` — are deliberately absent
/// from this enum: casting a person and picking a role's kind are each a single menu pick rather
/// than typing, so they are written immediately by their own bloc events instead, exactly as a
/// person's colour swatch is.
enum OcptRoleField {
  /// Maps to `updateRole`'s `name`.
  ///
  /// Meaningful for a hand-added role only: typing into a `isFromScreenplay` role's name is
  /// withheld by the widgets, since the next save's reconciliation would overwrite it right back.
  name,

  /// Maps to `updateRole`'s `castingNotes`.
  castingNotes,
}
