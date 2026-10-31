// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Something that holds edits typed into a field and written only once the typing stops, and can
/// be told to write them now.
///
/// A production mode bloc keeps the flushers its view blocs register and calls them whenever an
/// action needs the project database to be up to date: a selection change, an export, a version
/// preview, leaving the workspace. It does not know what each of them holds, only that it can be
/// asked to let go of it.
abstract interface class OcptPendingWritesFlusher {
  /// Writes whatever this holds, forgets it, and answers whether there was anything to write.
  ///
  /// Runs inside the flusher's own bloc, so it may emit the now-empty state.
  Future<bool> flushPendingWrites();

  /// Writes whatever this holds **without touching any state**, for the moments no handler can
  /// emit from: a widget leaving the tree, a bloc closing. A failure is only logged.
  Future<void> flushPendingWritesWithoutState();
}
