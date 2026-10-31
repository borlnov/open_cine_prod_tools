// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A scene heading's own time-of-day half, as `ocptSceneEffectOf` reads it. Null when the words
/// found are not one of the small set this app recognises — see `ocptSceneEffectOf`'s own doc
/// comment for why that set stays deliberately small.
enum OcptSceneTimeOfDay {
  /// The heading's own suffix reads as one of the day words `ocptSceneEffectOf` recognises.
  day,

  /// The heading's own suffix reads as one of the night words `ocptSceneEffectOf` recognises.
  night,
}
