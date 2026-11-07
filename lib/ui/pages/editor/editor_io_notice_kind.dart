// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The kind of transient notice `OcptEditorIoNotice` carries, one per export/import outcome.
enum OcptEditorIoNoticeKind {
  /// The screenplay was successfully exported to a `.fountain` file.
  exportSucceeded,

  /// Exporting the screenplay to a `.fountain` file failed.
  exportFailed,

  /// The screenplay text was successfully replaced by an imported screenplay file.
  importSucceeded,

  /// Importing a screenplay file to replace the screenplay text failed while it was being written
  /// to the project: the file itself was read, so the screenplay on screen is the old one still.
  importFailed,

  /// The picked file could not be read as a screenplay at all, so nothing was replaced.
  ///
  /// Told apart from [importFailed] on purpose: this one names the file the user picked, which
  /// picking another one fixes, where the other names the project's own write failing.
  importUnreadable,

  /// The screenplay was successfully exported to a PDF file.
  pdfExportSucceeded,

  /// Exporting the screenplay to a PDF file failed.
  pdfExportFailed,
}
