// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
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
  /// survive inside one on serialization. A note held as a placeholder ([OcptFountainNote]) is a
  /// note run of its own, its `[[text]]`, whatever attribution covers it.
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
    (bool, bool, bool, bool)? currentStyle;

    void closeRun(int end) {
      final style = currentStyle;
      if (style == null || end <= runStart) {
        return;
      }
      runs.add(
        FountainStyledRun(
          text: plainText.substring(runStart, end),
          isBold: style.$1,
          isItalic: style.$2,
          isUnderline: style.$3,
          isNote: style.$4,
        ),
      );
    }

    for (var offset = 0; offset < plainText.length; offset++) {
      final placeholder = text.placeholders[offset];
      if (placeholder is OcptFountainNote) {
        closeRun(offset);
        runs.add(FountainStyledRun(text: placeholder.expansion, isNote: true));
        currentStyle = null;
        continue;
      }
      final style = styleAt(offset);
      if (currentStyle == null) {
        runStart = offset;
      } else if (style != currentStyle) {
        closeRun(offset);
        runStart = offset;
      }
      currentStyle = style;
    }
    closeRun(plainText.length);

    return runs;
  }

  /// Parse [text] into styled text: the emphasis markers become attributions, a note an atomic
  /// run, and an escaped `[[` (which the parser reads as plain text) carries
  /// [ocptFountainEscapedAttribution], so that nothing takes it for a note afterwards.
  /// [boneyardStars] are the offsets of the `*` of the boneyard delimiters, which are no emphasis.
  static AttributedText parseInline(String text, Set<int> boneyardStars) {
    final runs = const FountainInlineParser().parseRuns(text, literalStars: boneyardStars);
    final styled = attributedTextFromRuns(runs);
    // The notes the parser read, run by run: two notes side by side are two runs, which their
    // attribution alone would join into one range.
    final notes = <(int, int)>{};
    var offset = 0;
    for (final run in runs) {
      if (run.isNote) {
        notes.add((offset, offset + run.text.length));
      }
      offset += run.text.length;
    }
    for (final span in FountainCommentSpans.notes(styled.toPlainText(), honoursEscapes: false)) {
      if (!notes.contains((span.start, span.end))) {
        styled.addAttribution(ocptFountainEscapedAttribution, SpanRange(span.start, span.start));
      }
    }
    return styled;
  }

  /// Copy [text]'s attribution spans and placeholders onto [upperText], the text uppercased with a
  /// replacement character at each placeholder, unchanged: uppercasing never changes a string's
  /// length for this app's supported locales, so every span's (start, end) offset still refers to
  /// the same run of characters.
  static AttributedText uppercased(AttributedText text, String upperText) {
    final buffer = StringBuffer();
    for (var index = 0; index < upperText.length; index++) {
      if (!text.placeholders.containsKey(index)) {
        buffer.write(upperText[index]);
      }
    }
    return AttributedText(buffer.toString(), text.spans.copy(), text.placeholders);
  }

  /// Get [text] in capitals, the characters inside [commentedRanges] (start, exclusive end) left as
  /// written.
  static String uppercasedOutside(String text, List<(int, int)> commentedRanges) {
    final buffer = StringBuffer();
    var cursor = 0;
    for (final (start, end) in commentedRanges) {
      buffer.write(text.substring(cursor, start).toUpperCase());
      buffer.write(text.substring(start, end));
      cursor = end;
    }
    buffer.write(text.substring(cursor).toUpperCase());
    return buffer.toString();
  }

  /// Tell whether [text] is made of notes held as placeholders and whitespace, at least one note.
  static bool holdsOnlyNotes(AttributedText text) {
    final plainText = text.toPlainText();
    var hasNote = false;
    for (var index = 0; index < plainText.length; index++) {
      if (text.placeholders[index] is OcptFountainNote) {
        hasNote = true;
      } else if (plainText[index].trim().isNotEmpty) {
        return false;
      }
    }
    return hasNote;
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
