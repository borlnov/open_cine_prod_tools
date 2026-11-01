// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_element_layout.dart';
import 'package:fountain_kit/src/layout/fountain_layout_alignment.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_styled_run.dart';
import 'package:fountain_kit/src/parser/fountain_line_type.dart';

/// One line of a paginated screenplay, already wrapped to its element's
/// column width and positioned in the page.
///
/// This is the line-level unit [FountainScriptComposer] emits: unlike the
/// source [FountainBlock]s (one per structural element, which may span
/// several printed lines once wrapped), every [FountainScriptLine] renders
/// as exactly one line of 12-point Courier. [leftIndentInches] and
/// [alignment] are copied from the owning element's
/// [FountainElementLayout] so a renderer never needs to look the element
/// type back up in [FountainLayoutMetrics]; [leftIndentInches] is kept in
/// inches (not columns) because the PDF renderer's own math is in
/// inches-to-points.
class FountainScriptLine extends Equatable {
  /// The line's text, already split into inline-styled runs. Empty for a
  /// blank spacer line or a preserved blank dialogue line (both are real,
  /// distinct lines that still occupy one row of the page).
  final List<FountainStyledRun> runs;

  /// The structural role of the element this line belongs to, for a
  /// renderer that wants to special-case, for example, transitions or
  /// centered text beyond what [alignment] already conveys. A blank spacer
  /// line inserted between two blocks carries [FountainLineType.blank].
  final FountainLineType lineType;

  /// The distance from the page's left edge to where this line starts, in
  /// inches, copied from the owning element's
  /// [FountainElementLayout.leftIndentInches].
  final double leftIndentInches;

  /// How this line is aligned within its element's box, copied from the
  /// owning element's [FountainElementLayout.alignment].
  final FountainLayoutAlignment alignment;

  /// Whether this line is (part of) a scene heading, so a renderer can
  /// place a scene number in both margins opposite it when the option to
  /// print scene numbers is on.
  final bool isSceneHeading;

  /// The scene number to print in the margins opposite this line, or
  /// `null` if [isSceneHeading] is `false` or the heading had no explicit
  /// `#...#` scene number in the source. Never auto-generated here: a
  /// heading with no explicit number stays unnumbered, by design.
  final String? sceneNumber;

  /// Whether this line is composed text with no source behind it: the
  /// `(MORE)` token closing a split dialogue group, and the `NAME (CONT'D)`
  /// cue repeated at the top of the page it continues onto.
  ///
  /// A synthetic line never carries a [sourceRange], but the converse does
  /// not hold — a blank spacer line has no range either and is not synthetic.
  /// A consumer mapping source offsets onto printed rows needs to tell the
  /// two apart: both are bridged over rather than resolved, but only a
  /// synthetic line renders text that the source never contained.
  final bool isSynthetic;

  /// This line's text with its inline styling discarded, i.e. the
  /// concatenation of every run's [FountainStyledRun.text] in order.
  String get plainText => runs.map((run) => run.text).join();

  /// The span of source text this printed line was composed from, or `null`
  /// when it has none: a blank spacer line, a preserved blank dialogue line,
  /// a synthetic line, or a line the composer could not anchor in the
  /// document's source text (see [FountainScriptComposer.compose]).
  ///
  /// It is the union of this line's runs' own
  /// [FountainStyledRun.sourceRange]s. Since no run's range covers its own
  /// emphasis markers, a marker *between* two runs of a line is part of that
  /// line's range while one sitting at either end of it is not — nothing on
  /// the line renders it. Consecutive printed lines of one wrapped paragraph
  /// have adjacent, non-overlapping ranges: the space a line breaks at
  /// belongs to neither of them, exactly as it belongs to neither line's
  /// text.
  FountainSourceRange? get sourceRange {
    FountainSourceRange? result;
    for (final run in runs) {
      final range = run.sourceRange;
      if (range == null) {
        continue;
      }
      result = result == null ? range : result.merge(range);
    }
    return result;
  }

  /// Creates a [FountainScriptLine].
  const FountainScriptLine({
    required this.runs,
    required this.lineType,
    required this.leftIndentInches,
    required this.alignment,
    required this.isSceneHeading,
    this.sceneNumber,
    this.isSynthetic = false,
  });

  @override
  String toString() =>
      'FountainScriptLine($lineType, "$plainText", '
      'indent: ${leftIndentInches}in)';

  @override
  List<Object?> get props => [
    runs,
    lineType,
    leftIndentInches,
    alignment,
    isSceneHeading,
    sceneNumber,
    isSynthetic,
  ];
}
