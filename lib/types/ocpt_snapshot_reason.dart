// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
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

  /// The snapshot was taken right before an imported `.fountain` file replaced the screenplay.
  import,

  /// The snapshot was taken right before a project version restored its own text over the
  /// screenplay's.
  ///
  /// This one exists for the merge rather than for the user: a screenplay's text is reconciled by a
  /// three-way line merge against the nearest common snapshot
  /// (`docs/adr/0010-sync-ready-data-model-prerequisites.md`), and a restore replaces the whole text
  /// in a single write. Without a snapshot taken at that very moment, the merge base would skip the
  /// discontinuity and reconcile against text that never existed on this replica.
  restore,
}
