// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One base region a merge's two diverging sides changed differently: the base lines that region
/// held, and what each side replaced them with.
class OcptThreeWayMergeHunk extends Equatable {
  /// The lines the common ancestor held in this region.
  final List<String> baseLines;

  /// The lines the first diverging side holds in the corresponding region.
  final List<String> leftLines;

  /// The lines the second diverging side holds in the corresponding region.
  final List<String> rightLines;

  /// Create a merge hunk.
  const OcptThreeWayMergeHunk({
    required this.baseLines,
    required this.leftLines,
    required this.rightLines,
  });

  /// Describe this [OcptThreeWayMergeHunk] for debugging and logging.
  @override
  String toString() =>
      'OcptThreeWayMergeHunk(baseLines: $baseLines, leftLines: $leftLines, rightLines: '
      '$rightLines)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [baseLines, leftLines, rightLines];
}
