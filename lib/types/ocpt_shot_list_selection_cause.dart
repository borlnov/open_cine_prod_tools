// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What moved the shot list mode's shared selection the last time its `selectionEpoch` advanced.
///
/// The epoch alone says the selection was touched; the views need to know how, because they clear
/// different things for different gestures — selecting the sequence already selected keeps the
/// selected panel, selecting the shot already selected does not. Every emit that changes the
/// selection carries one of these, so a new way to move it needs a value of its own.
enum OcptShotListSelectionCause {
  /// Nothing has moved the selection yet.
  none,

  /// A different sequence was selected.
  sequence,

  /// The sequence already selected was selected again.
  sequenceReselected,

  /// A shot was selected, whether or not it already was the selected one.
  shot,

  /// A shot was created at the end of the selected sequence and selected.
  shotCreated,

  /// The selected shot was deleted, and the selection fell back to the sequence's first shot (or
  /// to none).
  shotDeleted,

  /// A set was selected.
  set,

  /// A set was created, linked or duplicated into the selected sequence, and selected.
  setAdded,

  /// The selected set was unlinked from the selected sequence, and the selection fell back to the
  /// sequence's first set (or to none).
  setRemoved,

  /// The mode read everything again and picked its selection afresh: on entry, or when a version
  /// preview was entered or left.
  load,

  /// A symbol was deleted, deleted everywhere or restored as in the level above it: the placement
  /// the selection named is gone, and the selected arrow may have gone with it.
  symbolRemoved,

  /// A symbol was masked for one sequence or one shot (a hidden override of it was written).
  symbolHidden,

  /// An arrow was deleted.
  arrowRemoved,
}
