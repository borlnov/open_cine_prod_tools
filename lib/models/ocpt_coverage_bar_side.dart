// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which margin a coverage bar is drawn in.
enum OcptCoverageBarSide {
  /// The left margin, where the innermost lanes are: bars fill this side first.
  left,

  /// The right margin, where a bar goes once the left margin's lanes are all taken.
  right,
}
