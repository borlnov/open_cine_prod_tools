// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';
import 'package:spell_kit/spell_kit.dart';

/// The raw mode's source text controller, extended to paint the find/replace bar's highlight and
/// the spell-check underline directly into the field it searches — the raw mode's own half of the
/// rule that each editing surface highlights what it shows, the way
/// `SpellingAndGrammarStyler` does for the styled editor's own highlight.
/// `docs/architecture/screenplay.md` explains why the raw mode can't instead take
/// Flutter's own `SpellCheckConfiguration`: the moment `EditableText` receives one spell-check
/// result, it stops calling this controller's [buildTextSpan] at all, and the find bar's highlight
/// would silently disappear forever.
///
/// [updateMatches] and [updateSpellCheckRanges] are the page's only ways to feed this controller
/// what to paint (`raw mode searches/checks the Fountain source text, the very characters the field
/// displays`); [buildTextSpan] segments the text on the boundaries of *both* range sets so a
/// misspelled word sitting inside a search match gets both a background wash
/// ([ocptEditorSearchCurrentMatchColor] for the current match, [ocptEditorSearchMatchColor] for the
/// rest) and a wavy underline ([ocptEditorSpellCheckErrorColor]) at once.
class OcptEditorSearchTextController extends TextEditingController {
  /// The matches currently painted, in source order.
  List<OcptTextMatch> _matches = const [];

  /// The index, in [_matches], of the current match; null while there is none.
  int? _currentMatchIndex;

  /// The misspelled ranges currently painted, document-absolute — the very offsets [text] is
  /// addressed by.
  List<SpellRange> _spellCheckRanges = const [];

  /// Class constructor
  OcptEditorSearchTextController({super.text});

  /// Replaces the matches this controller paints and repaints, unless [matches] and
  /// [currentMatchIndex] are exactly the ones already held.
  void updateMatches(List<OcptTextMatch> matches, int? currentMatchIndex) {
    if (listEquals(_matches, matches) && _currentMatchIndex == currentMatchIndex) {
      return;
    }
    _matches = matches;
    _currentMatchIndex = currentMatchIndex;
    notifyListeners();
  }

  /// Replaces the misspelled ranges this controller paints and repaints, unless [ranges] is
  /// exactly what is already held — the same dedup [updateMatches] already applies to its own
  /// ranges.
  void updateSpellCheckRanges(List<SpellRange> ranges) {
    if (listEquals(_spellCheckRanges, ranges)) {
      return;
    }
    _spellCheckRanges = ranges;
    notifyListeners();
  }

  /// [withComposing] is deliberately ignored whenever [_matches] or [_spellCheckRanges] is
  /// non-empty: honouring it would mean intersecting the IME's own composing range against every
  /// match/misspelling span (a composing segment can start or end mid-span), for a rare pairing —
  /// an IME composing session while the find/replace bar's highlight or the spell-check underline
  /// is also active — that has no real cost beyond a dropped underline for the composing text
  /// itself while it lasts; the composed characters land in the document exactly the same either
  /// way. [super.buildTextSpan] still honours it normally once both are empty (the bar closed or
  /// the query cleared, and spell-checking off or nothing misspelled).
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_matches.isEmpty && _spellCheckRanges.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final source = text;

    // Both range sets are defensively clamped to `source`'s own length before either reaches a
    // boundary or a `substring` call — every offset here was computed against a text this
    // controller may since have moved on from (`updateMatches`'s own doc comment explains the
    // match side of this: a keystroke updates `text` and notifies listeners synchronously, before
    // either the bloc's search round trip or a spell-check isolate round trip reports back).
    //
    // A misspelling is dropped *outright* the moment either of its own offsets no longer fits,
    // rather than clamped to the text's end the way a match's end still is just below: it arrives
    // one isolate round trip later than a search match does, so it is *more* exposed to this, not
    // less (`docs/architecture/screenplay.md` names that trap), and clamping it would
    // risk painting a wavy underline over a word it was never actually computed against.
    final matches = <_RangeSpan>[
      for (var i = 0; i < _matches.length; i++)
        if (_matches[i].start >= 0 && _matches[i].start < source.length)
          _RangeSpan(
            _matches[i].start,
            _matches[i].end > source.length ? source.length : _matches[i].end,
            isCurrentMatch: i == _currentMatchIndex,
          ),
    ];
    final misspellings = <_RangeSpan>[
      for (final range in _spellCheckRanges)
        if (range.start >= 0 && range.end <= source.length && range.start < range.end)
          _RangeSpan(range.start, range.end, isCurrentMatch: false),
    ];

