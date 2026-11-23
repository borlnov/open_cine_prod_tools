// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// The forcing-marker half of `OcptWysiwygCodec`: how a source line is stripped of the marker its
/// type was read from (`#`, `=`, `~`, `> <`, `===`...) and of its `#N#` scene number, to get the
/// display text a node holds.
final class OcptWysiwygMarkers {
  /// Mirrors `FountainBlockBuilder`'s own (private) scene-number pattern, matching a trailing
  /// `#N#` tag on a scene heading line (e.g. `#4A#` in `INT. HOUSE #4A#`), captured as group 1.
  static final RegExp sceneNumberPattern = RegExp(r'#([A-Za-z0-9.\-]+)#\s*$');

  /// Mirrors [FountainLineClassifier]'s own (private) section-heading pattern, so a section
  /// node's display text can be recovered without re-deriving the leading `#` run's length here:
  /// see `OcptWysiwygCodec.decode`'s per-type stripping and the class doc comment on the
  /// section-level normalization `OcptWysiwygCodec.encode` accepts.
  static final RegExp _sectionPattern = RegExp(r'^(#{1,6})\s*(.*)$');

  /// Strip [rawLine]'s forcing prefix (if any) for its classified [type], returning its display
  /// text and whether a marker was actually present. Mirrors, in reverse, every rule
  /// [FountainLineClassifier.classifyLine] and [FountainLineWriter.writeLine] use for that type.
  ///
  /// A line this cannot strip exactly (a marker preceded by a comment, a page break or a centered
  /// text written with anything but its canonical form, [classificationLine] being the line with
  /// its boneyards and standalone notes blanked out) is kept as written, with no marker: its type
  /// is still the one the parser reads, and `OcptWysiwygCodec.encode` writes the text back as it
  /// is.
  static (String, bool) stripDisplayText(
    String rawLine,
    FountainLineType type,
    String classificationLine,
  ) {
    if (_isKeptAsWritten(rawLine, type, classificationLine)) {
      return (rawLine, false);
    }
    switch (type) {
      case FountainLineType.blank:
        // Never reached: blank lines are folded into ocptBlankLinesBefore before this is called.
        return (rawLine, false);
      case FountainLineType.pageBreak:
        // `FountainLineWriter` ignores the text entirely for a page break; there is nothing
        // meaningful to preserve.
        return ("", false);
      case FountainLineType.section:
        final match = _sectionPattern.firstMatch(rawLine.trim());
        return (match?.group(2) ?? "", true);
      case FountainLineType.synopsis:
        var rest = rawLine.substring(1);
        if (rest.startsWith(" ")) {
          rest = rest.substring(1);
        }
        return (rest, true);
      case FountainLineType.sceneHeading:
        return rawLine.startsWith(".") && !rawLine.startsWith("..")
            ? (rawLine.substring(1), true)
            : (rawLine, false);
      case FountainLineType.action:
        return rawLine.startsWith("!") ? (rawLine.substring(1), true) : (rawLine, false);
      case FountainLineType.character:
        return rawLine.startsWith("@") ? (rawLine.substring(1), true) : (rawLine, false);
      case FountainLineType.transition:
        return rawLine.startsWith(">") ? (rawLine.substring(1), true) : (rawLine, false);
      case FountainLineType.lyrics:
        return (rawLine.substring(1), true);
      case FountainLineType.centeredText:
        return (_stripCentered(rawLine), true);
      case FountainLineType.dialogue:
      case FountainLineType.parenthetical:
        return (rawLine, false);
    }
  }

  /// Strip a trailing `#N#` scene-number tag off a scene heading's already forcing-marker-
  /// stripped [text], returning the text without it (trailing whitespace trimmed) and the
  /// captured number, or [text] unchanged and null when there is no tag.
  static (String, String?) extractSceneNumber(String text) {
    final match = sceneNumberPattern.firstMatch(text);
    if (match == null) {
      return (text, null);
    }
    return (text.substring(0, match.start).trimRight(), match.group(1));
  }

  /// Tell whether the source line [rawLine], classified as [type], cannot have its marker stripped
  /// and re-written exactly.
  static bool _isKeptAsWritten(String rawLine, FountainLineType type, String classificationLine) {
    final leading = rawLine.length - rawLine.trimLeft().length;
    final markerIsCommented =
        classificationLine.length - classificationLine.trimLeft().length > leading ||
        FountainCommentSpans.notes(rawLine).any((note) => note.start == leading);
    return switch (type) {
      FountainLineType.section => markerIsCommented,
      FountainLineType.synopsis => markerIsCommented || !rawLine.startsWith("="),
      FountainLineType.lyrics => markerIsCommented || !rawLine.startsWith("~"),
      FountainLineType.pageBreak => rawLine != "===",
      FountainLineType.centeredText =>
        !(rawLine.startsWith("> ") && rawLine.endsWith(" <") && rawLine.length >= 4),
      _ => false,
    };
  }

  /// Strip the `> ` / ` <` wrapping [FountainLineWriter.writeLine] always emits for
  /// [FountainLineType.centeredText] (`'> $text <'`), tolerating the wrapping marker with or
  /// without its usual single space so a hand-written `>text<` line still recovers its inner text.
  static String _stripCentered(String rawLine) {
    final trimmed = rawLine.trim();
    if (trimmed.length < 2) {
      return "";
    }
    var body = trimmed.substring(1, trimmed.length - 1);
    if (body.startsWith(" ")) {
      body = body.substring(1);
    }
    if (body.endsWith(" ")) {
      body = body.substring(0, body.length - 1);
    }
    return body;
  }
}
