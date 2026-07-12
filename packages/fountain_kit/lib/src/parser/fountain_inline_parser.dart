// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_inline_span.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';

/// One recognized emphasis marker, paired with the [FountainInlineStyle] it
/// produces.
class _EmphasisMarker {
  /// Creates an [_EmphasisMarker].
  const _EmphasisMarker(this.token, this.style);

  /// The literal marker text, for example `**`.
  final String token;

  /// The style a span wrapped in [token] is rendered with.
  final FountainInlineStyle style;
}

/// Parses inline emphasis (`*italic*`, `**bold**`, `***bold italic***`,
/// `_underline_`) and inline authoring notes (`[[note]]`) out of a single
/// line of Fountain text.
///
/// Emphasis never spans a line break, so this parser only ever looks at one
/// line at a time; it does not need to know anything about the rest of the
/// document. It is a pure function of its input, which keeps it reusable
/// both from the block builder (for a future rich-text rendering pass) and
/// directly by callers who just want to highlight a snippet of text.
class FountainInlineParser {
  /// Creates a [FountainInlineParser].
  const FountainInlineParser();

  /// The emphasis markers this parser recognizes, ordered so that the
  /// longest marker (`***`) is tried before its prefixes (`**`, `*`).
  static const List<_EmphasisMarker> _markers = [
    _EmphasisMarker('***', FountainInlineStyle.boldItalic),
    _EmphasisMarker('**', FountainInlineStyle.bold),
    _EmphasisMarker('*', FountainInlineStyle.italic),
    _EmphasisMarker('_', FountainInlineStyle.underline),
  ];

  /// Characters that may be escaped with a leading `\` to suppress their
  /// usual markup meaning.
  static const String _escapable = r'*_\[]';

  /// Parses [text] into a sequence of [FountainInlineSpan]s.
  ///
  /// [line] is the 0-based source line [text] was taken from, and
  /// [startOffset] is the character offset, in the larger source document,
  /// of `text[0]`. Both default to zero, which is convenient for parsing a
  /// snippet in isolation (as most tests do); a caller assembling a full
  /// document should pass the real values so the resulting spans'
  /// [FountainInlineSpan.sourceRange]s point back into the original source.
  List<FountainInlineSpan> parse(
    String text, {
    int line = 0,
    int startOffset = 0,
  }) {
    final spans = <FountainInlineSpan>[];
    final plainBuffer = StringBuffer();
    var plainStart = 0;
    var index = 0;

    void flushPlain(int end) {
      if (plainBuffer.isEmpty) {
        return;
      }
      spans.add(
        FountainInlineSpan(
          text: plainBuffer.toString(),
          style: FountainInlineStyle.plain,
          sourceRange: _range(line, startOffset, plainStart, end),
        ),
      );
      plainBuffer.clear();
    }

    while (index < text.length) {
      final char = text[index];

      if (char == r'\' &&
          index + 1 < text.length &&
          _escapable.contains(text[index + 1])) {
        if (plainBuffer.isEmpty) {
          plainStart = index;
        }
        plainBuffer.write(text[index + 1]);
        index += 2;
        continue;
      }

      if (text.startsWith('[[', index)) {
        final closeIndex = text.indexOf(']]', index + 2);
        if (closeIndex != -1) {
          flushPlain(index);
          spans.add(
            FountainInlineSpan(
              text: text.substring(index + 2, closeIndex),
              style: FountainInlineStyle.note,
              sourceRange: _range(line, startOffset, index, closeIndex + 2),
            ),
          );
          index = closeIndex + 2;
          plainStart = index;
          continue;
        }
      }

      final matchedMarker = _matchEmphasis(text, index);
      if (matchedMarker != null) {
        final marker = matchedMarker.token;
        final closeIndex = text.indexOf(marker, index + marker.length);
        if (closeIndex != -1) {
          flushPlain(index);
          spans.add(
            FountainInlineSpan(
              text: text.substring(index + marker.length, closeIndex),
              style: matchedMarker.style,
              sourceRange: _range(
                line,
                startOffset,
                index,
                closeIndex + marker.length,
              ),
            ),
          );
          index = closeIndex + marker.length;
          plainStart = index;
          continue;
        }
      }

      if (plainBuffer.isEmpty) {
        plainStart = index;
      }
      plainBuffer.write(char);
      index++;
    }

    flushPlain(text.length);
    return spans;
  }

  /// Returns the first [_EmphasisMarker] whose token starts at [index] in
  /// [text], trying longer tokens first, or `null` if none matches.
  _EmphasisMarker? _matchEmphasis(String text, int index) {
    for (final marker in _markers) {
      if (text.startsWith(marker.token, index)) {
        return marker;
      }
    }
    return null;
  }

  /// Builds the [FountainSourceRange] for a span covering
  /// `[localStart, localEnd)` of a line, given that line's own [line]
  /// number and [lineStartOffset] within the larger source document.
  FountainSourceRange _range(
    int line,
    int lineStartOffset,
    int localStart,
    int localEnd,
  ) => FountainSourceRange(
    startLine: line,
    endLine: line,
    startOffset: lineStartOffset + localStart,
    endOffset: lineStartOffset + localEnd,
  );
}
