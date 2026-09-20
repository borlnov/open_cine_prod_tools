// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the shot list mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// [xlsx] and [coverage] share one `OcptWorkspaceExportEntry.unavailableReason`: the shot list
/// holding no shot leaves nothing for either document to print — an empty workbook, or a
/// screenplay with no bar to draw. [storyboard] and [floorPlans] each carry their own reason
/// instead, since a shot list can hold shots without holding a single panel or a single placed
/// camera: no panel anywhere in the whole shot list for [storyboard], no case holding a camera
/// anywhere for [floorPlans] (`docs/plans/storyboard.md`, §5).
enum OcptShotListExportDocument {
  /// The whole shot list, sequence by sequence, as an Excel workbook.
  xlsx,

  /// The screenplay annotated with a coloured bar for every passage a shot covers.
  coverage,

  /// The imported frames of every shot, annotated, with each shot's key information, as a PDF.
  storyboard,

  /// One floor plan per shot that has a camera placed on it, as a PDF.
  floorPlans,
}
