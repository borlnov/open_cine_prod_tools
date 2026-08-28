// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the person sheet's typed, free-text fields, whose edits go through the resources bloc's
/// 2 s autosave debounce (`OcptResourcesState.pendingFieldEdits`) rather than being written
/// immediately like a colour swatch or a difficulty dot would be — mirroring
/// `OcptShotListEditableField`'s own split between typed and discrete fields.
///
/// Every case maps onto one `OcptPeopleService.updatePerson` argument of the same name. The
/// discrete fields of `people` — `colorIndex`, `birthDate`, `isTransportAutonomous`,
/// `imageRightsStatus`, `imageRightsDate`, `mileageRateId` — are deliberately absent from this
/// enum: a colour swatch, a date picker, a status dropdown and a rate picker are each a single
/// action rather than typing, so they are written immediately by their own bloc events instead.
/// `mileageRateId` in particular picks from a project-wide catalogue rather than accepting free
/// text, exactly the reason a status dropdown is discrete rather than typed. The sub-lists
/// (positions,
/// skills, unavailabilities) are absent for the same reason `shotSize` alone, not a shot's
/// characters, is in `OcptShotListEditableField`: they are a different shape of edit (add/update/
/// remove a row) with their own events.
enum OcptPersonField {
  /// Maps to `updatePerson`'s `firstName`.
  firstName,

  /// Maps to `updatePerson`'s `lastName`.
  lastName,

  /// Maps to `updatePerson`'s `email`.
  email,

  /// Maps to `updatePerson`'s `phone`.
  phone,

  /// Maps to `updatePerson`'s `addressLine1`.
  addressLine1,

  /// Maps to `updatePerson`'s `addressLine2`.
  addressLine2,

  /// Maps to `updatePerson`'s `postalCode`.
  postalCode,

  /// Maps to `updatePerson`'s `city`.
  city,

  /// Maps to `updatePerson`'s `region`.
  region,

  /// Maps to `updatePerson`'s `country`.
  country,

  /// Maps to `updatePerson`'s `minorNotes`.
  minorNotes,

  /// Maps to `updatePerson`'s `maxDailyPresenceMinutes`.
  ///
  /// The one field of this enum that is typed but not stored as text, mirroring
  /// `OcptElementField.cost`: the bloc reads what was typed as a plain number of minutes
  /// (`ocptMaxDailyPresenceMinutesOf`) and writes null for anything it cannot, so a half-typed
  /// figure never blocks the field and never lands as a maximum either. The sheet flags it instead.
  maxDailyPresenceMinutes,

  /// Maps to `updatePerson`'s `commuteKmMilli`.
  ///
  /// Typed but not stored as text, mirroring [maxDailyPresenceMinutes]: the bloc reads what was
  /// typed as a distance in thousandths of a kilometre (`ocptBudgetQuantityMilliOf`,
  /// `lib/ui/utils/ocpt_budget_labels.dart` — the very parser the quote lines' own quantity field
  /// already uses) and writes null for anything it cannot, so a half-typed figure never blocks the
  /// field and never lands as a distance either.
  commuteKmMilli,

  /// Maps to `updatePerson`'s `accommodationNotes`.
  accommodationNotes,

  /// Maps to `updatePerson`'s `travelNotes`.
  travelNotes,

  /// Maps to `updatePerson`'s `dietaryNotes`.
  dietaryNotes,

  /// Maps to `updatePerson`'s `allergies`.
  allergies,

  /// Maps to `updatePerson`'s `measurementHeight`.
  measurementHeight,

  /// Maps to `updatePerson`'s `measurementChest`.
  measurementChest,

  /// Maps to `updatePerson`'s `measurementWaist`.
  measurementWaist,

  /// Maps to `updatePerson`'s `measurementHips`.
  measurementHips,

  /// Maps to `updatePerson`'s `sizeTop`.
  sizeTop,

  /// Maps to `updatePerson`'s `sizeBottom`.
  sizeBottom,

  /// Maps to `updatePerson`'s `sizeShoes`.
  sizeShoes,

  /// Maps to `updatePerson`'s `hmcNotes`.
  hmcNotes,

  /// Maps to `updatePerson`'s `notes`.
  notes,
}
