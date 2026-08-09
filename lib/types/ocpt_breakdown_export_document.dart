// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the breakdown mode's export panel offers, through `OcptWorkspaceExportDialog`.
enum OcptBreakdownExportDocument {
  /// One printed sheet per scene, everything tagged in it.
  sheets,

  /// The whole breakdown as a two-sheet XLSX workbook — one row per scene, then one row per tagged
  /// target in a scene.
  xlsx,
}
