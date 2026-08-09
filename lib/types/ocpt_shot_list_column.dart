// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// An optional column of the shot list table, shown or hidden through the table's `Columns ▾`
/// menu.
///
/// Only the *optional* columns are modelled here: the shot code, the characters, the shot size,
/// the framing, the camera move and the difficulty are always shown, so there is nothing for the
/// user to toggle and nothing to persist about them. The declaration order is the order the menu
/// lists them in, not the order the table lays them out in (which interleaves them with the
/// always-shown ones, see `OcptShotListTable`).
enum OcptShotListColumn {
  /// The scene's set/location, read from the sequence rather than stored on the shot.
  set,

  /// The lens/focal length used for the shot.
  lens,

  /// The recording format and frame rate.
  recordingFormat,

  /// The estimated duration of the shot.
  duration,

  /// The number of takes planned for the shot.
  takes,

  /// The sound notes of the shot.
  sound,

  /// The shot's placement in the schedule (`J3 · Tue 4 Aug`), a read-out rather than a field the
  /// table lets the user type into: see `shots.shootingDay`'s own doc comment.
  shootingDay,

  /// The shooting status of the shot.
  status;

  /// Whether this column is visible for a user who never opened the `Columns ▾` menu.
  ///
  /// The default set matches the mock-up's own: the three columns a director reads while
  /// planning a day of shooting ([duration], [shootingDay] and [status]), every other one folded
  /// away until it is asked for.
  bool get isDefaultVisible => switch (this) {
    OcptShotListColumn.duration ||
    OcptShotListColumn.shootingDay ||
    OcptShotListColumn.status => true,
    OcptShotListColumn.set ||
    OcptShotListColumn.lens ||
    OcptShotListColumn.recordingFormat ||
    OcptShotListColumn.takes ||
    OcptShotListColumn.sound => false,
  };

  /// The columns visible by default, i.e. every value whose [isDefaultVisible] is true.
  static Set<OcptShotListColumn> get defaultVisibleColumns =>
      OcptShotListColumn.values.where((column) => column.isDefaultVisible).toSet();
}
