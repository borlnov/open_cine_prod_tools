// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:super_editor/super_editor.dart';

/// The attribution marking an inline authoring note (`[[text]]`) for dimmed rendering; unlike
/// [boldAttribution]/[italicsAttribution]/[underlineAttribution], a note's delimiters stay part of
/// its node's plain text (see [FountainStyledRun.isNote]), so this attribution is only ever used
/// for styling, never for serialization (a node's text already carries the brackets verbatim).
const NamedAttribution ocptFountainNoteAttribution = NamedAttribution("fountainNote");

/// The attribution marking a commented span (a boneyard `/* ... */` or a note `[[ ... ]]`, possibly
/// running over several nodes) for dimmed rendering, the same way as [ocptFountainNoteAttribution].
///
/// Unlike it, this one never takes part in serialization: it is put on a node's text by a derived
/// pass after every edit, from the commented spans of the whole document, and is only ever read by
/// the stylesheet.
const NamedAttribution ocptFountainCommentAttribution = NamedAttribution("fountainComment");

/// The attribution marking the first `[` of a `[[` the source escaped (`\[[x]]`): printed text, not
/// a note. The inline parser drops the backslash, so without it nothing would tell the characters
/// from a note typed by hand.
const NamedAttribution ocptFountainEscapedAttribution = NamedAttribution("fountainEscaped");

/// Convert between Fountain styled runs and super_editor attributed text, the inline half of
/// `OcptWysiwygCodec`.
final class OcptWysiwygInlineRuns {
  /// Private constructor: this class only exposes static members.
  const OcptWysiwygInlineRuns._();

  /// Convert [runs] into an `AttributedText`, applying [boldAttribution], [italicsAttribution],
  /// [underlineAttribution] and [ocptFountainNoteAttribution] over each run's span; the inverse of
  /// [runsFromAttributedText].
  static AttributedText attributedTextFromRuns(List<FountainStyledRun> runs) {
    final buffer = StringBuffer();
    final spans = <(int, int, Attribution)>[];

    for (final run in runs) {
      final start = buffer.length;
      buffer.write(run.text);
      final end = buffer.length - 1;
      if (end < start) {
        continue;
      }
      if (run.isBold) {
        spans.add((start, end, boldAttribution));
      }
      if (run.isItalic) {
        spans.add((start, end, italicsAttribution));
      }
      if (run.isUnderline) {
        spans.add((start, end, underlineAttribution));
      }
      if (run.isNote) {
        spans.add((start, end, ocptFountainNoteAttribution));
      }
    }

    final attributedText = AttributedText(buffer.toString());
    for (final (start, end, attribution) in spans) {
      attributedText.addAttribution(attribution, SpanRange(start, end));
    }
    return attributedText;
  }

  /// Convert [text]'s attributions into [FountainStyledRun]s, splitting it wherever its bold,
  /// italic, underline or note attribution set changes; the inverse of [attributedTextFromRuns].
  ///
  /// An [ocptFountainNoteAttribution] range always wins over any overlapping bold/italic/underline
  /// attribution (dropped at this point): a note is atomic in Fountain, so emphasis can never
  /// survive inside one on serialization.
  static List<FountainStyledRun> runsFromAttributedText(AttributedText text) {
    final plainText = text.toPlainText();
    if (plainText.isEmpty) {
      return const [];
    }

    (bool, bool, bool, bool) styleAt(int offset) {
      final attributions = text.getAllAttributionsAt(offset);
      final isNote = attributions.contains(ocptFountainNoteAttribution);
      return (
        !isNote && attributions.contains(boldAttribution),
        !isNote && attributions.contains(italicsAttribution),
        !isNote && attributions.contains(underlineAttribution),
        isNote,
      );
    }

    final runs = <FountainStyledRun>[];
    var runStart = 0;
    var currentStyle = styleAt(0);
    for (var offset = 1; offset <= plainText.length; offset++) {
      final style = offset < plainText.length ? styleAt(offset) : null;
      if (style == currentStyle) {
        continue;
      }

      runs.add(
        FountainStyledRun(
          text: plainText.substring(runStart, offset),
          isBold: currentStyle.$1,
          isItalic: currentStyle.$2,
          isUnderline: currentStyle.$3,
          isNote: currentStyle.$4,
        ),
      );
      runStart = offset;
      if (style != null) {
        currentStyle = style;
      }
    }

    return runs;
  }

  /// Tell whether [a] and [b] hold the same (start, exclusive end) ranges in the same order.
  static bool sameRanges(List<(int, int)> a, List<(int, int)> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
