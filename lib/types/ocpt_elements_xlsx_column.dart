// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported elements sheet, in the order the sheet lays them out, following the
/// element sheet's own top-down reading — identification, sourcing, tracking, scenes, then notes.
enum OcptElementsXlsxColumn {
  /// The element's top-level category.
  category,

  /// The element's finer, free-text sub-category.
  subCategory,

  /// The element's short breakdown code.
  code,

  /// The element's display name.
  name,

  /// How many of the element are needed, free text.
  quantity,

  /// Where the element comes from, or is going to.
  sourceKind,

  /// The element's owner: the person's display name when there is one, [ownerNotes] otherwise.
  owner,

  /// Free-text notes on who owns the element (an organisation, most often).
  ownerNotes,

  /// The display name of the person who brings the element to set.
  broughtBy,

  /// Where the element is stored until the shoot.
  storageNotes,

  /// Whether the element is secured (owned, borrowed, rented or bought).
  secured,

  /// Whether the element is ready for the shoot.
  ready,

  /// Whether the element has been returned after the shoot.
  returned,

  /// How far along the element is, derived from [secured]/[ready]/[returned].
  trackingStatus,

  /// The element's cost, in a plain currency amount.
  cost,

  /// The scenes needing the element, each with its own quantity and notes, joined.
  scenes,

  /// Why the element is needed.
  purposeNotes,

  /// Free-form notes about the element.
  notes,
}
