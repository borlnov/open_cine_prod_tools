// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the shot list mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// Both values share one `OcptWorkspaceExportEntry.unavailableReason`: the shot list holding no
/// shot leaves nothing for either document to print — an empty workbook, or a screenplay with no
/// bar to draw.
enum OcptShotListExportDocument {
  /// The whole shot list, sequence by sequence, as an Excel workbook.
  xlsx,

  /// The screenplay annotated with a coloured bar for every passage a shot covers.
  coverage,
}
