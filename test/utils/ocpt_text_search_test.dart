// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';

void main() {
  group("ocptFindTextMatches", () {
    test("an empty query matches nothing", () {
      expect(
        ocptFindTextMatches(
          text: "MARIE walks into the room.",
          query: "",
          isCaseSensitive: false,
          isWholeWord: false,
        ),
        isEmpty,
      );
    });

    test("case-insensitive by default: matches regardless of case", () {
      final matches = ocptFindTextMatches(
        text: "Marie sees MARIE in the mirror.",
        query: "marie",
        isCaseSensitive: false,
        isWholeWord: false,
      );

      expect(matches, [
        const OcptTextMatch(start: 0, end: 5),
        const OcptTextMatch(start: 11, end: 16),
      ]);
    });

    test("case-sensitive: only matches the exact case", () {
      final matches = ocptFindTextMatches(
        text: "Marie sees MARIE in the mirror.",
        query: "MARIE",
        isCaseSensitive: true,
        isWholeWord: false,
      );

      expect(matches, [const OcptTextMatch(start: 11, end: 16)]);
    });

    test("whole word off: a query held inside a longer word still matches", () {
      final matches = ocptFindTextMatches(
        text: "MARIE-JEANNE enters.",
        query: "MARIE",
        isCaseSensitive: true,
        isWholeWord: false,
      );

      expect(matches, [const OcptTextMatch(start: 0, end: 5)]);
    });

    test("whole word on: a query held inside a longer word is rejected", () {
      final matches = ocptFindTextMatches(
        text: "MARIETTA enters, then MARIE speaks.",
        query: "MARIE",
        isCaseSensitive: true,
        isWholeWord: true,
      );

      // Only the second, standalone occurrence counts; the first is part of "MARIETTA", whose
      // "TTA" letters border it on the right.
      expect(matches, [const OcptTextMatch(start: 22, end: 27)]);
    });

    test("whole word on: a hyphen is a word boundary, not a word character", () {
      // A hyphenated character name is two words for whole-word purposes, the same way most find
      // tools treat punctuation: "MARIE" inside "MARIE-JEANNE" is a genuine whole-word match.
      final matches = ocptFindTextMatches(
        text: "MARIE-JEANNE enters.",
        query: "MARIE",
        isCaseSensitive: true,
        isWholeWord: true,
      );

      expect(matches, [const OcptTextMatch(start: 0, end: 5)]);
    });

    test("whole word on: an accented letter counts as a word character on either border", () {
      // "café" must not be treated as a whole-word match for "caf": "é" borders it and is a word
      // character too — a screenplay is written in French, so a naive [A-Za-z0-9_] class is wrong.
      final matches = ocptFindTextMatches(
        text: "Il commande un café glacé.",
        query: "caf",
        isCaseSensitive: false,
        isWholeWord: true,
      );

      expect(matches, isEmpty);

      final wholeWordMatches = ocptFindTextMatches(
        text: "Il commande un café glacé.",
        query: "café",
        isCaseSensitive: false,
        isWholeWord: true,
      );

      expect(wholeWordMatches, [const OcptTextMatch(start: 15, end: 19)]);
    });

    test("whole word on: a digit counts as a word character on either border", () {
      final matches = ocptFindTextMatches(
        text: "Scene 12 and scene 123 both mention 12.",
        query: "12",
        isCaseSensitive: false,
        isWholeWord: true,
      );

      // "12" inside "123" is rejected (bordered by the digit "3"); the standalone "12"s are kept.
      expect(matches, [
        const OcptTextMatch(start: 6, end: 8),
        const OcptTextMatch(start: 36, end: 38),
      ]);
    });

    test("a query holding regex metacharacters is matched literally", () {
      final matches = ocptFindTextMatches(
        text: "INT. HOUSE (DAY) - the clock reads 3.15.*",
        query: "(DAY)",
        isCaseSensitive: false,
        isWholeWord: false,
      );

      expect(matches, [const OcptTextMatch(start: 11, end: 16)]);

      final metacharMatches = ocptFindTextMatches(
        text: "INT. HOUSE (DAY) - the clock reads 3.15.*",
        query: "3.15.*",
        isCaseSensitive: false,
        isWholeWord: false,
      );

      expect(metacharMatches, [const OcptTextMatch(start: 35, end: 41)]);
    });

    test("overlapping candidates: non-overlapping, left to right", () {
      // "aa" over "aaaa" could candidate-match at offsets 0, 1 and 2; only the non-overlapping
      // left-to-right scan's own picks (0 and 2) are kept.
      final matches = ocptFindTextMatches(
        text: "aaaa",
        query: "aa",
        isCaseSensitive: true,
        isWholeWord: false,
      );

      expect(matches, [
        const OcptTextMatch(start: 0, end: 2),
        const OcptTextMatch(start: 2, end: 4),
      ]);
    });

    test("a query longer than the text matches nothing", () {
      expect(
        ocptFindTextMatches(
          text: "hi",
          query: "hello",
          isCaseSensitive: true,
          isWholeWord: false,
        ),
        isEmpty,
      );
    });
  });
}
