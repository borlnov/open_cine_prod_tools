// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The horizontal alignment of a printed screenplay element within its
/// layout box.
enum FountainLayoutAlignment {
  /// Text starts at the box's left indent.
  left,

  /// Text is centered within the box's width.
  center,

  /// Text ends at the box's right edge (used for transitions).
  right,
}
