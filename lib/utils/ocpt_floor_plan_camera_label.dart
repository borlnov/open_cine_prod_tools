// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The letters a camera's rank beyond the first is spelled with, in order: `A`, `B`, …, `Z`, then
/// `AA`, `AB`, … — the same spreadsheet-column convention used wherever a rank needs more than 26
/// letters, kept only so a sequence with an implausible number of cameras on one shot still gets a
/// legible label rather than throwing.
const String _letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/// The label a camera symbol shows: [shotRank] alone when it is the shot's only camera on this
/// case, or [shotRank] followed by a letter for the second, third, … one.
///
/// [shotRank] is the shot's own display number — its 1-based rank in its sequence, `docs/plans/
/// storyboard.md`, §2 ("the number is the shot's rank in the sequence … derived, never stored").
/// [cameraRank] is the camera symbol's **0-based** rank among the same shot's live camera symbols
/// on the same case, in `sortKey` order: rank 0 carries no letter (`3`), rank 1 is `A` (`3A`), rank
/// 2 is `B` (`3B`), and so on. Removing `3A` therefore turns what was `3B` into `3A` at the next
/// read — the letter is never stored, so there is never a gap to close by hand.
String ocptFloorPlanCameraLabelOf({required int shotRank, required int cameraRank}) {
  if (cameraRank <= 0) {
    return "$shotRank";
  }

  return "$shotRank${_letterOf(cameraRank - 1)}";
}

/// The spreadsheet-column-style letter(s) for the 0-based [index]: `0` → `A`, `25` → `Z`,
/// `26` → `AA`, and so on.
String _letterOf(int index) {
  var value = index;
  final buffer = StringBuffer();
  do {
    buffer.write(_letters[value % _letters.length]);
    value = value ~/ _letters.length - 1;
  } while (value >= 0);

  return buffer.toString().split('').reversed.join();
}
