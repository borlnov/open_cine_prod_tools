// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported crew & cast directory sheet, in the order the sheet lays them out.
///
/// Every column of a person is always written, whatever the person sheet happens to show at once
/// (its cards group these fields two by two, side by side): the workbook is what leaves the app, so
/// hiding a card on screen must not amputate the file a crew works from. The order follows the
/// person sheet's own top-down reading — header and functions, then the legal-hours callout's own
/// field, then meals/health/skills beside logistics, the HMC card beside image rights, the
/// unavailabilities, and last the notes.
enum OcptPeopleXlsxColumn {
  /// The person's display name (`firstName` + `lastName`).
  name,

  /// The crew positions the person holds, localized and joined.
  positions,

  /// The names of the roles the person is cast in, joined.
  roles,

  /// The person's email address.
  email,

  /// The person's phone number.
  phone,

  /// The street part of the person's postal address.
  addressLine1,

  /// The second line of the person's postal address.
  addressLine2,

  /// The person's postal code.
  postalCode,

  /// The person's city.
  city,

  /// The person's region, state, province or county.
  region,

  /// The person's country.
  country,

  /// The person's date of birth.
  birthDate,

  /// The person's age, derived from their date of birth.
  age,

  /// The legal framing to observe when the person is a minor.
  minorNotes,

  /// Whether the person can travel to set on their own; a tri-state flag, blank while unknown.
  transportAutonomy,

  /// Where the person stays during the shoot.
  accommodationNotes,

  /// The person's travel logistics.
  travelNotes,

  /// The person's dietary requirements.
  dietaryNotes,

  /// The person's allergies.
  allergies,

  /// The person's skills, joined.
  skills,

  /// The person's height.
  height,

  /// The person's chest measurement.
  chest,

  /// The person's waist measurement.
  waist,

  /// The person's hip measurement.
  hips,

  /// The person's top/upper body clothing size.
  topSize,

  /// The person's bottom clothing size.
  bottomSize,

  /// The person's shoe size.
  shoeSize,

  /// Hair/make-up/costume continuity notes.
  hmcNotes,

  /// Where the person's image rights release stands.
  imageRightsStatus,

  /// The date the person's image rights status last changed.
  imageRightsDate,

  /// A summary of every date range the person is known to be unavailable over.
  unavailabilities,

  /// Free-form notes about the person.
  notes,
}
