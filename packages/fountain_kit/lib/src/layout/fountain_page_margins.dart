// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The four page margins a Fountain screenplay page is typeset with, in
/// inches.
///
/// Margins are a rendering preference: they anchor the boxes that stretch to
/// the printable area (scene heading, action, transition, centered text) and
/// determine [FountainLayoutMetrics.linesPerPage]/`printableWidthInches`/
/// `printableHeightInches`, but they never move the element indents that are
/// fixed relative to the *page's* left edge (character cues, parentheticals,
/// dialogue) — see `FountainLayoutMetrics`'s class doc.
class FountainPageMargins extends Equatable {
  /// Creates a [FountainPageMargins] with every margin given explicitly.
  /// Prefer [FountainPageMargins.standard] unless a non-standard margin set
  /// is genuinely required.
  const FountainPageMargins({
    required this.leftInches,
    required this.rightInches,
    required this.topInches,
    required this.bottomInches,
  });

  /// The standard US screenplay margins: 1.5 inches on the left, to leave
  /// room for three-hole-punch binding, and 1 inch on the top, right and
  /// bottom.
  const FountainPageMargins.standard()
    : leftInches = 1.5,
      rightInches = 1,
      topInches = 1,
      bottomInches = 1;

  /// The left page margin, in inches.
  final double leftInches;

  /// The right page margin, in inches.
  final double rightInches;

  /// The top page margin, in inches.
  final double topInches;

  /// The bottom page margin, in inches.
  final double bottomInches;

  /// Copy these margins and update the given elements.
  FountainPageMargins copyWith({
    double? leftInches,
    double? rightInches,
    double? topInches,
    double? bottomInches,
  }) => FountainPageMargins(
    leftInches: leftInches ?? this.leftInches,
    rightInches: rightInches ?? this.rightInches,
    topInches: topInches ?? this.topInches,
    bottomInches: bottomInches ?? this.bottomInches,
  );

  @override
  List<Object?> get props => [
    leftInches,
    rightInches,
    topInches,
    bottomInches,
  ];

  @override
  String toString() =>
      'FountainPageMargins(left: ${leftInches}in, right: ${rightInches}in, '
      'top: ${topInches}in, bottom: ${bottomInches}in)';
}
