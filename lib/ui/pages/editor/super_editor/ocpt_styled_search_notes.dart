// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search_match.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_text_input_formatter.dart';
import 'package:super_editor/super_editor.dart';

/// The pure half of the find/replace of the styled editor over the text of the notes.
final class OcptStyledSearchNotes {
  /// Private constructor: this class only exposes static members.
  const OcptStyledSearchNotes._();

  /// Get the matches inside the notes of [matches], by note identifier, [current] being the
  /// current match of the search.
  static Map<String, OcptNoteMatches> matchesByNote(
    List<OcptStyledSearchMatch> matches,
    OcptStyledSearchMatch? current,
  ) {
    final ranges = <String, List<OcptTextMatch>>{};
    for (final entry in matches) {
      final noteId = entry.noteId;
      if (noteId != null) {
        (ranges[noteId] ??= []).add(entry.match);
      }
    }

    return {
      for (final entry in ranges.entries)
        entry.key: OcptNoteMatches(
          ranges: entry.value,
          current: current?.noteId == entry.key ? current?.match : null,
        ),
    };
  }

  /// Get the text of a note once its [matches] are replaced with [replacement], as the Fountain
  /// source writes it, or null when the note cannot take it: it would hold a `]]`, a `/*` or a
  /// `*/`, or end with a `]`.
  ///
  /// [text] is the text of the note, [allowsBlankLines] whether it may hold a blank line (see
  /// `OcptNoteTextInputFormatter.normalised`).
  static String? replacedText(
    String text,
    List<OcptTextMatch> matches,
    String replacement, {
    required bool allowsBlankLines,
  }) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      buffer
        ..write(text.substring(cursor, match.start))
        ..write(replacement);
      cursor = match.end;
    }
    buffer.write(text.substring(cursor));

    final replaced = OcptNoteTextInputFormatter.normalised(
      buffer.toString(),
      allowsBlankLines: allowsBlankLines,
    );
    return OcptNoteTextInputFormatter.isAcceptable(replaced) ? replaced : null;
  }

  /// Get [original] with the note of each identifier of [texts] given the text it maps to, every
  /// note keeping its identifier and its place, and the rest of the text what it was.
  static AttributedText withNoteTexts(AttributedText original, Map<String, String> texts) {
    var result = original;
    for (final placeholder in original.placeholders.entries) {
      final note = placeholder.value;
      final text = note is OcptFountainNote ? texts[note.id] : null;
      if (note is! OcptFountainNote || text == null) {
        continue;
      }

      final offset = placeholder.key;
      result = (offset <= 0 ? AttributedText("") : result.copyText(0, offset))
          .copyAndAppend(AttributedText("").insertPlaceholder(0, note.withText(text)))
          .copyAndAppend(
            offset + 1 >= result.length ? AttributedText("") : result.copyText(offset + 1),
          );
    }
    return result;
  }
}
