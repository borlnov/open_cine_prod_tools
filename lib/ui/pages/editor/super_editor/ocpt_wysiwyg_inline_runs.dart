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

/// The attribution marking the first `[` of a `[[` the source escaped (`\[[x]]`, or `\[[x` whose
/// note would close on a later line): printed text, not a note. The inline parser drops the
/// backslash, so without it nothing would tell the characters from a note typed by hand, and
/// [OcptWysiwygInlineRuns.writeLine] writes it back in front of every `[` carrying it.
const NamedAttribution ocptFountainEscapedAttribution = NamedAttribution("fountainEscaped");

/// Convert between Fountain styled runs and super_editor attributed text, the inline half of
/// `OcptWysiwygCodec`.
final class OcptWysiwygInlineRuns {
  /// The serializer used to turn a node's styled inline runs back into marked-up display text.
  static const FountainInlineSerializer _serializer = FountainInlineSerializer();

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
    final (runs, escapedBrackets) = _parseRunsKeepingEscapes(text, boneyardStars);
    final styled = attributedTextFromRuns(runs);
    for (final offset in escapedBrackets) {
      styled.addAttribution(ocptFountainEscapedAttribution, SpanRange(offset, offset));
    }
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

  /// Write [text] as one marked-up line of Fountain source, the inverse of [parseInline]: a `[`
  /// carrying [ocptFountainEscapedAttribution] that no `]]` follows on the line is written escaped,
  /// which the serializer, reading the line alone, would not do, since a `]]` on a later line would
  /// otherwise close it into a note. [literalStars] are as [FountainInlineSerializer.write] reads
  /// them.
  static String writeLine(AttributedText text, Set<int> literalStars) {
    final escaped = text.getAttributionSpans({ocptFountainEscapedAttribution});
    if (escaped.isEmpty) {
      return _serializer.write(runsFromAttributedText(text), literalStars: literalStars);
    }
    final plainText = text.toPlainText();
    final expansions = [
      for (final placeholder in text.placeholders.values)
        if (placeholder is OcptFountainNote) placeholder.expansion,
    ].join();
    final mask = _unusedCharacter(plainText + expansions, 0xE000);
    final masked = plainText.split("");
    for (final span in escaped) {
      for (var index = span.start; index <= span.end; index++) {
        // A `]]` on the line already makes the serializer escape the bracket, when it must.
        if (masked[index] == "[" && !plainText.contains("]]", index)) {
          masked[index] = mask;
        }
      }
    }
    final buffer = StringBuffer();
    for (var index = 0; index < masked.length; index++) {
      if (!text.placeholders.containsKey(index)) {
        buffer.write(masked[index]);
      }
    }
    final line = _serializer.write(
      runsFromAttributedText(
        AttributedText(buffer.toString(), text.spans.copy(), text.placeholders),
      ),
      literalStars: literalStars,
    );
    final written = StringBuffer();
    for (var index = 0; index < line.length; index++) {
      if (line[index] != mask) {
        written.write(line[index]);
        continue;
      }
      // A backslash the serializer left right before would escape the escaping one.
      written.write(_isEscaped(line, index) ? r"\\[" : r"\[");
    }
    return written.toString();
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

  /// Parse [text] into runs, and get the offsets, in the runs' text put end to end, of the first
  /// `[` of every `[[` the source escaped, whether a `]]` closes it on the line or not.
  ///
  /// Each escaping `\[` is swapped for two characters the parser leaves alone before parsing, so
  /// that [boneyardStars], offsets in [text], still point at the same characters.
  static (List<FountainStyledRun>, List<int>) _parseRunsKeepingEscapes(
    String text,
    Set<int> boneyardStars,
  ) {
    const parser = FountainInlineParser();
    final escapes = <int>[
      for (var index = 1; index < text.length; index++)
        if (text.startsWith("[[", index) && _isEscaped(text, index)) index,
    ];
    if (escapes.isEmpty) {
      return (parser.parseRuns(text, literalStars: boneyardStars), const []);
    }
    final backslash = _unusedCharacter(text, 0xE000);
    final bracket = _unusedCharacter(text, backslash.codeUnitAt(0) + 1);
    final masked = text.split("");
    for (final index in escapes) {
      masked[index - 1] = backslash;
      masked[index] = bracket;
    }
    final escapedBrackets = <int>[];
    final runs = <FountainStyledRun>[];
    var offset = 0;
    for (final run in parser.parseRuns(masked.join(), literalStars: boneyardStars)) {
      final buffer = StringBuffer();
      for (final character in run.text.split("")) {
        if (character == backslash) {
          continue;
        }
        if (character == bracket) {
          escapedBrackets.add(offset + buffer.length);
        }
        buffer.write(character == bracket ? "[" : character);
      }
      offset += buffer.length;
      runs.add(
        FountainStyledRun(
          text: buffer.toString(),
          isBold: run.isBold,
          isItalic: run.isItalic,
          isUnderline: run.isUnderline,
          isNote: run.isNote,
        ),
      );
    }
    return (runs, escapedBrackets);
  }

  /// Get the first character from [from] on that [text] does not hold.
  static String _unusedCharacter(String text, int from) {
    var code = from;
    while (text.contains(String.fromCharCode(code))) {
      code++;
    }
    return String.fromCharCode(code);
  }

  /// Tell whether the character at [index] of [text] is preceded by an odd number of backslashes.
  static bool _isEscaped(String text, int index) {
    var count = 0;
    while (index - count > 0 && text[index - count - 1] == r"\") {
      count++;
    }
    return count.isOdd;
  }
}
