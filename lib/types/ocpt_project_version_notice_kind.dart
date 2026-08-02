// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The outcome a project version operation reports back to the user, shown as a transient
/// SnackBar over whichever production mode the `Versions` dock tab was used from, then dismissed.
///
/// Only the outcomes the user has to be told about are here: a successful creation, deletion or
/// preview shows itself in the panel (a new card, a card gone, the version on screen) and needs no
/// notice of its own.
enum OcptProjectVersionNoticeKind {
  /// Capturing the project as a new version failed; nothing was written.
  creationFailed,

  /// Deleting a version failed; the version is still there.
  deletionFailed,

  /// A version can't be previewed while a mode still holds changes that haven't reached the
  /// database. The panel saves first and retries on its own, so this is only reported when that
  /// save itself didn't settle the matter.
  previewBlockedByUnsavedChanges,

  /// The version's payload was written by a later build of the app, and is refused rather than
  /// half-read.
  previewUnsupportedFormat,

  /// The version's payload couldn't be read or hydrated: that version is lost, the project isn't.
  previewFailed,
}
