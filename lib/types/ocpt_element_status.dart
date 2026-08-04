// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How far along an element is towards being ready for the shoot.
///
/// The three existing booleans on `elements` — `isSecured`, `isReadyForShoot`, `isReturned` —
/// cannot express *reserved* or *being made*, and they answer a different question anyway: on the
/// truck? given back? This status is what the breakdown pass tracks while an element is still being
/// found, and the three booleans stay untouched, tracking what happens to it afterwards.
enum OcptElementStatus {
  /// Nobody has secured this element yet.
  toFind,

  /// This element is reserved (a rental booked, a loan promised) but not yet in hand.
  reserved,

  /// This element is being made or built rather than sourced.
  beingMade,

  /// This element is secured and confirmed for the shoot.
  confirmed,
}
