// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What asking every flusher of a mode to write came to: whether any of them had something to write,
/// and whether any of them failed.
typedef OcptPendingWritesRun = ({bool hasWritten, bool hasFailed});

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
  ///
  /// Throws when the write failed, and then keeps what it holds: an answer of "nothing to write"
  /// would let the action waiting on the flush (a preview, a restore, an export) go on as if the
  /// database were up to date, and drop the edit with it. A flusher that reports its own failures
  /// to the user and wants the action to go on catches them itself instead.
  Future<bool> flushPendingWrites();

  /// Writes whatever this holds **without touching any state**, for the moments no handler can
  /// emit from: a widget leaving the tree, a bloc closing. A failure is only logged. Both moments
  /// can come one after the other, or overlap, for the same edit (the second starts while the
  /// first write is still running), so an implementation must not write it a second time: see
  /// `AbsOcptViewBloc.flushEditsWithoutState`.
  Future<void> flushPendingWritesWithoutState();
}
