// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_card_stacking.dart';

/// Run the tests of the placement of the cards of the notes margin.
void main() {
  group("ocptStackNoteCards", () {
    test("places nothing for no card", () {
      expect(ocptStackNoteCards(anchors: [], heights: []), isEmpty);
      expect(ocptStackNoteCards(anchors: [], heights: [], selectedIndex: 0), isEmpty);
    });

    test("puts a single card at its anchor, selected or not", () {
      expect(ocptStackNoteCards(anchors: [120], heights: [60]), [120]);
      expect(ocptStackNoteCards(anchors: [120], heights: [60], selectedIndex: 0), [120]);
    });

    test("keeps cards that do not overlap at their anchors", () {
      expect(ocptStackNoteCards(anchors: [0, 100, 300], heights: [50, 50, 50]), [0, 100, 300]);
    });

    test("pushes a card down below the previous one, a gap apart", () {
      final tops = ocptStackNoteCards(anchors: [0, 10, 20], heights: [50, 40, 30]);

      expect(tops, [0, 50 + ocptNoteCardGap, 50 + ocptNoteCardGap + 40 + ocptNoteCardGap]);
    });

    test("puts the selected card exactly at its anchor and pushes the next ones down", () {
      final tops = ocptStackNoteCards(
        anchors: [0, 10, 20],
        heights: [50, 40, 30],
        selectedIndex: 1,
      );

      expect(tops[1], 10);
      expect(tops[2], 10 + 40 + ocptNoteCardGap);
      expect(tops[0], 10 - ocptNoteCardGap - 50);
    });

    test("leaves the cards before the selected one at their anchors when they clear it", () {
      final tops = ocptStackNoteCards(
        anchors: [0, 200, 210],
        heights: [50, 40, 30],
        selectedIndex: 1,
      );

      expect(tops[0], 0);
      expect(tops[1], 200);
      expect(tops[2], 200 + 40 + ocptNoteCardGap);
    });

    test("never overlaps two cards, whichever one is selected", () {
      const anchors = [0.0, 5.0, 8.0, 9.0, 400.0];
      const heights = [70.0, 30.0, 90.0, 20.0, 60.0];

      for (final selected in <int?>[null, 0, 1, 2, 3, 4]) {
        final tops = ocptStackNoteCards(
          anchors: anchors,
          heights: heights,
          selectedIndex: selected,
        );

        for (var index = 1; index < tops.length; index++) {
          expect(
            tops[index],
            greaterThanOrEqualTo(tops[index - 1] + heights[index - 1] + ocptNoteCardGap - 1e-9),
            reason: "card $index with $selected selected",
          );
        }
        if (selected != null) {
          expect(tops[selected], anchors[selected]);
        }
      }
    });
  });
}
