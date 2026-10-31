// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A scene heading's own interior/exterior half, as `ocptSceneEffectOf` reads it. Null (rather than
/// a third value) when the heading's own prefix names neither unambiguously — an `INT/EXT` (or
/// `I/E`) heading, or one starting with neither word at all — since guessing which of the two a
/// scene mixing both actually is would be inventing a fact the heading itself refuses to commit to.
enum OcptScenePlace {
  /// The heading's own prefix reads as interior alone (`INT`).
  interior,

  /// The heading's own prefix reads as exterior alone (`EXT`, or the `EST` variant some scripts
  /// use).
  exterior,
}
