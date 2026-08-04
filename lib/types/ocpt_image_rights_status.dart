// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where a person's image rights release stands.
///
/// The document itself is out of scope for this step (no generator ships): this status and the
/// reference to a signed PDF are what a production tracks by hand until one exists.
enum OcptImageRightsStatus {
  /// No release is needed for this person (e.g. crew never on screen).
  notApplicable,

  /// A release is needed and has not been drafted yet.
  toGenerate,

  /// A release has been drafted and is awaiting signature.
  generated,

  /// A release has been signed.
  signed,
}
