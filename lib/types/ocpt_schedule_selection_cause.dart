// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Why the schedule mode's selection last moved (`OcptScheduleState.selectionCause`).
///
/// The selection is the selected day, block and shot. A view reads the cause to know how much of
/// what it holds was scoped to the selection that has just gone.
enum OcptScheduleSelectionCause {
  /// Nothing has moved the selection yet.
  none,

  /// A day was selected, which clears the selected block and the selected shot.
  day,

  /// A block was selected, with its own day, which clears the selected shot.
  block,

  /// A shot was selected, which clears the selected block.
  shot,

  /// A day was created or duplicated and selected, which clears the selected block.
  dayAdded,

  /// A read found the selected day or the selected block gone (deleted, or a block whose slot was)
  /// and dropped it.
  dropped,

  /// The selected shot was dropped ahead of a version preview, which swaps the data the shot was
  /// selected out of.
  shotCleared,

  /// The mode read everything again and picked its selection afresh: on entry, when a version
  /// preview was entered or left, or when the project settings page changed something.
  load,
}
