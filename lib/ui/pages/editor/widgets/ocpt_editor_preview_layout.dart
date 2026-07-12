// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/rendering.dart';
import 'package:fountain_kit/fountain_kit.dart';

/// Converts `FountainLayoutMetrics` character-column measurements into pixels for the preview.
///
/// Screenplay layout is defined in character columns of 12-point Courier (a fixed-pitch font), so
/// the whole mapping reduces to one number: the width of a single Courier Prime glyph at the
/// preview's font size, measured once per font size with a [TextPainter] and cached in
/// [_glyphWidthCache]. Every element indent/width is then `columns * glyphWidth`, and the page
/// itself is `pageWidthInches * charsPerInch * glyphWidth` wide.
///
/// Because the font is fixed-pitch, this class can also estimate how many lines a block wraps to
/// (greedy word wrap at the element's column width), which is what the preview uses to compute
/// the estimated scroll offset of any block without building its widget first (the preview list
/// is lazy, so an unbuilt block has no render object to `ensureVisible`).
class OcptEditorPreviewLayout {
  /// The font family the preview is typeset in, bundled with the app (see `pubspec.yaml`).
  static const fontFamily = "CourierPrime";

  /// The preview's font size, in logical pixels.
  static const double fontSize = 13;

  /// The preview's line height factor, applied to [fontSize] to get [lineHeight].
  static const double lineHeightFactor = 1.4;

  /// The vertical space left between two consecutive blocks: one blank line, like the one that
  /// separates them in the Fountain source.
  static const double blockSpacingFactor = 1;

  /// The measured width of a Courier Prime glyph, cached per font size: the font is fixed-pitch,
  /// so a single glyph ("0") is representative of every column.
  static final Map<double, double> _glyphWidthCache = {};

  /// The layout metrics (page size, margins, element boxes) the preview is typeset with.
  final FountainLayoutMetrics metrics;

  /// The width of one character column, in logical pixels.
  final double glyphWidth;

  /// Class constructor
  OcptEditorPreviewLayout({required this.metrics}) : glyphWidth = _measureGlyphWidth(fontSize);

  /// The height of one text line, in logical pixels.
  double get lineHeight => fontSize * lineHeightFactor;

  /// The vertical space left between two consecutive blocks, in logical pixels.
  double get blockSpacing => lineHeight * blockSpacingFactor;

  /// The full page width, in logical pixels.
  double get pageWidth => metrics.pageWidthInches * metrics.charsPerInch * glyphWidth;

  /// The top page margin, in logical pixels.
  double get marginTop => metrics.marginTopInches * metrics.charsPerInch * glyphWidth;

  /// The bottom page margin, in logical pixels.
  double get marginBottom => metrics.marginBottomInches * metrics.charsPerInch * glyphWidth;

  /// The distance from the page's left edge to where [element]'s text starts, in logical pixels.
  double indentOf(FountainElementLayout element) => element.leftIndentColumns * glyphWidth;

  /// The maximum width available to [element]'s text before it wraps, in logical pixels.
  double widthOf(FountainElementLayout element) => element.maxWidthColumns * glyphWidth;

  /// Returns the blocks of [document] that are part of the printed screenplay, in source order.
  ///
  /// Sections, synopses, notes and boneyard comments are editor-only constructs: they are never
  /// printed, so the preview skips them entirely.
  static List<FountainBlock> printableBlocks(FountainDocument document) => document.blocks
      .where(
        (block) => switch (block) {
          FountainSection() ||
          FountainSynopsis() ||
          FountainNoteBlock() ||
          FountainBoneyard() => false,
          _ => true,
        },
      )
      .toList(growable: false);

  /// Estimates the rendered height of [block], in logical pixels, including the trailing
  /// [blockSpacing].
  ///
  /// The estimate is based on a greedy word wrap at each element's column width, which matches
  /// what the fixed-pitch rendering does for all but pathological inputs; it's used to compute
  /// scroll targets, where being within a line or two is more than enough.
  double estimateBlockHeight(FountainBlock block) =>
      _estimateBlockLineCount(block) * lineHeight + blockSpacing;

  /// Estimates how many rendered lines [block] spans, wrapping included.
  int _estimateBlockLineCount(FountainBlock block) => switch (block) {
    FountainSceneHeading(:final headingText, :final sceneNumber) => wrappedLineCount(
      sceneNumber == null ? headingText : "$sceneNumber. $headingText",
      metrics.sceneHeading.maxWidthColumns,
    ),
    FountainActionBlock(:final lines) => _sumOfWrappedLines(lines, metrics.action.maxWidthColumns),
    FountainDialogueGroup(:final character, :final children) =>
      wrappedLineCount(_characterCueText(character), metrics.character.maxWidthColumns) +
          children
              .map(
                (child) => switch (child) {
                  FountainParenthetical(:final text) => wrappedLineCount(
                    "($text)",
                    metrics.parenthetical.maxWidthColumns,
                  ),
                  _ => wrappedLineCount(
                    child is FountainDialogueLine ? child.text : "",
                    metrics.dialogue.maxWidthColumns,
                  ),
                },
              )
              .fold(0, (sum, lineCount) => sum + lineCount),
    FountainTransition(:final text) => wrappedLineCount(text, metrics.transition.maxWidthColumns),
    FountainCenteredText(:final text) => wrappedLineCount(
      text,
      metrics.centeredText.maxWidthColumns,
    ),
    FountainLyrics(:final lines) => _sumOfWrappedLines(lines, metrics.lyrics.maxWidthColumns),
    FountainPageBreak() => 1,
    // Never printed (filtered out by [printableBlocks]) or never top-level (character cues,
    // parentheticals and dialogue lines only live inside a dialogue group).
    _ => 0,
  };

  /// The full character cue line: the name, followed by its parenthetical extension if any.
  static String _characterCueText(FountainCharacter character) => character.extension == null
      ? character.name
      : "${character.name} (${character.extension})";

  /// Sums [wrappedLineCount] over [lines] at [maxColumns].
  static int _sumOfWrappedLines(List<String> lines, int maxColumns) =>
      lines.fold(0, (sum, line) => sum + wrappedLineCount(line, maxColumns));

  /// Returns how many lines [text] wraps to in a box [maxColumns] characters wide, using a greedy
  /// word wrap (which is what text layout does for a fixed-pitch font). An empty [text] still
  /// occupies one line.
  static int wrappedLineCount(String text, int maxColumns) {
    if (text.length <= maxColumns) {
      return 1;
    }

    var lineCount = 1;
    var currentLineLength = 0;
    for (final word in text.split(" ")) {
      // +1 for the space that precedes the word on a non-empty line.
      final neededLength = currentLineLength == 0 ? word.length : currentLineLength + 1 + word.length;
      if (neededLength <= maxColumns) {
        currentLineLength = neededLength;
      } else {
        // A word longer than the whole box hard-wraps mid-word.
        lineCount += word.length > maxColumns ? (word.length / maxColumns).ceil() : 1;
        currentLineLength = word.length % maxColumns;
      }
    }

    return lineCount;
  }

  /// Measures (and caches) the width of one Courier Prime glyph at [fontSize] logical pixels.
  static double _measureGlyphWidth(double fontSize) => _glyphWidthCache.putIfAbsent(fontSize, () {
    final painter = TextPainter(
      text: TextSpan(
        text: "0",
        style: TextStyle(fontFamily: fontFamily, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();

    return width;
  });
}
