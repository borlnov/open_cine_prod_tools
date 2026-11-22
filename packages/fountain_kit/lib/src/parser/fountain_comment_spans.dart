// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A commented span of a text, as offsets: a boneyard (`/* ... */`) or an authoring note
/// (`[[ ... ]]`), markers included.
class FountainCommentSpan {
  /// The offset of the first character of the span, its opening marker included.
  final int start;

  /// The offset one past the last character of the span, its closing marker included.
  final int end;

  /// Whether the span is a boneyard (`true`) or a note (`false`).
  final bool isBoneyard;

  /// Class constructor.
  const FountainCommentSpan({required this.start, required this.end, required this.isBoneyard});

  /// Tell whether [offset] lies inside the span (its markers included).
  bool contains(int offset) => offset >= start && offset < end;
}

/// The one rule saying which parts of a Fountain text are commented out.
///
/// A boneyard (`/* ... */`) and a note (`[[ ... ]]`) both run to the first closing marker, on
/// several lines if need be. The parser, the spell checker and the styled editor all read the
/// spans through this class, so none of them keeps a copy of the patterns.
class FountainCommentSpans {
  /// Matches a boneyard, possibly spanning several lines.
  static final RegExp _boneyardPattern = RegExp(r'/\*[\s\S]*?\*/');

  /// Matches a note, possibly spanning several lines.
  static final RegExp _notePattern = RegExp(r'\[\[[\s\S]*?\]\]');

  /// Utility class: no instance.
  const FountainCommentSpans._();

  /// Get the boneyard spans of [text], in ascending order.
  static List<FountainCommentSpan> boneyards(String text) => _spansOf(text, _boneyardPattern, true);

  /// Get the note spans of [text], in ascending order.
  static List<FountainCommentSpan> notes(String text) => _spansOf(text, _notePattern, false);

  /// Get the commented spans of [text] as the parser reads them, in ascending order and without
  /// overlap: the boneyards first, then the notes found once the boneyards are blanked out, so a
  /// note inside a boneyard is no span of its own, and a `/*` inside a note starts nothing.
  static List<FountainCommentSpan> of(String text) {
    final boneyardSpans = boneyards(text);
    final noteSpans = notes(scrub(text, boneyardSpans));
    return [...boneyardSpans, ...noteSpans]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Get the notes of [text] that take one or more whole lines by themselves, nothing but whitespace
  /// sharing their lines: what the parser turns into a standalone note block rather than an inline
  /// note of another line.
  static List<FountainCommentSpan> standaloneNotes(String text) {
    final spans = <FountainCommentSpan>[];
    for (final note in notes(text)) {
      final lineStart = note.start == 0 ? 0 : text.lastIndexOf('\n', note.start - 1) + 1;
      final lineEndIndex = text.indexOf('\n', note.end);
      final lineEnd = lineEndIndex == -1 ? text.length : lineEndIndex;
      if (text.substring(lineStart, note.start).trim().isEmpty &&
          text.substring(note.end, lineEnd).trim().isEmpty) {
        spans.add(note);
      }
    }
    return spans;
  }

  /// Get [text] as the parser hands it to its line classifier: the boneyards blanked out, then the
  /// standalone notes, offsets and line structure kept. The inline notes stay, the classifier
  /// reads past them.
  static String scrubForClassification(String text) {
    final withoutBoneyards = scrub(text, boneyards(text));
    return scrub(withoutBoneyards, standaloneNotes(withoutBoneyards));
  }

  /// Get [text] with every character covered by [spans] replaced by a space, newlines kept, so the
  /// line structure and every other offset stay stable.
  static String scrub(String text, Iterable<FountainCommentSpan> spans) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      buffer.write(text.substring(cursor, span.start));
      for (var index = span.start; index < span.end; index++) {
        buffer.write(text[index] == '\n' ? '\n' : ' ');
      }
      cursor = span.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  /// Get every match of [pattern] in [text] as a span.
  static List<FountainCommentSpan> _spansOf(String text, RegExp pattern, bool isBoneyard) => [
    for (final match in pattern.allMatches(text))
      FountainCommentSpan(start: match.start, end: match.end, isBoneyard: isBoneyard),
  ];
}
