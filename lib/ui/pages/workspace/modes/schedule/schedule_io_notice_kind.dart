// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The kind of transient notice `OcptScheduleIoNotice` carries, one per schedule export outcome.
///
/// A folder export (the two call sheet kinds) is the one path with a middle ground between success
/// and failure — some files can be written while others aren't — which is why there are three kinds
/// rather than the two a single-file export would need: [folderExportPartiallySucceeded] must never
/// read as a plain success, `OcptCallSheetExportResult.failedFileNames` being non-empty meaning
/// exactly that someone's call sheet did not make it into the folder.
enum OcptScheduleIoNoticeKind {
  /// A single-file export (the shooting plan) was written successfully.
  fileExportSucceeded,

  /// A folder export (a call sheets run) wrote every file it set out to.
  folderExportSucceeded,

  /// A folder export wrote some files but not every one — `OcptCallSheetExportResult
  /// .failedFileNames` is non-empty.
  folderExportPartiallySucceeded,

  /// An export failed outright (an exception was thrown while rendering or writing it). A cancelled
  /// save/folder dialog is a silent no-op instead, exactly as the breakdown sheets export treats
  /// it.
  exportFailed,
}
