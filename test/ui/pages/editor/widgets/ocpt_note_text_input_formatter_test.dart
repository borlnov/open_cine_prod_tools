// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_text_input_formatter.dart';

/// Run the tests of [OcptNoteTextInputFormatter].
void main() {
  const formatter = OcptNoteTextInputFormatter();

  test("keeps the old value of a text no note can hold", () {
    const old = TextEditingValue(text: "old");
    for (final refused in ["a]]b", "a/*b", "a*/b", "ends with ]", "]]"]) {
      expect(formatter.formatEditUpdate(old, TextEditingValue(text: refused)), old);
    }
  });

  test("lets through every other text, brackets and slashes included", () {
    const old = TextEditingValue(text: "old");
    for (final accepted in ["", "a [b] c", "[a", "a/b", "a*b", "line\nline", "one ] two"]) {
      final value = TextEditingValue(text: accepted);
      expect(formatter.formatEditUpdate(old, value), value);
    }
  });

  test("writes a line left empty with two spaces, and an empty text as it is", () {
    expect(OcptNoteTextInputFormatter.normalised(""), "");
    expect(OcptNoteTextInputFormatter.normalised("a\n\nb"), "a\n  \nb");
    expect(OcptNoteTextInputFormatter.normalised("a\n"), "a\n  ");
    expect(OcptNoteTextInputFormatter.normalised("a\r\nb"), "a\nb");
    expect(OcptNoteTextInputFormatter.normalised("a\n  \nb"), "a\n  \nb");
  });

  test("drops the blank lines between the first and the last when the note may hold none", () {
    String normalised(String text) =>
        OcptNoteTextInputFormatter.normalised(text, allowsBlankLines: false);

    expect(normalised("a\n\nb"), "a\nb");
    expect(normalised("a\n  \n \nb"), "a\nb");
    expect(normalised("\na\n"), "  \na\n  ");
    expect(normalised("a\n\n"), "a\n  ");
    expect(normalised("a\nb"), "a\nb");
    expect(normalised(""), "");
  });
}
