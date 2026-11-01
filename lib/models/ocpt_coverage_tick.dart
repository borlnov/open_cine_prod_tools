// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';

/// The exact character a coverage range starts or ends at, when that boundary falls inside a
/// printed line rather than on its first or last column.
///
/// This is the short vertical stroke the reference document draws inside the text itself
/// (`…sérieux.▌A sa gauche…`), telling a reader which half of the line the bar beside it actually
/// covers.
class OcptCoverageTick extends Equatable {
  /// The 0-based row, within its page, of the printed line this tick sits on.
  final int row;

  /// The 0-based column, within that line's own printed text
  /// ([FountainScriptLine.plainText]), the tick is drawn before.
  final int column;

  /// Class constructor
  const OcptCoverageTick({required this.row, required this.column});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptCoverageTick(row: $row, column: $column)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [row, column];
}
