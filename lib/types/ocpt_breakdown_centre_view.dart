// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the breakdown mode's two centre views is currently shown, toggled by
/// `OcptBreakdownHeader`'s own `Script`/`Recap` switch.
enum OcptBreakdownCentreView {
  /// The screenplay typeset as a paper sheet, its words clickable — the mode's default view.
  script,

  /// The cross-table of every tagged target by scene, grouped by category.
  recap,
}
