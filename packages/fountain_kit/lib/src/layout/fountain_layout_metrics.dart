// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The horizontal alignment of a printed screenplay element within its
/// layout box.
enum FountainLayoutAlignment {
  /// Text starts at the box's left indent.
  left,

  /// Text is centered within the box's width.
  center,

  /// Text ends at the box's right edge (used for transitions).
  right,
}

/// The layout box a single kind of printed screenplay element is set in:
/// how far it is indented from the page's left edge, how wide it is
/// allowed to grow, and how its text is aligned within that width.
///
/// Every measurement is given both in inches (the authoritative unit, since
/// screenplay layout conventions are defined in inches) and in character
/// columns of 12-point Courier, which is the monospaced font every
/// screenplay is traditionally set in. A column count is
/// `round(inches * charsPerInch)`.
class FountainElementLayout extends Equatable {
  /// Creates a [FountainElementLayout].
  const FountainElementLayout({
    required this.leftIndentInches,
    required this.leftIndentColumns,
    required this.maxWidthInches,
    required this.maxWidthColumns,
    required this.alignment,
  });

  /// The distance from the page's physical left edge to where this
  /// element's text starts, in inches.
  final double leftIndentInches;

  /// [leftIndentInches] expressed in character columns.
  final int leftIndentColumns;

  /// The maximum width available to this element's text before it must
  /// wrap, in inches.
  final double maxWidthInches;

  /// [maxWidthInches] expressed in character columns.
  final int maxWidthColumns;

  /// How this element's text is aligned within its box.
  final FountainLayoutAlignment alignment;

  @override
  List<Object?> get props => [
    leftIndentInches,
    leftIndentColumns,
    maxWidthInches,
    maxWidthColumns,
    alignment,
  ];

  @override
  String toString() =>
      'FountainElementLayout(indent: ${leftIndentInches}in/'
      '$leftIndentColumns cols, width: ${maxWidthInches}in/'
      '$maxWidthColumns cols, $alignment)';
}

/// Page and element layout metrics for typesetting a Fountain screenplay in
/// 12-point Courier, the traditional screenplay font.
///
/// 12-point Courier is a fixed-pitch font that, at the point size used for
/// screenplays, sets 10 characters per inch horizontally and 6 lines per
/// inch vertically; every measurement below is derived from those two
/// constants plus the standard US screenplay page margins (1.5 inches on
/// the left, to leave room for binding punches; 1 inch on the top, bottom
/// and right) and the standard element indents measured from the *page's*
/// left edge (not from the left margin):
///
/// * Scene headings and action text start at the left margin and use the
///   full printable width.
/// * Character cues start 3.7 inches from the page's left edge (2.2 inches
///   past the left margin).
/// * Parentheticals start 3.1 inches from the page's left edge.
/// * Dialogue starts 2.5 inches from the page's left edge and is capped at
///   3.5 inches wide, regardless of page size, which is the width every
///   major screenwriting application wraps dialogue at.
/// * Transitions are right-aligned within the full printable width, so
///   they end flush with the right margin.
/// * Lyrics are set like dialogue, since they are sung/spoken text.
class FountainLayoutMetrics extends Equatable {
  /// Creates a [FountainLayoutMetrics] with every measurement given
  /// explicitly. Prefer the [FountainLayoutMetrics.usLetter] and
  /// [FountainLayoutMetrics.a4] presets unless a non-standard page size is
  /// genuinely required.
  const FountainLayoutMetrics({
    required this.pageWidthInches,
    required this.pageHeightInches,
    required this.marginLeftInches,
    required this.marginRightInches,
    required this.marginTopInches,
    required this.marginBottomInches,
    required this.charsPerInch,
    required this.linesPerInch,
    required this.linesPerPage,
    required this.sceneHeading,
    required this.action,
    required this.character,
    required this.parenthetical,
    required this.dialogue,
    required this.transition,
    required this.centeredText,
    required this.lyrics,
  });

