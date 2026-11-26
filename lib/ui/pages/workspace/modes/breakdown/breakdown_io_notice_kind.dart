// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The kind of transient notice `OcptBreakdownIoNotice` carries, one per breakdown export outcome.
enum OcptBreakdownIoNoticeKind {
  /// The breakdown sheets were successfully exported to a PDF file.
  sheetsExportSucceeded,

  /// Exporting the breakdown sheets to a PDF file failed.
  sheetsExportFailed,

  /// The breakdown workbook was successfully exported to an XLSX file.
  xlsxExportSucceeded,

  /// Exporting the breakdown workbook to an XLSX file failed.
  xlsxExportFailed,
}

/// What the kind of a notice says about its outcome.
extension OcptBreakdownIoNoticeKindOutcome on OcptBreakdownIoNoticeKind {
  /// Tell whether the notice reports a failure, which is shown as an error.
  bool get isFailure => switch (this) {
    OcptBreakdownIoNoticeKind.sheetsExportFailed ||
    OcptBreakdownIoNoticeKind.xlsxExportFailed => true,
    OcptBreakdownIoNoticeKind.sheetsExportSucceeded ||
    OcptBreakdownIoNoticeKind.xlsxExportSucceeded => false,
  };
}
