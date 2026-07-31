// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported shot list workbook, in the order the sheet lays them out.
///
/// Unlike `OcptShotListColumn`, which only models the table columns the user can *hide*, this
/// enumerates every column the spreadsheet carries: the workbook is what leaves the app, so it
/// always writes the whole shot rather than whichever columns the table happens to show. The
/// first fourteen values are the shot table's own columns, in its own layout order, so a reader
/// who knows the table finds the same sheet in front of them; [notes] and [locationNotes] follow
/// them, holding the two free-text fields the table has no room for at all.
enum OcptShotListXlsxColumn {
  /// The shot's derived `<scene number>/<rank>` code.
  shot,

  /// The characters attached to the shot, joined into a single cell.
  characters,

  /// The scene's set: the sequence's own heading, or the heading its scene had when it was
  /// deleted for an orphaned shot.
  set,

  /// The shot size ("valeur de plan").
  shotSize,

  /// The framing and composition.
  framing,

  /// The camera move.
  cameraMove,

  /// The lens/focal length.
  lens,

  /// The recording format and frame rate.
  recordingFormat,

  /// The estimated duration, written `m:ss`.
  duration,

  /// The number of planned takes, written as a number.
  takes,

  /// The sound notes.
  sound,

  /// The mean of the four difficulty axes, written as a number so the spreadsheet formats it in
  /// the reader's own locale rather than in the one the export ran under.
  difficulty,

  /// The shooting day the shot is planned for.
  shootingDay,

  /// The shooting status.
  status,

  /// The director's notes.
  notes,

  /// The location scouting notes.
  locationNotes,
}
