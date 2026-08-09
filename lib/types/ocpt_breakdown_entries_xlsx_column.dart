// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported breakdown workbook's `Breakdown` sheet, in the order the sheet lays
/// them out — one row per tagged target in a scene, the long, filterable format
/// `OcptBreakdownRecapTable`'s own cross-table cannot be.
///
/// Mirrors `OcptShotListXlsxColumn`'s own doc comment: every column is always written, whatever the
/// mode's own sheets happen to show at once, since the workbook is what leaves the app.
enum OcptBreakdownEntriesXlsxColumn {
  /// The scene's display number.
  sceneNumber,

  /// The scene's heading, verbatim from the screenplay.
  sceneHeading,

  /// The group this target's row falls under: an element's category, or the fixed roles/sets
  /// group label.
  group,

  /// The target's own short code: an element's or a set's own `code`, or a role's number.
  code,

  /// The target's display name.
  name,

  /// The target's status — an element's own `OcptElementStatus`, blank for a role or a set.
  status,

  /// The target's owner — an element's own, blank for a role or a set.
  owner,

  /// How many of the target this scene needs, overriding the target's own quantity for this scene
  /// alone — an element's own `scene_elements` link, blank for a role or a set.
  quantity,

  /// This scene's own notes about the target — an element's own `scene_elements` link, blank for a
  /// role or a set.
  notes,

  /// The tagged passage's own text, verbatim, as it read when the tag was last written or
  /// re-anchored.
  taggedText,
}
