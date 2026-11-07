// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The kind of transient notice `OcptBudgetIoNotice` carries — one shared pair reused across the
/// mode's four exports (three PDFs and one XLSX), exactly as `OcptScheduleIoNoticeKind` shares its
/// own `fileExportSucceeded`/`exportFailed` pair across the schedule mode's own heterogeneous
/// documents rather than growing one kind per document.
enum OcptBudgetIoNoticeKind {
  /// One of the four exports was written successfully.
  fileExportSucceeded,

  /// One of the four exports failed outright (an exception was thrown while rendering or writing
  /// it). A cancelled save dialog is a silent no-op instead, exactly as every other export in the
  /// app treats it.
  exportFailed,
}
