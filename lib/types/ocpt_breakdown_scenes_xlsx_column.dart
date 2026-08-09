// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported breakdown workbook's `Scenes` sheet, in the order the sheet lays
/// them out — one row per scene.
///
/// Mirrors `OcptShotListXlsxColumn`'s own doc comment: every column is always written, whatever a
/// given scene's own breakdown holds, so the workbook a department reworks never loses a fact the
/// screen simply chose not to show at once.
enum OcptBreakdownScenesXlsxColumn {
  /// The scene's display number (`OcptBreakdownScene.displayNumber`).
  number,

  /// The scene's heading, verbatim from the screenplay.
  heading,

  /// The scene's own breakdown status.
  status,

  /// The scene's length, in the eighths notation assistant directors write.
  length,

  /// The sets this scene is linked to, joined.
  sets,

  /// The number of distinct targets tagged in this scene — the same count the scene panel's own
  /// bars and its `N elements` label read.
  neededCount,

  /// The scene's own breakdown notes.
  notes,
}
