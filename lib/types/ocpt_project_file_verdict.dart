// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What reading a project file's own format number says about the build about to open it.
///
/// The whole point of asking is that **nothing may reach drift before this is known**: drift
/// migrates a file it is handed, silently and in place, and it cannot make sense of one written by
/// a later build at all — `onUpgrade(m, from, to)` is called with `from > to`, every
/// `if (from < N)` guard declines to run, and `PRAGMA user_version` is then stamped **back down**
/// to the running build's number, leaving a file that still holds the newer build's tables while
/// claiming to be old.
enum OcptProjectFileVerdict {
  /// The file is at the very schema version this build writes: it opens as it always has, with no
  /// dialog and no copy taken.
  current,

  /// The file was written by an older build. It can be migrated, but only after the user has been
  /// told and a copy has been kept.
  older,

  /// The file was written by a newer build than this one. It is refused: not opened, not touched
  /// and not added to the recent projects list.
  newer,

  /// The file could not be read as a project at all — it is not a SQLite database, it cannot be
  /// opened, or it states no schema version of its own (a brand-new or foreign database).
  ///
  /// Nothing is asked and nothing is refused here: the open goes ahead exactly as it did before
  /// this gate existed, and reports whatever it finds. This gate is about *formats*, and a file
  /// with no format to state is not its business.
  unreadable,
}
