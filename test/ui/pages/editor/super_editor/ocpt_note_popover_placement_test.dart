// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_popover_placement.dart';

/// The area the popover stays inside in the tests.
const Rect _bounds = Rect.fromLTWH(0, 0, 600, 400);

/// The size of the card in the tests.
const Size _card = Size(280, 120);

/// Run the tests of the placement of the popover of a note.
void main() {
  group("OcptNotePopoverPlacement", () {
    test("puts the card under the marker, centred on it, with a pointer on the marker", () {
      final placement = OcptNotePopoverPlacement.compute(
        anchor: const Rect.fromLTWH(290, 100, 20, 16),
        bounds: _bounds,
        cardSize: _card,
      );

      expect(placement.isAbove, isFalse);
      expect(placement.cardOffset.dy, 116 + OcptNotePopoverPlacement.pointerHeight);
      expect(placement.cardOffset.dx, 300 - 140);
      expect(placement.pointerX, 300);
    });

    test("puts the card above the marker when it would overflow below and there is more room", () {
      final placement = OcptNotePopoverPlacement.compute(
        anchor: const Rect.fromLTWH(290, 300, 20, 16),
        bounds: _bounds,
        cardSize: _card,
      );

      expect(placement.isAbove, isTrue);
      expect(placement.cardOffset.dy, 300 - OcptNotePopoverPlacement.pointerHeight - 120);
    });

    test("keeps the card under the marker when there is no more room above", () {
      final placement = OcptNotePopoverPlacement.compute(
        anchor: const Rect.fromLTWH(290, 20, 20, 16),
        bounds: const Rect.fromLTWH(0, 0, 600, 100),
        cardSize: _card,
      );

      expect(placement.isAbove, isFalse);
    });

    test("moves the card sideways to stay inside the area, the pointer staying on the card", () {
      final left = OcptNotePopoverPlacement.compute(
        anchor: const Rect.fromLTWH(2, 100, 20, 16),
        bounds: _bounds,
        cardSize: _card,
      );
      final right = OcptNotePopoverPlacement.compute(
        anchor: const Rect.fromLTWH(580, 100, 20, 16),
        bounds: _bounds,
        cardSize: _card,
      );

      expect(left.cardOffset.dx, OcptNotePopoverPlacement.edgeMargin);
      expect(left.pointerX, 16);
      expect(right.cardOffset.dx, 600 - OcptNotePopoverPlacement.edgeMargin - 280);
      expect(right.pointerX, 584);
    });

    test("keeps the pointer on the card when the marker is past its end", () {
      final placement = OcptNotePopoverPlacement.compute(
        anchor: const Rect.fromLTWH(700, 100, 20, 16),
        bounds: const Rect.fromLTWH(0, 0, 720, 400),
        cardSize: _card,
      );

      expect(placement.pointerX, lessThanOrEqualTo(placement.cardOffset.dx + 280 - 8));
    });
  });
}