  /// Millimeters per inch, used to derive [FountainLayoutMetrics.a4]'s page
  /// size from the ISO 216 A4 dimensions (210 mm by 297 mm).
  static const double _millimetersPerInch = 25.4;

  /// The standard US screenplay left margin, in inches: wider than the
  /// other three margins to leave room for three-hole-punch binding.
  static const double _standardMarginLeftInches = 1.5;

  /// The standard US screenplay top, bottom and right margin, in inches.
  static const double _standardMarginInches = 1;

  /// 12-point Courier's horizontal pitch: 10 characters per inch.
  static const double _courierCharsPerInch = 10;

  /// 12-point Courier's vertical pitch, single-spaced: 6 lines per inch.
  static const double _courierLinesPerInch = 6;

  /// The distance from the page's left edge to where a character cue
  /// starts, in inches (2.2 inches past the standard 1.5-inch left
  /// margin).
  static const double _characterIndentInches = 3.7;

  /// The distance from the page's left edge to where a parenthetical
  /// starts, in inches.
  static const double _parentheticalIndentInches = 3.1;

  /// The distance from the page's left edge to where dialogue starts, in
  /// inches.
  static const double _dialogueIndentInches = 2.5;

  /// The maximum width of a dialogue (or lyrics) block, in inches. Fixed
  /// regardless of page size, unlike the other elements' widths (which
  /// stretch to the printable area's right edge).
  static const double _dialogueMaxWidthInches = 3.5;

  /// The full page width, in inches.
  final double pageWidthInches;

  /// The full page height, in inches.
  final double pageHeightInches;

  /// The left page margin, in inches.
  final double marginLeftInches;

  /// The right page margin, in inches.
  final double marginRightInches;

  /// The top page margin, in inches.
  final double marginTopInches;

  /// The bottom page margin, in inches.
  final double marginBottomInches;

  /// The font's horizontal pitch, in characters per inch.
  final double charsPerInch;

  /// The font's vertical pitch, in lines per inch.
  final double linesPerInch;

  /// The number of text lines that fit in the printable area of one page,
  /// i.e. `floor((pageHeightInches - marginTopInches - marginBottomInches)
  /// * linesPerInch)`.
  final int linesPerPage;

  /// The layout box for scene headings.
  final FountainElementLayout sceneHeading;

  /// The layout box for action/description text.
  final FountainElementLayout action;

  /// The layout box for character cues.
  final FountainElementLayout character;

  /// The layout box for parentheticals.
  final FountainElementLayout parenthetical;

  /// The layout box for dialogue.
  final FountainElementLayout dialogue;

  /// The layout box for transitions.
  final FountainElementLayout transition;

  /// The layout box for centered text.
  final FountainElementLayout centeredText;

  /// The layout box for lyrics.
  final FountainElementLayout lyrics;

  /// The printable width of the page: `pageWidthInches - marginLeftInches -
  /// marginRightInches`.
  double get printableWidthInches =>
      pageWidthInches - marginLeftInches - marginRightInches;

  /// The printable height of the page: `pageHeightInches -
  /// marginTopInches - marginBottomInches`.
  double get printableHeightInches =>
      pageHeightInches - marginTopInches - marginBottomInches;

  /// Builds the standard US Letter (8.5 by 11 inch) preset.
  factory FountainLayoutMetrics.usLetter() => FountainLayoutMetrics._standard(
    pageWidthInches: 8.5,
    pageHeightInches: 11,
  );

  /// Builds the standard ISO A4 (210 by 297 mm) preset.
  ///
  /// The page margins and element indents are kept identical, in inches, to
  /// [FountainLayoutMetrics.usLetter]: only A4's narrower/taller page
  /// changes the printable area and, in turn, [linesPerPage] and the
  /// elements that stretch to the printable area's right edge (scene
  /// heading, action, character, parenthetical, transition, centered text).
  /// Dialogue and lyrics keep their fixed 3.5-inch width either way.
  factory FountainLayoutMetrics.a4() => FountainLayoutMetrics._standard(
    pageWidthInches: 210 / _millimetersPerInch,
    pageHeightInches: 297 / _millimetersPerInch,
  );

