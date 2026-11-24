// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search_match.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search_notes.dart';
import 'package:super_editor/super_editor.dart';

/// Build a match of a note.
OcptStyledSearchMatch _inNote(String noteId, int start, int end, {int anchor = 4}) =>
    OcptStyledSearchMatch(
      nodeId: "n",
      noteId: noteId,
      match: OcptTextMatch(start: start, end: end),
      anchor: anchor,
    );

/// Run the tests of the pure helpers of the search in the notes.
void main() {
  group("OcptStyledSearchNotes.replacedText", () {
    test("replaces every match, left to right", () {
      expect(
        OcptStyledSearchNotes.replacedText(
          "an old old one",
          const [OcptTextMatch(start: 3, end: 6), OcptTextMatch(start: 7, end: 10)],
          "new",
          allowsBlankLines: true,
        ),
        "an new new one",
      );
    });

    test("refuses a text holding `]]`, `/*` or `*/`, or ending with `]`", () {
      for (final replacement in ["]]", "a]]", "/*", "*/", "x]"]) {
        expect(
          OcptStyledSearchNotes.replacedText(
            "old",
            const [OcptTextMatch(start: 0, end: 3)],
            replacement,
            allowsBlankLines: true,
          ),
          isNull,
          reason: replacement,
        );
      }
    });

    test("writes a line left empty as two spaces, or drops it where blank lines are refused", () {
      const matches = [OcptTextMatch(start: 2, end: 3)];

      expect(
        OcptStyledSearchNotes.replacedText("a\nb\nc", matches, "", allowsBlankLines: true),
        "a\n  \nc",
      );
      expect(
        OcptStyledSearchNotes.replacedText("a\nb\nc", matches, "", allowsBlankLines: false),
        "a\nc",
      );
    });
  });

  group("OcptStyledSearchNotes.withNoteTexts", () {
    test("changes the text of the notes named, keeping their identifiers and the text around", () {
      const first = OcptFountainNote(id: "1", text: "one");
      const second = OcptFountainNote(id: "2", text: "two");
      final original = AttributedText("ab")
          .insertPlaceholder(0, first)
          .copyAndAppend(AttributedText(" cd"))
          .insertPlaceholder(4, second);

      final result = OcptStyledSearchNotes.withNoteTexts(original, {"2": "deux"});

      expect(result.toPlainText(), original.toPlainText());
      expect(result.placeholders, {0: first, 4: second.withText("deux")});
    });
  });

  group("OcptStyledSearchNotes.matchesByNote", () {
    test("groups the matches in notes by note, flagging the current one", () {
      final inFirst = _inNote("1", 0, 3);
      final inSecond = _inNote("2", 5, 8, anchor: 9);
      final others = [
        const OcptStyledSearchMatch(nodeId: "n", match: OcptTextMatch(start: 0, end: 3), anchor: 0),
        inFirst,
        _inNote("1", 6, 9),
        inSecond,
      ];

      final result = OcptStyledSearchNotes.matchesByNote(others, inSecond);

      expect(result.keys, ["1", "2"]);
      expect(
        result["1"],
        const OcptNoteMatches(
          ranges: [OcptTextMatch(start: 0, end: 3), OcptTextMatch(start: 6, end: 9)],
        ),
      );
      expect(result["2"]!.current, const OcptTextMatch(start: 5, end: 8));
    });
  });

  group("OcptStyledSearchMatch", () {
    test("orders a match of a note at its marker, after a text match at the same place", () {
      final inNote = _inNote("1", 2, 4);

      expect(inNote.isAtOrAfter(anchor: 4, orderInAnchor: 2), isTrue);
      expect(inNote.isAtOrAfter(anchor: 4, orderInAnchor: 3), isFalse);
      expect(inNote.isAtOrAfter(anchor: 5, orderInAnchor: -1), isFalse);
      expect(inNote.isAtOrAfter(anchor: 3, orderInAnchor: 99), isTrue);
      expect(inNote.isInNote, isTrue);
    });
  });
}
