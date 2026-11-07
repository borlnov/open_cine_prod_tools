// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The kind of transient notice `OcptShotListIoNotice` carries, one per shot list export outcome.
enum OcptShotListIoNoticeKind {
  /// The shot list was successfully exported to an XLSX workbook.
  xlsxExportSucceeded,

  /// Exporting the shot list to an XLSX workbook failed.
  xlsxExportFailed,

  /// The scenario coverage was successfully exported to an annotated screenplay PDF.
  scenarioCoverageExportSucceeded,

  /// Exporting the scenario coverage to an annotated screenplay PDF failed.
  scenarioCoverageExportFailed,

  /// The storyboard was successfully exported to a PDF.
  storyboardExportSucceeded,

  /// Exporting the storyboard to a PDF failed.
  storyboardExportFailed,

  /// The floor plans were successfully exported to a PDF.
  floorPlansExportSucceeded,

  /// Exporting the floor plans to a PDF failed.
  floorPlansExportFailed,
}
