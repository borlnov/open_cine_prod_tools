// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';

/// The raw mode's source text controller, extended to paint the find/replace bar's highlight
/// directly into the field it searches — the raw mode's own half of the plan's decision that each
/// editing surface highlights what it shows, the way `SpellingAndGrammarStyler` does for the
/// styled editor.
///
/// [updateMatches] is the page's only way to feed this controller the matches to paint (`raw mode
/// searches the Fountain source text, the very characters the field displays`); [buildTextSpan] is
/// overridden to lay a background wash under every match, [ocptEditorSearchCurrentMatchColor] for
/// the current one, [ocptEditorSearchMatchColor] for the rest.
///
/// Every offset in [_matches] is defensively clamped to [text]'s own length: the page recomputes
/// matches reactively from whatever text this controller currently holds, but a single frame can
/// still see this controller repaint with matches computed against a text that has since changed
/// underneath it (a keystroke updates [text] and notifies listeners synchronously, before the
/// bloc's own round trip reports fresh matches back) — a match past the current text's end must be
/// dropped rather than thrown from a `String.substring` call.
class OcptEditorSearchTextController extends TextEditingController {
  /// The matches currently painted, in source order.
  List<OcptTextMatch> _matches = const [];

  /// The index, in [_matches], of the current match; null while there is none.
  int? _currentMatchIndex;

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

  /// [withComposing] is deliberately ignored whenever [_matches] is non-empty: honouring it would
  /// mean intersecting the IME's own composing range against every match span (a composing
  /// segment can start or end mid-match), for a rare pairing — an IME composing session while the
  /// find/replace bar's highlight is also active — that has no real cost beyond a dropped
  /// underline for the composing text itself while it lasts; the composed characters land in the
  /// document exactly the same either way. [super.buildTextSpan] still honours it normally once
  /// [_matches] is empty (the bar closed, or the query cleared).
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_matches.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final source = text;
    final children = <TextSpan>[];
    var cursor = 0;

    for (var i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      if (match.start >= source.length || match.start < cursor) {
        continue;
      }
      final end = match.end > source.length ? source.length : match.end;

      if (match.start > cursor) {
        children.add(TextSpan(text: source.substring(cursor, match.start), style: style));
      }
      children.add(
        TextSpan(
          text: source.substring(match.start, end),
          style: (style ?? const TextStyle()).copyWith(
            backgroundColor: i == _currentMatchIndex
                ? ocptEditorSearchCurrentMatchColor
                : ocptEditorSearchMatchColor,
          ),
        ),
      );
      cursor = end;
    }

    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}
