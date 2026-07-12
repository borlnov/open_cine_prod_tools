// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The reason a [OcptSnapshotReason]-tagged safety copy of a screenplay's text was taken.
///
/// Every row in `screenplay_snapshots` carries one of these, so the history can later be
/// filtered/explained to the user (e.g. "auto-saved 5 minutes ago" vs "before export").
enum OcptSnapshotReason {
  /// The snapshot was taken when the project was opened, to protect against the very first edit.
  open,

  /// The snapshot was taken by a periodic/autosave timer.
  timer,

  /// The snapshot was taken right before exporting the screenplay to another format.
  export,

  /// The snapshot was explicitly requested by the user.
  manual,
}
