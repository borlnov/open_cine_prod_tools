// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the location sheet's typed, free-text fields, whose edits go through the resources bloc's
/// 2 s autosave debounce (`OcptResourcesState.pendingLocationFieldEdits`) rather than being written
/// immediately — mirroring `OcptPersonField` and `OcptRoleField`.
///
/// Every case maps onto one `OcptLocationsService.updateLocation` argument of the same name. The
/// discrete fields of `locations` are deliberately absent: the colour swatch, the permit status,
/// the permit date and the contact person are each a single pick rather than typing, so they are
/// written immediately by their own bloc events.
enum OcptLocationField {
  /// Maps to `updateLocation`'s `name`.
  name,

  /// Maps to `updateLocation`'s `addressLine1`.
  addressLine1,

  /// Maps to `updateLocation`'s `addressLine2`.
  addressLine2,

  /// Maps to `updateLocation`'s `postalCode`.
  postalCode,

  /// Maps to `updateLocation`'s `city`.
  city,

  /// Maps to `updateLocation`'s `region`.
  region,

  /// Maps to `updateLocation`'s `country`.
  country,

  /// Maps to `updateLocation`'s `latitude`.
  ///
  /// The one pair of fields (with [longitude]) that is typed but not stored as text: the bloc
  /// parses what was typed and writes null for anything it cannot read as a number, so a
  /// half-typed `48.` never blocks the field and never lands as a coordinate either. The sheet
  /// flags it instead, exactly as it flags a malformed email address.
  latitude,

  /// Maps to `updateLocation`'s `longitude`. See [latitude].
  longitude,

  /// Maps to `updateLocation`'s `contactNotes`.
  contactNotes,

  /// Maps to `updateLocation`'s `permitLabel`.
  permitLabel,

  /// Maps to `updateLocation`'s `parkingNotes`.
  parkingNotes,

  /// Maps to `updateLocation`'s `powerNotes`.
  powerNotes,

  /// Maps to `updateLocation`'s `facilitiesNotes`.
  facilitiesNotes,

  /// Maps to `updateLocation`'s `constraintsNotes`.
  constraintsNotes,

  /// Maps to `updateLocation`'s `notes`.
  notes,
}
