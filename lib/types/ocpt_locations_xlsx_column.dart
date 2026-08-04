// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported locations & sets sheet, in the order the sheet lays them out.
///
/// The sheet writes **one row per set** (see `OcptResourcesXlsxExportService`'s own doc comment for
/// why), so [locationName] and every other location-only column repeat identically on every row a
/// location's several sets produce, while [setCode]/[setName]/[setScenes] are the row's own. A
/// location with no set at all still gets one row, its set columns left empty.
enum OcptLocationsXlsxColumn {
  /// The location's display name.
  locationName,

  /// The set's short code, empty on a location-with-no-set row.
  setCode,

  /// The set's display name, empty on a location-with-no-set row.
  setName,

  /// The scenes shot in the set, joined, empty on a location-with-no-set row.
  setScenes,

  /// The street part of the location's postal address.
  addressLine1,

  /// The second line of the location's postal address.
  addressLine2,

  /// The location's postal code.
  postalCode,

  /// The location's city.
  city,

  /// The location's region, state, province or county.
  region,

  /// The location's country.
  country,

  /// The location's latitude.
  latitude,

  /// The location's longitude.
  longitude,

  /// The display name of the person to contact about the location.
  contact,

  /// Free-text notes about the contact.
  contactNotes,

  /// Where the location's filming permit stands.
  permitStatus,

  /// The permit's own reference/label.
  permitLabel,

  /// The date the permit status last changed.
  permitDate,

  /// A summary of every window the location may be shot in.
  availabilityWindows,

  /// Where vehicles and the production truck can park.
  parkingNotes,

  /// What electrical power is available.
  powerNotes,

  /// Facilities available on site.
  facilitiesNotes,

  /// Constraints on shooting at the location.
  constraintsNotes,

  /// Free-form notes about the location.
  notes,
}
