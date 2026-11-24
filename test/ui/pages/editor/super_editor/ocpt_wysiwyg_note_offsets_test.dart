// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_note_offsets.dart';
import 'package:super_editor/super_editor.dart';

/// Run the tests of [OcptWysiwygNoteOffsets], over `ab[[xy]]cd[[]]e`: the notes `xy` and an empty
/// one, at the offsets 2 and 5 of the node's text `ab￼cd￼e`.
void main() {
  final offsets = OcptWysiwygNoteOffsets.fromExpansions({2: "[[xy]]", 5: "[[]]"});
  const line = "ab[[xy]]cd[[]]e";

  group("a node holding no note", () {
    final none = OcptWysiwygNoteOffsets.fromExpansions({});

    test("is the identity", () {
      expect(none.isIdentity, isTrue);
      expect(none.expand("abc"), "abc");
      expect(none.lineOffsetOf(2), 2);
      expect(none.nodeRangeOf(1, 3), (1, 3));
      final ranges = [(0, 1), (2, 3)];
      expect(none.nodeRangesOf(ranges), ranges);
    });

    test("is read from a text without placeholder", () {
      expect(OcptWysiwygNoteOffsets.of(AttributedText("abc")).isIdentity, isTrue);
    });
  });

  group("a node holding notes", () {
    test("is read from the placeholders of its text, other objects left as one character", () {
      final text = AttributedText(
        "abcd",
      ).insertPlaceholder(2, OcptFountainNote.create("xy")).insertPlaceholder(3, "other");

      final read = OcptWysiwygNoteOffsets.of(text);

      expect(read.noteIndices, [2]);
      expect(read.noteExpansions, ["[[xy]]"]);
      expect(read.expand(text.toPlainText()), "ab[[xy]]￼cd");
    });

    test("expands every note back to its Fountain form", () {
      expect(offsets.expand("ab￼cd￼e"), line);
    });

    test("gives the range of each note in the line", () {
      expect(offsets.noteLineRanges, [(2, 8), (10, 14)]);
    });

    test("maps a node boundary to the line boundary", () {
      expect(
        [for (var offset = 0; offset <= 7; offset++) offsets.lineOffsetOf(offset)],
        [0, 1, 2, 8, 9, 10, 14, 15],
      );
    });

    test("maps a line boundary outside every note to the same node boundary", () {
      expect(offsets.nodeStartOf(0), 0);
      expect(offsets.nodeEndOf(2), 2);
      expect(offsets.nodeStartOf(8), 3);
      expect(offsets.nodeEndOf(10), 5);
      expect(offsets.nodeEndOf(15), 7);
    });

    test("covers a note whole when a range starts or ends inside it", () {
      expect(offsets.nodeStartOf(5), 2);
      expect(offsets.nodeEndOf(5), 3);
      expect(offsets.nodeRangeOf(4, 6), (2, 3));
      expect(offsets.nodeRangeOf(1, 9), (1, 4));
      expect(offsets.nodeRangeOf(11, 13), (5, 6));
    });

    test("maps a range spanning notes whole", () {
      expect(offsets.nodeRangeOf(0, 15), (0, 7));
      expect(offsets.lineRangeOf(0, 7), (0, 15));
      expect(offsets.nodeRangesOf([(2, 8), (10, 14)]), [(2, 3), (5, 6)]);
    });

    test("maps a node boundary to the line and back", () {
      for (var offset = 0; offset <= 7; offset++) {
        expect(offsets.nodeStartOf(offsets.lineOffsetOf(offset)), offset);
        expect(offsets.nodeEndOf(offsets.lineOffsetOf(offset)), offset);
      }
    });
  });
}
