// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What moved the shot list mode's shared selection the last time its `selectionEpoch` advanced.
///
/// The epoch alone says the selection was touched; the views need to know how, because they clear
/// different things for different gestures — selecting the sequence already selected keeps the
/// selected panel, selecting the shot already selected does not.
enum OcptShotListSelectionCause {
  /// Nothing has moved the selection yet.
  none,

  /// A different sequence was selected.
  sequence,

  /// The sequence already selected was selected again.
  sequenceReselected,

  /// A shot was selected, whether or not it already was the selected one.
  shot,

  /// A set was selected.
  set,

  /// The mode read everything again and picked its selection afresh: on entry, or when a version
  /// preview was entered or left.
  load,
}
