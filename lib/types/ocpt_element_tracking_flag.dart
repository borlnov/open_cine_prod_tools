// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the three boxes both reference spreadsheets tick about an element, in the order the shoot
/// goes through them: got it, it is ready to leave, it went home.
///
/// They are one enum rather than three unrelated booleans because they are one question asked three
/// times — the element sheet ticks them on one row, and the bloc writes whichever was ticked
/// through a single event. Each case maps onto the `elements` column of the same meaning.
enum OcptElementTrackingFlag {
  /// Maps to `elements.isSecured`: the element is owned, borrowed, rented or bought — the
  /// production knows it will have it.
  secured,

  /// Maps to `elements.isReadyForShoot`: it is prepared and ready to go to set.
  readyForShoot,

  /// Maps to `elements.isReturned`: it has been given back after the shoot.
  returned,
}
