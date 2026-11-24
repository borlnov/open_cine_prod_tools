// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_highlight_spans.dart';

/// The text controller of the field of a note card, which paints the matches of the find/replace
/// query inside the text it holds.
class OcptNoteHighlightController extends TextEditingController {
  /// The matches painted, or null for none.
  OcptNoteMatches? _matches;

  /// Class constructor.
  OcptNoteHighlightController({required TextEditingValue value}) : super.fromValue(value);

  /// Get the matches painted, or null for none.
  OcptNoteMatches? get matches => _matches;

  /// Set the matches painted, which repaints the field when they changed.
  set matches(OcptNoteMatches? value) {
    if (value != _matches) {
      _matches = value;
      notifyListeners();
    }
  }

  /// Build the span of the text of the field, the matches highlighted. A text being composed keeps
  /// the span the field gives it.
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_matches == null || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    return OcptNoteHighlightSpans.build(text, style, _matches);
  }
}
