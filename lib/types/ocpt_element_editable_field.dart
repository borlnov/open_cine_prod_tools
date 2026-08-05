// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the element sheet's typed, free-text fields, whose edits go through the resources bloc's
/// 2 s autosave debounce (`OcptResourcesState.pendingElementFieldEdits`) rather than being written
/// immediately — mirroring `OcptPersonField`, `OcptRoleField`, `OcptLocationField` and
/// `OcptSetField`.
///
/// Every case maps onto one `OcptElementsService.updateElement` argument of the same name. The
/// discrete fields of `elements` are deliberately absent: the category, the provenance, the owner,
/// who brings it and the three tracking flags are each a single pick or a single tick rather than
/// typing, so they are written immediately by their own bloc events.
///
/// `code` is absent for a different reason again: it is the app's own
/// (`OcptElementsService.createElement` mints it, a category change is the only thing that ever
/// rewrites it), so no sheet offers to type into it — `OcptResourcesCodeReadOut` reads it out.
///
/// The per-scene quantity and notes of a `scene_elements` link are absent for a different reason:
/// they belong to the link, not to the element, and their row debounces them locally and reports
/// the whole link at once, exactly as an unavailability's reason does.
enum OcptElementField {
  /// Maps to `updateElement`'s `name`.
  name,

  /// Maps to `updateElement`'s `subCategory`.
  subCategory,

  /// Maps to `updateElement`'s `quantity`.
  quantity,

  /// Maps to `updateElement`'s `ownerNotes`.
  ownerNotes,

  /// Maps to `updateElement`'s `storageNotes`.
  storageNotes,

  /// Maps to `updateElement`'s `cost`.
  ///
  /// The one field that is typed but not stored as text: the bloc reads what was typed as an amount
  /// of money (`ocptCostCentsOf`) and writes null for anything it cannot, so a `gratuit` typed into
  /// it never blocks the field and never lands as a price either. The sheet flags it instead,
  /// exactly as the location sheet flags a malformed coordinate.
  cost,

  /// Maps to `updateElement`'s `purposeNotes`.
  purposeNotes,

  /// Maps to `updateElement`'s `notes`.
  notes,
}
