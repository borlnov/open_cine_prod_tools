// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/rendering.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// Converts `FountainLayoutMetrics` character-column measurements into pixels for the preview.
///
/// Screenplay layout is defined in character columns of 12-point Courier (a fixed-pitch font), so
/// the whole mapping reduces to one number: the width of a single Courier Prime glyph at the
/// preview's font size, measured once per font size with a [TextPainter] and cached in
/// [_glyphWidthCache]. Every element indent/width is then `columns * glyphWidth`, and the page
/// itself is `pageWidthInches * pixelsPerInch` wide.
///
/// Every measurement — horizontal AND vertical — is derived from that single [pixelsPerInch]
/// scale: [lineHeight] is `pixelsPerInch / metrics.linesPerInch` rather than an arbitrary
/// `fontSize` multiple, which is what guarantees the identity
/// `marginTop + metrics.linesPerPage * lineHeight + marginBottom ≈ pageHeight` (see
/// `ocpt_editor_preview_layout_test.dart`): a page's simulated sheet is exactly as tall as
/// `linesPerPage` lines of text plus its margins, so content genuinely fills (rather than
/// overflows or under-fills) the sheet [pageHeight] describes. A previous version derived
/// [lineHeight] from `fontSize * 1.4` instead, which didn't agree with the horizontal scale: a
/// full page of `linesPerPage` lines rendered taller than [pageHeight], visibly overflowing every
/// simulated sheet.
///
/// Because the font is fixed-pitch, this class can also estimate how many lines a block wraps to
/// (greedy word wrap at the element's column width), which is what the preview uses to compute
/// the estimated scroll offset of any block without building its widget first (the preview list
/// is lazy, so an unbuilt block has no render object to `ensureVisible`).
class OcptEditorPreviewLayout {
  /// The font family the preview is typeset in, the app's one bundled fixed-pitch family.
  static const fontFamily = ocptMonospaceFontFamily;

  /// The preview's font size, in logical pixels.
  static const double fontSize = 13;

  /// The vertical space left between two consecutive blocks: one blank line, like the one that
  /// separates them in the Fountain source.
  static const double blockSpacingFactor = 1;

  /// The themed gap left between two consecutive simulated paper sheets, in logical pixels: the
  /// raw preview's paginated pages, the styled editor's page-sheets painter and its pagination
  /// pass all share this one value so their page boundaries agree pixel-for-pixel.
  static const double pageGap = 16;

  /// The measured width of a Courier Prime glyph, cached per font size: the font is fixed-pitch,
  /// so a single glyph ("0") is representative of every column.
  static final Map<double, double> _glyphWidthCache = {};

  /// The layout metrics (page size, margins, element boxes) the preview is typeset with.
  final FountainLayoutMetrics metrics;

  /// The width of one character column, in logical pixels.
  final double glyphWidth;

  /// Class constructor
  OcptEditorPreviewLayout({required this.metrics}) : glyphWidth = _measureGlyphWidth(fontSize);

  /// The single pixels-per-inch scale every measurement of this class derives from, horizontally
  /// AND vertically (see class doc comment for why that matters).
  double get pixelsPerInch => metrics.charsPerInch * glyphWidth;

  /// The height of one text line, in logical pixels: `pixelsPerInch / metrics.linesPerInch`.
  double get lineHeight => pixelsPerInch / metrics.linesPerInch;

  /// The line-height factor equivalent to [lineHeight] at [fontSize], for a `TextStyle.height`
  /// that renders text at exactly [lineHeight] (see `OcptEditorPreviewBlock` and
  /// `OcptFountainEditorStylesheet`, which both need the actually-rendered line height to match
  /// this class's own estimate).
  double get lineHeightFactor => lineHeight / fontSize;

  /// The vertical space left between two consecutive blocks, in logical pixels.
  double get blockSpacing => lineHeight * blockSpacingFactor;

  /// The full page width, in logical pixels.
  double get pageWidth => metrics.pageWidthInches * pixelsPerInch;

  /// The full page height, in logical pixels.
  double get pageHeight => metrics.pageHeightInches * pixelsPerInch;

  /// The left page margin, in logical pixels.
  double get marginLeft => metrics.marginLeftInches * pixelsPerInch;

  /// The right page margin, in logical pixels.
  double get marginRight => metrics.marginRightInches * pixelsPerInch;

  /// The top page margin, in logical pixels.
  double get marginTop => metrics.marginTopInches * pixelsPerInch;

  /// The bottom page margin, in logical pixels.
  double get marginBottom => metrics.marginBottomInches * pixelsPerInch;

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
      estimatedLineCount(block) * lineHeight + blockSpacing;

  /// Estimates how many rendered lines [block] spans, wrapping included.
  ///
  /// Used both by [estimateBlockHeight] (scroll-sync offset estimation) and by page-simulation
  /// pagination, which buckets blocks/nodes into pages by comparing a running sum of this count
  /// against [FountainLayoutMetrics.linesPerPage].
  int estimatedLineCount(FountainBlock block) => switch (block) {
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