    if (matches.isEmpty && misspellings.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final boundaries = <int>{0, source.length};
    for (final span in [...matches, ...misspellings]) {
      boundaries
        ..add(span.start)
        ..add(span.end);
    }
    final sortedBoundaries = boundaries.toList()..sort();
    final segmentCount = sortedBoundaries.length - 1;

    // Which segments each range set covers, resolved by walking the spans once rather than by
    // asking every segment about every span. This runs on every repaint of a field holding the
    // whole screenplay — a keystroke repaints it — and a feature script can carry several hundred
    // misspellings next to a find bar's own matches, which a per-segment scan would turn into
    // hundreds of thousands of comparisons per frame. Both lists are already in ascending order
    // (matches in source order, misspellings as the checker found them), so one forward walk
    // marks every segment they cover.
    final matchBySegment = List<_RangeSpan?>.filled(segmentCount, null);
    final isMisspelledSegment = List<bool>.filled(segmentCount, false);
    _markCoveredSegments(
      spans: matches,
      sortedBoundaries: sortedBoundaries,
      onSegment: (index, span) => matchBySegment[index] ??= span,
    );
    _markCoveredSegments(
      spans: misspellings,
      sortedBoundaries: sortedBoundaries,
      onSegment: (index, _) => isMisspelledSegment[index] = true,
    );

    final children = <TextSpan>[];
    for (var i = 0; i < segmentCount; i++) {
      final segmentStart = sortedBoundaries[i];
      final segmentEnd = sortedBoundaries[i + 1];
      if (segmentStart == segmentEnd) {
        continue;
      }

      final coveringMatch = matchBySegment[i];

      var segmentStyle = style ?? const TextStyle();
      if (coveringMatch != null) {
        segmentStyle = segmentStyle.copyWith(
          backgroundColor: coveringMatch.isCurrentMatch
              ? ocptEditorSearchCurrentMatchColor
              : ocptEditorSearchMatchColor,
        );
      }
      if (isMisspelledSegment[i]) {
        segmentStyle = segmentStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: ocptEditorSpellCheckErrorColor,
        );
      }

      children.add(
        TextSpan(text: source.substring(segmentStart, segmentEnd), style: segmentStyle),
      );
    }

    return TextSpan(style: style, children: children);
  }
}

/// Calls [onSegment] once per segment of [sortedBoundaries] that each of [spans] covers.
///
/// Every boundary [OcptEditorSearchTextController.buildTextSpan] segments on comes from a span's
/// own start or end, so a segment is always either fully inside or fully outside any given span,
/// never straddling one — which is what lets this simply walk each span's own segment run.
///
/// [spans] is expected in ascending start order, so the search for a span's first segment resumes
/// where the previous span's did instead of restarting from the beginning; a span list that turned
/// out not to be sorted would still be handled correctly, only with the cursor rewound for it.
void _markCoveredSegments({
  required List<_RangeSpan> spans,
  required List<int> sortedBoundaries,
  required void Function(int segmentIndex, _RangeSpan span) onSegment,
}) {
  final segmentCount = sortedBoundaries.length - 1;
  var cursor = 0;
  for (final span in spans) {
    if (cursor > 0 && sortedBoundaries[cursor] > span.start) {
      cursor = 0;
    }
    while (cursor < segmentCount && sortedBoundaries[cursor] < span.start) {
      cursor++;
    }
    for (var i = cursor; i < segmentCount && sortedBoundaries[i + 1] <= span.end; i++) {
      onSegment(i, span);
    }
  }
}

/// One `[start, end)` span [OcptEditorSearchTextController.buildTextSpan] segments the text
/// against — a match's own [isCurrentMatch] tells the current one apart from the rest; a
/// misspelling (which has no such notion) always carries `false`.
class _RangeSpan {
  /// The offset of this span's first character.
  final int start;

  /// The offset one past this span's last character.
  final int end;

  /// Whether this span is the find/replace bar's current match.
  final bool isCurrentMatch;

  /// Class constructor
  const _RangeSpan(this.start, this.end, {required this.isCurrentMatch});
}
