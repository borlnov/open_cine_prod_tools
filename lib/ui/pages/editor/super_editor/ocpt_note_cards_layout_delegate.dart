// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_card_stacking.dart';

/// The layout of the cards of the notes margin: it measures each card, which is as wide as the
/// column and as tall as its text needs, then places them with [ocptStackNoteCards].
///
/// The cards are the children, told apart by their index in document order. The anchors are in the
/// coordinates of the scrolled content, so the cards move with the text by [scrollOffset] alone,
/// without being placed again against a layout read a frame late.
class OcptNoteCardsLayoutDelegate extends MultiChildLayoutDelegate {
  /// The top of the line each card belongs to, in the coordinates of the scrolled content.
  final List<double> anchors;

  /// The index of the selected card, or null when none is.
  final int? selectedIndex;

  /// How far the content is scrolled, in logical pixels.
  final double scrollOffset;

  /// The width of every card, in logical pixels.
  final double cardWidth;

  /// How far the selected card is shifted towards the page, in logical pixels.
  final double selectedShift;

  /// Class constructor.
  OcptNoteCardsLayoutDelegate({
    required this.anchors,
    required this.selectedIndex,
    required this.scrollOffset,
    required this.cardWidth,
    required this.selectedShift,
  });

  /// Measure the cards, then place each one by [ocptStackNoteCards].
  @override
  void performLayout(Size size) {
    final heights = <double>[
      for (var index = 0; index < anchors.length; index++)
        layoutChild(index, BoxConstraints(minWidth: cardWidth, maxWidth: cardWidth)).height,
    ];
    final tops = ocptStackNoteCards(
      anchors: anchors,
      heights: heights,
      selectedIndex: selectedIndex,
    );

    for (var index = 0; index < anchors.length; index++) {
      positionChild(
        index,
        Offset(index == selectedIndex ? -selectedShift : 0, tops[index] - scrollOffset),
      );
    }
  }

  /// Tell whether the cards must be placed again for the delegate [oldDelegate] laid them out for.
  @override
  bool shouldRelayout(covariant OcptNoteCardsLayoutDelegate oldDelegate) =>
      !listEquals(oldDelegate.anchors, anchors) ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.cardWidth != cardWidth ||
      oldDelegate.selectedShift != selectedShift;
}
