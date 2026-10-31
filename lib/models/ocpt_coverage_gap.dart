// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A run of printed text no shot covers, as the export washes it to mark it.
///
/// Emitted per printed row and per contiguous run of uncovered characters within it, already
/// trimmed of its surrounding whitespace: a wash is drawn behind words, never behind the blank
/// columns around them.
class OcptCoverageGap extends Equatable {
  /// The 0-based index, among the composed script pages, of the page this run is printed on.
  final int pageIndex;

  /// The 0-based row, within that page, this run is printed on.
  final int row;

  /// The 0-based column, within that line's own printed text, the run starts at.
  final int startColumn;

  /// The column one past the run's last character.
  final int endColumn;

  /// Class constructor
  const OcptCoverageGap({
    required this.pageIndex,
    required this.row,
    required this.startColumn,
    required this.endColumn,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptCoverageGap(page: $pageIndex, row: $row, columns: $startColumn-$endColumn)";

  /// Object properties
  @override
  List<Object?> get props => [pageIndex, row, startColumn, endColumn];
}
