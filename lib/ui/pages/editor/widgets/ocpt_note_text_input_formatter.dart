// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';

/// The [TextInputFormatter] of the field of a note card: it keeps the old value of the field when
/// the new one could not be the text of a note in the Fountain source.
///
/// A note is written `[[text]]`, so its text can neither hold the `]]` closing it, nor end with a
/// `]` that would form one with the closing brackets, nor hold a `/*` or a `*/` opening or closing
/// a boneyard around it.
class OcptNoteTextInputFormatter extends TextInputFormatter {
  /// The two spaces a line left empty is written with in a note, for Fountain to keep the note
  /// together over a blank line.
  static const String blankLine = "  ";

  /// The character sequences no note text may hold.
  static const List<String> _forbidden = ["]]", "/*", "*/"];

  /// Class constructor.
  const OcptNoteTextInputFormatter();

  /// Get [newValue] when it is acceptable as the text of a note, [oldValue] otherwise.
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      isAcceptable(newValue.text) ? newValue : oldValue;

  /// Tell whether [text] can be the text of a note.
  static bool isAcceptable(String text) => !text.endsWith("]") && !_forbidden.any(text.contains);

  /// Get [text] as it is written in the Fountain source of a note: its line breaks are `\n`, and
  /// a line left empty is two spaces, unless the whole text is empty.
  static String normalised(String text) => text.isEmpty
      ? text
      : text
            .replaceAll("\r\n", "\n")
            .replaceAll("\r", "\n")
            .split("\n")
            .map((line) => line.isEmpty ? blankLine : line)
            .join("\n");
}
