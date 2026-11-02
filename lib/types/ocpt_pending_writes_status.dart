// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What asking a view to write the edits it holds came to.
///
/// See `OcptPendingWritesFlusher`. A failed write is reported as a value rather than raised, so a
/// flush that cannot write never takes the handler that asked for it down with it.
enum OcptPendingWritesStatus {
  /// The view had edits and wrote them, or dropped them for lack of an open project.
  ok,

  /// The view held nothing to write.
  nothingToWrite,

  /// The write failed, or the data could not be read again after it: the edits are still pending,
  /// and the action waiting on the flush must not go on as if the database were up to date.
  failed,
}
