// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_alignment.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';

/// The layout box a single kind of printed screenplay element is set in:
/// how far it is indented from the page's left edge, how wide it is
/// allowed to grow, and how its text is aligned within that width.
///
/// Every measurement is given both in inches (the authoritative unit, since
/// screenplay layout conventions are defined in inches) and in character
/// columns of 12-point Courier, which is the monospaced font every
/// screenplay is traditionally set in. An indent is
/// `round(inches * charsPerInch)`; a width is *truncated* rather than
/// rounded, see [maxWidthColumns].
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

  /// [maxWidthInches] expressed in character columns, always **truncated**
  /// (never rounded up), so a line wrapped at this many columns is
  /// guaranteed to physically fit within [maxWidthInches].
  ///
  /// Rounding up would let the width of a full line exceed its own box:
  /// on A4, an action's 5.7677in width rounds to 58 columns, which measure
  /// 5.796in of 12-point Courier — 0.03in too wide. A renderer sizing the
  /// line's box from [maxWidthInches] then re-wraps the overflowing word
  /// onto a second line of its own, which lands on top of the next line of
  /// the page. Truncating cannot overshoot, since the font's real pitch is
  /// never wider than the nominal [FountainLayoutMetrics.charsPerInch].
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
