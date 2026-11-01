// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_script_line.dart';

/// One printed page of a paginated screenplay: an ordered list of
/// positioned lines, already fitted to [FountainLayoutMetrics.linesPerPage].
class FountainScriptPage extends Equatable {
  /// This page's lines, top to bottom.
  final List<FountainScriptLine> lines;

  /// Create a [FountainScriptPage].
  const FountainScriptPage({required this.lines});

  /// Describe this [FountainScriptPage] for debugging and logging.
  @override
  String toString() => 'FountainScriptPage(${lines.length} lines)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [lines];
}