  /// Builds a [FountainLayoutMetrics] for a page of [pageWidthInches] by
  /// [pageHeightInches], using the standard US screenplay margins, element
  /// indents and Courier 12 pitch documented on this class.
  factory FountainLayoutMetrics._standard({
    required double pageWidthInches,
    required double pageHeightInches,
  }) {
    const marginLeft = _standardMarginLeftInches;
    const marginRight = _standardMarginInches;
    const marginTop = _standardMarginInches;
    const marginBottom = _standardMarginInches;
    final printableWidth = pageWidthInches - marginLeft - marginRight;
    final printableHeight = pageHeightInches - marginTop - marginBottom;
    final rightEdge = pageWidthInches - marginRight;

    FountainElementLayout fullWidthLeftAligned(double leftIndent) =>
        _elementLayout(
          leftIndentInches: leftIndent,
          maxWidthInches: rightEdge - leftIndent,
          alignment: FountainLayoutAlignment.left,
        );

    return FountainLayoutMetrics(
      pageWidthInches: pageWidthInches,
      pageHeightInches: pageHeightInches,
      marginLeftInches: marginLeft,
      marginRightInches: marginRight,
      marginTopInches: marginTop,
      marginBottomInches: marginBottom,
      charsPerInch: _courierCharsPerInch,
      linesPerInch: _courierLinesPerInch,
      linesPerPage: (printableHeight * _courierLinesPerInch).floor(),
      sceneHeading: fullWidthLeftAligned(marginLeft),
      action: fullWidthLeftAligned(marginLeft),
      character: fullWidthLeftAligned(_characterIndentInches),
      parenthetical: fullWidthLeftAligned(_parentheticalIndentInches),
      dialogue: _elementLayout(
        leftIndentInches: _dialogueIndentInches,
        maxWidthInches: _dialogueMaxWidthInches,
        alignment: FountainLayoutAlignment.left,
      ),
      transition: _elementLayout(
        leftIndentInches: marginLeft,
        maxWidthInches: printableWidth,
        alignment: FountainLayoutAlignment.right,
      ),
      centeredText: _elementLayout(
        leftIndentInches: marginLeft,
        maxWidthInches: printableWidth,
        alignment: FountainLayoutAlignment.center,
      ),
      lyrics: _elementLayout(
        leftIndentInches: _dialogueIndentInches,
        maxWidthInches: _dialogueMaxWidthInches,
        alignment: FountainLayoutAlignment.left,
      ),
    );
  }

  /// Builds a [FountainElementLayout], deriving its character-column
  /// measurements from its inch measurements at [_courierCharsPerInch].
  static FountainElementLayout _elementLayout({
    required double leftIndentInches,
    required double maxWidthInches,
    required FountainLayoutAlignment alignment,
  }) => FountainElementLayout(
    leftIndentInches: leftIndentInches,
    leftIndentColumns: (leftIndentInches * _courierCharsPerInch).round(),
    maxWidthInches: maxWidthInches,
    maxWidthColumns: (maxWidthInches * _courierCharsPerInch).round(),
    alignment: alignment,
  );

  @override
  List<Object?> get props => [
    pageWidthInches,
    pageHeightInches,
    marginLeftInches,
    marginRightInches,
    marginTopInches,
    marginBottomInches,
    charsPerInch,
    linesPerInch,
    linesPerPage,
    sceneHeading,
    action,
    character,
    parenthetical,
    dialogue,
    transition,
    centeredText,
    lyrics,
  ];

  @override
  String toString() =>
      'FountainLayoutMetrics(${pageWidthInches}in x '
      '${pageHeightInches}in, $linesPerPage lines/page)';
}
