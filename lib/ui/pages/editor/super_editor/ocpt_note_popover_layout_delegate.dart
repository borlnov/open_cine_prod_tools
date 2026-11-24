// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_popover_placement.dart';

/// The identifiers of the children [OcptNotePopoverLayoutDelegate] places.
enum OcptNotePopoverPart {
  /// The card holding the note.
  card,

  /// The pointer standing under the marker, pointing up at it.
  pointerUp,

  /// The pointer standing above the marker, pointing down at it.
  pointerDown,
}

/// Lay out the popover of a note: the card of a fixed width against its marker, and the one of
/// the two pointers that points at the marker, the other taking no room.
class OcptNotePopoverLayoutDelegate extends MultiChildLayoutDelegate {
  /// The rectangle of the marker, in the coordinates of the layout.
  final Rect anchor;

  /// The visible area the card stays inside, in the coordinates of the layout.
  final Rect bounds;

  /// The width of the card.
  final double cardWidth;

  /// Class constructor.
  OcptNotePopoverLayoutDelegate({
    required this.anchor,
    required this.bounds,
    required this.cardWidth,
  });

  /// Lay out the card, then the pointer facing the marker.
  @override
  void performLayout(Size size) {
    final width = math.min(
      cardWidth,
      math.max<double>(0, bounds.width - 2 * OcptNotePopoverPlacement.edgeMargin),
    );
    final cardSize = layoutChild(
      OcptNotePopoverPart.card,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max<double>(0, bounds.height - 2 * OcptNotePopoverPlacement.edgeMargin),
      ),
    );
    final placement = OcptNotePopoverPlacement.compute(
      anchor: anchor,
      bounds: bounds,
      cardSize: cardSize,
    );
    positionChild(OcptNotePopoverPart.card, placement.cardOffset);

    const pointerSize = Size(
      OcptNotePopoverPlacement.pointerWidth,
      OcptNotePopoverPlacement.pointerHeight,
    );
    final left = placement.pointerX - pointerSize.width / 2;
    for (final part in [OcptNotePopoverPart.pointerUp, OcptNotePopoverPart.pointerDown]) {
      final isUsed = (part == OcptNotePopoverPart.pointerDown) == placement.isAbove;
      layoutChild(part, BoxConstraints.tight(isUsed ? pointerSize : Size.zero));
      positionChild(
        part,
        isUsed
            ? Offset(
                left,
                placement.isAbove
                    ? placement.cardOffset.dy + cardSize.height
                    : placement.cardOffset.dy - pointerSize.height,
              )
            : Offset.zero,
      );
    }
  }

  /// Tell whether the layout must run again for [oldDelegate]: when the marker, the area or the
  /// width of the card changed.
  @override
  bool shouldRelayout(covariant OcptNotePopoverLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      cardWidth != oldDelegate.cardWidth;
}
