// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The letters a camera's rank is spelled with once its shot has more than one camera, in order:
/// `A`, `B`, …, `H`, `J`, `K`, … — `I` and `O` are skipped (the slate convention: too easily
/// confused with `1` and `0`) — then `AA`, `AB`, … past `Z`, the same spreadsheet-column
/// convention used wherever a rank needs more than this alphabet's own letters, kept only so a
/// sequence with an implausible number of cameras on one shot still gets a legible label rather
/// than throwing.
const String _letters = "ABCDEFGHJKLMNPQRSTUVWXYZ";

/// The label a camera symbol shows: [shotRank] alone while its shot carries only this one camera
/// ([cameraCount] `<= 1`), or [shotRank] followed by a letter for every camera of the shot,
/// starting at the first, the moment it carries two or more.
///
/// [shotRank] is the shot's own display number — its 1-based rank in its sequence, `docs/plans/
/// storyboard.md`, §2 ("the number is the shot's rank in the sequence … derived, never stored").
/// [cameraRank] is the camera symbol's **0-based** rank among the same shot's live camera symbols
/// on the same set, in `sortKey` order: rank 0 is `A`, rank 1 is `B`, and so on, skipping `I` and
/// `O`. [cameraCount] is that same shot's total live camera count: a solo camera (`cameraCount <=
/// 1`) carries no letter at all (`3`); as soon as a second one exists, **every** camera of that
/// shot is lettered (`3A`, `3B`, …), the first included. Removing a camera therefore shifts every
/// later one's own letter down at the next read — the letter is never stored, so there is never a
/// gap to close by hand, and a shot dropping back to one camera loses its own letter entirely.
String ocptFloorPlanCameraLabelOf({
  required int shotRank,
  required int cameraRank,
  required int cameraCount,
}) {
  if (cameraCount <= 1) {
    return "$shotRank";
  }

  return "$shotRank${_letterOf(cameraRank < 0 ? 0 : cameraRank)}";
}

/// The spreadsheet-column-style letter(s) for the 0-based [index], over [_letters] (`I`/`O`
/// skipped): `0` → `A`, `23` → `Z`, `24` → `AA`, and so on.
String _letterOf(int index) {
  var value = index;
  final buffer = StringBuffer();
  do {
    buffer.write(_letters[value % _letters.length]);
    value = value ~/ _letters.length - 1;
  } while (value >= 0);

  return buffer.toString().split('').reversed.join();
}
