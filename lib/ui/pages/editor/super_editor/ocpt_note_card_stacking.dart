// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The empty space kept between two stacked note cards, in logical pixels.
const double ocptNoteCardGap = 8;

/// Place the note cards of a column and return the top of each one, in the column's coordinates.
///
/// [anchors] holds, in document order, the top of the line each card belongs to, and [heights] the
/// measured height of each card. Without a selection ([selectedIndex] null) the cards are placed
/// top-down, each at its anchor or just below the previous one when that would overlap it. With a
/// selection, the selected card is placed exactly at its anchor, the cards after it are pushed
/// down as far as they need to clear it, and the cards before it are pushed up as far as they need
/// to, so that no two cards ever overlap and the order of the document is kept.
List<double> ocptStackNoteCards({
  required List<double> anchors,
  required List<double> heights,
  int? selectedIndex,
  double gap = ocptNoteCardGap,
}) {
  assert(anchors.length == heights.length, "A card needs an anchor and a height");
  final count = anchors.length;
  final tops = List<double>.of(anchors);
  final pivot = selectedIndex ?? 0;

  for (var index = selectedIndex == null ? 1 : pivot + 1; index < count; index++) {
    final minimumTop = tops[index - 1] + heights[index - 1] + gap;
    if (tops[index] < minimumTop) {
      tops[index] = minimumTop;
    }
  }

  for (var index = pivot - 1; index >= 0; index--) {
    final maximumTop = tops[index + 1] - gap - heights[index];
    if (tops[index] > maximumTop) {
      tops[index] = maximumTop;
    }
  }

  return tops;
}
