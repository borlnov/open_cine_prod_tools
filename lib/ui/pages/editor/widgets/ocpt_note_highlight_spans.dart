// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/painting.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';

/// The text of a note card cut in spans, the matches of the find/replace query painted with the
/// colours the matches of the text get.
final class OcptNoteHighlightSpans {
  /// Private constructor: this class only exposes static members.
  const OcptNoteHighlightSpans._();

  /// Build the span of [text] in [style], the ranges of [matches] drawn over the colour of a
  /// match, the current one over the stronger colour. A range running past [text] is ignored.
  static TextSpan build(String text, TextStyle? style, OcptNoteMatches? matches) {
    if (matches == null || matches.ranges.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final children = <TextSpan>[];
    var cursor = 0;
    for (final range in matches.ranges) {
      if (range.start < cursor || range.end > text.length || range.start >= range.end) {
        continue;
      }

      if (range.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(
            backgroundColor: range == matches.current
                ? ocptEditorSearchCurrentMatchColor
                : ocptEditorSearchMatchColor,
          ),
        ),
      );
      cursor = range.end;
    }

    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}
