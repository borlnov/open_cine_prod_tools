// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The outcome a project package export reports back to the user, shown as a transient SnackBar
/// over whichever production mode the `Export` panel was opened from, then dismissed.
///
/// Only the two outcomes worth a sentence are here. A cancelled save dialog is neither: the user
/// closed a dialog they opened, and telling them so would be reporting their own gesture back at
/// them. The missing files are not one either — they were asked about before the write and are
/// carried by the success message itself, since they belong to a package that *was* written.
enum OcptProjectPackageNoticeKind {
  /// The package was written, at the path the notice carries.
  exportSucceeded,

  /// The package could not be written: the project file could not be read, the disk refused it, or
  /// the archive failed halfway. Nothing usable was left behind.
  exportFailed,
}
