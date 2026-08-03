// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How much of a day a `person_unavailabilities` row covers.
enum OcptHalfDay {
  /// The whole day.
  full,

  /// The morning only.
  morning,

  /// The afternoon only.
  afternoon,
}
