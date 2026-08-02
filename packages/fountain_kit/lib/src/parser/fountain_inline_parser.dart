// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_inline_span.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_styled_run.dart';

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

  /// The markers [parseRuns] tries, in order, when looking for one level of
  /// nesting inside a span whose outer marker was `_` (underline): `_**x**_`
  /// → bold+underline, `_*x*_` → italic+underline, `_***x***_` →
  /// bold+italic+underline.
  static const List<_EmphasisMarker> _nestedInUnderline = [
    _EmphasisMarker('***', FountainInlineStyle.boldItalic),
    _EmphasisMarker('**', FountainInlineStyle.bold),
    _EmphasisMarker('*', FountainInlineStyle.italic),
  ];

  /// The marker [parseRuns] tries when looking for one level of nesting
  /// inside a span whose outer marker was `**` or `*`: `**_x_**` →
  /// bold+underline, `*_x_*` → italic+underline.
  static const List<_EmphasisMarker> _nestedInBoldOrItalic = [
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

  /// Parses [text] into a sequence of [FountainStyledRun]s, resolving one
  /// level of nesting inside emphasis spans that [parse] leaves as a single
  /// token with its inner markers still literally in its text.
  ///
  /// This builds on [parse] rather than duplicating its scanning logic: it
  /// calls [parse] to find each top-level span, then, for a span whose style
  /// is [FountainInlineStyle.bold], [FountainInlineStyle.italic] or
  /// [FountainInlineStyle.underline], checks whether that span's text is
  /// itself fully wrapped in one complementary marker (`_**x**_` →
  /// bold+underline, `_*x*_` → italic+underline, `**_x_**`/`*_x_*` → the
  /// same pairs the other way around, `_***x***_` → bold+italic+underline).
  /// [FountainInlineStyle.boldItalic] already covers `***x***` in a single
  /// token. A note span stays atomic: it never nests, and its
  /// [FountainStyledRun.text] is re-wrapped with its `[[`/`]]` delimiters
  /// (kept visible on screen, unlike emphasis markers) rather than stripped.
  ///
  /// [parse] itself is unchanged and keeps returning single-style spans, so
  /// callers that only need [FountainInlineStyle] (the raw-mode preview)
  /// keep working exactly as before.
  ///
  /// [line] and [startOffset] anchor the returned runs in a larger source
  /// document, exactly as [parse]'s parameters of the same name do: [line] is
  /// the 0-based source line [text] was taken from and [startOffset] is the
  /// character offset of `text[0]` within that document. They must be passed
  /// together; when either is left out, every returned run carries a `null`
  /// [FountainStyledRun.sourceRange] rather than one anchored at an offset
  /// that would be a fiction. Unlike [parse]'s spans, a run's range covers
  /// only what the run actually renders: the outer emphasis markers, and the
  /// nested ones this method resolves, are excluded from it.
  List<FountainStyledRun> parseRuns(
    String text, {
    int? line,
    int? startOffset,
  }) {
    final isAnchored = line != null && startOffset != null;
    return parse(
      text,
      line: line ?? 0,
      startOffset: startOffset ?? 0,
    ).map((span) => _toStyledRun(span, isAnchored: isAnchored)).toList();
  }

  /// Converts one top-level [FountainInlineSpan] into a [FountainStyledRun],
  /// resolving one level of nesting as described on [parseRuns].
  ///
  /// [isAnchored] tells whether [span]'s own range points into a real source
  /// document; when it does not, the resulting run carries no range at all.
  FountainStyledRun _toStyledRun(
    FountainInlineSpan span, {
    required bool isAnchored,
  }) {
    final range = isAnchored ? span.sourceRange : null;
    switch (span.style) {
      case FountainInlineStyle.plain:
        return FountainStyledRun(text: span.text, sourceRange: range);
      case FountainInlineStyle.note:
        // A note's `[[`/`]]` delimiters stay in the run's text, so its range
        // is the span's own, unnarrowed.
        return FountainStyledRun(
          text: '[[${span.text}]]',
          isNote: true,
          sourceRange: range,
        );
      case FountainInlineStyle.boldItalic:
        return FountainStyledRun(
          text: span.text,
          isBold: true,
          isItalic: true,
          sourceRange: _withoutMarkers(range, 3),
        );
      case FountainInlineStyle.bold:
        return _resolveNesting(
          span.text,
          _nestedInBoldOrItalic,
          _withoutMarkers(range, 2),
          isBold: true,
        );
      case FountainInlineStyle.italic:
        return _resolveNesting(
          span.text,
          _nestedInBoldOrItalic,
          _withoutMarkers(range, 1),
          isItalic: true,
        );
      case FountainInlineStyle.underline:
        return _resolveNesting(
          span.text,
          _nestedInUnderline,
          _withoutMarkers(range, 1),
          isUnderline: true,
        );
    }
  }

  /// Narrows [range] by [markerLength] characters at each end, turning the
  /// range of a `**bold**` span into the range of the `bold` a
  /// [FountainStyledRun] actually renders. Returns `null` for a `null`
  /// [range]; the parse rules guarantee the range is always long enough for
  /// the markers it is asked to drop.
  FountainSourceRange? _withoutMarkers(
    FountainSourceRange? range,
    int markerLength,
  ) => range == null
      ? null
      : FountainSourceRange(
          startLine: range.startLine,
          endLine: range.endLine,
          startOffset: range.startOffset + markerLength,
          endOffset: range.endOffset - markerLength,
        );

  /// Checks whether [text] is fully wrapped in one of [candidates]; if so,
  /// returns a [FountainStyledRun] combining that nested style with the
  /// outer style already carried by [isBold]/[isItalic]/[isUnderline],
  /// otherwise returns a run with only the outer style and [text] as-is.
  ///
  /// [range] is [text]'s own range, the outer marker already dropped from it;
  /// a resolved nesting narrows it further by the nested marker's own length,
  /// so the returned run's range always covers exactly what it renders.
  FountainStyledRun _resolveNesting(
    String text,
    List<_EmphasisMarker> candidates,
    FountainSourceRange? range, {
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
  }) {
    final nested = _matchFullWrap(text, candidates);
    if (nested == null) {
      return FountainStyledRun(
        text: text,
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
        sourceRange: range,
      );
    }
    final (nestedStyle, innerText, nestedMarkerLength) = nested;
    return FountainStyledRun(
      text: innerText,
      isBold:
          isBold ||
          nestedStyle == FountainInlineStyle.boldItalic ||
          nestedStyle == FountainInlineStyle.bold,
      isItalic:
          isItalic ||
          nestedStyle == FountainInlineStyle.boldItalic ||
          nestedStyle == FountainInlineStyle.italic,
      isUnderline: isUnderline || nestedStyle == FountainInlineStyle.underline,
      sourceRange: _withoutMarkers(range, nestedMarkerLength),
    );
  }

  /// Returns the nested style, inner text and marker length if [text] is
  /// entirely wrapped in one marker from [candidates] (tried longest-first),
  /// using the same leftmost-closing-marker rule as [parse] itself so the
  /// two agree on what counts as a matched pair; returns `null` if [text] is
  /// not fully wrapped by any candidate (for example plain, unmatched, or
  /// wrapped by only part of the string).
  (FountainInlineStyle, String, int)? _matchFullWrap(
    String text,
    List<_EmphasisMarker> candidates,
  ) {
    for (final marker in candidates) {
      final token = marker.token;
      if (text.length < 2 * token.length || !text.startsWith(token)) {
        continue;
      }
      final closeIndex = text.indexOf(token, token.length);
      if (closeIndex == text.length - token.length) {
        return (
          marker.style,
          text.substring(token.length, closeIndex),
          token.length,
        );
      }
    }
    return null;
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
