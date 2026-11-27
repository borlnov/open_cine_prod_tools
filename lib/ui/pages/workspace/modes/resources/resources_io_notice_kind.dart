// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The kind of transient notice `OcptResourcesIoNotice` carries, one per resources export outcome.
enum OcptResourcesIoNoticeKind {
  /// The resources catalogue was successfully exported to a four-sheet XLSX workbook.
  xlsxExportSucceeded,

  /// Exporting the resources catalogue to a four-sheet XLSX workbook failed.
  xlsxExportFailed,

  /// The contact list was successfully exported to a PDF.
  contactListExportSucceeded,

  /// Exporting the contact list to a PDF failed.
  contactListExportFailed,
}

/// What the kind of a notice says about its outcome.
extension OcptResourcesIoNoticeKindOutcome on OcptResourcesIoNoticeKind {
  /// Tell whether the notice reports a failure, which is shown as an error.
  bool get isFailure => switch (this) {
    OcptResourcesIoNoticeKind.xlsxExportFailed ||
    OcptResourcesIoNoticeKind.contactListExportFailed => true,
    OcptResourcesIoNoticeKind.xlsxExportSucceeded ||
    OcptResourcesIoNoticeKind.contactListExportSucceeded => false,
  };
}
