// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What subject an `assets` row's referenced file illustrates or documents.
///
/// See `docs/adr/0013-binary-assets-referenced-by-path.md`: the row holds a path, never bytes, and
/// this is what a reader uses to know which owner column of the row to expect populated and what
/// kind of thumbnail to attempt.
enum OcptAssetKind {
  /// A person's headshot/photo.
  personPhoto,

  /// A location's scouting photo.
  locationPhoto,

  /// An element's photo.
  elementPhoto,

  /// A document: a signed image rights release, a filming permit, or similar paperwork.
  document,
}
