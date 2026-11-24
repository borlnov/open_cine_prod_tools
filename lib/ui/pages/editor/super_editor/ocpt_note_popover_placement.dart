// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui';

/// Where the popover of a note goes, relative to its marker: the card under the marker, or above
/// it when there is no room below, kept inside the visible area, and the x the pointer joining the
/// card to the marker is centred on.
final class OcptNotePopoverPlacement {
  /// The distance kept between the card and the edges of the visible area, in logical pixels.
  static const double edgeMargin = 8;

  /// The height of the pointer, which is also the distance between the marker and the card.
  static const double pointerHeight = 8;

  /// The width of the pointer.
  static const double pointerWidth = 16;

  /// The position of the top left corner of the card.
  final Offset cardOffset;

  /// Whether the card is above the marker rather than under it.
  final bool isAbove;

  /// The x the pointer is centred on.
  final double pointerX;

  /// Class constructor.
  const OcptNotePopoverPlacement({
    required this.cardOffset,
    required this.isAbove,
    required this.pointerX,
  });

  /// Place a card of [cardSize] against the marker at [anchor], inside [bounds], all in the same
  /// coordinates.
  ///
  /// The card goes under the marker unless it would overflow the bottom of [bounds] and there is
  /// more room above. It is centred on the marker, then moved sideways to stay inside [bounds].
  factory OcptNotePopoverPlacement.compute({
    required Rect anchor,
    required Rect bounds,
    required Size cardSize,
  }) {
    const reach = pointerHeight;
    final roomBelow = bounds.bottom - edgeMargin - anchor.bottom - reach;
    final roomAbove = anchor.top - reach - bounds.top - edgeMargin;
    final isAbove = cardSize.height > roomBelow && roomAbove > roomBelow;

    final top = isAbove ? anchor.top - reach - cardSize.height : anchor.bottom + reach;
    final minLeft = bounds.left + edgeMargin;
    final maxLeft = math.max(minLeft, bounds.right - edgeMargin - cardSize.width);
    final left = (anchor.center.dx - cardSize.width / 2).clamp(minLeft, maxLeft);

    final halfPointer = pointerWidth / 2;
    final pointerX = anchor.center.dx
        .clamp(
          left + halfPointer,
          math.max(left + halfPointer, left + cardSize.width - halfPointer),
        )
        .toDouble();

    return OcptNotePopoverPlacement(
      cardOffset: Offset(left, top),
      isAbove: isAbove,
      pointerX: pointerX,
    );
  }
}
